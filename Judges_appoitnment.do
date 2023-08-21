/*******************************************************************************
Project: World Bank Kenya Arbiter
PIs: Anja Sautmann and Antoine Deeb
Purpose: Mediators appointed by judges during the technical testing phase. How
do they differ from the rest of mediators?
Author: Didac Marti Pinto
*******************************************************************************/

version 17
clear all

//Define locals 
local path "C:\Users\didac\Dropbox\Arbiter Research\Data analysis"
local datapull = "25072023" // "11062023" //"05102022" //  "27022023" 

/*******************************************************************************
	IMPORT AND PREPARE DATA
*******************************************************************************/

*** T AND C GROUPS
import delimited using "`path'\Output\va_groups_pull`datapull'.csv"

	* Tempsave
	tempfile VA_groups
	save `VA_groups'
	
*** MAIN CLEAN DATASET: Create some basic statistics about mediators to complement VA 
use "`path'/Data_Clean/cases_cleaned_`datapull'.dta", clear

	* First appointment
	egen first_case_assn = min(med_appt_date), by(mediator_id)
	
	* Number of cases referred to each mediator
	gen ones = 1 
	egen num_cases_referred = total(ones), by(mediator_id)
	drop ones
	
	* Number of cases concluded
	gen concluded = 1 if casestatus == 1
	egen num_cases_concl = total(concluded), by(mediator_id)
	drop concluded

	* Number of agreements
	egen num_agreement = total(case_outcome_agreement), by(mediator_id)

	* Percent of agreement from the concluded cases
	gen pct_agreement = num_agreement / num_cases_concl
	
	collapse first_case_assn num_cases_referred num_cases_concl pct_agreement, by(mediator_id)
	
	tempfile mediator_stats
	save `mediator_stats'

*** IMPORT DATA
import delimited "C:\Users\didac\OneDrive\Escritorio\Smart_Judge_Appointed.csv", clear
	
	** Selected mediators 
	* Match with their VA and other statistics
	rename vwallcasecasemediatorid mediator_id
	merge 1:1 mediator_id using `VA_groups'
	drop if _merge==2 
	drop _merge
	merge 1:1 mediator_id using `mediator_stats'
	drop if _merge==2 
	drop _merge
	rename (mediator_id tv group_tv first_case_assn num_cases_referred num_cases_concl pct_agreement) (mediator_id_selected tv_selected group_tv_selected first_case_assn_selected num_cases_referred_selected num_cases_concl_selected pct_agreement_selected)

	** Rejected mediators 
	* Match with their VA and other statistics
	rename mediatorid mediator_id
	merge 1:1 mediator_id using `VA_groups'
	drop if _merge==2 
	drop _merge
	merge 1:1 mediator_id using `mediator_stats'
	drop if _merge==2 
	drop _merge
	rename (mediator_id tv group_tv first_case_assn num_cases_referred num_cases_concl pct_agreement) (mediator_id_rejected tv_rejected group_tv_rejected first_case_assn_rejected num_cases_referred_rejected num_cases_concl_rejected pct_agreement_rejected)

/*******************************************************************************
	OUTSHEET OUTCOMES
*******************************************************************************/

*** Keep only relevant variables 
keep rejectreasoncourtnamedby mediator_id_selected tv_selected group_tv_selected first_case_assn_selected num_cases_referred_selected num_cases_concl_selected pct_agreement_selected mediator_id_rejected tv_rejected group_tv_rejected first_case_assn_rejected num_cases_referred_rejected num_cases_concl_rejected pct_agreement_rejected

* Sort by Appointing judge
sort rejectreasoncourtnamedby

format first_case_assn_selected %td
format first_case_assn_rejected %td

export excel using "`path'/Output/judges_appoint.xlsx", firstrow(variables) replace

/*


/*

*** MEDIATORS THAT WERE REJECTED
tab mediatorid if rejectreasoncourtnamedby == "HON M. N. LUBIA" | rejectreasoncourtnamedby == "HON. M.N. LUBIA" | rejectreasoncourtnamedby == "HON. M.N LUBIA" | rejectreasoncourtnamedby == "HON. M. N. LUBIA"

/* 

Mediator ID |      Freq.     Percent        Cum.
------------+-----------------------------------
        630 |          1       25.00       25.00
        711 |          1       25.00       50.00
        963 |          1       25.00       75.00
        976 |          1       25.00      100.00
------------+-----------------------------------
      Total |          4      100.00

	  
	  - None of them is in the VA groups. Probably they don't meet the criteria to be there
*/

*** MEDIATORS THAT HON LUBIA SELECTED

tab vwallcasecasemediatorid if rejectreasoncourtnamedby == "HON M. N. LUBIA" | rejectreasoncourtnamedby == "HON. M.N. LUBIA" | rejectreasoncourtnamedby == "HON. M.N LUBIA" | rejectreasoncourtnamedby == "HON. M. N. LUBIA"

/*
Vw All Case |
   - Case → |
Mediator ID |      Freq.     Percent        Cum.
------------+-----------------------------------
        608 |          1       25.00       25.00
        621 |          1       25.00       50.00
        637 |          1       25.00       75.00
        952 |          1       25.00      100.00
------------+-----------------------------------
      Total |          4      100.00
*/

*** OTHER MEDIATORS THAT WERE REJECTED

*** MEDIATORS THAT OTHER JUDGES SELECTED
tab vwallcasecasemediatorid
*/
