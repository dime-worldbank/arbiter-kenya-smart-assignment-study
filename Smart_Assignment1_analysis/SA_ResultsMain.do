/*****************************************************************
	 Smart Assignment main results (in construction)
	 - Regressions
	 - Brier scores
	 - Rejection rate by VA
	 - ...
******************************************************************/
	
	version 17
	clear all
	
	*** Create useful locals
	local path "C:\Users\didac\Dropbox\Arbiter Research\Data analysis"
	local datapull "06062024"
	
	
/*****************************************************************
	 Import all data
******************************************************************/

	use "`path'/Data_Clean/smartassign_cleaned_`datapull'.dta", clear
	drop if is_test == "t"
	
	* Simplified acceptance variable with only accept/reject
	gen accepted = 1 if acceptance_or_error_status == "accepted"
	replace accepted = 0 if acceptance_or_error_status == "rejected"
	
	gen case = 1
	
/*****************************************************************
	 Main reg t-test
******************************************************************/


	* All cases - Compare actual positive vs negative VA_s mediators. 
	* No matter if CAM officers accepted or rejected the recommendation.
	eststo mod1: reghdfe case_outcome_agreement group_va_s, noabsorb vce(robust)
	eststo mod2: reghdfe case_outcome_agreement group_va_s, absorb(i.appt_month_year i.casetype ///
	i.courttype i.courtstation i.referralmode) vce(robust)
	eststo modu1: reghdfe case_outcome_agreement group_va_u, noabsorb vce(robust)
	eststo modu2: reghdfe case_outcome_agreement group_va_u, absorb(i.appt_month_year i.casetype ///
	i.courttype i.courtstation i.referralmode) vce(robust)
	eststo modupdate1: reghdfe case_outcome_agreement group_va_s_postSA, noabsorb vce(robust)
	eststo modupdate2: reghdfe case_outcome_agreement group_va_s_postSA, absorb(i.appt_month_year i.casetype ///
	i.courttype i.courtstation i.referralmode) vce(robust)
	eststo moduupdate1: reghdfe case_outcome_agreement group_va_u_postSA, noabsorb vce(robust)
	eststo moduupdate2: reghdfe case_outcome_agreement group_va_u_postSA, absorb(i.appt_month_year i.casetype ///
	i.courttype i.courtstation i.referralmode) vce(robust)
	
	* Only if a recommended mediator is accepted by CAM Officers (could 
	* be the first or another)
	* - Accepted
	eststo mod3: reghdfe case_outcome_agreement group_va_s if acceptance_or_error_status =="accepted", noabsorb vce(robust)	
	eststo mod4: reghdfe case_outcome_agreement group_va_s if acceptance_or_error_status =="accepted", absorb(i.appt_month_year i.casetype i.courttype i.courtstation i.referralmode) vce(robust)
	eststo modu3: reghdfe case_outcome_agreement group_va_u if acceptance_or_error_status =="accepted", noabsorb vce(robust)	
	eststo modu4: reghdfe case_outcome_agreement group_va_u if acceptance_or_error_status =="accepted", absorb(i.appt_month_year i.casetype i.courttype i.courtstation i.referralmode) vce(robust)
	eststo modupdate3: reghdfe case_outcome_agreement group_va_s_postSA if acceptance_or_error_status =="accepted", noabsorb vce(robust)	
	eststo modupdate4: reghdfe case_outcome_agreement group_va_s_postSA if acceptance_or_error_status =="accepted", absorb(i.appt_month_year i.casetype i.courttype i.courtstation i.referralmode) vce(robust)
	eststo moduupdate3: reghdfe case_outcome_agreement group_va_u_postSA if acceptance_or_error_status =="accepted", noabsorb vce(robust)	
	eststo moduupdate4: reghdfe case_outcome_agreement group_va_u_postSA if acceptance_or_error_status =="accepted", absorb(i.appt_month_year i.casetype i.courttype i.courtstation i.referralmode) vce(robust)
	
	* Only first recommendation accepted
	* - Accepted
	* - First case accepted
	eststo mod5: reghdfe case_outcome_agreement group_va_s if recommendation_rank ==1, noabsorb vce(robust)
	eststo mod6: reghdfe case_outcome_agreement group_va_s if recommendation_rank ==1, absorb(i.appt_month_year i.casetype i.courttype i.courtstation i.referralmode) vce(robust)
	eststo modu5: reghdfe case_outcome_agreement group_va_u if recommendation_rank ==1, noabsorb vce(robust)
	eststo modu6: reghdfe case_outcome_agreement group_va_u if recommendation_rank ==1, absorb(i.appt_month_year i.casetype i.courttype i.courtstation i.referralmode) vce(robust)
	eststo modupdate5: reghdfe case_outcome_agreement group_va_s_postSA if recommendation_rank ==1, noabsorb vce(robust)
	eststo modupdate6: reghdfe case_outcome_agreement group_va_s_postSA if recommendation_rank ==1, absorb(i.appt_month_year i.casetype i.courttype i.courtstation i.referralmode) vce(robust)
	eststo moduupdate5: reghdfe case_outcome_agreement group_va_u_postSA if recommendation_rank ==1, noabsorb vce(robust)
	eststo moduupdate6: reghdfe case_outcome_agreement group_va_u_postSA if recommendation_rank ==1, absorb(i.appt_month_year i.casetype i.courttype i.courtstation i.referralmode) vce(robust)
	
	* Only accepted cases. Consider cases with more than 60 days as no agreement
	* - Accepted
	* - More than 60 days treated as no agreement 
	preserve
	replace case_outcome_agreement = 0 if case_days_med >60
	eststo mod7: reghdfe case_outcome_agreement group_va_s if acceptance_or_error_status =="accepted", noabsorb vce(robust)
	eststo mod8: reghdfe case_outcome_agreement group_va_s if acceptance_or_error_status =="accepted", absorb(i.appt_month_year i.casetype i.courttype i.courtstation i.referralmode) vce(robust)
	eststo modu7: reghdfe case_outcome_agreement group_va_u if acceptance_or_error_status =="accepted", noabsorb vce(robust)
	eststo modu8: reghdfe case_outcome_agreement group_va_u if acceptance_or_error_status =="accepted", absorb(i.appt_month_year i.casetype i.courttype i.courtstation i.referralmode) vce(robust)
	eststo modupdate7: reghdfe case_outcome_agreement group_va_s_postSA if acceptance_or_error_status =="accepted", noabsorb vce(robust)
	eststo modupdate8: reghdfe case_outcome_agreement group_va_s_postSA if acceptance_or_error_status =="accepted", absorb(i.appt_month_year i.casetype i.courttype i.courtstation i.referralmode) vce(robust)
	eststo moduupdate7: reghdfe case_outcome_agreement group_va_u_postSA if acceptance_or_error_status =="accepted", noabsorb vce(robust)
	eststo moduupdate8: reghdfe case_outcome_agreement group_va_u_postSA if acceptance_or_error_status =="accepted", absorb(i.appt_month_year i.casetype i.courttype i.courtstation i.referralmode) vce(robust)
	restore	
	
	* Only accepted cases. Consider cases with more than 60 days as no agreement
	* - Accepted
	* - First case accepted
	* - More than 60 days treated as no agreement 
	preserve
	replace case_outcome_agreement = 0 if case_days_med > 60
	eststo mod9: reghdfe case_outcome_agreement group_va_s if acceptance_or_error_status =="accepted" & recommendation_rank ==1, noabsorb vce(robust)
	eststo mod10: reghdfe case_outcome_agreement group_va_s if acceptance_or_error_status =="accepted" & recommendation_rank ==1, absorb(i.appt_month_year i.casetype i.courttype i.courtstation i.referralmode) vce(robust)
	eststo modu9: reghdfe case_outcome_agreement group_va_u if acceptance_or_error_status =="accepted" & recommendation_rank ==1, noabsorb vce(robust)
	eststo modu10: reghdfe case_outcome_agreement group_va_u if acceptance_or_error_status =="accepted" & recommendation_rank ==1, absorb(i.appt_month_year i.casetype i.courttype i.courtstation i.referralmode) vce(robust)
	eststo modupdate9: reghdfe case_outcome_agreement group_va_s_postSA if acceptance_or_error_status =="accepted" & recommendation_rank ==1, noabsorb vce(robust)
	eststo modupdate10: reghdfe case_outcome_agreement group_va_s_postSA if acceptance_or_error_status =="accepted" & recommendation_rank ==1, absorb(i.appt_month_year i.casetype i.courttype i.courtstation i.referralmode) vce(robust)
	eststo moduupdate9: reghdfe case_outcome_agreement group_va_u_postSA if acceptance_or_error_status =="accepted" & recommendation_rank ==1, noabsorb vce(robust)
	eststo moduupdate10: reghdfe case_outcome_agreement group_va_u_postSA if acceptance_or_error_status =="accepted" & recommendation_rank ==1, absorb(i.appt_month_year i.casetype i.courttype i.courtstation i.referralmode) vce(robust)
	restore	

	
	esttab mod1 mod2 mod3 mod4 mod5 mod6 mod7 mod8 mod9 mod10 using "`path'\Output\SA_main_reg.tex", se tex replace	
	esttab modu1 modu2 modu3 modu4 modu5 modu6 modu7 modu8 modu9 modu10 using "`path'\Output\SA_main_reg_u.tex", se tex replace	
	esttab modupdate1 modupdate2 modupdate3 modupdate4 modupdate5 modupdate6 modupdate7 modupdate8 modupdate9 modupdate10 using "`path'\Output\SA_main_reg_update.tex", se tex replace	
	esttab moduupdate1 moduupdate2 moduupdate3 moduupdate4 moduupdate5 moduupdate6 moduupdate7 moduupdate8 moduupdate9 moduupdate10 using "`path'\Output\SA_main_reg_uupdate.tex", se tex replace

	
/*****************************************************************
	 Accepted/rejected/all ineligible/pending 
******************************************************************/	
	
	
	* Total cases by group
	egen TOT_group = count(case), by(group)
	egen TOT_group_accepted = count(case) if acceptance_or_error_status == "accepted", by(group)
	egen TOT_group_rejected = count(case) if acceptance_or_error_status == "rejected", by(group)
	egen TOT_group_inel = count(case) if acceptance_or_error_status == "all ineligible", by(group)
	egen TOT_group_pending = count(case) if acceptance_or_error_status == "pending", by(group)
	
	

preserve
	collapse TOT_group TOT_group_accepted TOT_group_rejected TOT_group_inel TOT_group_pending, by(group)
	
	eststo types1: estpost tabstat TOT_group TOT_group_accepted TOT_group_rejected TOT_group_inel TOT_group_pending, by(group) st(mean)  
	esttab types1 using "`path'/Output/SA_casestatus_arip.tex", ///
	cells("TOT_group(fmt(0)) TOT_group_accepted(fmt(2)) TOT_group_rejected(fmt(2)) TOT_group_inel(fmt(2)) TOT_group_pending(fmt(2))") ///
	label replace noobs
restore	

/*****************************************************************
	 Duration 
******************************************************************/	
	
	* Total cases by group
	egen TOT_group_va_s = count(case) if accepted==1, by(group)
	* Case durations by group and (no-)agreement
	egen avg_case_days_med = mean(case_days_med) if accepted==1, by(group)
	egen avg_case_days_med_agree = mean(case_days_med) ///
	if case_outcome_agreement == 1 & accepted==1, by(group) // Agreement
	egen avg_case_days_med_dis = mean(case_days_med) ///
	if case_outcome_agreement == 0 & accepted==1, by(group) // No agreement

preserve
	collapse TOT_group_va_s avg_case_days_med avg_case_days_med_agree avg_case_days_med_dis, by(group)
	
	eststo types1: estpost tabstat TOT_group_va_s avg_case_days_med avg_case_days_med_agree avg_case_days_med_dis, by(group) st(mean)  
	esttab types1 using "`path'/Output/SA_durations.tex", ///
	cells("TOT_group_va_s(fmt(0)) avg_case_days_med(fmt(2)) avg_case_days_med_agree(fmt(2)) avg_case_days_med_dis(fmt(2))") ///
	label replace noobs
restore	

/*****************************************************************
	 Rejection rate by VA
	 - Ignore ineligible or pending cases
******************************************************************/

*** Table with average acceptance and rank by VA group
	* Total cases accepted or rejected
	egen TOT_group_va_s_ar = count(case) if accepted !=., by(group)
	* Percent acceptance of mediator by VA group
	egen avg_acceptance = mean(accepted), by(group)
	* Average rank by VA group
	egen avg_rank = mean(recommendation_rank) if accepted == 1, by(group)

	local path "C:\Users\didac\Dropbox\Arbiter Research\Data analysis"
	preserve
	collapse TOT_group_va_s_ar avg_acceptance avg_rank, by(group)
	
	eststo types1: estpost tabstat TOT_group_va_s_ar avg_acceptance avg_rank, by(group) st(mean)  
	esttab types1 using "`path'/Output/SA_groupsaccept.tex", ///
	cells("TOT_group_va_s_ar(fmt(0)) avg_acceptance(fmt(2)) avg_rank(fmt(2))") ///
	label replace noobs

* Histogram of rank
*tw (hist recommendation_rank if group_va_s == 1, width(1) lwidth(0) color(green%30)  freq ) ///
*(hist recommendation_rank if group_va_s == 0, width(1) lwidth(0) color(red%30)  freq ) ///
*(kdensity recommendation_rank if group_va_s == 1, yaxis(2) lcolor(green)) ///
*(kdensity recommendation_rank if group_va_s == 0, yaxis(2) lcolor(red) legend(off))


/*
encode acceptance_or_error_status, gen(acceptance_or_error_statusenc)

* Rejection rate by VA - Accepted vs rejected. Ignore all inelegible. 
preserve
keep if acceptance_or_error_statusenc == 1 | acceptance_or_error_statusenc == 4
replace acceptance_or_error_statusenc = 0 if acceptance_or_error_statusenc == 4
tw scatter acceptance_or_error_statusenc va_s
lpoly acceptance_or_error_statusenc va_s
restore

* Rejection rate by VA - Accepted vs rejected. Only if rejection reason is not court named
preserve
keep if acceptance_or_error_statusenc == 1 | acceptance_or_error_statusenc == 4
replace acceptance_or_error_statusenc = 0 if acceptance_or_error_statusenc == 1
tw scatter acceptance_or_error_statusenc va_s if reject_reason != "COURT_NAMED"
lpoly acceptance_or_error_statusenc va_s if reject_reason != "COURT_NAMED"
restore

* Rejection rate by VA - Accepted vs rejected. Only if rejection reason is not court named or parties requested
preserve
keep if acceptance_or_error_statusenc == 1 | acceptance_or_error_statusenc == 4
replace acceptance_or_error_statusenc = 0 if acceptance_or_error_statusenc == 4
tw scatter acceptance_or_error_statusenc va_s if reject_reason != "COURT_NAMED"
lpoly acceptance_or_error_statusenc va_s if reject_reason != "COURT_NAMED" & reject_reason != "PARTIES_REQUESTED"
restore

* 
gen firstaccepted = 1 if recommendation_rank==1
replace firstaccepted = 0 if recommendation_rank>1
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

* Durations


* Case duration by group and agreement/no agreement

