version 17
clear all


//Define locals 
local path "C:\Users\didac\Dropbox\Arbiter Research\Data analysis"


/*******************************************************************************
	
*******************************************************************************/

*** Import and tempsave last referral date for each mediator
use "`path'\Data_Clean\cases_cleaned_15062023.dta", replace
collapse (max) med_appt_date, by(mediator_id)
rename med_appt_date last_appt
tempfile last_appt
save `last_appt'

*** Import and tempsave VA groups
import delimited "`path'\Output\va_groups_pull15062023.csv", clear
tempfile va_groups
save `va_groups'

*** Import Active-Inactive changes
import delimited using "`path'\Data_Raw\inactive_changes_21082023.csv", clear

rename objectpk mediator_id

keep mediator_id timestamp changes

*** Merge all data
	* Merge with active-inactive changes
	merge m:1 mediator_id using `va_groups'
	drop if _merge==1
	drop _merge
	* Merge with last referral
	merge m:1 mediator_id using `last_appt'
	drop if _merge == 2
	drop _merge
	

*** Time
split timestamp, parse(T)
generate last_change_date = date(timestamp1, "YMD")
format last_change_date %td
drop timestamp1 timestamp2

*** Activity change
gen change_num = .
replace change_num = 1 if strpos(changes, `"status": ["Active", "Inactive"') 
replace change_num = 2 if strpos(changes, `"status": ["Inactive", "Active"') 
replace change_num = 3 if strpos(changes, `"status": ["Mentorship", "Active"') 
replace change_num = 4 if strpos(changes, `"status": ["Mentorship", "Inactive"') 
replace change_num = 5 if strpos(changes, "Active") & strpos(changes, "Deceased") 
replace change_num = 6 if strpos(changes, "Inactive") & strpos(changes, "Deceased") 

* Keep only last change of each mediator
sort mediator_id timestamp
by mediator_id: keep if _n == _N

*** Inactive mediator
	* Inactive because their last change was to "Inactive"
	gen inactive_now = 1 if change_num == 1 | change_num == 4 |  change_num == 5 |  change_num == 6
	* Inactive because they had not been referred to a case since 2021
	replace inactive_now = 1 if last_appt <= date("20220701","YMD")

summ inactive_now if group_tv==1
summ inactive_now if group_tv==0

