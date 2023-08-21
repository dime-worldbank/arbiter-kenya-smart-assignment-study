/*******************************************************************************
Project: World Bank Kenya Arbiter
PIs: Anja Sautmann and Antoine Deeb
Purpose: Analyse caseload of mediators in T and C groups. Find out if they deal
with more than 3 cases often. 
Author: Didac Marti Pinto
*******************************************************************************/

version 17
clear all

//Define locals 
local path "C:\Users\didac\Dropbox\Arbiter Research\Data analysis"
local datapull = "15062023" // "11062023" //"05102022" //  "27022023" 
local first_data_date "01032023" // DMY
local last_data_date "01062023" // DMY
local total_data_months = "3"


/*******************************************************************************
	IMPORT T AND C GROUPS
*******************************************************************************/

import delimited using "`path'\Output\va_groups_pull`datapull'.csv"

// Tempsave
tempfile VA_groups
save `VA_groups'

/*******************************************************************************
	CASELOAD: Create two statistics:
	1. Maximum number of simultaneous cases a mediator dealt with simultaneously
	2. Average number of cases a mediator dealt with in one month. They could be 
	simultaneous or not.
*******************************************************************************/

//Import data
use "`path'/Data_Clean/cases_cleaned_`datapull'.dta", clear

//Create some useful variables and drop some observations

	// Add to each mediator info on the groups they belong to
	merge m:1 mediator_id using `VA_groups'

	// Gen first_case_assn: First date a mediator was assigned a case
	bys mediator_id: egen first_case_assn = min(med_appt_date)
	format first_case_assn %td
	
	// Convert the dataset into a dataset where each observation is a case-day
	expand case_days_med // Create an observation for every day a case lasted. 
						 // So if a case lasted 10 days, there will be 10 
						 // (equal for the moment) observations.
	bys id: gen day = _n - 1 // "day" indicates the days that passed since the 
							// appointment for each observation. If a case 
							// lasted 10 days there will be 11 observations, and 
							// in each of them "day" will be different (from 0 to 10)
	

	// Create variables that contains the date of each observation
	gen num_days = med_appt_date + day
	format num_days %td
	gen num_month = month(num_days)
	format num_month %tm
	gen num_year = year(num_days)
	format num_year %ty
	gen num_month_year = ym(num_year,num_month)
	format num_month_year %tm 
	
	// Keep only cases from Jan 2022 to May 2023 
	keep if num_days >= date("`first_data_date'","DMY")
	drop if num_days >= date("`last_data_date'","DMY")
	
// STATISTIC 1: Maximum number of simultaneous cases a mediator dealt with 
// simultaneously. 

preserve

	// Collapse to get the number of cases a mediator was dealing with each day
	gen ones = 1
	collapse (count) cases = ones (mean) group_tv (mean) tv, by(mediator_id num_days)
	
	// Fix cases of mediators for which there seems to be a repetition in data entry
	/* 
	- Mediator with ID 663 was appointed to 21 cases on April 13, 2023. All of the 
	cases have different case numbers. And all of them except one concluded on the 
	June 29.  
	- Mediator with ID 191 was appointed to 18 cases on March 27, 2023. All of the 
	cases have different case numbers. And none of them concluded.
	I treat both of them as a single case.
	*/
	replace cases = cases - 20 if mediator_id == 663 & ///
	num_days >= date("13042023","DMY") & num_days <= date("29062023","DMY")
	replace cases = cases - 17 if mediator_id == 191 & ///
	num_days >= date("27032023","DMY")
	
	// Collapse to find the maximum number of cases a mediator deal with a single day
	collapse (max) cases  (mean) group_tv (mean) tv, by(mediator_id)
		
	// Histogram
	twoway (hist cases if group_tv == 0, width(1) color(red%30)) ///
	(hist cases if group_tv == 1, width(1) color(green%30)), ///
	legend(order(1 "Control" 2 "Treatment" )) xtitle("Number of cases") ///
	title("Max number of cases a mediator dealt with simultaneously")
	graph export "`path'/Output/cases_per_mediator_max_TC_from`first_data_date'_pull`datapull'.png", as(png) replace
	
	// Table
	replace group_tv = 2 if group_tv ==.
	eststo max: estpost tabstat cases, by(group_tv) st(n mean sd)
	esttab max using "`path'/Output/cases_per_mediator_max_TC_from`first_data_date'_pull`datapull'.xls", ///
	cells("count(fmt(0)) mean(fmt(2)) sd(fmt(2))") label replace
restore

// STATISTIC 2: Average number of cases a mediator dealt with in one month.  
// They could be simultaneous or not.

	// Collapse to get number of cases per mediator per month, conditional on 
	// having a case. Each observation becomes a case-month
	collapse (first) mediator_id first_case_assn group_tv, by(id num_month_year) 
	
	// Collapse. cases=Number of cases a mediator dealt with every month. Each 
	// observation is a different month for each mediator. 
	collapse (count) cases=id (first) first_case_assn group_tv, by(mediator_id num_month_year)
	
	// Fix cases of mediators for which there seems to be a repetition in data entry
	replace cases = cases - 20 if mediator_id == 663 & ///
	num_month_year >= ym(2023, 04) & num_month_year <= ym(2023, 06)
	replace cases = cases - 17 if mediator_id == 191 & ///
	num_month_year >= ym(2023, 03)
	
	// Statistic 2 conditional on having a case. This gives more weight to more 
	// experienced mediators (more months). Also it ignores, at this point, the 
	// months where there was no case
		preserve
		collapse (mean) cases group_tv, by(mediator_id)
		replace group_tv = 2 if group_tv ==.
		tabstat cases, by(group_tv) st(n mean sd)
	
		// Histogram
		twoway (hist cases if group_tv == 0, width(1) color(red%30)) ///
		(hist cases if group_tv == 1, width(1) color(green%30)), ///
		legend(order(1 "Control" 2 "Treatment" )) xtitle("Number of cases") ///
		title("Mean number of cases per month per mediator")
		graph export "`path'/Output/cases_per_mediator_month_TC_condcase_from`first_data_date'_pull`datapull'.png", as(png) replace

		// Table
		replace group_tv = 2 if group_tv ==.
		eststo cond: estpost tabstat cases, by(group_tv) st(n mean sd) 
		esttab cond using "`path'/Output/cases_per_mediator_month_TC_condcase_from`first_data_date'_pull`datapull'.xls", ///
		cells("count(fmt(0)) mean(fmt(2)) sd(fmt(2))") label replace
		restore
			   	
	// Add months where mediators had no cases
	preserve
	keep mediator_id first_case_assn
	duplicates drop mediator_id, force
	expand `total_data_months' 
	bys mediator_id: gen month = _n
	tempfile mediators
	save `mediators'
	restore
	preserve
	keep num_month_year
	duplicates drop num_month_year, force
	sort num_month_year
	gen month = _n
	merge 1:m month using `mediators', gen(_merge)
	drop _merge month
	tempfile month_mediator
	save `month_mediator'
	restore
	
	// Merge with original data to get the active months after first appointment
	// for each mediator and calculate case load
	merge 1:1 mediator_id num_month_year using `month_mediator', gen(_merge)
	gen case_month = month(first_case_assn)
	format case_month %tm
	gen case_year = year(first_case_assn)
	format case_year %ty
	gen case_month_year = ym(case_year,case_month)
	format case_month_year %tm
	drop case_month case_year first_case_assn _merge
	drop if case_month_year > num_month_year
	replace cases = 0 if missing(cases)
	summ cases 
	
	// Cases = Average number of cases a mediator dealt with every month. 
	// They could be simultaneous or not. 
	collapse (mean) cases group_tv, by(mediator_id) 
	
	// Histogram
	twoway (hist cases if group_tv == 0, width(1) start(0) color(red%30)) ///
	(hist cases if group_tv == 1, width(1) start(0) color(green%30)), ///
	legend(order(1 "Control" 2 "Treatment" )) xtitle("Number of cases") ///
	title("Mean number of cases per month per mediator")
	graph export "`path'/Output/cases_per_mediator_month_TC_from`first_data_date'_pull`datapull'.png", as(png) replace
	
	// Table
	replace group_tv = 2 if group_tv ==.
	eststo all: estpost tabstat cases, by(group_tv) st(n mean sd) 
	esttab all using "`path'/Output/cases_per_mediator_month_TC_from`first_data_date'_pull`datapull'.xls", ///
	cells("count(fmt(0)) mean(fmt(2)) sd(fmt(2))") label replace
	

/*
	Maximum num of cases     
	2022-2023   2023   Last 3 months 
	
	Mean num of cases dealt with per month
	Conditional on having dealt with at least 1 case       Unconditional 
	2022-2023   2023   Last 3 months 
	
*/

	
	
	