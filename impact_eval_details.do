/*****************************************************************
Project: World Bank Kenya Arbiter
PIs: Anja Sautmann and Antoine Deeb
Purpose: Number of mediators used
Author: Hamza Syed 
Updated by: Didac Marti Pinto 
******************************************************************/

clear all
local path "C:\Users\didac\Dropbox\Arbiter Research\Data analysis"
local datapull =   "05102022" // "15062023" // "11062023" //   "25072023" //
local min_cases = 4 // Number of cases per mediator
local first_data_date "01012022" // DMY. Only relevant dates for caseload
local last_data_date "01102022" // DMY. Only relevant dates for caseload
local total_data_months = "9" // Number of months between the two dates above

/*******************************************************************************
	OUTSHEET COURTSTATIONS IN THE IMPACT EVALUATION
	- Only courtstations in the impact evaluation i.e.:
	- Courtstations with more than 10 cases outside pandemic months that were 
	relevant cases (family, custody...) and not recent.
*******************************************************************************/

//Importing data
use "`path'\Data_Clean\cases_cleaned_`datapull'.dta", clear

//Case status, drop pending cases
tab case_status
drop if case_status == "PENDING"

//Keeping only relevant cases 
keep if usable == 1 // Keeping only relevant case types
drop if issue == 6 | issue == 7 // Dropping pandemic months and newest cases (cutoff)

//Keeping only courtstations with >=10 cases
bys courtstation:gen stationcases = _N

// Calculate number of courtstations
preserve 
	collapse (mean) stationcases, by(courtstation)
	export delimited "`path'\Output\courts_totalcasenum_pull`datapull'.csv", replace
	drop if stationcases<10
	export delimited "`path'\Output\courts_totalcasenum_only10plus_pull`datapull'.csv", replace
restore

/*******************************************************************************
	RELEVANT NUMBER OF CASES REFERRED MONTHLY: This helps to predict the number 
	of cases that will arrive every month in the impact evaluation. 
	- Only cases that will be in the impact evaluation i.e. 
	- Only courtstations in the impact eval (with more than 10 relavant cases)
	- Only relevant types of cases (family, custody...)
*******************************************************************************/	

// Keep only courtstation relevant for the VA calculations 
	* Find the courtstations in the impact eval, temp save it
	use "`path'/Data_Clean/cases_cleaned_`datapull'.dta", clear
	drop if case_status == "PENDING" //Drop pending cases
	keep if usable == 1 // Keeping only relevant case types
	drop if issue == 6 | issue == 7 // Dropping pandemic months and newest cases (cutoff)
	bys courtstation:gen stationcases = _N
	drop if stationcases<10 //Keep only courtstations with >=10 cases
	gen temp=.
	collapse temp, by(courtstation)
	tempfile courtstation_impacteval
	save `courtstation_impacteval'
	* Merge with the rest of data
	use "`path'/Data_Clean/cases_cleaned_`datapull'.dta", clear
	merge m:1 courtstation using `courtstation_impacteval'
	keep if _merge== 3
	
//Case status, drop pending cases
*tab case_status
*drop if case_status == "PENDING"

//Keeping only relevant cases
keep if usable == 1
*drop if issue == 6 | issue == 7 //Dropping pandemic months and recent cases

//Calculating number of cases per month
preserve
tab casetype
tab ref_month_year
bys ref_month_year: gen cases = _N
duplicates drop ref_month_year, force
summ cases
graph twoway bar cases ref_month_year, graphregion(color(white)) xtitle("month") ytitle("number of cases") title("number of cases referred per month") note("Cases eligible to be in the impact evaluation") 
*graph save "`path'/Output/relevant_cases_monthly_pull`datapull'", replace
graph export "`path'/Output/number_of_cases_monthly_impacteval_`datapull'.png", as(png) replace
collapse (mean) cases, by(ref_month_year)
export excel using "`path'/Output/number_of_cases_monthly_impacteval_`datapull'..xlsx", firstrow(variables) replace
restore

/*******************************************************************************
	CASELOAD PER MEDIATOR PER MONTH: Relevant for the power calcs
	- Only for a period of time (chosen on top of the code)
	- Only mediators eligible to be in the impact evaluation i.e. 
	- Mediators in courtstations with at least 10 relevant cases
	- Mediators with at least K relevant cases s.t. those cases are relevant (family, custody...)cases)
*******************************************************************************/	

//Importing data
use "`path'/Data_Clean/cases_cleaned_`datapull'.dta", clear

// Keep only courtstation relevant for the VA calculations /*
	* Find the courtstations in the impact eval, temp save it
	drop if case_status == "PENDING" //Drop pending cases
	keep if usable == 1 // Keeping only relevant case types
	drop if issue == 6 | issue == 7 // Dropping pandemic months and newest cases (cutoff)
	bys courtstation:gen stationcases = _N
	drop if stationcases<10 //Keep only courtstations with >=10 cases
	gen temp=.
	collapse temp, by(courtstation)
	tempfile courtstation_impacteval
	save `courtstation_impacteval'
	* Merge with the rest of data
	use "`path'/Data_Clean/cases_cleaned_`datapull'.dta", clear
	merge m:1 courtstation using `courtstation_impacteval'
	keep if _merge== 3

//Case status, drop pending cases
tab case_status
*drop if case_status == "PENDING"

//Keeping only relevant cases
keep if usable == 1
*drop if issue == 6 | issue == 7 //Dropping pandemic months and recent cases

//Keep only mediators with at least x total cases
	bys mediator_id: gen totalcases=_N //Total cases with relevant case types 
	keep if totalcases >= `min_cases' //Total cases with relevant case types

//Calculating case load per mediator per month
	*first need to figure out when the mediator first got a case, to not include months for new mediators
	bys mediator_id: egen first_case_assn = min(med_appt_date)
	format first_case_assn %td
	*need to see the days when the mediator had active case
	expand case_days_med
	bys id:gen day = _n - 1
	*converting active case days to month and keeping only 2022
	gen num_days = med_appt_date + day
	format num_days %td
	gen num_month = month(num_days)
	format num_month %tm
	gen num_year = year(num_days)
	format num_year %ty
	gen num_month_year = ym(num_year,num_month)
	format num_month_year %tm	
	*keep if num_year == 2022
	*drop if num_month == 10
	keep if num_days >= date("`first_data_date'","DMY")
	drop if num_days >= date("`last_data_date'","DMY")
	*collapsing to get number of cases per mediator per month, conditional on having a case
	collapse (first) mediator_id first_case_assn, by(id num_month_year)
	sort num_month_year mediator_id id
	collapse (count) cases=id (first) first_case_assn, by(mediator_id num_month_year)
	summ cases
	*adding months where the mediator did not have any cases
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
	*merging with original data to get the active months after first appointment for each mediator and calculate case load
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


/*******************************************************************************
	NUMBER OF MEDIATORS IN TREATMENT AND CONTROL UNDER DIFFERENT CONDITIONS
	- This is relevant for the power calculations
*******************************************************************************/	
			
//Calculating value added
//Importing data
use "`path'/Data_Clean/cases_cleaned_`datapull'.dta", clear

//Case status, drop pending cases
tab case_status
drop if case_status == "PENDING"

//Keeping only relevant cases
keep if usable == 1
drop if issue == 6 | issue == 7 //Dropping pandemic months and recent cases

//Keeping only courtstations with >=10 cases
bys courtstation:gen stationcases = _N
drop if stationcases<10

//Keep only mediators with at least K total cases
	bys mediator_id: gen totalcases=_N //Total cases with relevant case types 
	keep if totalcases >= `min_cases' //Total cases with relevant case types
	
	egen med_year=group(mediator_id appt_year)
	vam case_outcome_agreement, teacher(mediator_id) year(appt_year) driftlimit(3) class(med_year) controls(i.appt_month_year i.casetype i.courttype i.courtstation i.referralmode) tfx_resid(mediator_id) data(merge tv)

	collapse tv, by(mediator_id)
	sum tv
	drop if tv == .
	count
	
	//Number of mediators in treatment and control group
	//p=20
	_pctile tv, p(20 80) 
	scalar r1=r(r1)
	scalar r2=r(r2)
	gen treatment1 = 1 if tv >= r2
	replace treatment1 = 0 if tv <= r1 
	tab treatment1,m
	//p=30
	_pctile tv, p(30 70) 
	scalar r1=r(r1)
	scalar r2=r(r2)
	gen treatment2 = 1 if tv >= r2
	replace treatment2 = 0 if tv <= r1 
	tab treatment2,m
	//p=40
	_pctile tv, p(40 60) 
	scalar r1=r(r1)
	scalar r2=r(r2)
	gen treatment3 = 1 if tv >= r2
	replace treatment3 = 0 if tv <= r1 
	tab treatment3,m
	//p=50
	_pctile tv, p(50 50) 
	scalar r1=r(r1)
	scalar r2=r(r2)
	gen treatment4 = 1 if tv >= r2
	replace treatment4 = 0 if tv <= r1 
	tab treatment4,m
	