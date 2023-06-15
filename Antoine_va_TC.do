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
local outcome_variables = "case_days_med success conclude_70" 

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
vam case_outcome_agreement, teacher(mediator_id) year(appt_year) class(med_year) controls(i.appt_year i.casetype i.courttype i.courtstation i.referralmode) tfx_resid(mediator_id) data(merge tv)
collapse tv, by(mediator_id)
*sum tv
*hist tv

// Generate T and C groups. 
// group_tv=1 (high) and group_tv=0 (low)
drop if tv ==. // Need to check why they are missing
egen median_tv = pctile(tv), p(50) // Get the median
gen group_tv = 1 if tv > median_tv
replace group_tv = 0 if group_tv ==.
drop median_tv

// Save 
export delimited "`path'\Output\va_groups_pull`datapull'.csv", replace






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