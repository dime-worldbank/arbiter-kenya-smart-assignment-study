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
	gen treatment_u = 1 if va_u > 0
	replace treatment_u = 0 if va_u <= 0 
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
	collapse cases_req va_s va_u treatment treatment_u, by(mediator_id)

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

// Output
	** Treatment effect and whether it is significant or not
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
		
	* Average mediator sucess
	bys mediator_id: egen avg_success = mean(case_outcome_agreement)

// Collapse at mediator level
	collapse avg_success va_s va_u /// 
	treatment, by(mediator_id)	

// Output at mediator level
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

//Display the matrices to check that they all have values in the first run
matlist avg_success
matlist avg_success_diff
matlist b
matlist b_se
matlist p
matlist t_s
matlist t_u
matlist b_c 
matlist b_se_c
matlist p_c 

simulate avg_success = r(avg_success) avg_success_diff = r(avg_success_diff) b = r(b) b_se = r(b_se) p = r(p) b_c = r(b_c) b_se_c = r(b_se_c) p_c = r(p_c) t_s = r(va_s_diff) t_u = r(va_u_diff), ///
 reps(`n_sim') seed(45415): exp_effect 

bstat, stat(avg_success, avg_success_diff, b, b_se, p, b_c, b_se_c, p_c, t_s, t_u) 
 
//Significance
gen sig = 1 if p<0.05
gen sig_c = 1 if p_c<0.05
replace sig = 0 if p>=0.05 & p!=.
replace sig_c = 0 if p_c>=0.05 & p_c!=.
label define signif 1 "Significant" 0 "Not significant" -99 "No result"
label values sig signif
label values sig_c signif
tab sig sig_c,m

//Display the results of the simulation
eststo rts_final: estpost summ avg_success avg_success_diff b b_se p b_c b_se_c p_c t_s t_u sig sig_c
esttab rts_final using "`path'/Output/PAP/pc_step`step1'_c`cases_exp'_m`min_cases'_nsim`n_sim'_pull`datapull'.rtf", cells("count mean sd min max") replace

//save 	
save "`path'/Data_Clean/PAP/pc_step`step1'_p`p'_c`cases_exp'_m`min_cases'_nsim`n_sim'_pull`datapull'.dta", replace 
