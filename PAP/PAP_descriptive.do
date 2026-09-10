version 17
clear all


//Defining locals 
local path "C:\Users\didac\Dropbox\Arbiter Research\Data analysis"
local datapull = "15062023" // "11062023" //"05102022" //  "27022023" 
local min_cases = 4 

/*******************************************************************************
	IMPORT T AND C GROUPS
*******************************************************************************/

import delimited using "`path'\Output\va_groups_pull`datapull'.csv", clear

// Tempsave
tempfile VA_groups
save `VA_groups'

/*******************************************************************************
	INDICATE RELEVANT CASES
*******************************************************************************/

// Data preparation
	* Import data
	use "`path'/Data_Clean/cases_cleaned_15062023.dta", clear
	* Drop pending cases
	drop if case_status == "PENDING"
	* Keep only relevant cases
	keep if usable == 1
	drop if issue == 6 | issue == 7 //Dropping pandemic months 
	* Keep only courtstations with >=10 cases
	bys courtstation:gen stationcases = _N
	drop if stationcases<10
	
gen relevant_case = 1 
keep relevant_case id

tempfile rel
save `rel'

/*******************************************************************************
	MERGE ALL DATA AND OUTPUT IT
*******************************************************************************/

//Import main data
use "`path'/Data_Clean/cases_cleaned_`datapull'.dta", clear

drop if case_status == "PENDING"

	// Add to each mediator info on the groups they belong to
	merge m:1 mediator_id using `VA_groups'
	drop _merge
	
	// Add info on whether it is a case-eligible case
	merge 1:1 id using `rel'

// Variables to ouput
	* Relevant case
	replace relevant_case = 0 if relevant_case == .
	* Agreement rates
	egen case_outcome_agreement_med = mean(case_outcome_agreement), by(mediator_id)
	egen case_outcome_agreement_med_rel = mean(case_outcome_agreement) if relevant_case ==1, by(mediator_id)
	* Number of concluded cases
	gen num_concl_cases = 1 if case_status == "CONCLUDED"
	gen num_concl_cases_rel = 1 if case_status == "CONCLUDED" & relevant_case == 1
	* First appt case
	sort mediator_id med_appt_date
	bys mediator_id: egen first_med_appt = min(med_appt_date)
	format first_med_appt %td
	gen pulldate = date("`datapull'", "DMY")
	format pulldate %td
	gen days_since_first_appt = pulldate - first_med_appt
	* Case duration
	gen case_days_med_rel = case_days_med if relevant_case == 1
	
/*dtable case_outcome_agreement_med num_concl_cases case_days_med days_since_first_appt case_days_med, by(relevant_case, nototals) nformat(%16.2f) // export("`path'\Output\PAP\Descriptive.tex", replace tableonly) */
	
collapse (sum) num_concl_cases num_concl_cases_rel (mean) ///
case_outcome_agreement_med case_outcome_agreement_med_rel days_since_first_appt group_tv case_days_med case_days_med_rel, by(mediator_id)

// Table preparation
	label var num_concl_cases "Number of cases concluded"
	label var case_outcome_agreement_med "Agreement rate"
	label var num_concl_cases_rel "Number of relevant cases concluded"
	label var case_outcome_agreement_med_rel "Agreement rate in relevant cases"
	label var group_tv "Experimental group"
	label var days_since_first_appt "Days since the first appointment"
	label var case_days_med "Case duration"
	label var case_days_med_rel "Case duration for relevant cases"
	tostring group_tv, replace
	replace group_tv = "Treatment" if group_tv == "1"
	replace group_tv = "Control" if group_tv == "0"
	drop if group_tv == "."

// Outptut
dtable case_outcome_agreement_med case_outcome_agreement_med_rel num_concl_cases num_concl_cases_rel /*case_days_med case_days_med_rel days_since_first_appt case_days_med case_days_med*/, by(group_tv, nototals) nformat(%16.2f) export("`path'\Output\PAP\Descriptive.tex", replace tableonly) 


/*
// Graphs
twoway (hist num_concl_cases_rel if group_tv == "Control", width(1) start(0) freq color(red%30)) ///
(hist num_concl_cases_rel if group_tv == "Treatment", width(1) start(0) freq color(green%30) legend(order(1 "Control" 2 "Treatment" )))

twoway (hist num_concl_cases if group_tv == "Control", width(5) start(0) freq color(red%30)) ///
(hist num_concl_cases if group_tv == "Treatment", width(5) start(0) freq color(green%30) legend(order(1 "Control" 2 "Treatment" )))