/*******************************************************************************
	Clean historical Arbiter data
*******************************************************************************/

version 17
clear all

// Define locals
local path "C:\Users\didac\Dropbox\Arbiter Research\Data analysis"
local datapull = "20260513" 
local pandemic_start = "15032020"
local pandemic_end = "30062021"
local post_pandemic = 60 // Number of days after pandemic to possibly exclude


// Use accr2ct data to extract locals
	use "`path'\Data_Clean\accred2ct_`datapull'.dta", clear
	
		// Local: Total case type num
		ds ct_*, not
		ds ct_*
		local ct_num: word count `r(varlist)'
		
		// Locals: case type names	
		forvalue i=1(1)`ct_num' {
			local varname = "ct_`i'"
			local ct_`i'_label : variable label `varname'
			di "`ct_`i'_label'"
		}

// Import raw data
import delimited "`path'\Data_Raw\vw_deidentified_case_w_appointer_`datapull'.csv", clear 

/*******************************************************************************
	CREATE CASE DATE VARIABLES
*******************************************************************************/

//Referral date
	gen ref_date = date(referral_date, "YMD")
	format ref_date %td
	label variable ref_date "Referral date"
	label variable referral_date "Referral date (string)"
	* Year
	gen ref_year = year(ref_date)
	format ref_year %ty
	label variable ref_year "Referral year"
	* Month-year
	gen ref_month = month(ref_date)
	format ref_month %tm
	gen ref_month_year = ym(ref_year,ref_month)
	format ref_month_year %tm
	label variable ref_month_year "Referral month and year"
	* Month
	drop ref_month
	gen ref_month = month(ref_date)
	label variable ref_month "Referral month"

//Mediator appointment date
	gen med_appt_date = date(mediator_appointment_date, "YMD")
	format med_appt_date %td
	label variable med_appt_date "Mediator appointment date"
	label variable mediator_appointment_date "Mediator appointment date (string)"
	* Year
	gen appt_year = year(med_appt_date)
	format appt_year %ty
	label variable appt_year "Mediator appointment year"
	* Month-year
	gen appt_month = month(med_appt_date)
	format appt_month %tm
	gen appt_month_year = ym(appt_year,appt_month)
	format appt_month_year %tm
	label variable appt_month_year "Mediator appointment month and year"
	* Month
	drop appt_month
	gen appt_month = month(med_appt_date)
	label variable appt_month "Mediator appointment month"
		
//Creation date in cadaster/arbiter 
	gen cr_date = substr(created_at,1,10)
	gen create_date = date(cr_date, "YMD")
	format create_date %td
	drop cr_date
	label variable create_date "Creation date in cadaster/arbiter"
	label variable created_at "Creation in cadaster/arbiter date (string)"
	* Year
	gen create_year = year(create_date)
	format create_year %ty
	label variable create_year "Creation year in cadaster/arbiter"
	* Month-year
	gen create_month = month(create_date)
	format create_month %tm
	gen create_my = ym(create_year,create_month)
	format create_my %tm
	label variable create_my "Creation month and year in cadaster/arbiter"
	* Month
	drop create_month
	gen create_month = month(create_date)
	label variable create_month "Creation month in cadaster/arbiter"
		
//Case conclusion date
	gen concl_date = date(conclusion_date, "YMD")
	format concl_date %td
	label variable concl_date "Conclusion date"
	label variable conclusion_date "Conclusion date (string)"

/*******************************************************************************
	OTHER VARIABLES CREATION AND CHANGES
	- Encode relevant variables
	- Create other variables
	- Fix mediation session type
*******************************************************************************/

// Encode some string variables
	encode court_station, gen(courtstation)
	encode referral_mode, gen(referralmode)
	encode outcome_name, gen(caseoutcome)
	encode case_status, gen(casestatus)
	encode court_type, gen(courttype)
	*encode case_type, gen(casetype)
	
// Casetype (encoding has to match original)
	gen casetype = 0
		forvalue i=1(1)`ct_num' {
		replace casetype = `i' if case_type == "`ct_`i'_label'"
	}
	
// High court and court of appeal indicator 
	gen highcourt = 0
	replace highcourt = 1 if courttype == 4
	gen courtofappeal = 0 
	replace courtofappeal = 1 if courttype == 1
	
// Simplified case type
	gen case_type_simplified = case_type
	
	// Civil group
	replace case_type_simplified = "Civil group" if case_type == "Civil Appeals" 
	replace case_type_simplified = "Civil group" if case_type == "Civil Cases" 
	// Family group
	replace case_type_simplified = "AAFamily group" if case_type == "Divorce and Separation" 
	replace case_type_simplified = "AAFamily group" if case_type == "Family Appeals" 
	replace case_type_simplified = "AAFamily group" if case_type =="Family Miscellaneous" 
	replace case_type_simplified = "AAFamily group" if case_type == "Succession (Probate & Administration - P&A)"  
	// Commercial and Tax group
	replace case_type_simplified = "Commercial and tax group" if case_type == "Commercial Cases" 
	replace case_type_simplified = "Commercial and tax group" if case_type == "Tax Appeals" 
	encode case_type_simplified, gen(casetype_simplified)
	*replace casetype_simplified = 0 if case_type_simplified == "Family group"

// Create case duration days based on mediator assignment
	gen case_days_med = concl_date - med_appt_date if case_status != "PENDING" // There are a few negative values
	replace case_days_med = date("`datapull'", "YMD") - med_appt_date if missing(case_days_med) 
	label variable case_days_med "Number of days between mediator assignment and case conclusion/datapull"	

// Create issues variable
/* 
 1 Missing mediator ID
 2 Mediator appointment date missing but mediator assigned
 3 Case conclusion date before mediator assignment
 4 Cases which came in during the pandemic
*/
	*Cases with no mediator ID
		gen issue1 = 1 if missing(mediator_id)
		label variable issue1 "Flag for missing mediator ID"

	*Cases where mediator appointment date is missing but mediator assigned
		gen issue2 = 2 if missing(med_appt_date) & !missing(mediator_id) 
		label variable issue2 "Flag Mediator appointment date missing but mediator assigned"

	*Check if there are cases with negative number of days (ask Wei to check)
		gen issue3 = 3 if case_days_med < 0 
		label variable issue3 "Flag Case conclusion date before mediator assignment"

	*Flagging pandemic cases (including x months post pandemic)
		gen issue4 = 4 if date("`pandemic_start'", "DMY") < med_appt_date & (date("`pandemic_end'", "DMY") + `post_pandemic') > med_appt_date
		label variable issue4 "Flag Cases which mediator was apptd during the pandemic"
		
	*Labelling issues
		label define issues 1 "Missing mediator ID" 3 "Mediator appointment date missing but mediator assigned" 4 "Case conclusion date before mediator assignment" 7 "Cases which came in during the pandemic"
		label values issue1 issues
		label values issue2 issues
		label values issue3 issues
		label values issue4 issues	

/*******************************************************************************
	LABEL REMAINING VARIABLES
*******************************************************************************/

	label variable id "Identifier for cases"
	label variable case_number "Case number"
	label variable case_status "Whether concluded or not (string)"
	label variable outcome_name "Case outcome if concluded (string)"
	label variable agreement_mode "Full or partial agreement, if agreement reached"
	label variable case_outcome_agreement "Flag for agreement"
	label variable pending_reason "Reason for pending, also available for some cases which have concluded"
	label variable case_days "System calculated days between referral and conclusion/datapull"
	label variable mediator_appointment_days "System calculated days since mediator appointment"
	label variable case_type "Category of case"
	label variable court_division "Category of court - civil, commercial, criminal, etc."
	label variable court_type "Type of court - high court, magistrate, appeals, etc."
	label variable court_station "Location of court (string)"
	label variable mediator_id "Identifier for mediator"
	label variable referral_mode "Referred by court, screened or requested by parties (string)"
	label variable session_type "Mediation session type - in person, online, hybrid"
	label variable updated_at "Case updation date in cadaster/arbiter (string)"
	label variable courtstation "Location of court (encoded)"
	label variable referralmode "Referred by court, screened or requested by parties (encoded)"
	label variable caseoutcome "Case outcome if concluded (encoded)"
	label variable casestatus "Whether concluded or not (encoded)"
	label variable courttype "Type of court (encoded)"
	label variable casetype "Type of case (encoded)"
	label variable number_of_defendant_languages "Number of defendent languages"
	label variable number_of_plaintiff_languages "Number of plaintiff languages"

//Saving cleaned file
	save "`path'/Data_Clean/cases_cleaned_`datapull'.dta", replace
	*export delimited using "`path'/Data_Clean/cases_cleaned_`datapull'.csv", replace
	

