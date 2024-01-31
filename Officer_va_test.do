/*****************************************************************
Project: World Bank Kenya Arbiter
PIs: Anja Sautmann and Antoine Deeb
Purpose: Power calculation
Author: Hamza Syed (based on Antoine's file)
Updated by: Didac Marti Pinto
******************************************************************/

*ssc install vam

//Defining locals 
local path "C:\Users\didac\Dropbox\Arbiter Research\Data analysis"
local datapull = "15062023" // "01112023" //"01112023" // "15062023" // "11062023" //"05102022" //  "27022023" 
local min_cases =  0 // 4 //


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
if `min_cases' > 0 {
	bys mediator_id: gen totalcases=_N //Total cases with relevant case types 
	keep if totalcases >= `min_cases'
}

	
******************************************************************
	* Explore
******************************************************************


// Missing "appointer_user_id"
	* All years
	count if appointer_user_id == . 
	count if appointer_user_id != . 
	* Each year
	forvalues y = 2016(1)2023 {
		di "Year " `y'
		count if appointer_user_id == . & appt_year == `y' // 
		count if appointer_user_id != . & appt_year == `y' // 
	}
/*
Conclusion: Significant number of missing appointer id's (around 28%). The 
biggest problem is in 2019. Why? Ask Wei. 
*/

// Number of different appointing mediators by courtstation
preserve
drop if appointer_user_id == .
bysort courtstation appointer_user_id: gen nvals = _n == 1 
collapse (sum) nvals, by(courtstation)
restore
drop if appointer_user_id == .
bysort courtstation appointer_user_id: gen nvals = _n == 1 
egen num_appointers_cs = sum(nvals), by(courtstation)
drop if num_appointers_cs == 1

// 
* Bomet, Eldoret 
/*
drop if appointer_user_id == .
collapse id, by(courtstation appointer_user_id appt_month_year)
sort courtstation appt_month_year
*/
******************************************************************
	* VA
******************************************************************

drop if appointer_user_id == .

// Generate half-calendar-year appointment variable
	gen firsthalf_year = 0 if appt_month <= 6 // First half year indicator variable
	replace firsthalf_year = 1 if appt_month >=7 // Second half year indicator variable
	egen appt_halfyear = group(appt_year firsthalf_year) // half-year 

// Interaction appointer and date
	egen appointer_halfyear=group(appointer_user_id appt_halfyear)	
	egen appointer_year=group(appointer_user_id appt_year)

foreach tt in "year" "halfyear" {
preserve 

*local tt "halfyear"
// VA calculations
	vam case_outcome_agreement, teacher(appointer_user_id) year(appt_`tt') ///
	driftlimit(3) class(appointer_`tt') controls(i.appt_month_year i.casetype ///
	i.courttype i.courtstation i.referralmode) tfx_resid(appointer_user_id) ///
	data(merge tv)
rename tv va

// VA calculations - Mediator FE
	vam case_outcome_agreement, teacher(appointer_user_id) year(appt_`tt') ///
	driftlimit(3) class(appointer_`tt') controls(i.appt_month_year i.casetype ///
	i.courttype i.courtstation i.referralmode i.mediator_id) tfx_resid(appointer_user_id) ///
	data(merge tv)
rename tv va_medFE	

collapse va va_medFE, by(appointer_user_id)

twoway  (hist va if va >-1.425 & va < 1.5, freq width(.15) color(red%30) start(-1.425)) ///
        (hist va_medFE if va_medFE >-1.425 & va_medFE < 1.5, freq width(.15) color(green%30) start(-1.425) ///
		xtitle("Value Added")   ///
		legend(order(1 "VA" 2 "VA with mediator FE" ))   )
		graph export "`path'/Output/CAM Officers/off_VA_`tt'_mincasesmedi`min_cases'.png", as(png) replace

restore
}
		
/*
// Generate T and C groups.
drop if tv == . 
gen group_tv = 1 if tv > 0
replace group_tv = 0 if tv <=0
hist tv, freq bin(15)


// Save 
*export delimited "`path'\Output\va_groups_pull`datapull'.csv", replace

* Missing appointing CAM Officers
* Number of different appointing CAM officers in each Courtstation

* Overlap of CAM officers vs one after the other:
	* Number of CAM Officers who appointed a mediator at the same time 
	* than another at the same courtstation
* Is there specialization of CAM Officers? Some mediators 

* Number of cases per appointing mediator

* Conclusion: VA can be more accurately calculated, but we have less VA's. 
* We need to drop courtstations with only 1 appointing mediator? Courtstation
* fixed effects impossible to calculate
