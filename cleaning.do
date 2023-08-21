/*******************************************************************************
Project: World Bank Kenya Arbiter
PIs: Anja Sautmann and Antoine Deeb
Purpose: Data cleaning
Author: Hamza Syed 
Updated by: Didac Marti Pinto
Instructions:
- Specify at the beginning of the code the desired parameters, including the 
date of the data pull. 
- The data pulls 27022023 and 14062023 do not work with this version of the code
because they have slightly different data formats
*******************************************************************************/

version 17
clear all
*ssc install fre

//Defining locals for flexible decisions
local path "C:\Users\didac\Dropbox\Arbiter Research\Data analysis"
local cutoff = 300 //Number of days after which case is considered lost cause and also number of days before data pull where cases will be considered too recent
local datapull = "25072023"  // "15062023" // "05102022" // "25072023" 
local pandemic_start = "15032020"
local pandemic_end = "30062021"
local post_pandemic = 60 //number of days after pandemic to exclude
local relevant_cases = "1,11,12" //Select from the list below
/*
 1  Children Custody and Maintenance        
 2  Civil Appeals    
 3  Civil Cases   
 4  Commercial Cases  
 5  Criminal Cases 
 6  Divorce and Separation 
 7  Employment and Labour Relations Cases (ELRC) 
 8  Environment and Land Cases (ELC)        
 9  Family Appeals  
 10 Family Miscellaneous  
 11 Matrimonial Property Cases           
 12 Succession (Probate & Administration - P&A)
*/
local exclusion_issues = "1,2,3,4,5" //Select from list below
/* 
 1 Missing mediator ID
 2 Mediator appointed before referral
 3 Mediator appointment date missing but mediator assigned
 4 Case conclusion date before mediator assignment
 5 Case days since appointment more than number of days since appointment
 6 Cases which are too new to be included
 7 Cases which came in during the pandemic
*/

//Importing the raw data
import delimited "`path'\Data_Raw\cases_raw_`datapull'.csv", clear 

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

//Create relevant cases variable
	fre casetype // Frequency table
	gen relevantcase = 1 if inlist(casetype,`relevant_cases')
	replace relevantcase = 0 if missing(relevantcase)
	label variable relevantcase "Flag for relevant casetypes for the study (=1)"

//Create issues variable
	*Cases with no mediator ID
		gen issue = 1 if missing(mediator_id)
		label variable issue "Flag for cases with issues"

	*Where mediator appointed before referral
		gen gap = med_appt_date - ref_date
		replace issue = 2 if gap < 0 & missing(issue)
		drop gap

	*Cases where mediator appointment date is missing but mediator assigned
		replace issue = 3 if missing(med_appt_date) & !missing(mediator_id) & missing(issue)

	*Check if there are cases with negative number of days (ask Wei to check)
		replace issue = 4 if case_days_med < 0 & missing(issue)

	*Checking for feasibility of case days
		gen feasible_gap = date("`datapull'", "DMY") - med_appt_date
		gen case_days_gap = feasible_gap - case_days_med
		replace issue = 5 if case_days_gap < 0 & missing(issue)
		drop feasible_gap case_days_gap

	*Flagging cases which came in x (cutoff) days before datapull
		replace issue = 6 if date("`datapull'", "DMY") - med_appt_date < `cutoff'
		
	*Flagging pandemic cases (including x months post pandemic)
		replace issue = 7 if date("`pandemic_start'", "DMY") < ref_date & (date("`pandemic_end'", "DMY") + `post_pandemic') > ref_date

	*Labelling issues
		label define issues 1 "Missing mediator ID" 2 "Mediator appointed before referral" 3 "Mediator appointment date missing but mediator assigned" 4 "Case conclusion date before mediator assignment" 5 "Case days since appointment more than number of days since appointment" 6 "Cases which are too new to be included" 7 "Cases which came in during the pandemic"
		label values issue issues

	*Outsheeting issue cases
		preserve
		keep if inlist(issue, `exclusion_issues')
		keep id mediator_id mediator_appointment_date referral_date case_days case_days_med issue
		export excel using "`path'/Data_Clean/issues_`datapull'.xlsx", firstrow(variables) replace
		restore
	
//Create exclusion variable
	gen exclusion = 1 if inlist(issue, `exclusion_issues')
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
		
/*******************************************************************************
	CREATE ARBITER ROLLOUT DATE VARIABLES
*******************************************************************************/

//Generate rollout date for each courtstation
	sort courtstation create_date
	bys courtstation: egen rollout = min(create_date)
	format rollout %td
	label variable rollout "Rollout date of cadaster for the courtstation"
	* Year
	gen rollout_year = year(rollout)
	format rollout_year %ty
	label variable rollout_year "Rollout year of cadaster for the courtstation"
	* Month-year
	gen rollout_month = month(rollout)
	format rollout_month %tm
	gen rollout_month_year = ym(rollout_year,rollout_month)
	format rollout_month_year %tm
	label variable rollout_month_year "Rollout month and year of cadaster for the courtstation"
	* Month
	drop rollout_month
	gen rollout_month = month(rollout)
	label variable rollout_month "Rollout month of cadaster for the courtstation"

//Generate first mediator assignment date for each courtstation
	sort courtstation create_date
	bys courtstation: egen first_med_assn = min(med_appt_date)
	format first_med_assn %td
	label variable first_med_assn "Date for first mediator assignment for the courtstation"
	*Year
	gen first_med_assn_year = year(first_med_assn)
	format first_med_assn_year %ty
	label variable first_med_assn_year "Year for first mediator assignment for the courtstation"
	*Month-year
	gen first_med_assn_month = month(first_med_assn)
	format first_med_assn_month %tm
	gen first_med_assn_month_year = ym(first_med_assn_year,first_med_assn_month)
	format first_med_assn_month_year %tm
	label variable first_med_assn_month_year "Month and year for first mediator assignment for the courtstation"
	*Month
	drop first_med_assn_month
	gen first_med_assn_month = month(first_med_assn)
	label variable first_med_assn_month "Month for first mediator assignment for the courtstation"

//Create a flag for whether the case was pre rollout or post
	gen post_rollout = 1 if med_appt_date >= rollout
	replace post_rollout = 0 if missing(post_rollout)
	label variable post_rollout "Flag for whether the assignment was done after rollout of cadaster/arbiter"			
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

//Saving cleaned file
	save "`path'/Data_Clean/cases_cleaned_`datapull'.dta", replace
	
/*
	// Rename variables
if "`datapull'" == "14062023" { 
rename (id referraldate casenumber originalcasenumber valuemode casevalue ///
casestatus outcomename agreementmode caseoutcomeagreement pendingreason ///
mediatorappointmentdate conclusiondate forwardedforpaymentdate ///
casedays mediatorappointmentdays numberofplaintifflanguages ///
numberofdefendantlanguages casetype courtdivision courttype courtstation ///
inferredcourt mediatorid referralmode sessiontype ///
completioncertificatedate createdat updatedat ///
 appointmentdataentrytimestamp appointedatcasecreationtime ///
appointeruserid oldmediatormac newmediatormac defendantlanguages ///
 plaintifflanguages) ///
(id referral_date case_number original_case_number value_mode case_value ///
case_status outcome_name agreement_mode case_outcome_agreement pending_reason ///
mediator_appointment_date conclusion_date forwarded_for_payment_date ///
case_days mediator_appointment_days number_of_plaintiff_languages ///
number_of_defendant_languages case_type court_division court_type court_station ///
inferred_court mediator_id referral_mode session_type ///
completion_certificate_date created_at updated_at ///
appointment_data_entry_timestamp appointed_at_case_creation_time ///
appointer_user_id old_mediator_mac new_mediator_mac defendant_languages ///
plaintiff_languages) 
}
*/
