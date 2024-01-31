/*****************************************************************
Project: World Bank Kenya Arbiter
PIs: Anja Sautmann and Antoine Deeb
Purpose: Power calculation
Author: Hamza Syed (based on Antoine's file)
Updated by: Didac Marti Pinto
******************************************************************/

ssc install vam

//Defining locals 
local path "C:\Users\didac\Dropbox\Arbiter Research\Data analysis"
local datapull = "15062023" // "11062023" //"05102022" //  "27022023" 
local min_cases = 4 

// Import data
use "`path'\Data_Clean\cases_cleaned_`datapull'.dta", clear

// Keep only cases relevant for the VA calculations 
	//Case status, drop pending cases
	tab case_status
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

// VA calculations
	* Basic
	vam case_outcome_agreement, teacher(mediator_id) year(appt_year) ///
	driftlimit(3) class(med_year) controls(i.appt_month_year i.casetype ///
	i.courttype i.courtstation i.referralmode) tfx_resid(mediator_id) ///
	data(merge tv)
	rename tv tv_basic
	* With Appointing CAM Officer FE
	vam case_outcome_agreement, teacher(mediator_id) year(appt_year) ///
	driftlimit(3) class(med_year) controls(i.appointer_user_id i.appt_month_year i.casetype ///
	i.courttype i.courtstation i.referralmode) tfx_resid(mediator_id) ///
	data(merge tv)	

collapse tv tv_basic, by(mediator_id)
gen diff = tv -tv_basic

corr tv tv_basic

twoway (kdensity tv) (kdensity tv_basic, ///
legend( order(1 "Mediators VA" 2 "Mediators VA with Appointer FE") position(6) col(2) ))
graph export "`path'/Output/mediator_VA_apptrFE_kd.png", as(png) replace

twoway (scatter tv tv_basic, xtitle("Mediators VA") ytitle("Mediators VA with Appointer FE") yline(0) xline(0))
graph export "`path'/Output/mediator_VA_apptrFE_scatter.png", as(png) replace


*sum tv
*hist tv

// Generate T and C groups.
drop if tv == . 
gen group_tv = 1 if tv > 0
replace group_tv = 0 if tv <=0


// Save 
*export delimited "`path'\Output\va_groups_pull`datapull'.csv", replace

/*
// Count mediators before VA calculations
preserve
	collapse (count) cases=id, by(mediator_id)
	gen ones = 1
	collapse (sum) ones
	rename ones total_mediators
	tempfile mediators_no_restr
	save `mediators_no_restr'
restore 
*/ 

/*
// Count mediators used in VA estimation
preserve
	gen ones = 1
	collapse (sum) ones
	rename ones total_eligiblemediators_VA
	tempfile mediators_eligibleVA
	save `mediators_eligibleVA'
restore 

// Export counting of mediators before and after VA estimation
preserve
	use `mediators_no_restr', clear
	append using `mediators_eligibleVA'
	export excel using "`path'/Output/number_mediators_inVAcalc_`current_date'.xlsx", firstrow(variables) replace
restore
*/