/*******************************************************************************
	Clean Smart assignment data
*******************************************************************************/

version 17
clear all

//Defining locals for flexible decisions
local path "C:\Users\didac\Dropbox\Arbiter Research\Data analysis"
local datapull = "17102024" // "18042024"  // "15062023" // "05102022" // "25072023" 

// Import and tempsave SA VA
	// Shrunk
	import delimited "`path'\Output\SA_VA_Groups.csv", clear // SA shrunk VA's
	rename tv va_s
	label variable va_s "Value Added (shrunk)"
	rename group_tv group_va_s
	label variable group_va_s "Value Added group (shrunk)"
	tempfile va_s_groups
	save `va_s_groups'
	// Unshrunk
	import delimited using "`path'\Output\SA_VAu_Groups.csv", clear // SA unshrunk VA's
	label variable va_u "Value Added (unshrunk)"
	label variable group_va_u "Value Added group (shrunk)"
	tempfile va_u_groups // tempfile for merge
	save `va_u_groups'

// Import and tempsave eligible mediators for each case 
import delimited "`path'\Data_Raw\Studyeligiblemediator_07112024.csv", clear
drop if mediatorid == .

	// Add VA
	rename mediatorid mediator_id
	merge m:1 mediator_id using `va_s_groups'
	drop if _merge == 2
	drop _merge
	merge m:1 mediator_id using `va_u_groups'
	drop if _merge == 2

	// Reshape
	drop id
	rename caseid id
	rename mediator_id list_mid_
	rename rejectreason list_rejectreason_
	rename rejectreasoncourtnamedby list_rejectreason_court_
	rename rejectreasonother list_rejectreason_other_
	rename (va_s group_va_s va_u group_va_u) ///
	(list_va_s_ list_group_va_s_ list_va_u_ list_group_va_u_)
	
	keep id rank list_mid_ list_rejectreason_ list_rejectreason_court_ ///
	list_rejectreason_other_ list_va_s_ list_group_va_s_ list_va_u_ ///
	list_group_va_u_

	reshape wide list_mid_ list_rejectreason_ list_rejectreason_court_ ///
	list_rejectreason_other_ list_va_s_ list_group_va_s_ list_va_u_ ///
	list_group_va_u_ , i(id) j(rank)
	
	tempfile eligiblelist // tempfile for merge
	save `eligiblelist'
	
// Import smart assignment data 
import delimited "`path'\Data_Raw\Vw_All_Random_Study_Case_`datapull'.csv", clear

	// Manually change missing mediator ID's
	*replace mediator_id = 525 if id == 16162
	*replace mediator_id = 175 if id == 17285
	

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
	- Outsheet issues
	- Fix mediation session type
*******************************************************************************/

//Encode some string variables
	encode court_station, gen(courtstation)
	encode referral_mode, gen(referralmode)
	encode outcome_name, gen(caseoutcome)
	encode case_status, gen(casestatus)
	encode court_type, g(courttype)
	encode case_type, gen(casetype)

//Create case duration days based on mediator assignment
	gen case_days_med = concl_date - med_appt_date if case_status != "PENDING" // There are a few negative values
	replace case_days_med = date("`datapull'", "DMY") - med_appt_date if missing(case_days_med) 
	label variable case_days_med "Number of days between mediator assignment and case conclusion/datapull"	

/*	
	
//Create relevant cases variable
	fre casetype // Frequency table
	gen relevantcase = 1 if inlist(casetype,`relevant_cases')
	replace relevantcase = 0 if missing(relevantcase)
	label variable relevantcase "Flag for relevant casetypes for the study (=1)"

//Create issues variable
	*Cases with no mediator ID
		gen issue1 = 1 if missing(mediator_id)
		label variable issue1 "Flag for missing mediator ID"

	*Where mediator appointed before referral
		gen gap = med_appt_date - ref_date
		gen issue2 = 2 if gap < 0
		label variable issue2 "Flag Mediator appointed before referral"
		drop gap

	*Cases where mediator appointment date is missing but mediator assigned
		gen issue3 = 3 if missing(med_appt_date) & !missing(mediator_id) 
		label variable issue3 "Flag Mediator appointment date missing but mediator assigned"

	*Check if there are cases with negative number of days (ask Wei to check)
		gen issue4 = 4 if case_days_med < 0 
		label variable issue4 "Flag Case conclusion date before mediator assignment"

	*Checking for feasibility of case days
		gen feasible_gap = date("`datapull'", "DMY") - med_appt_date
		gen case_days_gap = feasible_gap - case_days_med
		gen issue5 = 5 if case_days_gap < 0 
		drop feasible_gap case_days_gap
		label variable issue5 "Flag Case days since appointment more than number of days since appointment"

	*Flagging cases which came in x (cutoff) days before datapull
		gen issue6 = 6 if date("`datapull'", "DMY") - med_appt_date < `cutoff'
		label variable issue6 "Flag Cases which are too new to be included"
		
	*Flagging pandemic cases (including x months post pandemic)
		gen issue7 = 7 if date("`pandemic_start'", "DMY") < ref_date & (date("`pandemic_end'", "DMY") + `post_pandemic') > ref_date
		label variable issue7 "Flag Cases which came in during the pandemic"
		

	*Labelling issues
		label define issues 1 "Missing mediator ID" 2 "Mediator appointed before referral" 3 "Mediator appointment date missing but mediator assigned" 4 "Case conclusion date before mediator assignment" 5 "Case days since appointment more than number of days since appointment" 6 "Cases which are too new to be included" 7 "Cases which came in during the pandemic"
		label values issue1 issues
		label values issue2 issues
		label values issue3 issues
		label values issue4 issues
		label values issue5 issues
		label values issue6 issues
		label values issue7 issues

	/*Outsheeting issue cases
		preserve
		keep if inlist(issue1, `exclusion_issues') | inlist(issue2, `exclusion_issues') | inlist(issue3, `exclusion_issues') | inlist(issue4, `exclusion_issues') |  inlist(issue5, `exclusion_issues') | inlist(issue6, `exclusion_issues') | inlist(issue7, `exclusion_issues')
		keep id mediator_id mediator_appointment_date referral_date case_days case_days_med issue1 issue2 issue3 issue4 issue5 
		export excel using "`path'/Data_Clean/issues_`datapull'.xlsx", firstrow(variables) replace
		restore*/
	
//Create exclusion variable
	gen exclusion = 1 if inlist(issue1, `exclusion_issues') | inlist(issue2, `exclusion_issues') | inlist(issue3, `exclusion_issues') | inlist(issue4, `exclusion_issues') |  inlist(issue5, `exclusion_issues') | inlist(issue6, `exclusion_issues') | inlist(issue7, `exclusion_issues')
	label variable exclusion "Flag for cases to be excluded due to issues"
		
//Create usable case variable 
	gen usable = 1 if relevantcase == 1 & missing(exclusion)
	label variable usable "Flag for cases to be used in analysis (=1)"
		
//Create successful outcome variable
	gen success = 1 if caseoutcome == 3
	replace success = 0 if missing(success)
	replace success = 0 if case_days_med > `cutoff'
	label variable success "Flag for successful resolution of case"
		
//Create variable for cases concluded within 70 days
	gen conclude_70 = 1 if case_days_med <= 70
	replace conclude_70 = 0 if missing(conclude_70)
	label variable conclude_70 "Flag for cases concluded within 70 days (=1)"
	
//Create count of number of cases for each mediator
	bys mediator_id: gen total_cases=_N
	label variable total_cases "Total cases for the mediator"		

//Change mediation session type: based on Wei's suggestion, assign in-person to pre-pandemic cases with missing session type
	tab session_type,m
	replace session_type = "In-Person" if missing(session_type) & ref_date < date("31032020", "DMY")
*/					
/*******************************************************************************
	ADD VA'S AND ALL ELIGIBLE MEDIATORS LIST
*******************************************************************************/

	// Shrunk VA
	merge m:1 mediator_id using `va_s_groups'
	tab acceptance_or_error_status if _merge == 1 
		// _merge == 1: Non-accepted cases or missing mediator ID
	tab acceptance_or_error_status if _merge == 2
		// _merge == 2: Eligible mediators who had no case assigned during SA 
	drop if _merge == 2
	drop _merge
	
	// Unshrunk VA
	merge m:1 mediator_id using `va_u_groups'
	drop if _merge == 2
	drop _merge
	
	// Eligible mediators list
	merge m:1 id using `eligiblelist'
	*drop if _merge == 1 // Non-merges because "all ineligible" - No need to drop
	drop _merge
	
	
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
	label variable appointment_data_entry_timestamp "Timestamp of when mediator appointment was entered into the data"
	label variable appointed_at_case_creation_time "Flag for whether mediator was appointed at case creation"
	label variable appointer_user_id "Identifier for appointing officer"
	label variable defendant_languages "Languages spoken by defendants"
	label variable plaintiff_languages "Languages spoken by plaintiffs"
	label variable courtstation "Location of court (encoded)"
	label variable referralmode "Referred by court, screened or requested by parties (encoded)"
	label variable caseoutcome "Case outcome if concluded (encoded)"
	label variable casestatus "Whether concluded or not (encoded)"
	label variable courttype "Type of court (encoded)"
	label variable casetype "Type of case (encoded)"
	label variable number_of_defendant_languages "Number of defendent languages"
	label variable number_of_plaintiff_languages "Number of plaintiff languages"
	label variable group "Treatment or Control"
	label variable is_test "Technical test indicator"
	label variable reject_reason "First reject reason"
	label variable recommendation_rank "Rank of the accepted mediator"

	
//Saving cleaned file
	save "`path'/Data_Clean/smartassign_cleaned_`datapull'.dta", replace

* Missing mediator_id despite acceptance?
