	
	version 17
	clear all
	
	*** Create useful locals
	local path "C:\Users\didac\Dropbox\Arbiter Research\Data analysis"
	local datapull "03042024" 	
	
	
/*****************************************************************
	 Import all data
******************************************************************/
	
*** VA GROUPS: Import and tempsave
	* Shrunk VA
	import delimited "`path'\Output\va_groups_pull15062023.csv", clear
	rename (tv group_tv) (va_s group_va_s)
	tempfile va_s_groups
	save `va_s_groups'	

	* Unhrunk VA
	import delimited using "`path'\Output\va_u_groups_pull15062023.csv", clear
	tempfile va_u_groups // tempfile for merge
	save `va_u_groups'
	
*** Smart assignment cases: Import and tempsave
	import delimited "`path'\Data_Raw\Vw_All_Random_Study_Case_20032024.csv", clear
	rename mediatorid mediator_id
	keep group istest acceptanceorerrorstatus rejectreason recommendationrank /// 
	studyeligiblemediatorforcaseid id mediator_id
	drop if istest == "true" // Drop technical testing cases	
	tempfile SA // tempfile for merge
	save `SA'	
	
*** Cases main: Import
	use "`path'/Data_Clean/cases_cleaned_`datapull'.dta", clear

*** Merge all 
	merge 1:1 id using `SA'
	keep if _merge == 3
	drop _merge
	merge m:1 mediator_id using `va_s_groups'
	drop _merge
	merge m:1 mediator_id using `va_u_groups'
	drop _merge
	
	
/*****************************************************************
	 Main reg t-test
******************************************************************/

	* All cases - SA recommended T vs SA recommended C - (ITT, I think) 
	reghdfe case_outcome_agreement group i.appt_month_year i.casetype ///
	i.courttype i.courtstation i.referralmode, noabsorb nocons
	
	* All cases - Compare actual positive vs negative VA_s mediators. No matter if CAM officers accepted or rejected the recommendation.
	reghdfe case_outcome_agreement group_va_s i.appt_month_year i.casetype ///
	i.courttype i.courtstation i.referralmode, noabsorb nocons
	
	* Only if a recommended mediator is accepted by CAM Officers (could be the first or another)
	reghdfe case_outcome_agreement group_va_s i.appt_month_year i.casetype ///
	i.courttype i.courtstation i.referralmode if acceptanceorerrorstatus =="accepted", noabsorb nocons
	
	* Only first recommendation accepted
	reghdfe case_outcome_agreement group_va_s i.appt_month_year i.casetype ///
	i.courttype i.courtstation i.referralmode if recommendationrank ==1, noabsorb nocons
	
	* Foucs only in accepted cases in which the max number of days is 60
	reghdfe case_outcome_agreement group_va_s i.appt_month_year i.casetype ///
	i.courttype i.courtstation i.referralmode if acceptanceorerrorstatus =="accepted" & case_days_med <60, noabsorb nocons
	
	reg case_outcome_agreement group_va_s i.appt_month_year i.casetype ///
	i.courttype i.courtstation i.referralmode if acceptanceorerrorstatus =="accepted" & case_days_med <60,  nocons
	
	* Foucs only in accepted cases in which the max number of days is 90
	reghdfe case_outcome_agreement group_va_s i.appt_month_year i.casetype ///
	i.courttype i.courtstation i.referralmode if acceptanceorerrorstatus =="accepted" & case_days_med <90, noabsorb nocons
	
	* Only accepted cases. Consider cases with more than 60 days as no agreement
	preserve
	replace case_outcome_agreement = 0 if case_days_med >60
	reghdfe case_outcome_agreement group_va_s i.appt_month_year i.casetype ///
	i.courttype i.courtstation i.referralmode if acceptanceorerrorstatus =="accepted", noabsorb nocons
	restore	
	
	* Only accepted cases. Consider cases with more than 90 days as no agreement
	preserve
	replace case_outcome_agreement = 0 if case_days_med >90
	reghdfe case_outcome_agreement group_va_s i.appt_month_year i.casetype ///
	i.courttype i.courtstation i.referralmode if acceptanceorerrorstatus =="accepted", noabsorb nocons
	restore	
	
	* Only if first recommendation is accepted. Consider cases with more than 60 days as no agreement
	preserve
	replace case_outcome_agreement = 0 if case_days_med >60
	reghdfe case_outcome_agreement group_va_s i.appt_month_year i.casetype ///
	i.courttype i.courtstation i.referralmode if recommendationrank ==1, noabsorb nocons
	restore	
	
	* Only if first recommendation is accepted. Consider cases with more than 90 days as no agreement
	preserve
	reghdfe case_outcome_agreement group_va_s i.appt_month_year i.casetype ///
	i.courttype i.courtstation i.referralmode if recommendationrank ==1 & case_days_med <60, noabsorb nocons
	restore	

	*** Unshrunk VA
	preserve
	replace case_outcome_agreement = 0 if case_days_med >60
	reghdfe case_outcome_agreement group_va_s i.appt_month_year i.casetype ///
	i.courttype i.courtstation i.referralmode if recommendationrank ==1, noabsorb nocons
	restore	

/*****************************************************************
	 Rejection rate by VA
******************************************************************/

gen first

encode acceptanceorerrorstatus, gen(acceptanceorerrorstatusencoded)

* Rejection rate by VA - Accepted vs rejected. Ignore all inelegible. 
preserve
keep if acceptanceorerrorstatusencoded == 1 | acceptanceorerrorstatusencoded == 4
replace acceptanceorerrorstatusencoded = 0 if acceptanceorerrorstatusencoded == 4
tw scatter acceptanceorerrorstatusencoded va_s
lpoly acceptanceorerrorstatusencoded va_s
restore

* Rejection rate by VA - Accepted vs rejected. Only if rejection reason is not court named
preserve
keep if acceptanceorerrorstatusencoded == 1 | acceptanceorerrorstatusencoded == 4
replace acceptanceorerrorstatusencoded = 0 if acceptanceorerrorstatusencoded == 1
tw scatter acceptanceorerrorstatusencoded va_s if rejectreason != "COURT_NAMED"
lpoly acceptanceorerrorstatusencoded va_s if rejectreason != "COURT_NAMED"
restore

* Rejection rate by VA - Accepted vs rejected. Only if rejection reason is not court named or parties requested
preserve
keep if acceptanceorerrorstatusencoded == 1 | acceptanceorerrorstatusencoded == 4
replace acceptanceorerrorstatusencoded = 0 if acceptanceorerrorstatusencoded == 4
tw scatter acceptanceorerrorstatusencoded va_s if rejectreason != "COURT_NAMED"
lpoly acceptanceorerrorstatusencoded va_s if rejectreason != "COURT_NAMED" & rejectreason != "PARTIES_REQUESTED"
restore

* 
gen firstaccepted = 1 if recommendationrank==1
replace firstaccepted = 0 if recommendationrank>1
tab firstaccepted group_va_s
tw (scatter firstaccepted va_s) (lfit firstaccepted va_s)
tw (scatter firstaccepted va_s) (lpoly firstaccepted va_s)


/*****************************************************************
	 Brier score
******************************************************************/

* Regressions - Try Unshrunk VA
* Brier scores - Future
* Graphs
* Rejection rate by VA
* Overleaf - Future


/* To do
- Brier scores
- Overleaf? I can save all these results in overleaf just to keep better track
of everything we do. 

