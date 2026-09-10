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
	local step1 = 2 // 1 if step 1 is used. 2 otherwise
	
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
	local step1 = 2 // 1 if step 1 is used. 2 otherwise
	
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
	if `step1' == 1 {
		bsample if totalcases >= `min_cases', strata(mediator_id)
	}
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

// Assign mediators to treatment and control group
	collapse va_s va_u mediator_d, by(mediator_id)
	drop if va_s == .
	gen treatment = 1 if va_s > 0
	replace treatment = 0 if va_s <= 0
	drop if missing(treatment)
	tab treatment 
	local tot_med = r(N) 
	gen merge_id = _n 
	tempfile mediators
	save `mediators'
	
// Select mediators of the experiment
	expand 3 
	* Randomly assign the N cases to T and C with equal prob
		preserve
		generate n_C = round(runiform(0,1))
		keep if _n<=`cases_exp'
		summ n_C, d
		scalar nC = r(sum) // relevant scalar indicating the mediators in C
		di nC 
	restore
	* Select the mediators from C
	preserve
		bsample nC if treatment == 0
		tempfile C_mediators
		save `C_mediators'
	restore
	* Select the mediators from T
	bsample `cases_exp' - nC if treatment == 1
	append using `C_mediators'
	
// Create cases_req which indicates the number of cases that mediator will get.
// Collapse so that each observation is a mediator.
	bys merge_id: gen cases_req = _N
	bys merge_id: gen case_no = _n
	collapse cases_req va_s va_u treatment mediator_d, by(mediator_id)

// Merge mediators with all the cases
	merge 1:m mediator_id using `raw'
	sort id, stable 
	keep if _merge == 3
	drop _merge

// Sample cases from past mediator outcomes. The number of cases is given by 
// cases_req
	expand 3
	bsample cases_req, strata(mediator_id)
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

	** Treatment effect and whether it is significant or not
	** Shrunk outcomes
	* Controls
	reghdfe case_outcome_agreement treatment i.appt_month_year i.casetype ///
	i.courttype i.courtstation i.referralmode, noabsorb nocons
		return scalar b_c = el(r(table),1,1)
		return scalar b_se_c = el(r(table),2,1)
		return scalar p_c = el(r(table),4,1)
	* No controls
	reghdfe case_outcome_agreement treatment, noabsorb nocons
		return scalar b = el(r(table),1,1)
		return scalar b_se = el(r(table),2,1)
		return scalar p = el(r(table),4,1)
	** Unshrunk outcomes
	* Controls
	reghdfe case_outcome_agreement_u treatment i.appt_month_year i.casetype ///
	i.courttype i.courtstation i.referralmode, noabsorb nocons
		return scalar b_u_c = el(r(table),1,1)
		return scalar b_se_u_c = el(r(table),2,1)
		return scalar p_u_c = el(r(table),4,1)
	* No controls
	reghdfe case_outcome_agreement_u treatment, noabsorb nocons
		return scalar b_u = el(r(table),1,1)
		return scalar b_se_u = el(r(table),2,1)
		return scalar p_u = el(r(table),4,1)
	
	** Average mediator sucess
	bys mediator_id: egen avg_success = mean(case_outcome_agreement)

// Collapse at mediator level
	collapse avg_success va_s va_u treatment, by(mediator_id)	

// Outputs at mediator level
	* Return the avg mediator success in experiment
	summ avg_success 
		return scalar avg_success = r(mean)
	** Return the difference between avg success for treatment and control
	* Baseline
	summ avg_success if treatment == 1
	scalar avg_upper = r(mean)
	summ avg_success if treatment == 0
	scalar avg_lower = r(mean)
		return scalar avg_success_diff = avg_upper - avg_lower
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

end

//Runn the program the first time and store the results in different matrices
exp_effect
matrix brier_s = r(brier_s)
matrix brier_s_flip = r(brier_s_flip)
matrix brier_s_random = r(brier_s_random)
matrix brier_u = r(brier_u)
matrix brier_u_flip = r(brier_u_flip)
matrix brier_u_random = r(brier_u_random)
matrix brier_diff_s_random  = r(brier_diff_s_random )
matrix brier_diff_s_flip = r(brier_diff_s_flip)
matrix brier_diff_s_random_rout  = r(brier_diff_s_random_rout)
matrix brier_diff_s_flip_fout  = r(brier_diff_s_flip_fout )
matrix brier_diff_u_random  = r(brier_diff_u_random )
matrix brier_diff_u_flip = r(brier_diff_u_flip)
matrix brier_diff_u_random_rout  = r(brier_diff_u_random_rout)
matrix brier_diff_u_flip_fout  = r(brier_diff_u_flip_fout )
matrix avg_success = r(avg_success)
matrix avg_success_diff = r(avg_success_diff)
matrix t_s = r(va_s_diff)
matrix t_u = r(va_u_diff)
matrix b = r(b)
matrix b_se = r(b_se)
matrix p = r(p)
matrix b_c = r(b_c)
matrix b_se_c = r(b_se_c)
matrix p_c = r(p_c)
matrix b_u = r(b_u)
matrix b_se_u = r(b_se_u)
matrix p_u = r(p_u)
matrix b_u_c = r(b_u_c)
matrix b_se_u_c = r(b_se_u_c)
matrix p_u_c = r(p_u_c)

//Display the matrices to check that they all have values in the first run
matlist brier_s
matlist brier_s_flip 
matlist brier_s_random
matlist brier_u 
matlist brier_u_flip 
matlist brier_u_random 
matlist brier_diff_s_random 
matlist brier_diff_s_flip 
matlist brier_diff_s_random_rout 
matlist brier_diff_s_flip_fout 
matlist brier_diff_u_random 
matlist brier_diff_u_flip 
matlist brier_diff_u_random_rout 
matlist brier_diff_u_flip_fout
matlist avg_success 
matlist avg_success_diff 
matlist t_s 
matlist t_u 
matlist b 
matlist b_se 
matlist p
matlist b_c 
matlist b_se_c 
matlist p_c
matlist b_u
matlist b_se_u
matlist p_u
matlist b_u_c 
matlist b_se_u_c 
matlist p_u_c

//Simulate
simulate avg_success = r(avg_success) avg_success_diff = r(avg_success_diff) b = r(b) b_se = r(b_se) p = r(p) b_c = r(b_c) b_se_c = r(b_se_c) p_c = r(p_c) b_u = r(b_u) b_se_u = r(b_se_u) p_u = r(p_u) b_u_c = r(b_u_c) b_se_u_c = r(b_se_u_c) p_u_c = r(p_u_c) t_s = r(va_s_diff) t_u = r(va_u_diff) brier_s = r(brier_s) brier_s_flip = r(brier_s_flip) brier_s_random = r(brier_s_random) brier_u = r(brier_u) brier_u_flip = r(brier_u_flip) brier_u_random = r(brier_u_random) brier_diff_s_random  = r(brier_diff_s_random ) brier_diff_s_flip = r(brier_diff_s_flip) brier_diff_s_random_rout  = r(brier_diff_s_random_rout) brier_diff_s_flip_fout  = r(brier_diff_s_flip_fout ) brier_diff_u_random  = r(brier_diff_u_random ) brier_diff_u_flip = r(brier_diff_u_flip) brier_diff_u_random_rout  = r(brier_diff_u_random_rout) brier_diff_u_flip_fout  = r(brier_diff_u_flip_fout ), ///
 reps(`n_sim') seed(45415): exp_effect 
 
bstat, stat(brier_s, brier_s_flip, brier_s_random, brier_u, brier_u_flip, brier_u_random, brier_diff_s_random, brier_diff_s_flip, brier_diff_s_random_rout, brier_diff_s_flip_fout, brier_diff_u_random, brier_diff_u_flip, brier_diff_u_random_rout, brier_diff_u_flip_fout, avg_success, avg_success_diff, t_s, t_u, b, b_se, p, b_c, b_se_c, p_c, b_u, b_se_u, p_u, b_u_c, b_se_u_c, p_u_c)
 
//Significance
gen sig = 1 if p<0.05
gen sig_c = 1 if p_c<0.05
gen sig_u = 1 if p_u<0.05
gen sig_u_c = 1 if p_u_c<0.05
replace sig = 0 if p>=0.05 & p!=.
replace sig_c = 0 if p_c>=0.05 & p_c!=.
replace sig_u = 0 if p_u>=0.05 & p!=.
replace sig_u_c = 0 if p_u_c>=0.05 & p_c!=.
label define signif 1 "Significant" 0 "Not significant" -99 "No result"
label values sig signif
label values sig_c signif
label values sig_u signif
label values sig_u_c signif
tab sig,m
tab sig_c,m
tab sig_u,m
tab sig_u_c,m

//Display the results of the simulation
eststo rts_final: estpost summ  brier_s brier_s_flip  brier_s_random brier_u brier_u_flip brier_u_random brier_diff_s_random brier_diff_s_flip brier_diff_s_random_rout brier_diff_s_flip_fout  brier_diff_u_random brier_diff_u_flip brier_diff_u_random_rout brier_diff_u_flip_fout avg_success avg_success_diff t_s t_u b b_se p b_c b_se_c p_c b_u b_se_u p_u b_u_c b_se_u_c p_u_c sig sig_c sig_u sig_u_c
esttab rts_final using "`path'/Output/PAP/simul_step`step1'_c`cases_exp'_m`min_cases'_nsim`n_sim'_pull`datapull'.rtf", cells("count mean sd min max") replace

if `step1' == 2 {
	
// Graphs
	** Kdensity Brier score
	qui twoway kdensity brier_s || kdensity brier_s_random ///
	 || kdensity brier_s_flip, xtitle("Brier Score") ///
	legend(label(1 "Standard VA model") label(2 "Random VA model") ///
	 label(3 "Flipped VA model") position(6) cols(3)) ///
	ytitle(Frequency)
	graph export "`path'/Output/PAP/brier_s.png", as(png) replace
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
}

save "`path'/Data_Clean/PAP/simul_step`step1'_p`p'_c`cases_exp'_m`min_cases'_nsim`n_sim'_pull`datapull'.dta", replace 