/*******************************************************************************
      VA Estimation
      June 2025
      Instructions: Change the path at the beginning of the script
*******************************************************************************/

*ssc install vam
clear all

// Defining locals
	local path "C:\Users\didac\Dropbox\Arbiter Research\Data analysis"
	local datapull = "20260513" 
	local estimation_sample_enddate = 19122025 // 3 months?
	local min_med_cases = 2 // Minimum cases per mediator
	local min_cs_med = 2 // Minimum mediators per courtstation
	local small_cs = 35 // Small cs indicator
	local small_ct = 2 // Small ct indicator
	
/*
Drop cases that:
- Have a missing mediator ID
- Appointment date missing but mediator appointed
- Conclusion date before mediator is assigned
- Pandemic cases (15032020 to 30062021)

Mediators with only 1 case are included in the estimation, but their ID is pooled.
They are like one mediator in the estimation.
*/

/*******************************************************************************
      DATA PREPARATION
*******************************************************************************/

// Import data
	use "`path'\Data_Clean\cases_cleaned_`datapull'.dta", clear

// Gen days since appointment
	gen days_since_appt = date("`datapull'", "YMD") - med_appt_date

// Drop cases with data "issues"
	drop if issue1 == 1 // Missing mediator ID
	drop if issue2 == 2 // Appointment date missing but mediator appointed
	drop if issue3 == 3 // Conclusion date before mediator is assigned
	drop if issue4 == 4 // Pandemic cases

// Indicator for mediators with less than `min_med_cases' total completed cases
	bys mediator_id: gen totalcases=_N if casestatus == 1
	egen totalcases2 = count(totalcases), by(mediator_id)
	replace mediator_id = -999 if totalcases2 < `min_med_cases' 

// Indicator for courtstations with less than `min_cs_med' total completed cases
	bys courtstation: gen totalcscases=_N if med_appt_date < date("`estimation_sample_enddate'", "DMY") & casestatus == 1 // Total courtstation cases
	egen totalcscases2 = count(totalcscases), by(courtstation)
	replace courtstation = 999 if totalcscases2 <= `small_cs'

// Indicator for case types with less than 2 completed cases
	bys casetype_simplified: gen totalctcases=_N if med_appt_date < date("`estimation_sample_enddate'", "DMY") & casestatus == 1 // Total courtstation cases
	egen totalctcases2 = count(totalctcases), by(casetype_simplified)
	replace casetype_simplified = 999 if totalctcases2 < `small_ct'

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


	// Omitted variables
	replace courtstation = 0 if court_station == "MILIMANI" 
	replace referralmode = 0 if referral_mode == "Referred by Court"
	/* ib1.appt_month: January
	ib0.quasiyear: Closest six months
	ib0.casetype_simplified: Family group
	i.highcourt: 0 (no)
	i.courtofappeal: 0 (no)
	*/
	
	
	// Main Regression
	areg case_outcome_agreement ib1.appt_month ib0.quasiyear ///
	ib1.casetype_simplified i.highcourt i.courtofappeal ///
	ib0.courtstation ib0.referralmode if days_since_appt >= 180 & ///
	med_appt_date < date("`estimation_sample_enddate'", "DMY"), ///
	vce(robust) absorb(mediator_id)



// VARIANCE OF P_HAT
/* 

//	We estimate (in matrix notation):

		y_i = X_i' \beta + epsilon_i

	** X_i s a kx1 vector containing all the independent variable values of
	the regression for an individual i. They are always 0-1 indicatiors
		X_i' = (X1_i, X2_i..., Xk_i) 
		
	** \beta is a kx1 vector containg the coefficients
	
	
//	The variance of p-hat can be written as:

		Var(p_hat_i) = Var(X_i' \beta_hat) = X_i' Var(beta_hat) X_i
		
	** X_i is a kx1 vector containing all the independent variable values of
	the regression for an individual i
	** \beta_hat is a kx1 vector containg the estimated coefficients
	** Var(beta_hat) is the kxk variance-covariance matrix of the 
	coefficients

	The formula of the variance can be rewritten as:
	
	Var(p_hat_i) =
	(X1*V[1,1] + X2*V[2,1] + X3*V[3,1] + ... + X3*V[k,1])*X1
	+
	(X1*V[1,2] + X2*V[2,2] + X3*V[3,2] + ... + X3*V[k,2])*X2
	+ ... +
	(X1*V[1,k] + X2*V[2,k] + X3*V[3,k] + ... + X3*V[k,k])*Xk
		
*/
/*
	matrix V = e(V)
	matrix b = e(b)

	// Generate X_i
		// appt_month
		local j = 0
		levelsof appt_month, local(appt_month_vals)
		foreach i in `appt_month_vals' {
			local j = `j'+1
			gen X_`j' = 1 if appt_month == `i'
			replace X_`j' = 0 if X_`j' == .		
		}		
		
		// quasiyear 
		levelsof quasiyear, local(quasiyear_vals)
		foreach i in `quasiyear_vals' {
			local j = `j'+1
			gen X_`j' = 1 if quasiyear == `i'
			replace X_`j' = 0 if X_`j' == .		
		}	
		
		// casetype_simplified
		levelsof casetype_simplified, local(casetype_simplified_vals)
		foreach i in `casetype_simplified_vals' {
			local j = `j'+1
			gen X_`j' = 1 if casetype_simplified == `i'
			replace X_`j' = 0 if X_`j' == .		
		}
		// High court
		local j = `j'+1 
		gen X_`j' = 1 if highcourt == 0
		replace X_`j' = 0 if X_`j' == .
		local j = `j'+1 
		gen X_`j' = 1 if highcourt == 1
		replace X_`j' = 0 if X_`j' == .
		// Court of appeal
		local j = `j'+1 
		gen X_`j' = 1 if courtofappeal == 0
		replace X_`j' = 0 if X_`j' == .
		local j = `j'+1 
		gen X_`j' = 1 if courtofappeal == 1
		replace X_`j' = 0 if X_`j' == .
		// Courtstation
		levelsof courtstation, local(courtstation_vals)
		foreach i in `courtstation_vals' {
			local j = `j'+1
			gen X_`j' = 1 if courtstation == `i'
			replace X_`j' = 0 if X_`j' == .		
		}
		// Referral mode
		levelsof referralmode, local(referralmode_vals)
		foreach i in `referralmode_vals' {
			local j = `j'+1
			gen X_`j' = 1 if referralmode == `i'
			replace X_`j' = 0 if X_`j' == .		
		}	
		// Constant
		local j = `j'+1
		gen X_`j' = 1

	// p_pred var (variance of predictions)
	gen p_pred_var = 0
	forvalues i = 1(1)90{
		forvalues j = 1(1)90{
			replace p_pred_var = p_pred_var + (X_`j'*V[`j',`i'])*X_`i'
		}
	}
*/
	
// Recent cases
	replace case_outcome_agreement = 0 if casestatus == 2 & case_days_med > 90
	drop if casestatus == 2 & case_days_med <= 90 // Drop pending cases appointed

// Predictions
	predict p_pred, xb // predicted agreeement
	/*
	gen p_pred_alt = 0

	forvalues j = 1(1)90{
		replace p_pred_alt = p_pred_alt + X_`j'*b[1,`j']
	}*/


// Residuals
	gen residuals = case_outcome_agreement - p_pred // case residual

// Keep only mediators with at least 2 cases to calculate VA
*keep if totalcases2 >= `min_med_cases'

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
	file open sigma using "`path'\Output\VA\sigma_STATA_`datapull'.txt", write replace //create temporary text file
	file write sigma "sigma" _n // columns headers
	file write sigma (cov_avgs_sd)  _n // write locals separated by commas into the text file
	file close sigma
	copy "`path'\Output\VA\sigma_STATA_`datapull'.txt" "`path'\Output\VA\sigma_STATA_`datapull'.csv", replace //change extension to csv
	rm "`path'\Output\VA\sigma_STATA_`datapull'.txt" //remove text file

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
	gen va = naive_med * shrinkage_med

/*******************************************************************************
      MLE ESTIMATION
*******************************************************************************/
/*
egen case_outcome_agreement_medmean = mean(case_outcome_agreement), by(mediator_id)
gen sq = sqrt(2*c(pi))
gen sd = .

program define lll
	args lnf sd va
	quietly replace `lnf' = ln( (p_pred+ln(`va')) * sq * ln(`sd') ) if case_outcome_agreement==1
	quietly replace `lnf' = ln( 1 - (p_pred+ln(`va')) * sq * ln(`sd') ) if case_outcome_agreement==0
end

preserve
keep if mediator_id == 1585
ml model lf lll (va:) (sd:)
ml init va:_cons = 1.2
ml init sd:_cons = 1.2
ml maximize, trace
restore

local ee = ln(48)
di `ee'
* 1518
*1662

tempfile allmeds 
save `allmeds'

levelsof mediator_id, local(meds)
di `meds'

foreach mid in `meds'{
	
	qui keep if mediator_id == `mid'
	
	if case_outcome_agreement_medmean != 0 & case_outcome_agreement_medmean != 1{
		ml model lf lll () 
		ml init _cons = 0.1
		qui ml maximize //, trace
		qui gen sd_temp = r(table)[1,1] if mediator_id == `mid'
	}
	else{
		qui gen sd_temp = .
	}
	
	collapse sd_temp, by(mediator_id)	
	qui merge 1:m mediator_id using `allmeds'
	qui replace sd = sd_temp if mediator_id == `mid'
	drop sd_temp _merge
	tempfile allmeds 
	qui save `allmeds'
}

*/
*******************************************************************************

/*
** WORKING ONLY SD ESTIMATION -- THE GOOD ONE

egen case_outcome_agreement_medmean = mean(case_outcome_agreement), by(mediator_id)
gen sq = sqrt(2*c(pi))
gen sd = .

program define lll
	args lnf sd
	quietly replace `lnf' = ln( (p_pred+va) * sq * `sd' ) if case_outcome_agreement==1
	quietly replace `lnf' = ln( 1 - (p_pred+va) * sq * `sd' ) if case_outcome_agreement==0
end


tempfile allmeds 
save `allmeds'

levelsof mediator_id, local(meds)
di `meds'

foreach mid in `meds'{
	
	qui keep if mediator_id == `mid'
	
	if case_outcome_agreement_medmean != 0 & case_outcome_agreement_medmean != 1{
		ml model lf lll () 
		ml init _cons = 0.1
		qui ml maximize //, trace
		qui gen sd_temp = r(table)[1,1] if mediator_id == `mid'
	}
	else{
		qui gen sd_temp = .
	}
	
	collapse sd_temp, by(mediator_id)	
	qui merge 1:m mediator_id using `allmeds'
	qui replace sd = sd_temp if mediator_id == `mid'
	drop sd_temp _merge
	tempfile allmeds 
	qui save `allmeds'
}
*/

/*

************************************************************************
****** Example 1: stata webpage ********
sysuse auto, clear

** Log-likelihood function 
program define mylogit
	  args lnf Xb
	  quietly replace `lnf' = -ln(1+exp(-`Xb')) if $ML_y1==1
	  quietly replace `lnf' = -`Xb' - ln(1+exp(-`Xb')) if $ML_y1==0
end

ml model lf mylogit (foreign=mpg weight)
ml maximize


************************************************************************
****** Example 2: Slides ********
* Maximize likelihood
sysuse auto, clear

program myprobit_lf
version 10.0
args lnf xb
quietly replace `lnf' = ln(normal( `xb' )) ///
if $ML_y1 == 1
quietly replace `lnf' = ln(normal( -`xb' )) ///
if $ML_y1 == 0
end

gen gpm = 1/mpg
ml model lf myprobit_lf ///
(foreign = price gpm displacement)
ml maximize

************************************************************************
****** Example 3: Slides ********


program mynormal_lf
version 10.0
args lnf mu sigma
quietly replace `lnf' = ///
ln(normalden( $ML_y1, `mu', `sigma' ))
end

* Version 1
ml model lf mynormal_lf ///
(mpg = weight displacement) /// mu
() // sigma
ml maximize

* Version 2: Same, different notation
ml model lf mynormal_lf ///
(mpg = weight displacement) /sigma
ml maximize


************************************************************************
* Working test

gen ones = 1
gen sq = sqrt(2*c(pi))
program define lll
	args lnf sd
	quietly replace `lnf' = ln( (p_pred+va_new) * sq * `sd' ) if $ML_y1==1
	quietly replace `lnf' = ln( 1 - (p_pred+va_new) * sq * `sd' ) if $ML_y1==0
end

*tempfile allmeds 
*save `allmeds'

preserve
keep if mediator_id == 1603
ml model lf lll ///
(case_outcome_agreement = ones) 
ml maximize
restore


program drop lll


************************************************************************
* Working test 2
egen case_outcome_agreement_medmean = mean(case_outcome_agreement), by(mediator_id)
gen sq = sqrt(2*c(pi))
gen sd = .

program define lll
	args lnf sd
	quietly replace `lnf' = ln( (p_pred+va) * sq * `sd' ) if case_outcome_agreement==1
	quietly replace `lnf' = ln( 1 - (p_pred+va) * sq * `sd' ) if case_outcome_agreement==0
end


*tempfile allmeds 
*save `allmeds'



levelsof mediator_id, local(meds)
di `meds'

foreach mid in `meds'{
	
	preserve
	
	keep if mediator_id == `mid'
	if case_outcome_agreement_medmean != 0 & case_outcome_agreement_medmean != 1{
		tab mediator_id
		*tab case_outcome_agreement_medmean
		ml model lf lll () 
		ml init _cons = 0.1
		qui ml maximize //, trace
	}
	restore
	matrix list r(table)
	*replace sd = r(table)[1,1] if mediator_id == `mid'
}

program drop lll


preserve
keep if mediator_id == 2
tab mediator_id
ml model lf lll () 
ml init _cons = 0.1
ml maximize //, trace
matrix list r(table)
restore



/*
1601
https://www.wolframalpha.com/input?i=f%28x%29+%3D+ln%28+1+-+.4115147+*+sqrt%282*pi%29+*+x%29+%2B++ln%28+.6285434+*+sqrt%282*pi%29+*+x%29

* Doesnt work if all outcomes are the same (0 or 1) e.g. 
1655
1604

* Important to have good initial values, otherwise it may fail 
1410
*/


************************************************************************
****** Baseline ******** 
** Log-likelihood function
program drop ll
program define ll
	  args lnf sd
	  quietly replace `lnf' = ln( (p_pred+va) * sqrt(2*c(pi)) * `sd' ) if $ML_y1==1
	  quietly replace `lnf' = ln( 1 - (p_pred+va) * sqrt(2*c(pi)) * `sd' ) if $ML_y1==0
end

* Maximize likelihood
ml model lf ll (case_outcome_agreement=ones)
ml maximize


***********************************************************************



** Log-likelihood function

global xp = p_pred
global xv = va

*
program drop ll
program define ll
	  args lnf sd
	  quietly replace `lnf' = ln( ( $xp + $xv ) * sqrt(2*c(pi)) * `sd' ) if $ML_y1==1
	  quietly replace `lnf' = ln( 1 - ($xp + $xv) * sqrt(2*c(pi)) * `sd' ) if $ML_y1==0
end

* Maximize likelihood
ml model lf ll (case_outcome_agreement=ones)
ml maximize

***********************************************************************

** Log-likelihood function
program drop ll
program define ll
	  args lnf sd
	  quietly replace `lnf' = ln( (p_pred+va) * sqrt(2*c(pi)) * `sd' ) if $ML_y1==1
	  quietly replace `lnf' = ln( 1 - (p_pred+va) * sqrt(2*c(pi)) * `sd' ) if $ML_y1==0
end

* Maximize likelihood
ml model lf ll (case_outcome_agreement=ones)
ml maximize




*/

/*******************************************************************************
      CASE PREDICTIONS VS OUTCOME
*******************************************************************************/

/*
      gen p_pred_va = p_pred + va // Shrunk
      
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

*rename sd sd_mle_stata
*rename va va_stata

// p's
// Save predicted p's in csv
preserve
keep if med_appt_date < date("`estimation_sample_enddate'", "DMY")
export delimited id mediator_id p_pred /*p_pred_var*/ va  case_outcome_agreement /*case_outcome_agreement_medmean totalcases2*/ using  "`path'\Output\VA\p_pred_STATA_`datapull'.csv", replace
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
graph export "`path'\Output\Model_input\p_pred_distrib_ctypes.png", replace */

// VA
preserve
collapse va totalcases2, by(mediator_id)
// Graph: Distribution VA
/*hist va, width(.01) freq start(-.3) width(0.025) ///
note("Mean: `r(mean)'. Standard deviation: `r(sd)'") ///
xtitle(Value Added) ytitle(Frequency) title(Value Added distribution)
graph export "`path'/Output/Model_input\VA_distribution.png", as(png) replace */
// Export VA's
export delimited mediator_id va totalcases2  using  "`path'\Output\VA\VA_STATA_`datapull'.csv", replace
restore