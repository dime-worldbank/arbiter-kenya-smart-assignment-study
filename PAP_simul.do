/*****************************************************************
Project: World Bank Kenya Arbiter
PIs: Anja Sautmann and Antoine Deeb
Purpose: Power calculation
Author: Hamza Syed 
Updated by: Didac Marti Pinto
Instructions: To run this code change the locals at the beginning of 
the code
******************************************************************/

clear all
version 18
set more off

*ssc install gsample
*ssc install moremata

// Define locals
	local path "C:\Users\didac\Dropbox\Arbiter Research\Data analysis"
	local datapull "15062023" // 05102022
	local n_sim = 1000 // Number of simulations
	local min_cases = 4 // Number of cases per mediator
	local cases_exp = 300 //Number of cases for experimental sample
	local p = 50 // 50 or 30
	local np = 100-`p'
	
// Simulations program
capture program drop exp_effect
program define exp_effect, rclass

// Define locals 
	*set seed 123
	local path "C:\Users\didac\Dropbox\Arbiter Research\Data analysis"
	local datapull  "15062023" //"05102022" 
	local n_sim = 1000 // Number of simulations
	local min_cases = 4 // Number of cases per mediator
	local cases_exp = 300 //Number of cases for experimental sample
	local p = 50 // 50 or 30
	local np = 100-`p'

// Data preparation
	* Import data
	use "`path'/Data_Clean/cases_cleaned_15062023.dta", clear
	* Drop pending cases
	drop if case_status == "PENDING"
	* Keep only relevant cases
	keep if usable == 1
	drop if issue == 6 | issue == 7 //Dropping pandemic months 
	* Keep only courtstations with >=10 cases
	bys courtstation:gen stationcases = _N
	drop if stationcases<10
	* Create number of cases per mediator
	bys mediator_id: gen totalcases=_N 
	sort id, stable 
	* Save sample of relevant and usable cases
	tempfile raw
	save `raw'

// Draw sample with replacement (optional "step 1")
	*bsample if totalcases >= `min_cases', strata(mediator_id)
	tempfile sampled
	save `sampled'

// Calculate VA
	* Keep only mediators with at least K total cases for VA estimation
	keep if totalcases >= `min_cases'
	* Shrunk estimator
	egen med_year=group(mediator_id appt_year)
	local state = c(rngstate)
	vam case_outcome_agreement, teacher(mediator_id) year(appt_year) ///
	driftlimit(3) class(med_year) controls(i.appt_month_year i.casetype ///
	i.courttype i.courtstation i.referralmode) tfx_resid(mediator_id) ///
	data(merge tv)
	rename tv va_s
	set rngstate `state'
	* Unshrunk estimator
	areg case_outcome_agreement i.appt_year i.casetype i.courttype ///
	i.courtstation i.referralmode, absorb(mediator_id)
	predict residuals, dr
	bys mediator_id: egen va_u=mean(residuals)
	predict mediator_d, d
	*predict fit_u, xbd
	*predict fit_uu, xb
	*gen fit_u2 = fit_uu + d

// Assign mediators to treatment and control group
	collapse va_s va_u mediator_d, by(mediator_id)
	drop if va_s == .
	*_pctile va_s, p(`p' `np') 
	*scalar r1=r(r1)
	*scalar r2=r(r2)
	gen treatment = 1 if va_s > 0
	replace treatment = 0 if va_s <= 0
	drop if missing(treatment)
	tab treatment 
	local tot_med = r(N) 
	gen merge_id = _n 
	*_pctile va_u, p(`p' `np') 
	*scalar r1=r(r1)
	*scalar r2=r(r2)
	gen treatment_u = 1 if va_u > 0
	replace treatment_u = 0 if va_u <= 0 
	tempfile mediators
	save `mediators'

// Draw random sample of experimental cases and assign mediators to it
	use `raw', clear
	rename mediator_id old_mediator_id
	sample `cases_exp', count 
	gen merge_id = int(runiform(1,`tot_med')) 
	sort merge_id id, stable 
	merge m:1 merge_id using `mediators'
	drop if _merge !=3 
	drop _merge
	gen experimental = 1 // experimental case indicator
	replace appt_year = 2023 if experimental == 1 // Assume 2023 for new cases

// Predict experimental case outcomes 
	predict p_random, xb // p_random
	gen pred_s = p_random + va_s // p_s = Shrunk VA predictions 	
	gen p_s_flipped = p_random - va_s // p_s_flipped
	gen pred_u = p_random + mediator_d // p_u = Unshrunk VA predictions 
	gen p_u_flipped = p_random - mediator_d // p_u_flipped
	* Rounded to 0-1 predictions
	gen pred_s_round = round(pred_s)
	gen pred_u_round = round(pred_u)
	gen p_s_flipped_round = round(p_s_flipped)
	gen p_u_flipped_round = round(p_u_flipped)
	gen p_random_round = round(p_random)
	
// Simulate experimental case outcome
	** Shrunk
	* Baseline model
	gen random = runiform(0,1)
	replace case_outcome_agreement = 1 if pred_s > random
	replace case_outcome_agreement = 0 if pred_s <= random
	drop random
	* Random model
	gen random = runiform(0,1)
	gen case_outcome_agreement_random = 1 if p_random > random
	replace case_outcome_agreement_random = 0 if p_random <= random
	drop random
	* Flipped model
	gen random = runiform(0,1)
	gen case_outcome_agreement_flip = 1 if p_s_flipped > random
	replace case_outcome_agreement_flip = 0 if p_s_flipped <= random
	drop random 
	** Unshrunk
	* Baseline model
	gen random = runiform(0,1)
	gen case_outcome_agreement_u = 1 if pred_u > random
	replace case_outcome_agreement_u = 0 if pred_u <= random
	drop random
	* Flipped outcomes model
	gen random = runiform(0,1)
	gen case_outcome_agreement_u_flip = 1 if p_u_flipped > random
	replace case_outcome_agreement_u_flip = 0 if p_u_flipped <= random
	drop random

// Outputs
	** Brier score
	gen brier_s = (pred_s - case_outcome_agreement)^2
	gen brier_s_flip = (pred_s - case_outcome_agreement_flip)^2
	gen brier_s_random = (pred_s - case_outcome_agreement_random)^2
	gen brier_u = (pred_u - case_outcome_agreement_u)^2
	gen brier_u_flip = (pred_u - case_outcome_agreement_u_flip)^2
	gen brier_u_random = (pred_u - case_outcome_agreement_random)^2
	* Return Brier score
	summ brier_s
		return scalar brier_s = r(mean)
	summ brier_s_flip
		return scalar brier_s_flip = r(mean)
	summ brier_s_random
		return scalar brier_s_random = r(mean)
	summ brier_u
		return scalar brier_u = r(mean)
	summ brier_u_flip
		return scalar brier_u_flip = r(mean)
	summ brier_u_random
		return scalar brier_u_random = r(mean)
	** Correct predictions
	* Shrunk
	gen pred_correct_s = 0 
	replace pred_correct_s = 1 if pred_s_round == case_outcome_agreement
	gen pred_correct_s_flip = 0
	replace pred_correct_s_flip = 1 if ///
	pred_s_round == case_outcome_agreement_flip
	gen pred_correct_s_random = 0
	replace pred_correct_s_random = 1 if ///
	pred_s_round == case_outcome_agreement_random
	* Unshrunk
	gen pred_correct_u = 0 
	replace pred_correct_u = 1 if pred_u_round == case_outcome_agreement_u
	gen pred_correct_u_flip = 0
	replace pred_correct_u_flip = 1 if ///
	pred_u_round == case_outcome_agreement_u_flip
	gen pred_correct_u_random = 0
	replace pred_correct_u_random = 1 if ///
	pred_u_round == case_outcome_agreement_random	
	* Return percent correct predictions
	summ pred_correct_s
		return scalar pred_correct_s = r(mean)
	summ pred_correct_s_flip
		return scalar pred_correct_s_flip = r(mean)
	summ pred_correct_s_random
		return scalar pred_correct_s_random = r(mean)
	summ pred_correct_u
		return scalar pred_correct_u = r(mean)
	summ pred_correct_u_flip
		return scalar pred_correct_u_flip = r(mean)
	summ pred_correct_u_random
		return scalar pred_correct_u_random = r(mean)
	** Log loss
	* Shrunk
	gen logloss_s = -( case_outcome_agreement * log(pred_s) + ///
	(1-case_outcome_agreement) * log(1-pred_s) )
	gen logloss_s_random = -( case_outcome_agreement_random * log(pred_s) + ///
	(1-case_outcome_agreement_random) * log(1-pred_s) )
	gen logloss_s_flip = -( case_outcome_agreement_flip * log(pred_s) + ///
	(1-case_outcome_agreement_flip) * log(1-pred_s)	)
	* Unshrunk
	gen logloss_u = -( case_outcome_agreement_u * log(pred_u) + ///
	(1-case_outcome_agreement_u) * log(1-pred_u) )
	gen logloss_u_random = -( case_outcome_agreement_random * log(pred_u) + ///
	(1-case_outcome_agreement_random) * log(1-pred_u) )
	gen logloss_u_flip = -( case_outcome_agreement_u_flip * log(pred_u) + ///
	(1-case_outcome_agreement_u_flip) * log(1-pred_u)	)
	* Return log loss
	summ logloss_s 
		return scalar logloss_s = r(sum) / _N
	summ logloss_s_random 
		return scalar logloss_s_random = r(sum) / _N
	summ logloss_s_flip 
		return scalar logloss_s_flip = r(sum) / _N
	summ logloss_u 
		return scalar logloss_u = r(sum) / _N
	summ logloss_u_random 
		return scalar logloss_u_random = r(sum) / _N
	summ logloss_u_flip 
		return scalar logloss_u_flip = r(sum) / _N
		
	** Brier score differences
	gen brier_diff_s_random_sout_pt1 = (pred_s - case_outcome_agreement)^2
	gen brier_diff_s_random_sout_pt2  =  (p_random - case_outcome_agreement)^2 
	gen brier_diff_s_flip_sout_pt1 = (pred_s - case_outcome_agreement)^2
	gen brier_diff_s_flip_sout_pt2  =  (p_s_flipped - case_outcome_agreement)^2 	
	gen brier_diff_s_random_rout_pt1 = (pred_s - case_outcome_agreement_random)^2
	gen brier_diff_s_random_rout_pt2  =  (p_random - case_outcome_agreement_random)^2 
	gen brier_diff_s_flip_fout_pt1 = (pred_s - case_outcome_agreement_flip)^2
	gen brier_diff_s_flip_fout_pt2  =  (p_s_flipped - case_outcome_agreement_flip)^2 
	gen brier_diff_u_random_sout_pt1 = (pred_u - case_outcome_agreement_u)^2
	gen brier_diff_u_random_sout_pt2  =  (p_random - case_outcome_agreement_u)^2 
	gen brier_diff_u_flip_sout_pt1 = (pred_u - case_outcome_agreement_u)^2
	gen brier_diff_u_flip_sout_pt2  =  (p_u_flipped - case_outcome_agreement_u)^2 	
	gen brier_diff_u_random_rout_pt1 = (pred_u - case_outcome_agreement_random)^2
	gen brier_diff_u_random_rout_pt2  =  (p_random - case_outcome_agreement_random)^2 
	gen brier_diff_u_flip_fout_pt1 = (pred_u - case_outcome_agreement_u_flip)^2
	gen brier_diff_u_flip_fout_pt2  =  (p_u_flipped - case_outcome_agreement_u_flip)^2 
	** Correct predictions differences
	gen corrpred_diff_s_random_sout_pt1 = (pred_s_round - case_outcome_agreement)^2
	gen corrpred_diff_s_random_sout_pt2  =  (p_random_round - case_outcome_agreement)^2
	gen corrpred_diff_s_flip_sout_pt1 = (pred_s_round - case_outcome_agreement)^2
	gen corrpred_diff_s_flip_sout_pt2  =  (p_s_flipped_round - case_outcome_agreement)^2 	
	gen corrpred_diff_s_random_rout_pt1 = (pred_s_round - case_outcome_agreement_random)^2
	gen corrpred_diff_s_random_rout_pt2  =  (p_random_round - case_outcome_agreement_random)^2 
	gen corrpred_diff_s_flip_fout_pt1 = (pred_s_round - case_outcome_agreement_flip)^2
	gen corrpred_diff_s_flip_fout_pt2  =  (p_s_flipped_round - case_outcome_agreement_flip)^2 
	gen corrpred_diff_u_random_sout_pt1 = (pred_u_round - case_outcome_agreement_u)^2
	gen corrpred_diff_u_random_sout_pt2  =  (p_random - case_outcome_agreement_u)^2 
	gen corrpred_diff_u_flip_sout_pt1 = (pred_u_round - case_outcome_agreement_u)^2
	gen corrpred_diff_u_flip_sout_pt2  =  (p_u_flipped_round - case_outcome_agreement_u)^2 	
	gen corrpred_diff_u_random_rout_pt1 = (pred_u_round - case_outcome_agreement_random)^2
	gen corrpred_diff_u_random_rout_pt2  =  (p_random - case_outcome_agreement_random)^2 
	gen corrpred_diff_u_flip_fout_pt1 = (pred_u_round - case_outcome_agreement_u_flip)^2
	gen corrpred_diff_u_flip_fout_pt2  =  (p_u_flipped_round - case_outcome_agreement_u_flip)^2 
	** Log loss differences
	gen logloss_diff_s_random_sout_pt1 = (case_outcome_agreement*log(pred_s) + (1-case_outcome_agreement)*log(1-pred_s))
	gen logloss_diff_s_random_sout_pt2 = (case_outcome_agreement*log(p_random) + (1-case_outcome_agreement)*log(1-p_random))
	gen logloss_diff_s_flip_sout_pt1 = (case_outcome_agreement*log(pred_s) + (1-case_outcome_agreement)*log(1-pred_s))
	gen logloss_diff_s_flip_sout_pt2  = (case_outcome_agreement*log(p_s_flipped) + (1-case_outcome_agreement)*log(1-p_s_flipped)) 
	gen logloss_diff_s_random_rout_pt1 = (case_outcome_agreement_random*log(pred_s) + (1-case_outcome_agreement_random)*log(1-pred_s))
	gen logloss_diff_s_random_rout_pt2  = (case_outcome_agreement_random*log(p_random) + (1-case_outcome_agreement_random)*log(1-p_random))
	gen logloss_diff_s_flip_fout_pt1 = (case_outcome_agreement_flip*log(pred_s) + (1-case_outcome_agreement_flip)*log(1-pred_s))
	gen logloss_diff_s_flip_fout_pt2  = (case_outcome_agreement_flip*log(p_s_flipped) + (1-case_outcome_agreement_flip)*log(1-p_s_flipped))
	gen logloss_diff_u_random_sout_pt1 = (case_outcome_agreement_u*log(pred_u) + (1-case_outcome_agreement)*log(1-pred_u))
	gen logloss_diff_u_random_sout_pt2 = (case_outcome_agreement_u*log(p_random) + (1-case_outcome_agreement)*log(1-p_random))
	gen logloss_diff_u_flip_sout_pt1 = (case_outcome_agreement_u*log(pred_u) + (1-case_outcome_agreement)*log(1-pred_u))
	gen logloss_diff_u_flip_sout_pt2  = (case_outcome_agreement_u*log(p_u_flipped) + (1-case_outcome_agreement)*log(1-p_u_flipped)) 
	gen logloss_diff_u_random_rout_pt1 = (case_outcome_agreement_random*log(pred_u) + (1-case_outcome_agreement_random)*log(1-pred_u))
	gen logloss_diff_u_random_rout_pt2  = (case_outcome_agreement_random*log(p_random) + (1-case_outcome_agreement_random)*log(1-p_random))
	gen logloss_diff_u_flip_fout_pt1 = (case_outcome_agreement_u_flip*log(pred_u) + (1-case_outcome_agreement_flip)*log(1-pred_u))
	gen logloss_diff_u_flip_fout_pt2  = (case_outcome_agreement_u_flip*log(p_u_flipped) + (1-case_outcome_agreement_flip)*log(1-p_u_flipped))
	* Return brier score differences
	summ brier_diff_s_random_sout_pt1
	scalar s_brier_diff_s_random_sout_pt1 = r(sum)
	summ brier_diff_s_random_sout_pt2
	scalar s_brier_diff_s_random_sout_pt2 = r(sum)		
		return scalar brier_diff_s_random = (s_brier_diff_s_random_sout_pt2 - ///
		s_brier_diff_s_random_sout_pt1) / _N
	summ brier_diff_s_flip_sout_pt1
	scalar s_brier_diff_s_flip_sout_pt1 = r(sum)
	summ brier_diff_s_flip_sout_pt2
	scalar s_brier_diff_s_flip_sout_pt2 = r(sum)		
		return scalar brier_diff_s_flip = (s_brier_diff_s_flip_sout_pt2 - ///
		s_brier_diff_s_flip_sout_pt1) / _N		
	summ brier_diff_s_random_rout_pt1
	scalar s_brier_diff_s_random_rout_pt1 = r(sum)
	summ brier_diff_s_random_rout_pt2
	scalar s_brier_diff_s_random_rout_pt2 = r(sum)		
		return scalar brier_diff_s_random_rout = (s_brier_diff_s_random_rout_pt2 - ///
		s_brier_diff_s_random_rout_pt1) / _N		
	summ brier_diff_s_flip_fout_pt1
	scalar s_brier_diff_s_flip_fout_pt1 = r(sum)
	summ brier_diff_s_flip_fout_pt2
	scalar s_brier_diff_s_flip_fout_pt2 = r(sum)		
		return scalar brier_diff_s_flip_fout = (s_brier_diff_s_flip_fout_pt2 - ///
		s_brier_diff_s_flip_fout_pt1) / _N	
	summ brier_diff_u_random_sout_pt1
	scalar s_brier_diff_u_random_sout_pt1 = r(sum)
	summ brier_diff_u_random_sout_pt2
	scalar s_brier_diff_u_random_sout_pt2 = r(sum)		
		return scalar brier_diff_u_random = (s_brier_diff_u_random_sout_pt2 - ///
		s_brier_diff_u_random_sout_pt1) / _N
	summ brier_diff_u_flip_sout_pt1
	scalar s_brier_diff_u_flip_sout_pt1 = r(sum)
	summ brier_diff_u_flip_sout_pt2
	scalar s_brier_diff_u_flip_sout_pt2 = r(sum)		
		return scalar brier_diff_u_flip = (s_brier_diff_u_flip_sout_pt2 - ///
		s_brier_diff_u_flip_sout_pt1) / _N		
	summ brier_diff_u_random_rout_pt1
	scalar s_brier_diff_u_random_rout_pt1 = r(sum)
	summ brier_diff_u_random_rout_pt2
	scalar s_brier_diff_u_random_rout_pt2 = r(sum)		
		return scalar brier_diff_u_random_rout = (s_brier_diff_u_random_rout_pt2 - ///
		s_brier_diff_u_random_rout_pt1) / _N		
	summ brier_diff_u_flip_fout_pt1
	scalar s_brier_diff_u_flip_fout_pt1 = r(sum)
	summ brier_diff_u_flip_fout_pt2
	scalar s_brier_diff_u_flip_fout_pt2 = r(sum)		
		return scalar brier_diff_u_flip_fout = (s_brier_diff_u_flip_fout_pt2 - ///
		s_brier_diff_u_flip_fout_pt1) / _N
	/*
	summ brier2_s_random
		scalar brier2_sum_s_random = r(sum)
		return scalar brier_diff_s_random = (brier2_sum_s_random - brier_sum_s) / _N
	summ brier2_s_flip
		scalar brier2_sum_s_flip = r(sum)
		return scalar brier_diff_s_flip = (brier2_sum_s_flip - brier_sum_s) / _N
	summ brier2_u_random
		scalar brier2_sum_u_random = r(sum)
		return scalar brier_diff_u_random = (brier2_sum_u_random - brier_sum_u) / _N
	summ brier2_u_flip  
		scalar brier2_sum_u_flip = r(sum)
		return scalar brier_diff_u_flip = (brier2_sum_u_flip - brier_sum_u)/_N 
	*/
	* Return pct correct predictions differences
	summ corrpred_diff_s_random_sout_pt1
	scalar s_cp_diff_s_random_sout_pt1 = r(sum)
	summ corrpred_diff_s_random_sout_pt2
	scalar s_cp_diff_s_random_sout_pt2 = r(sum)		
		return scalar corrpred_diff_s_random = (s_cp_diff_s_random_sout_pt2 - ///
		s_cp_diff_s_random_sout_pt1) / _N
	summ corrpred_diff_s_flip_sout_pt1
	scalar s_cp_diff_s_flip_sout_pt1 = r(sum)
	summ corrpred_diff_s_flip_sout_pt2
	scalar s_cp_diff_s_flip_sout_pt2 = r(sum)		
		return scalar corrpred_diff_s_flip = (s_cp_diff_s_flip_sout_pt2 - ///
		s_cp_diff_s_flip_sout_pt1) / _N		
	summ corrpred_diff_s_random_rout_pt1
	scalar s_cp_diff_s_random_rout_pt1 = r(sum)
	summ corrpred_diff_s_random_rout_pt2
	scalar s_cp_diff_s_random_rout_pt2 = r(sum)		
		return scalar corrpred_diff_s_random_rout = (s_cp_diff_s_random_rout_pt2 - ///
		s_cp_diff_s_random_rout_pt1) / _N		
	summ corrpred_diff_s_flip_fout_pt1
	scalar s_cp_diff_s_flip_fout_pt1 = r(sum)
	summ corrpred_diff_s_flip_fout_pt2
	scalar s_cp_diff_s_flip_fout_pt2 = r(sum)		
		return scalar corrpred_diff_s_flip_fout = (s_cp_diff_s_flip_fout_pt2 - ///
		s_cp_diff_s_flip_fout_pt1) / _N	
	summ corrpred_diff_u_random_sout_pt1
	scalar s_cp_diff_u_random_sout_pt1 = r(sum)
	summ corrpred_diff_u_random_sout_pt2
	scalar s_cp_diff_u_random_sout_pt2 = r(sum)		
		return scalar corrpred_diff_u_random = (s_cp_diff_u_random_sout_pt2 - ///
		s_cp_diff_u_random_sout_pt1) / _N
	summ corrpred_diff_u_flip_sout_pt1
	scalar s_cp_diff_u_flip_sout_pt1 = r(sum)
	summ corrpred_diff_u_flip_sout_pt2
	scalar s_cp_diff_u_flip_sout_pt2 = r(sum)		
		return scalar corrpred_diff_u_flip = (s_cp_diff_u_flip_sout_pt2 - ///
		s_cp_diff_u_flip_sout_pt1) / _N		
	summ corrpred_diff_u_random_rout_pt1
	scalar s_cp_diff_u_random_rout_pt1 = r(sum)
	summ corrpred_diff_u_random_rout_pt2
	scalar s_cp_diff_u_random_rout_pt2 = r(sum)		
		return scalar corrpred_diff_u_random_rout = (s_cp_diff_u_random_rout_pt2 - ///
		s_cp_diff_u_random_rout_pt1) / _N		
	summ corrpred_diff_u_flip_fout_pt1
	scalar s_cp_diff_u_flip_fout_pt1 = r(sum)
	summ corrpred_diff_u_flip_fout_pt2
	scalar s_cp_diff_u_flip_fout_pt2 = r(sum)		
		return scalar corrpred_diff_u_flip_fout = (s_cp_diff_u_flip_fout_pt2 - ///
		s_cp_diff_u_flip_fout_pt1) / _N
	* Return log loss differences
	summ logloss_diff_s_random_sout_pt1
	scalar s_logloss_diff_s_random_sout_pt1 = r(sum)
	summ logloss_diff_s_random_sout_pt2
	scalar s_logloss_diff_s_random_sout_pt2 = r(sum)		
		return scalar logloss_diff_s_random = (s_logloss_diff_s_random_sout_pt2 - ///
		s_logloss_diff_s_random_sout_pt1) / _N
	summ logloss_diff_s_flip_sout_pt1
	scalar s_logloss_diff_s_flip_sout_pt1 = r(sum)
	summ logloss_diff_s_flip_sout_pt2
	scalar s_logloss_diff_s_flip_sout_pt2 = r(sum)		
		return scalar logloss_diff_s_flip = (s_logloss_diff_s_flip_sout_pt2 - ///
		s_logloss_diff_s_flip_sout_pt1) / _N		
	summ logloss_diff_s_random_rout_pt1
	scalar s_logloss_diff_s_random_rout_pt1 = r(sum)
	summ logloss_diff_s_random_rout_pt2
	scalar s_logloss_diff_s_random_rout_pt2 = r(sum)		
		return scalar logloss_diff_s_random_rout = (s_logloss_diff_s_random_rout_pt2 - ///
		s_logloss_diff_s_random_rout_pt1) / _N		
	summ logloss_diff_s_flip_fout_pt1
	scalar s_logloss_diff_s_flip_fout_pt1 = r(sum)
	summ logloss_diff_s_flip_fout_pt2
	scalar s_logloss_diff_s_flip_fout_pt2 = r(sum)		
		return scalar logloss_diff_s_flip_fout = (s_logloss_diff_s_flip_fout_pt2 - ///
		s_logloss_diff_s_flip_fout_pt1) / _N	
	summ logloss_diff_u_random_sout_pt1
	scalar s_logloss_diff_u_random_sout_pt1 = r(sum)
	summ logloss_diff_u_random_sout_pt2
	scalar s_logloss_diff_u_random_sout_pt2 = r(sum)		
		return scalar logloss_diff_u_random = (s_logloss_diff_u_random_sout_pt2 - ///
		s_logloss_diff_u_random_sout_pt1) / _N
	summ logloss_diff_u_flip_sout_pt1
	scalar s_logloss_diff_u_flip_sout_pt1 = r(sum)
	summ logloss_diff_u_flip_sout_pt2
	scalar s_logloss_diff_u_flip_sout_pt2 = r(sum)		
		return scalar logloss_diff_u_flip = (s_logloss_diff_u_flip_sout_pt2 - ///
		s_logloss_diff_u_flip_sout_pt1) / _N		
	summ logloss_diff_u_random_rout_pt1
	scalar s_logloss_diff_u_random_rout_pt1 = r(sum)
	summ logloss_diff_u_random_rout_pt2
	scalar s_logloss_diff_u_random_rout_pt2 = r(sum)		
		return scalar logloss_diff_u_random_rout = (s_logloss_diff_u_random_rout_pt2 - ///
		s_logloss_diff_u_random_rout_pt1) / _N		
	summ logloss_diff_u_flip_fout_pt1
	scalar s_logloss_diff_u_flip_fout_pt1 = r(sum)
	summ logloss_diff_u_flip_fout_pt2
	scalar s_logloss_diff_u_flip_fout_pt2 = r(sum)		
		return scalar logloss_diff_u_flip_fout = (s_logloss_diff_u_flip_fout_pt2 - ///
		s_logloss_diff_u_flip_fout_pt1) / _N		
	** Brier scores with unshrunk predictions but shrunk outcomes
	gen brier_us = (pred_u - case_outcome_agreement)^2
	gen brier_us_flip = (pred_u - case_outcome_agreement_flip)^2
		* Return Brier scores with unshrunk predictions but shrunk outcomes
	summ brier_us
		return scalar brier_us = r(mean)
	summ brier_us_flip
		return scalar brier_us_flip = r(mean)		
	** Brier scores differences with unshrunk predictions but shrunk outcomes
	gen brier_diff_us_random_sout_pt1 = (pred_u - case_outcome_agreement)^2
	gen brier_diff_us_random_sout_pt2  =  (p_random - case_outcome_agreement)^2 
	gen brier_diff_us_random_rout_pt1 = (pred_u - case_outcome_agreement_random)^2
	gen brier_diff_us_random_rout_pt2  =  (p_random - case_outcome_agreement_random)^2
	gen brier_diff_us_flip_sout_pt1 = (pred_u - case_outcome_agreement)^2
	gen brier_diff_us_flip_sout_pt2  =  (p_u_flipped - case_outcome_agreement)^2
	gen brier_diff_us_flip_fout_pt1 = (pred_u - case_outcome_agreement_flip)^2
	gen brier_diff_us_flip_fout_pt2  =  (p_u_flipped - case_outcome_agreement_flip)^2
	* Return brier score differences with unshrunk predictions and shrunk outcomes
	summ brier_diff_us_random_sout_pt1
	scalar s_brier_diff_us_random_sout_pt1 = r(sum)
	summ brier_diff_us_random_sout_pt2
	scalar s_brier_diff_us_random_sout_pt2 = r(sum)		
		return scalar brier_diff_us_random_sout = (s_brier_diff_us_random_sout_pt2 - ///
		s_brier_diff_us_random_sout_pt1) / _N
		
	summ brier_diff_us_flip_sout_pt1
	scalar s_brier_diff_us_flip_sout_pt1 = r(sum)
	summ brier_diff_us_flip_sout_pt2
	scalar s_brier_diff_us_flip_sout_pt2 = r(sum)		
		return scalar brier_diff_us_flip_sout = (s_brier_diff_us_flip_sout_pt2 - ///
		s_brier_diff_us_flip_sout_pt1) / _N	
		
	summ brier_diff_us_random_rout_pt1
	scalar s_brier_diff_us_random_rout_pt1 = r(sum)
	summ brier_diff_us_random_rout_pt2
	scalar s_brier_diff_us_random_rout_pt2 = r(sum)		
		return scalar brier_diff_us_random_rout = (s_brier_diff_us_random_rout_pt2 - ///
		s_brier_diff_us_random_rout_pt1) / _N
		
	summ brier_diff_us_flip_fout_pt1
	scalar s_brier_diff_us_flip_fout_pt1 = r(sum)
	summ brier_diff_us_flip_fout_pt2
	scalar s_brier_diff_us_flip_fout_pt2 = r(sum)		
		return scalar brier_diff_us_flip_fout = (s_brier_diff_us_flip_fout_pt2 - ///
		s_brier_diff_us_flip_fout_pt1) / _N	

	** Treatment effect and whether it is significant or not
	* Baseline
	reghdfe case_outcome_agreement treatment i.appt_month_year i.casetype i.courttype i.courtstation i.referralmode, noabsorb nocons
		return scalar b = el(r(table),1,1)
		return scalar p = el(r(table),4,1)
	* Flip 
		reghdfe case_outcome_agreement_u treatment_u i.appt_month_year i.casetype i.courttype i.courtstation i.referralmode, noabsorb nocons
		return scalar b_u = el(r(table),1,1)
		return scalar p_u = el(r(table),4,1) 
	* Average mediator sucess
	bys mediator_id: egen avg_success = mean(case_outcome_agreement)
	bys mediator_id: egen avg_success_random = ///
	mean(case_outcome_agreement_random)
	bys mediator_id: egen avg_success_flip = mean(case_outcome_agreement_flip)

// Predicted vs actual outcome graphs 
/*
forvalues i = 1/5 {
foreach mm in s u {
	* Quadratic fit. Shrunk
	twoway (qfitci case_outcome_agreement pred_`mm') ///
	(line pred_`mm' pred_`mm', sort lcolor(red) legend(off) ///
	title("Quadratic fit", size(medium)) ///
	xtitle("Predicted outcome") ytitle("Actual outcome") note("The red line is a 45 degree line for reference. "))
	graph export "`path'/Output/PAP/sim`i'/pred_actual_qfit_`mm'_`datapull'.png", as(png) replace
	* Quadratic fit. Shrunk. Flip
	twoway (qfitci case_outcome_agreement_flip pred_`mm') ///
	(line pred_`mm' pred_`mm', sort lcolor(red) legend(off) ///
	title("Quadratic fit. Flipped outcomes", size(medium)) xtitle("Predicted outcome") ytitle("Actual outcome") note("The red line is a 45 degree line for reference. "))
	graph export "`path'/Output/PAP/sim`i'/pred_actual_qfit_`mm'_flip_`datapull'.png", as(png) replace
	* Quadratic fit. Shrunk. Random
	twoway (qfitci case_outcome_agreement_random pred_`mm') ///
	(line pred_`mm' pred_`mm', sort lcolor(red) legend(off) ///
	title("Quadratic fit. Random outcomes", size(medium)) xtitle("Predicted outcome") ytitle("Actual outcome") note("The red line is a 45 degree line for reference. "))
	graph export "`path'/Output/PAP/sim`i'/pred_actual_qfit_`mm'_random_`datapull'.png", as(png) replace
	* Kernel reg. Shrunk 
	lprobust case_outcome_agreement pred_`mm', p(1) neval(100) genvars bwselect(mse-dpi) plot 
	summ lprobust_h
	local bw = round(r(mean), .01)
	tw (line lprobust_gx_us lprobust_eval, sort lcolor(blue)) ///
	(line lprobust_CI_l_rb lprobust_eval, sort lcolor(blue) lpattern(dash) mcolor(%30)) ///
	(line lprobust_CI_r_rb lprobust_eval, sort lcolor(blue) lpattern(dash) mcolor(%30)) ///
	(line pred_`mm' pred_`mm' if pred_`mm'>0 & pred_`mm'<1, sort lcolor(red) legend(off) ///
	xscale(range(0 1)) yscale(range(0 1)) xla(0 (.2) 1) yla(0 (.2) 1) aspectratio(1) ///
	title("Kernel Reg", size(medium)) xtitle("Predicted outcome") ytitle("Actual outcome") note("Kernel: Epanechnikov. Pointwise bandwidths.""The mean bandwidth is `bw'" "The red line is a 45 degree line") )
	graph export "`path'/Output/PAP/sim`i'/pred_actual_kreg_`mm'_`datapull'.png", as(png) replace
	drop lprobust_*
	* Kernel reg. Shrunk. Flip
	lprobust case_outcome_agreement_flip pred_`mm', p(1) neval(100) genvars bwselect(mse-dpi) plot 
	summ lprobust_h
	local bw = round(r(mean), .01)
	tw (line lprobust_gx_us lprobust_eval, sort lcolor(blue)) ///
	(line lprobust_CI_l_rb lprobust_eval, sort lcolor(blue) lpattern(dash) mcolor(%30)) ///
	(line lprobust_CI_r_rb lprobust_eval, sort lcolor(blue) lpattern(dash) mcolor(%30)) ///
	(line pred_`mm' pred_`mm' if pred_`mm'>0 & pred_`mm'<1, sort lcolor(red) legend(off) ///
	xscale(range(0 1)) yscale(range(0 1)) xla(0 (.2) 1) yla(0 (.2) 1) aspectratio(1) ///
	title("Kernel Reg. Flipped outcomes.", size(medium)) xtitle("Predicted outcome") ytitle("Actual outcome") note("Kernel: Epanechnikov. Pointwise bandwidths.""The mean bandwidth is `bw'" "The red line is a 45 degree line") )
	graph export "`path'/Output/PAP/sim`i'/pred_actual_kreg_`mm'_flip_`datapull'.png", as(png) replace
	drop lprobust_*
	* Kernel reg. Shrunk. random
	lprobust case_outcome_agreement_random pred_`mm', p(1) neval(100) genvars bwselect(mse-dpi) plot 
	summ lprobust_h
	local bw = round(r(mean), .01)
	tw (line lprobust_gx_us lprobust_eval, sort lcolor(blue)) ///
	(line lprobust_CI_l_rb lprobust_eval, sort lcolor(blue) lpattern(dash) mcolor(%30)) ///
	(line lprobust_CI_r_rb lprobust_eval, sort lcolor(blue) lpattern(dash) mcolor(%30)) ///
	(line pred_`mm' pred_`mm' if pred_`mm'>0 & pred_`mm'<1, sort lcolor(red) legend(off) ///
	xscale(range(0 1)) yscale(range(0 1)) xla(0 (.2) 1) yla(0 (.2) 1) aspectratio(1) ///
	title("Kernel Reg. Random outcomes", size(medium)) xtitle("Predicted outcome") ytitle("Actual outcome") note("Kernel: Epanechnikov. Pointwise bandwidths.""The mean bandwidth is `bw'" "The red line is a 45 degree line") )
	graph export "`path'/Output/PAP/sim`i'/pred_actual_kreg_`mm'_random_`datapull'.png", as(png) replace
	drop lprobust_*
}
}
	*/

	tempfile rts_cases
	save `rts_cases'

// Collapse at mediator level
	collapse avg_success avg_success_flip avg_success_random va_s va_u /// 
	treatment, by(mediator_id)	

// Outputs at mediator level
	* Return the avg mediator success in experiment
	summ avg_success 
		return scalar avg_success = r(mean)
	summ avg_success_flip 
		return scalar avg_success_flip = r(mean)
	summ avg_success_random
		return scalar avg_success_random = r(mean)
	** Return the difference between avg success for treatment and control
	* Baseline
	summ avg_success if treatment == 1
	scalar avg_upper = r(mean)
	summ avg_success if treatment == 0
	scalar avg_lower = r(mean)
		return scalar avg_success_diff = avg_upper - avg_lower
	* Flip
	summ avg_success_flip if treatment == 1
	scalar avg_upper_flip = r(mean)
	summ avg_success_flip if treatment == 0
	scalar avg_lower_flip = r(mean)
		return scalar avg_success_diff_flip = avg_upper_flip - avg_lower_flip
	* Random
	summ avg_success_random if treatment == 1
	scalar avg_upper_random = r(mean)
	summ avg_success_random if treatment == 0
	scalar avg_lower_random = r(mean)
		return scalar avg_success_diff_random = ///
		avg_upper_random - avg_lower_random
	** VA Difference between treatment and control mediators shrunk
	* Shrunk
	summ va_s if treatment == 1
	scalar va_s_upper = r(mean)
	summ va_s if treatment == 0
	scalar va_s_lower = r(mean)
		return scalar va_s_diff = va_s_upper - va_s_lower
	* Unshrunk
	summ va_u if treatment == 1
	scalar va_upper_unsh = r(mean)
	summ va_u if treatment == 0
	scalar va_lower_unsh = r(mean)
		return scalar va_u_diff = va_upper_unsh - va_lower_unsh

// Create original + simulated cases dataset
	use `rts_cases', clear
	sort mediator_id id 
	rename va_s va_s_nosimul
	rename va_u va_u_nosimul
	append using `sampled' 
	replace case_outcome_agreement_flip = case_outcome_agreement if ///
	experimental != 1
	replace case_outcome_agreement_random = case_outcome_agreement if ///
	experimental != 1
	replace case_outcome_agreement_u = case_outcome_agreement if ///
	experimental != 1
	replace case_outcome_agreement_u_flip = case_outcome_agreement if ///
	experimental != 1
	
// Re-estimate VA with original + simulated case outcomes
	* Shrunk - Baseline
	egen med_year=group(mediator_id appt_year)
	local state = c(rngstate)
	vam case_outcome_agreement, teacher(mediator_id) year(appt_year) ///
	driftlimit(3) class(med_year) controls(i.appt_month_year i.casetype ///
	i.courttype i.courtstation i.referralmode) tfx_resid(mediator_id) ///
	data(merge tv)
	set rngstate `state'
	rename tv va_s_all
	* Shrunk - Flip
	local state = c(rngstate)
	vam case_outcome_agreement_flip, teacher(mediator_id) year(appt_year) ///
	driftlimit(3) class(med_year) controls(i.appt_month_year i.casetype ///
	i.courttype i.courtstation i.referralmode) tfx_resid(mediator_id) ///
	data(merge tv)
	set rngstate `state'
	rename tv va_s_all_flip
	* Shrunk - Random
	local state = c(rngstate)
	vam case_outcome_agreement_random, teacher(mediator_id) year(appt_year) ///
	driftlimit(3) class(med_year) controls(i.appt_month_year i.casetype ///
	i.courttype i.courtstation i.referralmode) tfx_resid(mediator_id) ///
	data(merge tv)
	set rngstate `state'
	rename tv va_all_random
	* Unshrunk - No flip
	areg case_outcome_agreement i.appt_year i.casetype i.courttype ///
	i.courtstation i.referralmode, absorb(mediator_id)
	predict residuals, dr
	bys mediator_id: egen va_u_all =mean(residuals)
	drop residuals
	* Unshrunk - Flip
	areg case_outcome_agreement_flip i.appt_year i.casetype i.courttype ///
	i.courtstation i.referralmode, absorb(mediator_id)
	predict residuals, dr
	bys mediator_id: egen va_u_all_flip =mean(residuals)
	
// Do not use for the results mediators which are not used in the simulations
	egen va_s_nonsimul_possible = sum(va_s_nosimul), by(mediator_id)
	drop if va_s_nonsimul_possible == 0 
	
// Collapse at the mediator level
	collapse va_s_all va_s_all_flip va_all_random va_s_nosimul va_u_all ///
	va_u_all_flip va_u_nosimul, by(mediator_id)

// Output - VA Diff and VA Diff sq
	** Diff VA shrunk
	gen diff_va_s = va_s_nosimul - va_s_all
	summ diff_va_s	
		return scalar diff_va_s = r(mean)
	gen diff_va_s_flip = va_s_nosimul - va_s_all_flip
	summ diff_va_s_flip	
		return scalar diff_va_s_flip = r(mean)
	gen diff_va_s_random = va_s_nosimul - va_all_random
	summ diff_va_s_random	
		return scalar diff_va_s_random = r(mean)
	** Diff VA sq srhunk
	gen diff_va_s_sq = (va_s_nosimul - va_s_all)^2
	summ diff_va_s_sq	
		return scalar diff_va_s_sq = r(mean) 
	gen diff_va_s_sq_flip = (va_s_nosimul - va_s_all_flip)^2
	summ diff_va_s_sq_flip	
		return scalar diff_va_s_sq_flip = r(mean) 
	gen diff_va_s_sq_random = (va_s_nosimul - va_all_random)^2
	summ diff_va_s_sq_random	
		return scalar diff_va_s_sq_random = r(mean) 
	** Diff VA unshrunk	
	gen diff_va_u = va_u_nosimul - va_u_all
	summ diff_va_u	
		return scalar diff_va_u = r(mean)
	gen diff_va_u_flip = va_u_nosimul - va_u_all_flip
	summ diff_va_u_flip	
		return scalar diff_va_u_flip = r(mean)
	gen diff_va_u_random = va_u_nosimul - va_all_random
	summ diff_va_u_random	
		return scalar diff_va_u_random = r(mean)
	** Diff VA sq unshrunk	
	gen diff_va_u_sq = (va_u_nosimul - va_u_all)^2
	summ diff_va_u_sq	
		return scalar diff_va_u_sq = r(mean) 
	gen diff_va_u_sq_flip = (va_u_nosimul - va_u_all_flip)^2
	summ diff_va_u_sq_flip	
		return scalar diff_va_u_sq_flip = r(mean) 
	gen diff_va_u_sq_random = (va_u_nosimul - va_all_random)^2
	summ diff_va_u_sq_random	
		return scalar diff_va_u_sq_random = r(mean) 
/*
forvalues i = 1/5 {
// VA distrib
* Shrunk
twoway  (kdensity va_s_nosimul) (kdensity va_all_random) (kdensity va_s_all) (kdensity va_s_all_flip) 
graph export "`path'/Output/PAP/sim`i'/1sim_va_s_p`p'_c`cases_exp'_m`min_cases'_pull`datapull'.png", as(png) replace 
* Unshrunk
twoway  (kdensity va_u_nosimul) (kdensity va_u_all) (kdensity va_all_random) (kdensity va_u_all_flip)
graph export "`path'/Output/PAP/sim`i'/1sim_va_u_p`p'_c`cases_exp'_m`min_cases'_pull`datapull'.png", as(png) replace

// Diff VA distrib
* Shrunk
twoway (kdensity diff_va_s) (kdensity diff_va_s_flip) (kdensity diff_va_s_random)
graph export "`path'/Output/PAP/sim`i'/1sim_diffva_s_p`p'_c`cases_exp'_m`min_cases'_pull`datapull'.png", as(png) replace
* Unshrunk
twoway (kdensity diff_va_u) (kdensity diff_va_u_flip) (kdensity diff_va_u_random)
graph export "`path'/Output/PAP/sim`i'/1sim_diffva_u_p`p'_c`cases_exp'_m`min_cases'_pull`datapull'.png", as(png) replace

// Sq Diff VA distrib
* Shrunk
twoway (kdensity diff_va_s_sq) (kdensity diff_va_s_sq_flip) (kdensity diff_va_s_sq_random)
graph export "`path'/Output/PAP/sim`i'/1sim_diffvasq_s_p`p'_c`cases_exp'_m`min_cases'_pull`datapull'.png", as(png) replace
* Unshrunk
twoway (kdensity diff_va_u_sq) (kdensity diff_va_u_sq_random) (kdensity diff_va_u_sq_flip)
graph export "`path'/Output/PAP/sim`i'/1sim_diffvasq_u_p`p'_c`cases_exp'_m`min_cases'_pull`datapull'.png", as(png) replace
}
*/
end

//Runn the program the first time and store the results in different matrices
exp_effect
matrix avg_success = r(avg_success)
matrix avg_success_flip = r(avg_success_flip)
matrix avg_success_random = r(avg_success_random)
matrix avg_success_diff = r(avg_success_diff)
matrix avg_success_diff_flip = r(avg_success_diff_flip)
matrix avg_success_diff_random = r(avg_success_diff_random)
matrix brier_s = r(brier_s)
matrix brier_s_flip = r(brier_s_flip)
matrix brier_s_random = r(brier_s_random)
matrix brier_u = r(brier_u)
matrix brier_u_flip = r(brier_u_flip)
matrix brier_u_random = r(brier_u_random)
matrix brier_diff_s_random = r(brier_diff_s_random )
matrix brier_diff_s_flip  = r(brier_diff_s_flip )
matrix brier_diff_u_random  = r(brier_diff_u_random )
matrix brier_diff_u_flip = r(brier_diff_u_flip)
matrix brier_diff_s_random_rout = r(brier_diff_s_random_rout)
matrix brier_diff_s_flip_fout  = r(brier_diff_s_flip_fout)
matrix brier_diff_u_random_rout  = r(brier_diff_u_random_rout )
matrix brier_diff_u_flip_fout = r(brier_diff_u_flip_fout)
matrix corrpred_diff_s_random = r(corrpred_diff_s_random )
matrix corrpred_diff_s_flip  = r(corrpred_diff_s_flip )
matrix corrpred_diff_u_random  = r(corrpred_diff_u_random )
matrix corrpred_diff_u_flip = r(corrpred_diff_u_flip)
matrix corrpred_diff_s_random_rout = r(corrpred_diff_s_random_rout)
matrix corrpred_diff_s_flip_fout  = r(corrpred_diff_s_flip_fout)
matrix corrpred_diff_u_random_rout  = r(corrpred_diff_u_random_rout )
matrix corrpred_diff_u_flip_fout = r(corrpred_diff_u_flip_fout)
matrix logloss_diff_s_random = r(logloss_diff_s_random )
matrix logloss_diff_s_flip  = r(logloss_diff_s_flip )
matrix logloss_diff_u_random  = r(logloss_diff_u_random )
matrix logloss_diff_u_flip = r(logloss_diff_u_flip)
matrix logloss_diff_s_random_rout = r(logloss_diff_s_random_rout)
matrix logloss_diff_s_flip_fout  = r(logloss_diff_s_flip_fout)
matrix logloss_diff_u_random_rout  = r(logloss_diff_u_random_rout )
matrix logloss_diff_u_flip_fout = r(logloss_diff_u_flip_fout)
matrix brier_us = r(brier_us)
matrix brier_us_flip = r(brier_us_flip)
matrix brier_diff_us_random_sout = r(brier_diff_us_random_sout)
matrix brier_diff_us_flip_sout = r(brier_diff_us_flip_sout)
matrix brier_diff_us_random_rout = r(brier_diff_us_random_rout)
matrix brier_diff_us_flip_fout = r(brier_diff_us_flip_fout)
matrix pred_correct_s = r(pred_correct_s)
matrix pred_correct_s_flip = r(pred_correct_s_flip)
matrix pred_correct_s_random = r(pred_correct_s_random)
matrix pred_correct_u = r(pred_correct_u)
matrix pred_correct_u_flip = r(pred_correct_u_flip)
matrix pred_correct_u_random = r(pred_correct_u_random)
matrix logloss_s = r(logloss_s)
matrix logloss_s_flip = r(logloss_s_flip)
matrix logloss_s_random = r(logloss_s_random)
matrix logloss_u = r(logloss_u)
matrix logloss_u_flip = r(logloss_u_flip)
matrix logloss_u_random = r(logloss_u_random)
matrix t_s = r(va_s_diff)
matrix t_u = r(va_u_diff)
matrix b = r(b)
matrix b_u = r(b)
matrix p = r(p)
matrix p_u = r(p)
matrix diff_va_s = r(diff_va_s)
matrix diff_va_s_flip = r(diff_va_s_flip)
matrix diff_va_s_random = r(diff_va_s_random)
matrix diff_va_s_sq = r(diff_va_s_sq)
matrix diff_va_s_sq_flip = r(diff_va_s_sq_flip)
matrix diff_va_s_sq_random = r(diff_va_s_sq_random)
matrix diff_va_u = r(diff_va_u)
matrix diff_va_u_flip = r(diff_va_u_flip)
matrix diff_va_u_random = r(diff_va_u_random)
matrix diff_va_u_sq = r(diff_va_u_sq)
matrix diff_va_u_sq_flip = r(diff_va_u_sq_flip)
matrix diff_va_u_sq_random = r(diff_va_u_sq_flip)

//Display the matrices to check that they all have values in the first run
matlist avg_success
matlist avg_success_flip
matlist avg_success_random
matlist avg_success_diff
matlist avg_success_diff_flip
matlist avg_success_diff_random
matlist brier_s
matlist brier_s_flip
matlist brier_s_random
matlist brier_u
matlist brier_u_flip
matlist brier_u_random
matlist brier_diff_s_random 
matlist brier_diff_s_flip 
matlist brier_diff_u_random 
matlist brier_diff_u_flip
matlist brier_diff_s_random_rout 
matlist brier_diff_s_flip_fout
matlist brier_diff_u_random_rout 
matlist brier_diff_u_flip_fout
matlist corrpred_diff_s_random 
matlist corrpred_diff_s_flip  
matlist corrpred_diff_u_random 
matlist corrpred_diff_u_flip 
matlist corrpred_diff_s_random_rout 
matlist corrpred_diff_s_flip_fout 
matlist corrpred_diff_u_random_rout 
matlist corrpred_diff_u_flip_fout
matlist logloss_diff_s_random 
matlist logloss_diff_s_flip 
matlist logloss_diff_u_random 
matlist logloss_diff_u_flip 
matlist logloss_diff_s_random_rout 
matlist logloss_diff_s_flip_fout 
matlist logloss_diff_u_random_rout 
matlist logloss_diff_u_flip_fout 
matlist brier_us
matlist brier_us_flip
matlist brier_diff_us_random_sout	
matlist brier_diff_us_flip_sout
matlist brier_diff_us_random_rout
matlist brier_diff_us_flip_fout
matlist pred_correct_s
matlist pred_correct_s_flip
matlist pred_correct_s_random
matlist pred_correct_u
matlist pred_correct_u_flip
matlist pred_correct_u_random
matlist logloss_s
matlist logloss_s_flip
matlist logloss_s_random
matlist logloss_u
matlist logloss_u_flip
matlist logloss_u_random
matlist b
matlist b_u
matlist p
matlist p_u
matlist t_s
matlist t_u
matlist diff_va_s
matlist diff_va_s_flip
matlist diff_va_s_random
matlist diff_va_s_sq
matlist diff_va_s_sq_flip
matlist diff_va_s_sq_random
matlist diff_va_u
matlist diff_va_u_flip
matlist diff_va_u_random
matlist diff_va_u_sq
matlist diff_va_u_sq_flip
matlist diff_va_u_sq_random



//Simulate
simulate avg_success = r(avg_success) avg_success_flip = r(avg_success_flip) avg_success_random = r(avg_success_random) avg_success_diff=r(avg_success_diff) avg_success_diff_flip=r(avg_success_diff_flip) avg_success_diff_random=r(avg_success_diff_random) ///
brier_s = r(brier_s) brier_s_flip = r(brier_s_flip) brier_s_random = r(brier_s_random) brier_u = r(brier_u) brier_u_flip = r(brier_u_flip) brier_u_random = r(brier_u_random) brier_diff_s_random  = r(brier_diff_s_random ) brier_diff_s_flip = r(brier_diff_s_flip) brier_diff_u_random  = r(brier_diff_u_random) brier_diff_u_flip = r(brier_diff_u_flip) brier_diff_s_random_rout  = r(brier_diff_s_random_rout ) brier_diff_s_flip_fout = r(brier_diff_s_flip_fout) brier_diff_u_random_rout  = r(brier_diff_u_random_rout) brier_diff_u_flip_fout = r(brier_diff_u_flip_fout) corrpred_diff_s_random  = r(corrpred_diff_s_random ) corrpred_diff_s_flip = r(corrpred_diff_s_flip) corrpred_diff_u_random  = r(corrpred_diff_u_random) corrpred_diff_u_flip = r(corrpred_diff_u_flip) corrpred_diff_s_random_rout  = r(corrpred_diff_s_random_rout ) corrpred_diff_s_flip_fout = r(corrpred_diff_s_flip_fout) corrpred_diff_u_random_rout  = r(corrpred_diff_u_random_rout) corrpred_diff_u_flip_fout = r(corrpred_diff_u_flip_fout) logloss_diff_s_random  = r(logloss_diff_s_random ) logloss_diff_s_flip = r(logloss_diff_s_flip) logloss_diff_u_random  = r(logloss_diff_u_random) logloss_diff_u_flip = r(logloss_diff_u_flip) logloss_diff_s_random_rout  = r(logloss_diff_s_random_rout ) logloss_diff_s_flip_fout = r(logloss_diff_s_flip_fout) logloss_diff_u_random_rout  = r(logloss_diff_u_random_rout) logloss_diff_u_flip_fout = r(logloss_diff_u_flip_fout) brier_us = r(brier_us) brier_us_flip = r(brier_us_flip) brier_diff_us_random_sout = r(brier_diff_us_random_sout) brier_diff_us_flip_sout = r(brier_diff_us_flip_sout) brier_diff_us_random_rout = r(brier_diff_us_random_rout) brier_diff_us_flip_fout = r(brier_diff_us_flip_fout) pred_correct_s = r(pred_correct_s) pred_correct_s_flip = r(pred_correct_s_flip) pred_correct_s_random = r(pred_correct_s_random) pred_correct_u = r(pred_correct_u) pred_correct_u_flip = r(pred_correct_u_flip) pred_correct_u_random = r(pred_correct_u_random) logloss_s = r(logloss_s) logloss_s_flip = r(logloss_s_flip) logloss_s_random = r(logloss_s_random) logloss_u = r(logloss_u) logloss_u_flip = r(logloss_u_flip) logloss_u_random = r(logloss_u_random) ///
b = r(b) b_u = r(b_u) p = r(p) p_u = r(p_u) t_s=r(va_s_diff) t_u=r(va_u_diff) ///
diff_va_s = r(diff_va_s) diff_va_s_flip = r(diff_va_s_flip) diff_va_s_random = r(diff_va_s_random) diff_va_s_sq = r(diff_va_s_sq) diff_va_s_sq_flip = r(diff_va_s_sq_flip) diff_va_s_sq_random = r(diff_va_s_sq_random) diff_va_u = r(diff_va_u)  diff_va_u_flip = r(diff_va_u_flip) diff_va_u_random = r(diff_va_u_random) diff_va_u_sq = r(diff_va_u_sq) diff_va_u_sq_flip = r(diff_va_u_sq_flip) diff_va_u_sq_random = r(diff_va_u_sq_random), ///
 reps(`n_sim') seed(45415): exp_effect 
 

bstat, stat(avg_success, avg_success_flip, avg_success_random, avg_success_diff, avg_success_diff_flip, avg_success_diff_random, ///
brier_s, brier_s_flip, brier_s_random, brier_u, brier_u_flip, brier_u_random, brier_diff_s_random, brier_diff_s_flip, brier_diff_u_random, brier_diff_u_flip,brier_diff_s_random_rout, brier_diff_s_flip_fout, brier_diff_u_random_rout, brier_diff_u_flip_fout, corrpred_diff_s_random, corrpred_diff_s_flip, corrpred_diff_u_random, corrpred_diff_u_flip, corrpred_diff_s_random_rout, corrpred_diff_s_flip_fout, corrpred_diff_u_random_rout, corrpred_diff_u_flip_fout, logloss_diff_s_random, logloss_diff_s_flip, logloss_diff_u_random, logloss_diff_u_flip, logloss_diff_s_random_rout, logloss_diff_s_flip_fout, logloss_diff_u_random_rout, logloss_diff_u_flip_fout, brier_us, brier_us_flip, brier_diff_us_random_sout, brier_diff_us_flip_sout, brier_diff_us_random_rout, brier_diff_us_flip_fout, pred_correct_s, pred_correct_s_flip, pred_correct_s_random, pred_correct_u, pred_correct_u_flip, pred_correct_u_random,  logloss_s, logloss_s_flip, logloss_s_random, logloss_u, logloss_u_flip, logloss_u_random, ///
p, p_u, b, b_u, t_s, t_u, ///
diff_va_s, diff_va_s_flip, diff_va_s_random, diff_va_s_sq, diff_va_s_sq_flip, diff_va_s_sq_random, diff_va_u, diff_va_u_flip, diff_va_u_random, diff_va_u_sq, diff_va_u_sq_flip, diff_va_u_sq_random)

//Significance
gen sig = 1 if p<0.05
replace sig = 0 if p>=0.05 & p!=.
replace sig = -99 if missing(sig)
label define signif 1 "Significant" 0 "Not significant" -99 "No result"
label values sig signif
tab sig,m

//Display the results of the simulation
eststo rts_final: estpost summ avg_success avg_success_flip avg_success_random avg_success_diff avg_success_diff_flip avg_success_diff_random p p_u brier_s brier_s_flip brier_s_random brier_u brier_u_flip brier_u_random brier_diff_s_random brier_diff_s_flip brier_diff_u_random brier_diff_u_flip brier_diff_s_random_rout brier_diff_s_flip_fout brier_diff_u_random_rout brier_diff_u_flip_fout corrpred_diff_s_random corrpred_diff_s_flip corrpred_diff_u_random corrpred_diff_u_flip corrpred_diff_s_random_rout corrpred_diff_s_flip_fout corrpred_diff_u_random_rout corrpred_diff_u_flip_fout logloss_diff_s_random logloss_diff_s_flip logloss_diff_u_random logloss_diff_u_flip logloss_diff_s_random_rout logloss_diff_s_flip_fout logloss_diff_u_random_rout logloss_diff_u_flip_fout brier_us brier_us_flip brier_diff_us_random_sout brier_diff_us_flip_sout brier_diff_us_random_rout brier_diff_us_flip_fout brier_diff_us_flip_fout pred_correct_s pred_correct_s_flip pred_correct_s_random pred_correct_u pred_correct_u_flip pred_correct_u_random logloss_s logloss_s_flip logloss_s_random logloss_u logloss_u_flip logloss_u_random b b_u t_s t_u diff_va_s diff_va_s_flip diff_va_s_random diff_va_s_sq diff_va_s_sq_flip diff_va_s_sq_random diff_va_u diff_va_u_flip diff_va_u_random diff_va_u_sq diff_va_u_sq_flip diff_va_u_sq_random sig
esttab rts_final using "`path'/Output/PAP/p`p'_c`cases_exp'_m`min_cases'_nsim`n_sim'_pull`datapull'.rtf", cells("count mean sd min max") replace

// Graphs
/*
	** Diff_VA 
	* Difference VA shrunk
	qui twoway kdensity diff_va_s || kdensity diff_va_s_random || kdensity diff_va_s_flip ///
	, xtitle("VA difference") ///
	legend(label(1 "Diff VA") label(2 "Diff VA random") label(3 "Diff VA flip") ///
	) 
	graph export "`path'/Output/PAP/diff_s_p`p'_c`cases_exp'_m`min_cases'_nsim`n_sim'_pull`datapull'.png", as(png) replace
	* Difference VA unshrunk
	qui twoway kdensity diff_va_u || kdensity diff_va_u_random || kdensity diff_va_u_flip, ///
	xtitle("VA difference") legend(label(1 "Diff VA") label(2 "Diff VA random") label(3 "Diff VA flip")  )
	graph export "`path'/Output/PAP/diff_u_p`p'_c`cases_exp'_m`min_cases'_nsim`n_sim'_pull`datapull'.png", as(png) replace
	
	** Diff_VA_sq
	* Difference sq VA shrunk
	qui twoway kdensity diff_va_s_sq || kdensity diff_va_s_sq_random || kdensity diff_va_s_sq_flip ///
	, xtitle("Squared VA difference") ///
	legend(label(1 "Diff VA Sq") label(2 "Diff VA Sq random") ///
	label(3 "Diff VA Sq flip"))
	graph export "`path'/Output/PAP/sqdiff_s_p`p'_c`cases_exp'_m`min_cases'_nsim`n_sim'_pull`datapull'.png", as(png) replace 
	* Difference sq VA unshrunk
	qui twoway kdensity diff_va_u_sq || kdensity diff_va_u_sq_random || kdensity diff_va_u_sq_flip, ///
	xtitle("Squared VA difference") legend(label(1 "Diff VA Sq") ///
	label(2 "Diff VA Sq random") label(3 "Diff VA Sq flip"))
	graph export "`path'/Output/PAP/sqdiff_u_p`p'_c`cases_exp'_m`min_cases'_nsim`n_sim'_pull`datapull'.png", as(png) replace 
*/
local path "C:\Users\didac\Dropbox\Arbiter Research\Data analysis"
	** Kdensity Brier score
	qui twoway kdensity brier_s || kdensity brier_s_random ///
	 || kdensity brier_s_flip, xtitle("Brier Score") ///
	legend(label(1 "Standard VA model") label(2 "Random VA model") ///
	 label(3 "Flipped VA model") position(6) cols(3)) ///
	ytitle(Frequency)
	graph export "`path'/Output/PAP/brier_s.png", as(png) replace
	/*
	qui twoway kdensity brier_u  ///
	|| kdensity brier_u_random || kdensity brier_u_flip, xtitle("Brier Score unshrunk") ///
	legend(label(1 "Brier score") label(2 "Brier score random") label(3 "Brier score flip")) ///
	ytitle(Frequency)
	graph export "`path'/Output/PAP/brier_u_p`p'_c`cases_exp'_m`min_cases'_nsim`n_sim'_pull`datapull'.png.png", as(png) replace
*/
	** Kdensity Brier score differences
	qui twoway kdensity brier_diff_s_flip    ///
	|| kdensity brier_diff_s_flip_fout, ///
	legend(label(1 "Outcomes from standard VA model") ///
	label(2 "Outcomes from flipped VA model") position(6) cols(2)) ///
	xtitle("Brier Score Difference") ///
	ytitle(Frequency)
	graph export "`path'/Output/PAP/brierdiff_s_flip.png", as(png) replace
	
	qui twoway kdensity brier_diff_s_random    ///
	|| kdensity brier_diff_s_random_rout, ///
	legend(label(1 "Outcomes from standard VA model") ///
	label(2 "Outcomes from random VA model") position(6) cols(2)) ///
	xtitle("Brier Score Difference") ///
	ytitle(Frequency)
	graph export "`path'/Output/PAP/brierdiff_s_random.png", as(png) replace
/*	
	qui twoway kdensity brier_diff_u_flip    ///
	|| kdensity brier_diff_u_flip_fout, ///
	legend(label(1 "Standard outcomes") ///
	label(2 "Flipped outcomes")) ///
	title("Brier diff. Unshrunk") ///
	xtitle("Brier Score Differences") ///
	ytitle(Frequency)
	graph export "`path'/Output/PAP/brierdiff_u_flip_p`p'_c`cases_exp'_m`min_cases'_nsim`n_sim'_pull`datapull'.png", as(png) replace
	
	qui twoway kdensity brier_diff_u_random    ///
	|| kdensity brier_diff_u_random_rout, ///
	legend(label(1 "Standard outcomes") ///
	label(2 "Random outcomes")) ///
	title("Brier diff. Unshrunk") ///
	xtitle("Brier Score Differences") ///
	ytitle(Frequency)
	graph export "`path'/Output/PAP/brierdiff_u_random_p`p'_c`cases_exp'_m`min_cases'_nsim`n_sim'_pull`datapull'.png", as(png) replace	

	
	** Kdensity Brier score U predictions but S outcomes
	qui twoway kdensity brier_us   ///
	|| kdensity brier_u_random || kdensity brier_us_flip, ///
	xtitle("Brier Score. U predictions. S outcomes") legend(label(1 "Standard outcomes") ///
	label(2 "Random Outcomes") label(3 "Flipped outcomes")) ytitle(Frequency) 
	graph export "`path'/Output/PAP/brierus_p`p'_c`cases_exp'_m`min_cases'_nsim`n_sim'_pull`datapull'.png", as(png) replace
	
	** Kdensity Brier score difference U predictions but S outcomes
	qui twoway kdensity brier_diff_us_random_sout   ///
	|| kdensity brier_diff_us_random_rout, ///
	xtitle("Brier Score diff. U predictions. S outcomes") legend(label(1 "Standard outcomes") ///
	label(2 "Random outcomes")) ytitle(Frequency) 
	graph export "`path'/Output/PAP/brierusdiff_r_p`p'_c`cases_exp'_m`min_cases'_nsim`n_sim'_pull`datapull'.png", as(png) replace
	
	qui twoway kdensity brier_diff_us_flip_sout   ///
	|| kdensity brier_diff_us_flip_fout, ///
	xtitle("Brier Score diff. U predictions. S outcomes") legend(label(1 "Standard outcomes") ///
	label(2 "Flipped outcomes")) ytitle(Frequency) 
	graph export "`path'/Output/PAP/brierusdiff_f_p`p'_c`cases_exp'_m`min_cases'_nsim`n_sim'_pull`datapull'.png", as(png) replace
		
	
** Kdensity pct corr predictions differences
	qui twoway kdensity corrpred_diff_s_flip    ///
	|| kdensity corrpred_diff_s_flip_fout, ///
	legend(label(1 "Standard outcomes") ///
	label(2 "Flipped outcomes")) ///
	title("Corr Pred diff. Shrunk") ///
	xtitle("Correct Predictions Differences") ///
	ytitle(Frequency)
	graph export "`path'/Output/PAP/corrpreddiff_s_flip_p`p'_c`cases_exp'_m`min_cases'_nsim`n_sim'_pull`datapull'.png", as(png) replace
	
	qui twoway kdensity corrpred_diff_s_random    ///
	|| kdensity corrpred_diff_s_random_rout, ///
	legend(label(1 "Standard outcomes") ///
	label(2 "Random outcomes")) ///
	title("Corr Pred diff. Shrunk") ///
	xtitle("Correct Predictions Differences") ///
	ytitle(Frequency)
	graph export "`path'/Output/PAP/corrpreddiff_s_random_p`p'_c`cases_exp'_m`min_cases'_nsim`n_sim'_pull`datapull'.png", as(png) replace
	
	qui twoway kdensity corrpred_diff_u_flip    ///
	|| kdensity corrpred_diff_u_flip_fout, ///
	legend(label(1 "Standard outcomes") ///
	label(2 "Flipped outcomes")) ///
	title("Corr Pred diff. Unshrunk") ///
	xtitle("Correct Predictions Differences") ///
	ytitle(Frequency)
	graph export "`path'/Output/PAP/corrpreddiff_u_flip_p`p'_c`cases_exp'_m`min_cases'_nsim`n_sim'_pull`datapull'.png", as(png) replace
	
	qui twoway kdensity corrpred_diff_u_random    ///
	|| kdensity corrpred_diff_u_random_rout, ///
	legend(label(1 "Standard outcomes") ///
	label(2 "Random outcomes")) ///
	title("Corr Pred diff. Unshrunk") ///
	xtitle("Correct Predictions Differences") ///
	ytitle(Frequency)
	graph export "`path'/Output/PAP/corrpreddiff_u_random_p`p'_c`cases_exp'_m`min_cases'_nsim`n_sim'_pull`datapull'.png", as(png) replace	
	
** Kdensity logloss differences
	qui twoway kdensity logloss_diff_s_flip    ///
	|| kdensity logloss_diff_s_flip_fout, ///
	legend(label(1 "Standard outcomes") ///
	label(2 "Flipped outcomes")) ///
	title("Log loss diff. Shrunk") ///
	xtitle("Log loss Differences") ///
	ytitle(Frequency)
	graph export "`path'/Output/PAP/loglossdiff_s_flip_p`p'_c`cases_exp'_m`min_cases'_nsim`n_sim'_pull`datapull'.png", as(png) replace
	
	qui twoway kdensity logloss_diff_s_random    ///
	|| kdensity logloss_diff_s_random_rout, ///
	legend(label(1 "Standard outcomes") ///
	label(2 "Random outcomes")) ///
	title("Log loss diff. Shrunk") ///
	xtitle("Log loss Differences") ///
	ytitle(Frequency)
	graph export "`path'/Output/PAP/loglossdiff_s_random_p`p'_c`cases_exp'_m`min_cases'_nsim`n_sim'_pull`datapull'.png", as(png) replace
	
	qui twoway kdensity logloss_diff_u_flip    ///
	|| kdensity logloss_diff_u_flip_fout, ///
	legend(label(1 "Standard outcomes") ///
	label(2 "Flipped outcomes")) ///
	title("Log loss diff. Unshrunk") ///
	xtitle("Log loss Differences") ///
	ytitle(Frequency)
	graph export "`path'/Output/PAP/loglossdiff_u_flip_p`p'_c`cases_exp'_m`min_cases'_nsim`n_sim'_pull`datapull'.png", as(png) replace
	
	qui twoway kdensity logloss_diff_u_random    ///
	|| kdensity logloss_diff_u_random_rout, ///
	legend(label(1 "Standard outcomes") ///
	label(2 "Random outcomes")) ///
	title("Log loss diff. Unshrunk") ///
	xtitle("Log loss Differences") ///
	ytitle(Frequency)
	graph export "`path'/Output/PAP/loglossdiff_u_random_p`p'_c`cases_exp'_m`min_cases'_nsim`n_sim'_pull`datapull'.png", as(png) replace		
	
	

	** Kdensity Correct predictions
	qui twoway kdensity pred_correct_s   || kdensity pred_correct_s_random || kdensity pred_correct_s_flip, ///
	xtitle("Percent correct predictions") legend(label(1 "Predictions") ///
	label(2 "Predictions random outcomes") ///
	label(3 "Predictions flipped outcomes")) ytitle(Frequency)
	graph export "`path'/Output/PAP/corrpred_s_p`p'_c`cases_exp'_m`min_cases'_nsim`n_sim'_pull`datapull'.png", as(png) replace
	qui twoway kdensity pred_correct_u   || kdensity pred_correct_u_random || kdensity pred_correct_u_flip, ///
	xtitle("Percent correct predictions") legend(label(1 "Predictions") ///
	label(2 "Predictions random outcomes") ///
	label(3 "Predictions flipped outcomes")) ytitle(Frequency)
	graph export "`path'/Output/PAP/corrpred_u_p`p'_c`cases_exp'_m`min_cases'_nsim`n_sim'_pull`datapull'.png", as(png) replace
	
	** Kdensity log loss
	qui twoway kdensity logloss_s   || kdensity logloss_s_random || kdensity logloss_s_flip, ///
	xtitle("Log loss") legend(label(1 "Baseline") ///
	label(2 "Random outcomes") ///
	label(3 "Flipped outcomes")) ytitle(Frequency)
	graph export "`path'/Output/PAP/logloss_s_p`p'_c`cases_exp'_m`min_cases'_nsim`n_sim'_pull`datapull'.png", as(png) replace
	qui twoway kdensity logloss_u   || kdensity logloss_u_random || kdensity logloss_u_flip, ///
	xtitle("Log loss") legend(label(1 "Baseline") ///
	label(2 "Random outcomes") ///
	label(3 "Flipped outcomes")) ytitle(Frequency)
	graph export "`path'/Output/PAP/logloss_u_p`p'_c`cases_exp'_m`min_cases'_nsim`n_sim'_pull`datapull'.png", as(png) replace

*/
	
/*
	* KS test
	preserve
	expand 2
	
	gen model = 1 if _n <= _N/2 // Baseline
	replace model = 2 if _n > _N/2 // Random
	
	gen brier_test = brier_s if model == 1
	replace brier_test = brier_s_random if model ==2
	
	gen pred_correct_test = pred_correct_s if model == 1
	replace pred_correct_test = pred_correct_s_random if model ==2
	
	ksmirnov brier_test, by(model)	
	
	ksmirnov pred_correct_test, by(model)
	restore
	
	count if brier_s < brier_s_random
	count if brier_s < brier_s_flip
	count if brier_u < brier_u_random
	count if brier_u < brier_u_flip
*/


** P-values
putexcel set "`path'/Output/PAP/brierdiff_pval.xls", replace 
putexcel A1 = "90th percentile of the random outcomes distribution:"
putexcel A2 = "In the standard outcomes distribution that value corresponds to the percentile:"

putexcel A4 = "90th percentile of the flipped outcomes distribution"
putexcel A5 = "In the standard outcomes distribution that value corresponds to the percentile:"

_pctile brier_diff_s_random_rout , p(90)
return list
putexcel B1 = (r(r1))
count if brier_diff_s_random < r(r1)
putexcel B2 = (r(N)/c(N))

*twoway kdensity brier_diff_s_flip || kdensity brier_diff_s_flip_fout
_pctile brier_diff_s_flip_fout, p(90)
return list
putexcel B4 = (r(r1))
count if brier_diff_s_flip < r(r1)
putexcel B5 = (r(N)/c(N))

save "C:\Users\didac\OneDrive\Escritorio\datasets\simul_p`p'_c`cases_exp'_m`min_cases'_nsim`n_sim'_pull`datapull'.dta", replace 