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
	
	** MISSING MEDIATOR ID's - NEED TO FIND OUT WHAT HAPPENED
	drop if mediator_id == .

/*****************************************************************
	 TABLE 1  
******************************************************************/	

	* "Sample 0" - All cases
	gen ALL_sample = case

	* "Sample 1" - Clean ITT 
	gen ITTc_sample = 1 if acceptance_or_error_status == "accepted" | ///
	acceptance_or_error_status == "all ineligible" | ///
	(acceptance_or_error_status == "rejected" & ///
	(reject_reason == "MEDIATOR_DECLINED" | ///
	reject_reason == "MEDIATOR_UNREACHABLE" | reject_reason == "OTHER"))
	
	* "Sample 2" - ITT 
	gen ITT_sample = 1 if acceptance_or_error_status == "accepted" | ///
	(acceptance_or_error_status == "rejected" & ///
	(reject_reason == "MEDIATOR_DECLINED" | ///
	reject_reason == "MEDIATOR_UNREACHABLE" | reject_reason == "OTHER"))
	
	* "Sample 3" TOT
	gen TOT_sample = 1 if acceptance_or_error_status == "accepted" 	
	
	* "Sample 4" - Clean TOT 
	gen TOTc_sample = 1 if acceptance_or_error_status == "accepted" ///
	&recommendation_rank == 1		
		
	*** Relevant variables: Number of cases by different status
	* Total cases by group
	egen TOT_group = count(case), by(group)	
	egen TOT_group_courtnamed = count(case) if ///
	reject_reason == "COURT_NAMED", by(group)
	egen TOT_group_partiesreqst = count(case) if ///
	reject_reason == "PARTIES_REQUESTED", by(group)
	egen TOT_group_inel = count(case) if ///
	acceptance_or_error_status == "all ineligible", by(group)
	
** Table 1

	* Top
	file open tab1_descr using "`path'/Output/Smart_assignment_rts/SA_tab1.tex", write text replace
	file write tab1_descr "\begin{tabular}{c|cccccccc}"  _n
	file write tab1_descr "\toprule" _n
	file write tab1_descr " & Cases & Court named & Parties request & Med ineligible & Sample 1 & Sample 2 & Sample 3 & Sample 4\\" _n
	file write tab1_descr "Arm & (1) & (2) & (3) & (4) & (5)=1-2-3 & (6)=1-2-3-4 & (7) & (8)\\" _n
	file write tab1_descr "\hline" _n
	
	* Body
	
	* T and C
	forvalues i = 0(1)1{
	summ ALL_sample if group == `i'
	local N_`i' = `r(N)'
	summ ALL_sample if reject_reason == "COURT_NAMED" & group == `i'
	local N_court_`i' = `r(N)'
	summ ALL_sample if reject_reason == "PARTIES_REQUESTED" & group == `i'
	local N_parties_`i' = `r(N)'
	summ ALL_sample if acceptance_or_error_status == "all ineligible" ///
	& group == `i'
	local N_inelegible_`i' = `r(N)'
	summ ITTc_sample if group == `i'
	local N_ITTc_`i' = `r(N)'
	summ ITT_sample if group == `i'
	local N_ITT_`i' = `r(N)'
	summ TOT_sample if group == `i'
	local N_TOT_`i' = `r(N)'
	summ TOTc_sample if group == `i'
	local N_TOTc_`i' = `r(N)'
	}
	
	* All
	summ ALL_sample 
	local N = `r(N)'
	summ ALL_sample if reject_reason == "COURT_NAMED" 
	local N_court = `r(N)'
	summ ALL_sample if reject_reason == "PARTIES_REQUESTED" 
	local N_parties = `r(N)'
	summ ALL_sample if acceptance_or_error_status == "all ineligible" 
	local N_inelegible = `r(N)'
	summ ITTc_sample 
	local N_ITTc = `r(N)'
	summ ITT_sample 
	local N_ITT = `r(N)'
	summ TOT_sample 
	local N_TOT = `r(N)'
	summ TOTc_sample 
	local N_TOTc = `r(N)'
	
	* All concluded
	summ ALL_sample if case_status == "CONCLUDED"
	local N_concl = `r(N)'
	summ ALL_sample if reject_reason == "COURT_NAMED" & ///
	case_status == "CONCLUDED"
	local N_court_concl = `r(N)'
	summ ALL_sample if reject_reason == "PARTIES_REQUESTED" & ///
	case_status == "CONCLUDED"
	local N_parties_concl = `r(N)'
	summ ALL_sample if acceptance_or_error_status == "all ineligible" & ///
	case_status == "CONCLUDED"
	local N_inelegible_concl = `r(N)'
	summ ITTc_sample if case_status == "CONCLUDED"
	local N_ITTc_concl = `r(N)'
	summ ITT_sample if case_status == "CONCLUDED"
	local N_ITT_concl = `r(N)'
	summ TOT_sample if case_status == "CONCLUDED"
	local N_TOT_concl = `r(N)'
	summ TOTc_sample if case_status == "CONCLUDED"
	local N_TOTc_concl = `r(N)'
	
	file write tab1_descr " C & `N_0' & `N_court_0' & `N_parties_0' & `N_inelegible_0' & `N_ITTc_0' & `N_ITT_0' & `N_TOT_0' & `N_TOTc_0' \\" _n
	file write tab1_descr " T & `N_1' & `N_court_1' & `N_parties_1' & `N_inelegible_1' & `N_ITTc_1' & `N_ITT_1' & `N_TOT_1' & `N_TOTc_1' \\" _n
	file write tab1_descr "\midrule" _n
	file write tab1_descr " All & `N' & `N_court' & `N_parties' & `N_inelegible' & `N_ITTc' & `N_ITT' & `N_TOT' & `N_TOTc' \\" _n
	file write tab1_descr " Concluded & `N_concl' & `N_court_concl' & `N_parties_concl' & `N_inelegible_concl' & `N_ITTc_concl' & `N_ITT_concl' & `N_TOT_concl' & `N_TOTc_concl' \\" _n
		
	* Bottom
	file write tab1_descr "\bottomrule" _n
	file write tab1_descr "\end{tabular}" _n
	file close tab1_descr


/*****************************************************************
	 TABLE 2 
******************************************************************/	

	** Compliance - Percent Acceptance
	* Sample 1
	egen TOT_group_ITTc_accept = count(case) if ITTc_sample == 1 & ///
	acceptance_or_error_status == "accepted", by(group)
	egen TOT_group_ITTc = count(case) if ITTc_sample == 1, by(group)
	gen PCT_group_ITTc_accept = TOT_group_ITTc_accept / TOT_group_ITTc 	
	* Sample 2
	egen TOT_group_ITT_accept = count(case) if ITT_sample == 1 & ///
	acceptance_or_error_status == "accepted", by(group)
	egen TOT_group_ITT = count(case) if ITT_sample == 1, by(group)
	gen PCT_group_ITT_accept = TOT_group_ITT_accept / TOT_group_ITT 
	* Sample 3
	egen TOT_group_TOT_accept = count(case) if TOT_sample == 1 & ///
	acceptance_or_error_status == "accepted", by(group)
	egen TOT_group_TOT = count(case) if TOT_sample == 1, by(group)
	gen PCT_group_TOT_accept = TOT_group_TOT_accept / TOT_group_TOT
	
	** Pct in T
	* Sample 1
	egen TOT_group_ITTc_T = count(case) if ITTc_sample == 1 & ///
	group_va_s == 1, by(group)
	gen PCT_group_ITTc_T = TOT_group_ITTc_T / TOT_group_ITTc 	
	* Sample 2
	egen TOT_group_ITT_T = count(case) if ITT_sample == 1 & ///
	group_va_s == 1, by(group)
	gen PCT_group_ITT_T = TOT_group_ITT_T / TOT_group_ITT 
	* Sample 3
	egen TOT_group_TOT_T = count(case) if TOT_sample == 1 & ///
	group_va_s == 1, by(group)
	gen PCT_group_TOT_T = TOT_group_TOT_T / TOT_group_TOT
	
	** Pct in C
	* Sample 1
	egen TOT_group_ITTc_C = count(case) if ITTc_sample == 1 & ///
	group_va_s == 0, by(group)
	gen PCT_group_ITTc_C = TOT_group_ITTc_C / TOT_group_ITTc 	
	* Sample 2
	egen TOT_group_ITT_C = count(case) if ITT_sample == 1 & ///
	group_va_s == 0, by(group)
	gen PCT_group_ITT_C = TOT_group_ITT_C / TOT_group_ITT 
	* Sample 3
	egen TOT_group_TOT_C = count(case) if TOT_sample == 1 & ///
	group_va_s == 0, by(group)
	gen PCT_group_TOT_C = TOT_group_TOT_C / TOT_group_TOT
	
	** Pct no VA
	* Sample 1
	egen TOT_group_ITTc_noVA = count(case) if ITTc_sample == 1 & ///
	group_va_s == ., by(group)
	gen PCT_group_ITTc_noVA = TOT_group_ITTc_noVA / TOT_group_ITTc 	
	* Sample 2
	egen TOT_group_ITT_noVA = count(case) if ITT_sample == 1 & ///
	group_va_s == ., by(group)
	gen PCT_group_ITT_noVA = TOT_group_ITT_noVA / TOT_group_ITT 
	* Sample 3
	egen TOT_group_TOT_noVA = count(case) if TOT_sample == 1 & ///
	group_va_s == ., by(group)
	gen PCT_group_TOT_noVA = TOT_group_TOT_noVA / TOT_group_TOT
	
	** Avg rank 
	* Sample 1
	egen AVG_group_rank_ITTc = mean(recommendation_rank) if ITTc_sample == 1 & ///
	acceptance_or_error_status == "accepted", by(group)
	* Sample 2
	egen AVG_group_rank_ITT = mean(recommendation_rank) if ITT_sample == 1 & ///
	acceptance_or_error_status == "accepted", by(group)
	* Sample 3
	egen AVG_group_rank_TOT = mean(recommendation_rank) if TOT_sample == 1 & ///
	acceptance_or_error_status == "accepted", by(group)
	
	** Pct First accept
	* Sample 1
	egen TOT_group_ITTc_firstacceptt = count(case) if ITTc_sample == 1 & ///
	acceptance_or_error_status == "accepted" & recommendation_rank == 1, ///
	by(group)
	gen PCT_group_ITTc_firstaccept = TOT_group_ITTc_firstacceptt / TOT_group_ITTc
	* Sample 2
	egen TOT_group_ITT_firstacceptt = count(case) if ITT_sample == 1 & ///
	acceptance_or_error_status == "accepted" & recommendation_rank == 1, ///
	by(group)
	gen PCT_group_ITT_firstaccept = TOT_group_ITT_firstacceptt / TOT_group_ITT
	* Sample 3
	egen TOT_group_TOT_firstacceptt = count(case) if TOT_sample == 1 & ///
	acceptance_or_error_status == "accepted" & recommendation_rank == 1, ///
	by(group)
	gen PCT_group_TOT_firstaccept = TOT_group_TOT_firstacceptt / TOT_group_TOT
	
	** Average VA of assigned mediators
	* Sample 1
	egen MeanVA_group_ITTc = mean(va_s) if ITTc_sample == 1, by(group)
	* Sample 2
	egen MeanVA_group_ITT = mean(va_s) if ITT_sample == 1, by(group)
	* Sample 3
	egen MeanVA_group_TOT = mean(va_s) if TOT_sample == 1, by(group)
	
	** Average VA of the first recommended mediator
	* Sample 1
	egen firstVA_group_ITTc = mean(list_va_s_1) if ITTc_sample == 1, by(group)
	* Sample 2
	egen firstVA_group_ITT = mean(list_va_s_1) if ITT_sample == 1, by(group)
	* Sample 3
	egen firstVA_group_TOT = mean(list_va_s_1) if TOT_sample == 1, by(group)
	
	** TABLE
	* Top
	file open tab2_acceptance using "`path'/Output/Smart_assignment_rts/SA_tab2.tex", write text replace
	file write tab2_acceptance "\begin{tabular}{ccc|cccc|cccc}"  _n
	file write tab2_acceptance "\toprule" _n
	*file write tab2_acceptance " Sample & Arm & Cases & Pct Accepted & Avg VA assigned med & Avg VA first med \\" _n
	file write tab2_acceptance "  &  &  & \multicolumn{4}{c|}{Compliance} & \multicolumn{4}{c}{Selection} \\" _n	
	file write tab2_acceptance " Sample & Arm & Cases & \% Accept & \% T & \% C & \% no VA & Avg rank & \% First & Mean VA assigned & Mean VA First \\" _n	
	file write tab2_acceptance "\hline" _n

	
	* Body
	forvalues i = 0(1)1{
	
	* Pct Accept
	summ PCT_group_ITTc_accept if group == `i'
	local PCT_group_ITTc_accept_`i' = round(`r(mean)', 0.01)
	summ PCT_group_ITT_accept if group == `i'
	local PCT_group_ITT_accept_`i' = round(`r(mean)', 0.01)
	summ PCT_group_TOT_accept if group == `i'
	local PCT_group_TOT_accept_`i' = round(`r(mean)', 0.01)
	
	* Pct in T
	summ PCT_group_ITTc_T if group == `i'
	local PCT_group_ITTc_T_`i' = round(`r(mean)', 0.01)
	summ PCT_group_ITT_T if group == `i'
	local PCT_group_ITT_T_`i' = round(`r(mean)', 0.01)
	summ PCT_group_TOT_T if group == `i'
	local PCT_group_TOT_T_`i' = round(`r(mean)', 0.01)	
	
	* Pct in C
	summ PCT_group_ITTc_C if group == `i'
	local PCT_group_ITTc_C_`i' = round(`r(mean)', 0.01)
	summ PCT_group_ITT_C if group == `i'
	local PCT_group_ITT_C_`i' = round(`r(mean)', 0.01)
	summ PCT_group_TOT_C if group == `i'
	local PCT_group_TOT_C_`i' = round(`r(mean)', 0.01)	
	
	* Pct no VA
	summ PCT_group_ITTc_noVA if group == `i'
	local PCT_group_ITTc_noVA_`i' = round(`r(mean)', 0.01)
	summ PCT_group_ITT_noVA if group == `i'
	local PCT_group_ITT_noVA_`i' = round(`r(mean)', 0.01)
	summ PCT_group_TOT_noVA if group == `i'
	local PCT_group_TOT_noVA_`i' = round(`r(mean)', 0.01)	
	
	* Avg rank
	summ AVG_group_rank_ITTc if group == `i'
	local AVG_group_rank_ITTc_`i' = round(`r(mean)', 0.01)	
	summ AVG_group_rank_ITT if group == `i'
	local AVG_group_rank_ITT_`i' = round(`r(mean)', 0.01)
	summ AVG_group_rank_TOT if group == `i'
	local AVG_group_rank_TOT_`i' = round(`r(mean)', 0.01)
	
	* Pct First accept
	summ PCT_group_ITTc_firstaccept if group == `i'
	local PCT_group_ITTc_firstaccept_`i' = round(`r(mean)', 0.001)
	summ PCT_group_ITT_firstaccept if group == `i'
	local PCT_group_ITT_firstaccept_`i' = round(`r(mean)', 0.001)
	summ PCT_group_TOT_firstaccept if group == `i'
	local PCT_group_TOT_firstaccept_`i' = round(`r(mean)', 0.001)
	
	* Avg VA assigned mediators
	summ MeanVA_group_ITTc if group == `i'
	local MeanVA_group_ITTc_`i' = round(`r(mean)', 0.0001)
	summ MeanVA_group_ITT if group == `i'
	local MeanVA_group_ITT_`i' = round(`r(mean)', 0.0001)	
	summ MeanVA_group_TOT if group == `i'
	local MeanVA_group_TOT_`i' = round(`r(mean)', 0.0001)
	
	* Avg VA first recommended mediator
	summ firstVA_group_ITTc if group == `i'
	local firstVA_group_ITTc_`i' = round(`r(mean)', 0.0001)
	summ firstVA_group_ITT if group == `i'
	local firstVA_group_ITT_`i' = round(`r(mean)', 0.0001)	
	summ firstVA_group_TOT if group == `i'
	local firstVA_group_TOT_`i' = round(`r(mean)', 0.0001)
	}

	* ITTc
	file write tab2_acceptance " 1 & C & `N_ITTc_0' & `PCT_group_ITTc_accept_0' & `PCT_group_ITTc_T_0' & `PCT_group_ITTc_C_0' & `PCT_group_ITTc_noVA_0' &  `AVG_group_rank_ITTc_0' & `PCT_group_ITTc_firstaccept_0' & `MeanVA_group_ITTc_0' & `firstVA_group_ITTc_0' \\" _n
	file write tab2_acceptance " 1 & T & `N_ITTc_1' & `PCT_group_ITTc_accept_1' & `PCT_group_ITTc_T_1' & `PCT_group_ITTc_C_1' & `PCT_group_ITTc_noVA_1' &  `AVG_group_rank_ITTc_1' & `PCT_group_ITTc_firstaccept_1' & `MeanVA_group_ITTc_1' & `firstVA_group_ITTc_1' \\" _n

	* ITT
	file write tab2_acceptance " 2 & C & `N_ITT_0' & `PCT_group_ITT_accept_0' & `PCT_group_ITT_T_0' & `PCT_group_ITT_C_0' & `PCT_group_ITT_noVA_0' &  `AVG_group_rank_ITT_0' & `PCT_group_ITT_firstaccept_0' & `MeanVA_group_ITT_0' & `firstVA_group_ITT_0' \\" _n
	file write tab2_acceptance " 2 & T & `N_ITT_1' & `PCT_group_ITT_accept_1' & `PCT_group_ITT_T_1' & `PCT_group_ITT_C_1' & `PCT_group_ITT_noVA_1' &  `AVG_group_rank_ITT_1' & `PCT_group_ITT_firstaccept_1' & `MeanVA_group_ITT_1' & `firstVA_group_ITT_1' \\" _n	
	
	* TOT
	file write tab2_acceptance " 3 & C & `N_TOT_0' & `PCT_group_TOT_accept_0' & `PCT_group_TOT_T_0' & `PCT_group_TOT_C_0' & `PCT_group_TOT_noVA_0' &  `AVG_group_rank_TOT_0' & `PCT_group_TOT_firstaccept_0' & `MeanVA_group_TOT_0' & `firstVA_group_TOT_0' \\" _n
	file write tab2_acceptance " 3 & T & `N_TOT_1' & `PCT_group_TOT_accept_1' & `PCT_group_TOT_T_1' & `PCT_group_TOT_C_1' & `PCT_group_TOT_noVA_1' &  `AVG_group_rank_TOT_1' & `PCT_group_TOT_firstaccept_1' & `MeanVA_group_TOT_1' & `firstVA_group_TOT_1' \\" _n	
		

	* Bottom
	file write tab2_acceptance "\bottomrule" _n
	file write tab2_acceptance "\end{tabular}" _n
	file close tab2_acceptance	
	
	
/*****************************************************************
	 TABLE 3 - Duration 
******************************************************************/	
		
	* Duration 
		* Sample 1
		egen AVG_group_ITTc_case_days = mean(case_days_med) ///
		if ITTc_sample == 1, by(group)
		* Sample 2
		egen AVG_group_ITT_case_days = mean(case_days_med) ///
		if ITT_sample == 1, by(group)		
		* Sample 3
		egen AVG_group_TOT_case_days = mean(case_days_med) ///
		if TOT_sample == 1, by(group)
		
	* Duration agreement
		* Sample 1
		egen AVG_group_ITTc_case_days_a = mean(case_days_med) if ///
		case_outcome_agreement == 1 & ITTc_sample == 1, by(group)
		* Sample 2
		egen AVG_group_ITT_case_days_a = mean(case_days_med) if ///
		case_outcome_agreement == 1 & ITT_sample == 1, by(group)
		* Sample 3
		egen AVG_group_TOT_case_days_a = mean(case_days_med) if ///
		case_outcome_agreement == 1 & TOT_sample == 1, by(group)
		
	* Duration no agreement
		* Sample 1
		egen AVG_group_ITTc_case_days_r = mean(case_days_med) if ///
		case_outcome_agreement == 0 & ITTc_sample == 1, by(group)
		* Sample 2
		egen AVG_group_ITT_case_days_r = mean(case_days_med) if ///
		case_outcome_agreement == 0 & ITT_sample == 1, by(group)
		* Sample 3		
		egen AVG_group_TOT_case_days_r = mean(case_days_med) if ///
		case_outcome_agreement == 0 & TOT_sample == 1, by(group)

	* Top
	file open tab3_duration using "`path'/Output/Smart_assignment_rts/SA_tab3.tex", write text replace
	file write tab3_duration "\begin{tabular}{ccc|ccc}"  _n
	file write tab3_duration "\toprule" _n
	file write tab3_duration " Sample & Arm & Cases & Duration & Duration Agreement & Duration no agreement  \\" _n	
	file write tab3_duration "\hline" _n
	
	* Body
	forvalues i = 0(1)1{
	
	* Duration 
	summ AVG_group_ITTc_case_days if group == `i'
	local AVG_group_ITTc_case_days_`i' = round(`r(mean)', 0.01)
	summ AVG_group_ITT_case_days if group == `i'
	local AVG_group_ITT_case_days_`i' = round(`r(mean)', 0.01)
	summ AVG_group_TOT_case_days if group == `i'
	local AVG_group_TOT_case_days_`i' = round(`r(mean)', 0.01)	
	
	* Duration Accept
	summ AVG_group_ITTc_case_days_a if group == `i'
	local AVG_group_ITTc_case_days_a_`i' = round(`r(mean)', 0.01)
	summ AVG_group_ITT_case_days_a if group == `i'
	local AVG_group_ITT_case_days_a_`i' = round(`r(mean)', 0.01)
	summ AVG_group_TOT_case_days_a if group == `i'
	local AVG_group_TOT_case_days_a_`i' = round(`r(mean)', 0.01)
	
	* Duration Reject
	summ AVG_group_ITTc_case_days_r if group == `i'
	local AVG_group_ITTc_case_days_r_`i' = round(`r(mean)', 0.01)
	summ AVG_group_ITT_case_days_r if group == `i'
	local AVG_group_ITT_case_days_r_`i' = round(`r(mean)', 0.01)
	summ AVG_group_TOT_case_days_r if group == `i'
	local AVG_group_TOT_case_days_r_`i' = round(`r(mean)', 0.01)	
	}

	* ITTc
	file write tab3_duration " 1 & C & `N_ITTc_0' & `AVG_group_ITTc_case_days_0' & `AVG_group_ITTc_case_days_a_0' & `AVG_group_ITTc_case_days_r_0' \\" _n
	file write tab3_duration " 1 & T & `N_ITTc_1' & `AVG_group_ITTc_case_days_1' & `AVG_group_ITTc_case_days_a_1' & `AVG_group_ITTc_case_days_r_1' \\" _n

	* ITT
	file write tab3_duration " 2 & C & `N_ITT_0' & `AVG_group_ITT_case_days_0' & `AVG_group_ITT_case_days_a_0' & `AVG_group_ITT_case_days_r_0' \\" _n
	file write tab3_duration " 2 & T & `N_ITT_1' & `AVG_group_ITT_case_days_1' & `AVG_group_ITT_case_days_a_1' & `AVG_group_ITT_case_days_r_1' \\" _n
	
	* TOT
	file write tab3_duration " 3 & C & `N_TOT_0' & `AVG_group_TOT_case_days_0' & `AVG_group_TOT_case_days_a_0' & `AVG_group_TOT_case_days_r_0' \\" _n
	file write tab3_duration " 3 & T & `N_TOT_1' & `AVG_group_TOT_case_days_1' & `AVG_group_TOT_case_days_a_1' & `AVG_group_TOT_case_days_r_1' \\" _n
		
		
	* Bottom
	file write tab3_duration "\bottomrule" _n
	file write tab3_duration "\end{tabular}" _n
	file close tab3_duration


	
/*****************************************************************
	 Main reg t-test
******************************************************************/

local dep_var case_outcome_agreement case_days_med

foreach i in case_outcome_agreement case_days_med{
	
	/*
	if `i' == "case_outcome_agreement"{
		local j = 4
	}
	else {
		local j == 5
	}
	
	di `j'
	*/

	
	** Reg 1: No controls
	* Sample 0 (all cases)
	eststo s0_`i': reghdfe `i' group, noabsorb vce(robust)
	* Sample 1
	eststo s1_`i': reghdfe `i' group if ITTc_sample == 1, noabsorb vce(robust)
	* Sample 2
	eststo s2_`i': reghdfe `i' group if ITT_sample == 1, noabsorb vce(robust)
	* Sample 3
	eststo s3_`i': reghdfe `i' group if TOT_sample == 1, noabsorb vce(robust)
	* Sample 4
	eststo s4_`i': reghdfe `i' group if TOTc_sample == 1, noabsorb vce(robust)

	** Reg 2: Controls
	* Sample 0 (all cases)
	eststo s0_c_`i': reghdfe `i' group, absorb(i.appt_month_year i.casetype i.courttype i.courtstation i.referralmode) vce(robust)
	* Sample 1
	eststo s1_c_`i': reghdfe `i' group if ITTc_sample == 1, absorb(i.appt_month_year i.casetype i.courttype i.courtstation i.referralmode) vce(robust)
	* Sample 2
	eststo s2_c_`i': reghdfe `i' group if ITT_sample == 1, absorb(i.appt_month_year i.casetype i.courttype i.courtstation i.referralmode) vce(robust)
	* Sample 3
	eststo s3_c_`i': reghdfe `i' group if TOT_sample == 1, absorb(i.appt_month_year i.casetype i.courttype i.courtstation i.referralmode) vce(robust)
	* Sample 4
	eststo s4_c_`i': reghdfe `i' group if TOTc_sample == 1, absorb(i.appt_month_year i.casetype i.courttype i.courtstation i.referralmode) vce(robust)
	
		
	esttab s0_`i' s1_`i' s2_`i' s3_`i' s4_`i' s0_c_`i' s1_c_`i' s2_c_`i' s3_c_`i' s4_c_`i' using "`path'\Output\Smart_assignment_rts\SA_tab4_`i'.tex", se star(* 0.10 ** 0.05 *** 0.01) tex replace	

}	


	reghdfe case_outcome_agreement group_va_s if TOTc_sample == 1, noabsorb vce(robust) 
	
	reghdfe case_outcome_agreement va_u, absorb(i.appt_month_year i.casetype i.courttype i.courtstation i.referralmode) vce(robust) 	

****************

/*
	** Reg 1: No controls
	* Sample 0 (all cases)
	eststo s0: reghdfe case_outcome_agreement group, noabsorb vce(robust)
	* Sample 1
	eststo s1: reghdfe case_outcome_agreement group if ITTc_sample == 1, noabsorb vce(robust)
	* Sample 2
	eststo s2: reghdfe case_outcome_agreement group if ITT_sample == 1, noabsorb vce(robust)
	* Sample 3
	eststo s3: reghdfe case_outcome_agreement group if TOT_sample == 1, noabsorb vce(robust)
	* Sample 4
	eststo s4: reghdfe case_outcome_agreement group if TOTc_sample == 1, noabsorb vce(robust)

	** Reg 2: Controls
	* Sample 0 (all cases)
	eststo s0_c: reghdfe case_outcome_agreement group, absorb(i.appt_month_year i.casetype i.courttype i.courtstation i.referralmode) vce(robust)
	* Sample 1
	eststo s1_c: reghdfe case_outcome_agreement group if ITTc_sample == 1, absorb(i.appt_month_year i.casetype i.courttype i.courtstation i.referralmode) vce(robust)
	* Sample 2
	eststo s2_c: reghdfe case_outcome_agreement group if ITT_sample == 1, absorb(i.appt_month_year i.casetype i.courttype i.courtstation i.referralmode) vce(robust)
	* Sample 3
	eststo s3_c: reghdfe case_outcome_agreement group if TOT_sample == 1, absorb(i.appt_month_year i.casetype i.courttype i.courtstation i.referralmode) vce(robust)
	* Sample 4
	eststo s4_c: reghdfe case_outcome_agreement group if TOTc_sample == 1, absorb(i.appt_month_year i.casetype i.courttype i.courtstation i.referralmode) vce(robust)
	
		
	esttab s0 s1 s2 s3 s4 s0_c s1_c s2_c s3_c s4_c using "`path'\Output\Smart_assignment_rts\SA_tab4.tex", se tex replace		
	
*/

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

