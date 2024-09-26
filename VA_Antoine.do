/*******************************************************************************
      VA Estimation
      July 2024
      Instructions: Change the path at the beginning of the script
*******************************************************************************/

*ssc install vam
clear all

// Defining locals
*local path "C:\Users\user\Dropbox\Arbiter Research\Data analysis"
local path "C:\Users\didac\Dropbox\Arbiter Research\Data analysis"
local datapull = 20092024 //"02062024" // "15062023" //  "11062023" //"05102022" //  "27022023"
local estimation_sample_enddate = 18042024 // 01062023 // 19042024 //31122022 // 15102023 // 19042024 // 30062023 //
local min_med_cases = 2 // Minimum cases per mediator
local min_cs_med = 2 // Minimum mediators per courtstation
local small_cs = 35

/*******************************************************************************
      DATA PREPARATION
*******************************************************************************/

// Import data
use "`path'\Data_Clean\cases_cleaned_`datapull'.dta", clear

// Gen days since appointment
gen days_since_appt = date("`datapull'", "DMY") - med_appt_date

// Drop cases with data "issues"
//drop if issue = 1 | issue = 2 | issue = 3 | issue = 4 | issue = 7 |
drop if issue1 == 1 // 255 Missing mediator ID
//drop if issue2 == 2 // 0 Mediator appointed before referral
drop if issue3 == 3 // 63 Appointment date missing but mediator appointed
drop if issue4 == 4 // 1 Conclusion date before mediator is assigned
//drop if issue5 == 5 // 0 Conclusion date after data pull date
drop if issue7 == 7 // Pandemic cases

// Keep only mediators with at least X total cases
bys mediator_id: gen totalcases=_N if med_appt_date < date("`estimation_sample_enddate'", "DMY") & casestatus == 1
egen totalcases2 = count(totalcases), by(mediator_id)
keep if totalcases2 >= `min_med_cases'

// Keep only courtstations with >=Y mediators
egen tag = tag(mediator_id courtstation)
egen ndistinct_med_cs = total(tag), by(courtstation) // num mediators in cs
keep if ndistinct_med_cs >= `min_med_cases'
drop tag

// Generate courtsation number of cases
bys courtstation: gen totalcscases=_N
replace courtstation = 999 if totalcscases <= `small_cs'

// Generate quasi-year FE
// "p": Generate a 12-months-indicators variable with shorter (6-months)
// for the latest data, and longer (12 to 23) months for the oldest data
gen quasiyear = .
qui summ appt_month_year
// 12 months
forvalues t = 0(1)30{
local lb = `t'*12
local ub = `t'*12 + 12
replace quasiyear = `t' if appt_month_year <= `r(max)' - `lb' ///
& appt_month_year > `r(max)' - `ub'
}
// Oldest data 12 to 23 months
qui summ quasiyear
local oldest_qy = `r(max)'
qui summ appt_month_year if quasiyear == `oldest_qy'
if `r(max)'-`r(min)' < 12 {
replace quasiyear = quasiyear - 1 ///
if quasiyear == `oldest_qy'
}

/*******************************************************************************
      VALUE ADDED ESTIMATION
*******************************************************************************/

replace courtstation = 0 if court_station == "MILIMANI"

areg case_outcome_agreement ib1.appt_month ib0.quasiyear ///
ib14.casetype_simplified i.highcourt i.courtofappeal ///
ib0.courtstation i.referralmode if days_since_appt >= 180 & ///
med_appt_date < date("`estimation_sample_enddate'", "DMY"), ///
vce(robust) absorb(mediator_id)

// Recent cases
replace case_outcome_agreement = 0 if casestatus == 2 & case_days_med > 90
drop if casestatus == 2 & case_days_med <= 90 // Drop pending cases appointed

// Predictions
predict p_pred, xb // predicted agreeement

// Residuals
gen residuals = case_outcome_agreement - p_pred // case residual

// Average residuals by mediator on their first (calendar) half of cases
// and second half.
bys mediator_id: gen total_med_cases = _N
// First half
sort mediator_id med_appt_date id, stable
by mediator_id: egen temp1=mean(residuals) if _n<=total_med_cases/2
by mediator_id: egen average1=mean(temp1)
// Second half
sort mediator_id med_appt_date, stable
by mediator_id: egen temp2=mean(residuals) if _n>total_med_cases/2
by mediator_id: egen average2=mean(temp2)

// Covariance of average1 average2, for the whole sample
preserve
collapse average1 average2, by(mediator_id)
corr average1 average2, covariance
matrix covmat = r(C)
scalar cov_avgs = covmat[2,1]
restore
scalar cov_avgs_sd = sqrt(cov_avgs) // share
file open sigma using "`path'\Output\Model\sigma_STATA_`datapull'.txt", write replace //create temporary text file
file write sigma "sigma" _n // columns headers
file write sigma (cov_avgs_sd)  _n // write locals separated by commas into the text file
file close sigma
copy "`path'\Output\Model\sigma_STATA_`datapull'.txt" "`path'\Output\Model\sigma_STATA_`datapull'.csv", replace //change extension to csv
rm "`path'\Output\Model\sigma_STATA_`datapull'.txt" //remove text file

// Residual-average1 or Residual-average2. In the same variable
gen halfcases_dev = residuals - average1 if temp1 !=.
replace halfcases_dev = residuals - average2 if temp2 !=.

// Variance of previous variable for the whole sample
summ halfcases_dev
scalar var_halfcases_dev = (r(sd))^2

// Variance of residuals
summ residuals
scalar var_residuals = (r(sd))^2

// Scalar = variance of residuals - covariance average1&average2 - var_halfcases_dev
scalar final_rst = var_residuals - cov_avgs - var_halfcases_dev // Same for all pop

bys mediator_id: egen naive=mean(residuals)

gen h= 1/(final_rst+(var_halfcases_dev/(0.5*total_med_cases)))

gen h2 = 1/(2*h)

gen shrinkage = cov_avgs / (cov_avgs+h2)

egen shrinkage_med = mean(shrinkage), by(mediator_id)
egen naive_med = mean(naive), by(mediator_id)
gen va_new = naive_med * shrinkage_med

/*******************************************************************************
      CASE PREDICTIONS VS OUTCOME
*******************************************************************************/

/*
      gen p_pred_va = p_pred + va_new // Shrunk
      
      lprobust case_outcome_agreement p_pred_va, p(1) neval(100) genvars bwselect(mse-dpi) plot
      
      tw (scatter case_outcome_agreement p_pred_va if p_pred_va < 1 & p_pred_va > 0, msize(tiny)) ///
            (line lprobust_gx_us lprobust_eval if lprobust_eval < 1 & lprobust_eval > 0, sort lcolor(red)) ///
            (line lprobust_CI_l_rb lprobust_eval if lprobust_eval < 1 & lprobust_eval > 0, sort lcolor(blue) lpattern(dash) mcolor(%30)) ///
            (line lprobust_CI_r_rb lprobust_eval if lprobust_eval < 1 & lprobust_eval > 0, sort lcolor(blue) lpattern(dash) mcolor(%30) ///
            aspectratio(1)  xtitle("Predicted agreement rate") ytitle("Case outcome") ///
            legend(pos(6) order(1 "Cases" 2 "Kernel reg" 3 "Confidence interval") cols(3))  ///
            title("Shrunk VA") ///
            name(sa_shrunk, replace) )
*/

/*******************************************************************************
      EXPORT RESULTS
*******************************************************************************/
local path "C:\Users\didac\Dropbox\Arbiter Research\Data analysis"
local datapull = 18042024
// p's
// Save predicted p's in csv
preserve
keep if med_appt_date < date("`estimation_sample_enddate'", "DMY")
export delimited id p_pred temp1 average1 temp2 average2 case_outcome_agreement using  "`path'\Output\Model\p_pred_STATA_`datapull'.csv", replace
restore

/*
preserve
keep if med_appt_date > date("`estimation_sample_enddate'", "DMY")
export delimited id p_pred case_outcome_agreement using  "`path'\Output\Model_input\p_pred_predsample_`datapull'.csv", replace
restore
*/

// Graph predicted p's
/*summ p_pred
            hist p_pred, width(.01) freq width(0.025) ///
            xtitle(Predicted agreement probability - p) ytitle(Frequency) title(p distribution) note("Min: `r(min)'. Max: `r(max)'")
            graph export "`path'\Output\Model_input\p_pred_distrib.png", replace    
            tw (kdensity p_pred if casetype_simplified == 1) ///
            (kdensity p_pred if casetype_simplified != 1) ///
            (kdensity p_pred, legend(order(1 "Children Custody and Maintenance" 2 "Other case types" 3 "All case types")) xtitle(Predicted agreement probability - p) ytitle(Density))
graph export "`path'\Output\Model_input\p_pred_distrib_ctypes.png", replace         */

// VA
preserve
collapse va_new totalcases2, by(mediator_id)
// Graph: Distribution VA
summ va_new
/*hist va_new, width(.01) freq start(-.3) width(0.025) ///
note("Mean: `r(mean)'. Standard deviation: `r(sd)'") ///
xtitle(Value Added) ytitle(Frequency) title(Value Added distribution)
graph export "`path'/Output/Model_input\VA_distribution.png", as(png) replace */
// Export VA's
export delimited va_new totalcases2 mediator_id using  "`path'\Output\Model\VA_STATA_`datapull'.csv", replace
restore