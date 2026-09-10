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
	local datapull "17102024"
	
	
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
	 TABLE 1  
******************************************************************/	
		
	*** Relevant variables: Number of cases by different status
	* Total cases by group
	egen TOT_group = count(case), by(group)
	
	* Assignment status
	egen TOT_group_noassign = count(case) if ///
	acceptance_or_error_status == "pending", by(group)
	egen TOT_group_assign = count(case) if ///
	TOT_group_noassign == ., by(group)
	
	* Case conclusion status
	egen TOT_group_concl = count(case) if ///
	case_status == "CONCLUDED", by(group)
	egen TOT_group_noconcl = count(case) if ///
	case_status == "PENDING", by(group)
	
	* Final mediator assignment
	egen TOT_group_accepted = count(case) if ///
	acceptance_or_error_status == "accepted", by(group)
	egen TOT_group_inel = count(case) if ///
	acceptance_or_error_status == "all ineligible", by(group)
	egen TOT_group_rejected = count(case) if ///
	acceptance_or_error_status == "rejected", by(group)
		* Rejection reason
		egen TOT_group_partiesreqst = count(case) if ///
		reject_reason == "PARTIES_REQUESTED", by(group)
		egen TOT_group_courtnamed = count(case) if ///
		reject_reason == "COURT_NAMED", by(group)
		egen TOT_group_meddecline = count(case) if ///
		reject_reason == "MEDIATOR_DECLINED", by(group)
		egen TOT_group_medunreach = count(case) if ///
		reject_reason == "MEDIATOR_UNREACHABLE", by(group)
		egen TOT_group_other = count(case) if ///
		reject_reason == "OTHER", by(group)

	
	* First recommended mediator is assigned
	egen TOT_group_firstassign = count(case) if recommendation_rank == 1 & ///
	acceptance_or_error_status == "accepted", by(group)	
	
** Table 1

	* Top
	file open tab1_descr using "`path'/Output/Smart_assignment_rts/SA_tab1.tex", write text replace
	file write tab1_descr "\scalebox{0.7}{" _n
	file write tab1_descr "\begin{tabular}{c|c|cc|cc|ccc|ccccc|c}"  _n
	file write tab1_descr "\toprule" _n
	
	file write tab1_descr "&  & \multicolumn{2}{c|}{Mediator assignment}  & \multicolumn{2}{c|}{Conclusion status} & \multicolumn{3}{c|}{Mediator in-list choice} & \multicolumn{5}{c|}{Reject reason} & First Med \\" _n
	
	file write tab1_descr "Arm & Cases & Assigned & Not assigned & Concluded & Not concluded & Accepted & All ineligible & Rejected &  Parties request & Court named & Med decline & Med unreachable & Other & Accepted \\" _n
	
	file write tab1_descr "\hline" _n
	
	* Body
	forvalues i = 0(1)1{
	summ TOT_group if group == `i'
	local TOT_group_`i' = `r(N)'
	summ TOT_group_assign if group == `i'
	local TOT_group_assign_`i' = `r(N)'
	summ TOT_group_noassign if group == `i'
	local TOT_group_noassign_`i' = `r(N)'
	summ TOT_group_concl if group == `i'
	local TOT_group_concl_`i' = `r(N)'
	summ TOT_group_noconcl if group == `i'
	local TOT_group_noconcl_`i' = `r(N)'
	summ TOT_group_accepted if group == `i'
	local TOT_group_accepted_`i' = `r(N)'
	summ TOT_group_inel if group == `i'
	local TOT_group_inel_`i' = `r(N)'
	summ TOT_group_rejected if group == `i'
	local TOT_group_rejected_`i' = `r(N)'
	summ TOT_group_partiesreqst if group == `i'
	local TOT_group_partiesreqst_`i' = `r(N)'
	summ TOT_group_courtnamed if group == `i'
	local TOT_group_courtnamed_`i' = `r(N)'
	summ TOT_group_meddecline if group == `i'
	local TOT_group_meddecline_`i' = `r(N)'
	summ TOT_group_medunreach if group == `i'
	local TOT_group_medunreach_`i' = `r(N)'
	summ TOT_group_other if group == `i'
	local TOT_group_other_`i' = `r(N)'
	summ TOT_group_firstassign if group == `i'
	local TOT_group_firstassign_`i' = `r(N)'	
	}
	
	summ TOT_group 
	local TOT_group_all = `r(N)'
	summ TOT_group_assign 
	local TOT_group_assign_all = `r(N)'
	summ TOT_group_noassign 
	local TOT_group_noassign_all = `r(N)'
	summ TOT_group_concl 
	local TOT_group_concl_all = `r(N)'
	summ TOT_group_noconcl 
	local TOT_group_noconcl_all = `r(N)'
	summ TOT_group_accepted 
	local TOT_group_accepted_all = `r(N)'
	summ TOT_group_inel 
	local TOT_group_inel_all = `r(N)'
	summ TOT_group_rejected 
	local TOT_group_rejected_all = `r(N)'
	summ TOT_group_partiesreqst 
	local TOT_group_partiesreqst_all = `r(N)'
	summ TOT_group_courtnamed 
	local TOT_group_courtnamed_all = `r(N)'
	summ TOT_group_meddecline 
	local TOT_group_meddecline_all = `r(N)'
	summ TOT_group_medunreach 
	local TOT_group_medunreach_all = `r(N)'
	summ TOT_group_other 
	local TOT_group_other_all = `r(N)'
	summ TOT_group_firstassign
	local TOT_group_firstassign_all = `r(N)'	
	
	file write tab1_descr " C & `TOT_group_0' & `TOT_group_assign_0' & `TOT_group_noassign_0' & `TOT_group_concl_0' & `TOT_group_noconcl_0' & `TOT_group_accepted_0' & `TOT_group_inel_0' & `TOT_group_rejected_0'  & `TOT_group_partiesreqst_0' & `TOT_group_courtnamed_0' & `TOT_group_meddecline_0' & `TOT_group_medunreach_0' & `TOT_group_other_0' & `TOT_group_firstassign_0' \\" _n

	file write tab1_descr " T & `TOT_group_1' & `TOT_group_assign_1' & `TOT_group_noassign_1' & `TOT_group_concl_1' & `TOT_group_noconcl_1' & `TOT_group_accepted_1' & `TOT_group_inel_1' &  `TOT_group_rejected_1' & `TOT_group_partiesreqst_1' & `TOT_group_courtnamed_1' & `TOT_group_meddecline_1' & `TOT_group_medunreach_1' & `TOT_group_other_1' &  `TOT_group_firstassign_1' \\" _n

	file write tab1_descr "\midrule" _n
	
	file write tab1_descr " All & `TOT_group_all' & `TOT_group_assign_all' & `TOT_group_noassign_all' & `TOT_group_concl_all' & `TOT_group_noconcl_all' & `TOT_group_accepted_all' & `TOT_group_inel_all' &  `TOT_group_rejected_all' & `TOT_group_partiesreqst_all' & `TOT_group_courtnamed_all' & `TOT_group_meddecline_all' & `TOT_group_medunreach_all' & `TOT_group_other_all' &  `TOT_group_firstassign_all' \\" _n
		
	* Bottom
	file write tab1_descr "\bottomrule" _n
	file write tab1_descr "\end{tabular}" _n
	file write tab1_descr "}" 
	file close tab1_descr
/*
preserve
	collapse TOT_group TOT_group_accepted TOT_group_rejected TOT_group_inel TOT_group_pending, by(group)
	
	eststo types1: estpost tabstat TOT_group TOT_group_accepted TOT_group_rejected TOT_group_inel TOT_group_pending, by(group) st(mean)  
	esttab types1 using "`path'/Output/Smart_assignment_rts/SA_casestatus_arip.tex", ///
	cells("TOT_group(fmt(0)) TOT_group_accepted(fmt(2)) TOT_group_rejected(fmt(2)) TOT_group_inel(fmt(2)) TOT_group_pending(fmt(2))") ///
	label replace noobs
restore		
*/

/*****************************************************************
	 TABLE 2 - Rejection rate by VA
	 - Ignore ineligible or pending cases
******************************************************************/

	* Indicator for being in the ITT sample
	gen ITT_sample = 1 if acceptance_or_error_status == "accepted" | ///
	(acceptance_or_error_status == "rejected" & ///
	(reject_reason == "MEDIATOR_DECLINED" | ///
	reject_reason == "MEDIATOR_UNREACHABLE" | reject_reason == "OTHER"))

	* Total cases
	egen TOT_group_ITT = count(case) if ///
	ITT_sample == 1, by(group)
	
	* Percent Acceptance
	egen TOT_group_ITT_acceptt = count(case) if ITT_sample == 1 & ///
	acceptance_or_error_status == "accepted", by(group)
	bys group: egen TOT_group_ITT_accept = mean(TOT_group_ITT_acceptt)
	egen TOT_group_ITT_rejectt = count(case) if ITT_sample == 1 & ///
	acceptance_or_error_status == "rejected", by(group)
	bys group: egen TOT_group_ITT_reject = mean(TOT_group_ITT_rejectt)
	gen PCT_group_ITT_accept = TOT_group_ITT_accept / TOT_group_ITT

	* Percent First Acceptance
	egen TOT_group_ITT_firstacceptt = count(case) if ITT_sample == 1 & ///
	acceptance_or_error_status == "accepted" & recommendation_rank == 1, ///
	by(group)
	gen PCT_group_ITT_firstaccept = TOT_group_ITT_firstacceptt / TOT_group_ITT
	
	* Avg rank of accepted
	egen AVG_group_rank = mean(recommendation_rank) if ///
	acceptance_or_error_status == "accepted", by(group)
	
	* VA accepted - Mean VA proposed mediators
	* Group rejected/inelegible mediators go to 

** Table 2

	* Top
	file open tab2_acceptance using "`path'/Output/Smart_assignment_rts/SA_tab2.tex", write text replace
	file write tab2_acceptance "\begin{tabular}{ccccc}"  _n
	file write tab2_acceptance "\toprule" _n
	file write tab2_acceptance " Arm & Cases & Pct Accepted & Pct Accepted first & Avg rank accepted \\" _n
	file write tab2_acceptance "\hline" _n
	
	* Body
	forvalues i = 0(1)1{
	summ TOT_group_ITT if group == `i'
	local TOT_group_ITT_`i' = `r(N)'
	summ PCT_group_ITT_accept if group == `i'
	local PCT_group_ITT_accept_`i' = round(`r(mean)', 0.01)
	summ PCT_group_ITT_firstaccept if group == `i'
	local PCT_group_ITT_firstaccept_`i' = round(`r(mean)', 0.01)
	summ AVG_group_rank if group == `i'
	local AVG_group_rank_`i' = round(`r(mean)', 0.01)
	}
	/*
	summ TOT_group_ITT 
	local TOT_group_ITT_all = `r(N)'
	summ PCT_group_ITT_accept 
	local PCT_group_ITT_accept_all = round(`r(mean)', 0.01)
	summ PCT_group_ITT_firstaccept 
	local PCT_group_ITT_firstaccept_all = round(`r(mean)', 0.01)
	summ AVG_group_rank 
	local AVG_group_rank_all = round(`r(mean)', 0.01)*/

	file write tab2_acceptance " C & `TOT_group_ITT_0' & `PCT_group_ITT_accept_0' & `PCT_group_ITT_firstaccept_0' & `AVG_group_rank_0'  \\" _n
	file write tab2_acceptance " T & `TOT_group_ITT_1' & `PCT_group_ITT_accept_1' & `PCT_group_ITT_firstaccept_1' & `AVG_group_rank_1'  \\" _n
	/*file write tab2_acceptance "\midrule" _n
	file write tab2_acceptance " All & `TOT_group_ITT_all' & `PCT_group_ITT_accept_all' & `PCT_group_ITT_firstaccept_all' & `AVG_group_rank_all'  \\" _n*/
	
	* Bottom
	file write tab2_acceptance "\bottomrule" _n
	file write tab2_acceptance "\end{tabular}" _n
	file close tab2_acceptance
	
/*
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
	esttab types1 using "`path'/Output/Smart_assignment_rts/SA_groupsaccept.tex", ///
	cells("TOT_group_va_s_ar(fmt(0)) avg_acceptance(fmt(2)) avg_rank(fmt(2))") ///
	label replace noobs
*/

/* Histogram of rank
tw (hist recommendation_rank if group == 1 & ///
acceptance_or_error_status == "accepted", width(1) lwidth(0) color(green%30)  freq ) ///
(hist recommendation_rank if group_va_s == 0& ///
acceptance_or_error_status == "accepted", width(1) lwidth(0) color(red%30)  freq ) ///
(kdensity recommendation_rank if group_va_s == 1, yaxis(2) lcolor(green)) ///
(kdensity recommendation_rank if group_va_s == 0, yaxis(2) lcolor(red) legend(off))
*/

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
*/

/*****************************************************************
	 TABLE 3 - Duration 
******************************************************************/	
	
	* Indicator for being in the TOT full or partial sample
	gen TOTf_sample = 1 if acceptance_or_error_status == "accepted" 	
	gen TOTp_sample = 1 if acceptance_or_error_status == "accepted" ///
	&recommendation_rank == 1
	
	* Completed cases
		* Full sample
		* ITT
		* TOT full
		* TOT partial
	
	* Duration 
		* Full
		egen AVG_group_case_days_med = mean(case_days_med), by(group)
		* ITT
		egen AVG_group_ITT_case_days_med = mean(case_days_med) ///
		if ITT_sample == 1 , by(group)
		* TOTf
		egen AVG_group_TOTf_case_days_med = mean(case_days_med) ///
		if TOTf_sample == 1 , by(group)		
		* TOTp
		egen AVG_group_TOTp_case_days_med = mean(case_days_med) ///
		if TOTp_sample == 1 , by(group)
		
	* Duration accepted
		* Full
		egen AVG_group_case_days_med_accept = mean(case_days_med) if ///
		acceptance_or_error_status == "accepted", by(group)
		* ITT
		egen AVG_group_ITT_case_days_med_accept = mean(case_days_med) if ///
		acceptance_or_error_status == "accepted" & ITT_sample == 1, by(group)
		* TOTf
		egen AVG_group_TOTf_case_days_med_accept = mean(case_days_med) if ///
		acceptance_or_error_status == "accepted" & TOTf_sample == 1, by(group)
		* TOTp
		egen AVG_group_TOTp_case_days_med_accept = mean(case_days_med) if ///
		acceptance_or_error_status == "accepted" & TOTp_sample == 1, by(group)
		
	* Duration rejected
		* Full
		egen AVG_group_case_days_med = mean(case_days_med) if ///
		acceptance_or_error_status == "rejected", by(group)
		* ITT
		egen AVG_group_ITT_case_days_med = mean(case_days_med) if ///
		acceptance_or_error_status == "rejected" & ITT_sample == 1, by(group)
		* TOTf
		egen AVG_group_TOTf_case_days_med = mean(case_days_med) if ///
		acceptance_or_error_status == "rejected" & TOTf_sample == 1, by(group)		
		* TOTp		
		egen AVG_group_TOTp_case_days_med = mean(case_days_med) if ///
		acceptance_or_error_status == "rejected" & TOTp_sample == 1, by(group)

	/*
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
	esttab types1 using "`path'/Output/Smart_assignment_rts/SA_durations.tex", ///
	cells("TOT_group_va_s(fmt(0)) avg_case_days_med(fmt(2)) avg_case_days_med_agree(fmt(2)) avg_case_days_med_dis(fmt(2))") ///
	label replace noobs
restore	
*/


	
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

	
	esttab mod1 mod2 mod3 mod4 mod5 mod6 mod7 mod8 mod9 mod10 using "`path'\Output\Smart_assignment_rts\SA_main_reg.tex", se tex replace	
	esttab modu1 modu2 modu3 modu4 modu5 modu6 modu7 modu8 modu9 modu10 using "`path'\Output\Smart_assignment_rts\SA_main_reg_u.tex", se tex replace	
	esttab modupdate1 modupdate2 modupdate3 modupdate4 modupdate5 modupdate6 modupdate7 modupdate8 modupdate9 modupdate10 using "`path'\Output\Smart_assignment_rts\SA_main_reg_update.tex", se tex replace	
	esttab moduupdate1 moduupdate2 moduupdate3 moduupdate4 moduupdate5 moduupdate6 moduupdate7 moduupdate8 moduupdate9 moduupdate10 using "`path'\Output\Smart_assignment_rts\SA_main_reg_uupdate.tex", se tex replace

	

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
	esttab types1 using "`path'/Output/Smart_assignment_rts/SA_durations.tex", ///
	cells("TOT_group_va_s(fmt(0)) avg_case_days_med(fmt(2)) avg_case_days_med_agree(fmt(2)) avg_case_days_med_dis(fmt(2))") ///
	label replace noobs
restore	



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

