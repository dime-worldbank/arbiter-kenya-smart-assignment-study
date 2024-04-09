
version 17
clear all

*net install grc1leg, from( http://www.stata.com/users/vwiggins/)

//Defining locals 
local path "C:\Users\didac\Dropbox\Arbiter Research\Data analysis"
local datapull = "15062023" // "11062023" //"05102022" //  "27022023" 
local min_cases = 4 



/*****************************************************************
	 Smart Assignment
******************************************************************/

*import delimited "`path'\Data_Raw\study_case_last_action_2024-03-13T09_25_08.693152Z.csv", clear

import delimited "`path'\Data_Raw\Vw_All_Random_Study_Case_20032024.csv", clear

drop if istest == "true" // Drop technical testing cases

tab acceptanceorerrorstatus

keep if acceptanceorerrorstatus == "accepted" | acceptanceorerrorstatus == "rejected" // Keep only accepted and rejected cases

*drop id
*rename case_id id

keep acceptanceorerrorstatus id

tempfile SA
save `SA'


/*****************************************************************
	 VALUE ADDED: Preparation of data from up to June 15, 2023
******************************************************************/

// Import data
use "`path'\Data_Clean\cases_cleaned_`datapull'.dta", clear

// Keep only cases relevant for the VA calculations 
	//Case status, drop pending cases
	drop if case_status == "PENDING"

	//Keep only relevant cases 
	keep if usable == 1 // Keeping only relevant case types
	drop if issue == 6 | issue == 7 // Dropping pandemic months and newest cases (cutoff)

//Keep only courtstations with >=10 cases
	bys courtstation:gen stationcases = _N
	drop if stationcases<10

//Keep only mediators with at least K total cases
	bys mediator_id: gen totalcases=_N //Total cases with relevant case types 
	keep if totalcases >= `min_cases'

	egen med_year=group(mediator_id appt_year)
	
// Generate half-calendar-year indicator variable
	gen appt_firsthalf_year = 1 if appt_month <= 6 // First half year
	replace appt_firsthalf_year = 0 if appt_month >=7 // Second half year
	egen appt_halfyear = group(appt_firsthalf_year appt_year) // half-year indicator variable
	
	
/*****************************************************************
	 VALUE ADDED: Calculate Shrunk and unshrunk
******************************************************************/
	
// Shrunk VA
	vam case_outcome_agreement, teacher(mediator_id) year(appt_year) class(med_year) controls(i.appt_year i.casetype i.courttype i.courtstation i.referralmode) tfx_resid(mediator_id) data(merge tv) // Use calendary-years
	bys mediator_id: egen va_shrunk=mean(tv) // Shrunk VA
	
// Unshrunk VA
	areg case_outcome_agreement i.appt_year i.casetype i.courttype i.courtstation i.referralmode, absorb(mediator_id)
	predict residuals, dr
	predict mediator_d, d
	bys mediator_id: egen va_unshrunk=mean(residuals) // Unshrunk VA
	
// Collapse VA's at mediator level
collapse va_shrunk va_unshrunk mediator_d, by(mediator_id)


*******************************************************************
*******************************************************************



/*****************************************************************
	 Add Cases Smart Assignment cases
******************************************************************/


// Merge with more recent cases
merge 1:m mediator_id using "`path'\Data_Clean\cases_cleaned_20032024"
drop if _merge == 2
drop _merge

merge 1:1 id using `SA'
keep if _merge == 3

count if va_shrunk != . & acceptanceorerrorstatus == "accepted"
count if va_shrunk == . & acceptanceorerrorstatus == "accepted"
count if va_shrunk != . & acceptanceorerrorstatus == "rejected"
count if va_shrunk == . & acceptanceorerrorstatus == "rejected"

keep if acceptanceorerrorstatus == "accepted"

/*****************************************************************
	 Predicted values calculation
******************************************************************/

// Predicted values
	predict p_random, xb
	gen p_s = p_random + va_shrunk // Shrunk
	gen p_u = p_random + mediator_d // Unshrunk
	
	
/*****************************************************************
	 Results
******************************************************************/

drop if case_outcome_agreement==.

// Correlations
corr case_outcome_agreement p_s
corr case_outcome_agreement p_u	

// Agreement rates T vs C
	* Shrunk
	tab case_outcome_agreement if va_shrunk < 0 & va_shrunk != . // 36% agreement. 
	  // SA 45 agreement, 29 no agreement -> 61% agreement
	tab case_outcome_agreement if va_shrunk > 0 & va_shrunk != . // 60% agreement. 
	  // SA 57 agreement, 28 no agreement -> 67% agreement
	* Unsrhunk
	tab case_outcome_agreement if va_unshrunk < 0 // 41% agreement
	tab case_outcome_agreement if va_unshrunk > 0 // 61% agreement

// Kernel reg case outcome on predicted outcome
	* Shrunk
	lprobust case_outcome_agreement p_s, p(1) neval(100) genvars bwselect(mse-dpi) plot
	tw (scatter case_outcome_agreement p_s if p_s < 1 & p_s > 0, msize(tiny)) ///
		(line lprobust_gx_us lprobust_eval if lprobust_eval < 1 & lprobust_eval > 0, sort lcolor(red)) ///
		(line lprobust_CI_l_rb lprobust_eval if lprobust_eval < 1 & lprobust_eval > 0, sort lcolor(blue) lpattern(dash) mcolor(%30)) ///
		(line lprobust_CI_r_rb lprobust_eval if lprobust_eval < 1 & lprobust_eval > 0 & lprobust_CI_r_rb<=1, sort lcolor(blue) lpattern(dash) mcolor(%30) ///
		aspectratio(1)  xtitle("Predicted agreement rate") ytitle("Case outcome") ///
		legend(pos(6) order(1 "Cases" 2 "Kernel reg" 3 "Confidence interval") cols(3))  ///
		title("Shrunk VA") ///
		name(sa_shrunk, replace) )
	*graph export "`path'/Output/pred_vs_outcome_kernel_s.png", as(png) replace
	drop lprobust_*
	* Unshrunk
	lprobust case_outcome_agreement p_u, p(1) neval(100) genvars bwselect(mse-dpi) plot
	tw (scatter case_outcome_agreement p_u if p_u < 1 & p_u > 0, msize(tiny)) ///
		(line lprobust_gx_us lprobust_eval if lprobust_eval < 1 & lprobust_eval > 0, sort lcolor(red)) ///
		(line lprobust_CI_l_rb lprobust_eval if lprobust_eval < 1 & lprobust_eval > 0, sort lcolor(blue) lpattern(dash) mcolor(%30)) ///
		(line lprobust_CI_r_rb lprobust_eval if lprobust_eval < 1 & lprobust_eval > 0, sort lcolor(blue) lpattern(dash) mcolor(%30) ///
		aspectratio(1)  xtitle("Predicted agreement rate") ytitle("Case outcome") ///
		legend(pos(6) order(1 "Cases" 2 "Kernel reg" 3 "Confidence interval") cols(3) )  ///
		title("Unhrunk VA") ///
		name(sa_unshrunk, replace) )
	*graph export "`path'/Output/pred_vs_outcome_kernel_u.png", as(png) replace
	
grc1leg sa_shrunk sa_unshrunk, ycommon xcommon t1title("Smart Assignment")
graph export "`path'/Output/pred_vs_outcome_kernel_SA.png", as(png) replace


/*******************************************************************
*******************************************************************



/*****************************************************************
	 Add Cases from June 15, 2023 to October 13, 2023
******************************************************************/

// Merge with more recent cases
merge 1:m mediator_id using "`path'\Data_Clean\cases_cleaned_13032024"
drop if _merge == 2

// Keep only dates after VA calc and start of Smart assignment
keep if med_appt_date > date("15Jun2023","DMY")
keep if med_appt_date < date("13Oct2023","DMY")

/*****************************************************************
	 Predicted values calculation
******************************************************************/

// Predicted values
	predict p_random, xb
	gen p_s = p_random + va_shrunk // Shrunk
	gen p_u = p_random + mediator_d // Unshrunk


/*****************************************************************
	 Results
******************************************************************/

drop if case_outcome_agreement==.

// Correlations
corr case_outcome_agreement p_s
corr case_outcome_agreement p_u	

// Agreement rates T vs C
	* Shrunk
	tab case_outcome_agreement if va_shrunk < 0 & va_shrunk != . // 36% agreement. 
	  // SA 45 agreement, 29 no agreement -> 61% agreement
	tab case_outcome_agreement if va_shrunk > 0 & va_shrunk != . // 60% agreement. 
	  // SA 57 agreement, 28 no agreement -> 67% agreement
	* Unsrhunk
	tab case_outcome_agreement if va_unshrunk < 0 // 41% agreement
	tab case_outcome_agreement if va_unshrunk > 0 // 61% agreement

// Kernel reg case outcome on predicted outcome
	* Shrunk
	lprobust case_outcome_agreement p_s, p(1) neval(100) genvars bwselect(mse-dpi) plot
	tw (scatter case_outcome_agreement p_s if p_s < 1 & p_s > 0, msize(tiny)) ///
		(line lprobust_gx_us lprobust_eval if lprobust_eval < 1 & lprobust_eval > 0, sort lcolor(red)) ///
		(line lprobust_CI_l_rb lprobust_eval if lprobust_eval < 1 & lprobust_eval > 0, sort lcolor(blue) lpattern(dash) mcolor(%30)) ///
		(line lprobust_CI_r_rb lprobust_eval if lprobust_eval < 1 & lprobust_eval > 0, sort lcolor(blue) lpattern(dash) mcolor(%30) ///
		aspectratio(1)  xtitle("Predicted agreement rate") ytitle("Case outcome") ///
		legend(pos(6) order(1 "Cases" 2 "Kernel reg" 3 "Confidence interval") cols(3))  ///
		title("Shrunk VA") ///
		name(sa_shrunk, replace) )
	*graph export "`path'/Output/pred_vs_outcome_kernel_s.png", as(png) replace
	drop lprobust_*
	* Unshrunk
	lprobust case_outcome_agreement p_u, p(1) neval(100) genvars bwselect(mse-dpi) plot
	tw (scatter case_outcome_agreement p_u if p_u < 1 & p_u > 0, msize(tiny)) ///
		(line lprobust_gx_us lprobust_eval if lprobust_eval < 1 & lprobust_eval > 0, sort lcolor(red)) ///
		(line lprobust_CI_l_rb lprobust_eval if lprobust_eval < 1 & lprobust_eval > 0, sort lcolor(blue) lpattern(dash) mcolor(%30)) ///
		(line lprobust_CI_r_rb lprobust_eval if lprobust_eval < 1 & lprobust_eval > 0, sort lcolor(blue) lpattern(dash) mcolor(%30) ///
		aspectratio(1)  xtitle("Predicted agreement rate") ytitle("Case outcome") ///
		legend(pos(6) order(1 "Cases" 2 "Kernel reg" 3 "Confidence interval") cols(3) )  ///
		title("Unhrunk VA") ///
		name(sa_unshrunk, replace) )
	*graph export "`path'/Output/pred_vs_outcome_kernel_u.png", as(png) replace
	
grc1leg sa_shrunk sa_unshrunk, ycommon xcommon t1title("Historical data")
graph export "`path'/Output/pred_vs_outcome_kernel_hist.png", as(png) replace






