/*****************************************************************
Project: World Bank Kenya Arbiter
PIs: Anja Sautmann and Antoine Deeb
Purpose: Power calculation
Author: Hamza Syed 
Updated by: Didac Marti Pinto
Instructions: To run this code change the locals at the beginning of 
the code
******************************************************************/

*ssc install gsample
*ssc install moremata

clear all
version 18
set more off

//Define locals
local path "C:\Users\didac\Dropbox\Arbiter Research\Data analysis"
local datapull "15062023"
local n_sim = 1000 // Number of simulations
local min_cases = 4 // Number of cases per mediator
local cases_exp = 300 //Number of cases for experimental sample
local p = 50 // 50 or 30
local np = 100-`p'

capture program drop exp_effect
program define exp_effect, rclass
*set seed 123
//Define locals 
local path "C:\Users\didac\Dropbox\Arbiter Research\Data analysis"
local datapull "15062023"
local n_sim = 1000 // Number of simulations
local min_cases = 4 // Number of cases per mediator
local cases_exp = 300 //Number of cases for experimental sample
local p = 50 // 50 or 30
local np = 100-`p'

//Import data
use "`path'/Data_Clean/cases_cleaned_15062023.dta", clear

//Case status, drop pending cases
tab case_status
drop if case_status == "PENDING"

//Keep only relevant cases
keep if usable == 1
drop if issue == 6 | issue == 7 //Dropping pandemic months 

//Keep only courtstations with >=10 cases
bys courtstation:gen stationcases = _N
drop if stationcases<10

//Keep only mediators with at least 5 total cases
bys mediator_id: gen totalcases=_N //Total cases with relevant case types 
sort id, stable // NEW NEW
tempfile raw
save `raw'
keep if totalcases >= `min_cases'

//Draw sample with replacement 
*bsample if totalcases >= `min_cases', strata(mediator_id)

tempfile sampled
save `sampled'

//Calculate value added
	* Shrunk estimator
	egen med_year=group(mediator_id appt_year)
	local state = c(rngstate)
	vam case_outcome_agreement, teacher(mediator_id) year(appt_year) driftlimit(3) class(med_year) controls(i.appt_month_year i.casetype i.courttype i.courtstation i.referralmode) tfx_resid(mediator_id) data(merge tv)
	rename tv va_s
	set rngstate `state'
	* Unshrunk estimator
	areg case_outcome_agreement i.appt_year i.casetype i.courttype i.courtstation i.referralmode, absorb(mediator_id)
	predict residuals, dr
	bys mediator_id: egen va_u=mean(residuals)

//Save the case level sample
tempfile sampled_va
save `sampled_va'

collapse va_s va_u, by(mediator_id)
drop if va_s == .

//Assign mediators to treatment and control group
_pctile va_s, p(`p' `np') //Change this for different values of p - the values are (p 100-p)
return list
scalar r1=r(r1)
scalar r2=r(r2)
gen treatment = 1 if va_s >= r2
replace treatment = 0 if va_s <= r1 
tab treatment,m
drop if missing(treatment)
tab treatment 
local tot_med = r(N) 
count if treatment == 1
local treated = r(N) 
count if treatment == 0 
local untreated = r(N) 
gen merge_id = _n 
tempfile mediators
save `mediators'

//Draw random sample of experimental cases 
use `raw', clear
rename mediator_id old_mediator_id
sample `cases_exp', count 
gen merge_id = int(runiform(1,`tot_med')) // Mediator id num that the case will be assigned to
sort merge_id id, stable 
tab merge_id
merge m:1 merge_id using `mediators'
drop if _merge !=3 
drop _merge
bys merge_id: gen cases_req = _N
bys merge_id: gen case_no = _n
tempfile assigned
save `assigned'

//Save a dataset which has the number of cases the mediator will be assigned in the experiment
keep mediator_id merge_id cases_req 
duplicates drop merge_id, force
tempfile sampling_req
save `sampling_req'

//Draw case outcome for treatment and control mediators
use `sampled_va', clear
merge m:1 mediator_id using `mediators'
keep if _merge == 3
drop _merge
merge m:1 merge_id using `sampling_req'
sort id, stable // NEW
drop _merge
gsample cases_req, strata(mediator_id)
sort mediator_id id, stable // NEW
*bsample cases_req, strata(mediator_id)
bys mediator_id: gen case_no = _n
keep mediator_id merge_id case_no case_outcome_agreement treatment appt_year

//Flip outcomes
gen case_outcome_agreement_flip = 0 if case_outcome_agreement == 1
replace case_outcome_agreement_flip = 1 if case_outcome_agreement == 0

//Merge experimental outcome to experimental cases
merge 1:m mediator_id merge_id case_no using `assigned'
keep if _merge == 3
bys mediator_id: egen avg_success = mean(case_outcome_agreement)
bys mediator_id: egen avg_success_flip = mean(case_outcome_agreement_flip)
gen experimental = 1
replace appt_year = 2023 if experimental == 1 

//Predict values
predict fit_u, xb
gen pred_s = fit_u + va_s
gen pred_s_round = round(pred_s)
	// Brier score
	gen brier_s = (pred_s - case_outcome_agreement)^2
	gen brier_s_flip = (pred_s - case_outcome_agreement_flip)^2
	// Correct prediction
	gen pred_correct_s = 0 
	replace pred_correct_s = 1 if pred_s_round == case_outcome_agreement
	gen pred_correct_s_flip = 0
	replace pred_correct_s_flip = 1 if pred_s_round == case_outcome_agreement_flip

//Output
	*calculate the treatment effect and whether it is significant or not
		* No flip
		reghdfe case_outcome_agreement treatment, noabsorb nocons
		return scalar b = el(r(table),1,1)
		return scalar p = el(r(table),4,1)
		* Flip 
		reghdfe case_outcome_agreement_flip treatment, noabsorb nocons
		return scalar b_flip = el(r(table),1,1)
		return scalar p_flip = el(r(table),4,1)
	*return brier scores
	summ brier_s
		return scalar brier_s = r(mean)
	summ brier_s_flip
		return scalar brier_s_flip = r(mean)
	*return percent correct predictions
	summ pred_correct_s
		return scalar pred_correct_s = r(mean)
	summ pred_correct_s_flip
		return scalar pred_correct_s_flip = r(mean)	

// Predicted vs actual outcome
/*
	* Quadratic fit - shrunk
	twoway (qfitci case_outcome_agreement pred_s) ///
	(line pred_s pred_s, sort lcolor(red) legend(off) ///
	title("Quadratic fit. Shrunk estimator", size(medium)) xtitle("Predicted outcome") ytitle("Actual outcome") note("The red line is a 45 degree line for reference. "))
	graph export "`path'/Output/simul_predict_actual_qfit_s_`datapull'.png", as(png) replace
	* Kernel reg - shrunk 
	lprobust case_outcome_agreement pred_s, p(1) neval(100) genvars bwselect(mse-dpi) plot 
	summ lprobust_h
	local bw = round(r(mean), .01)
	tw (line lprobust_gx_us lprobust_eval, sort lcolor(blue)) ///
	(line lprobust_CI_l_rb lprobust_eval, sort lcolor(blue) lpattern(dash) mcolor(%30)) ///
	(line lprobust_CI_r_rb lprobust_eval, sort lcolor(blue) lpattern(dash) mcolor(%30)) ///
	(line pred_s pred_s if pred_s>0 & pred_s<1, sort lcolor(red) legend(off) ///
	xscale(range(0 1)) yscale(range(0 1)) xla(0 (.2) 1) yla(0 (.2) 1) aspectratio(1) ///
	title("Kernel Reg. Shrunk estimator", size(medium)) xtitle("Predicted outcome") ytitle("Actual outcome") note("Kernel: Epanechnikov. Pointwise bandwidths.""The mean bandwidth is `bw'" "The red line is a 45 degree line") )
	graph export "`path'/Output/simul_predict_actual_kreg_s_`datapull'.png", as(png) replace
*/

	tempfile rts_cases
	save `rts_cases'

// Output
	*collapse at mediator level
	collapse avg_success avg_success_flip va_s va_u treatment, by(mediator_id)
	*return the avg success in experiment and probability of success for mediators
	summ avg_success 
		return scalar avg_success = r(mean)
	summ avg_success_flip 
		return scalar avg_success_flip = r(mean)
	*calculate the difference between avg success for treatment and control
	summ avg_success if treatment == 1
	scalar avg_upper = r(mean)
	summ avg_success if treatment == 0
	scalar avg_lower = r(mean)
		return scalar avg_success_diff = avg_upper - avg_lower
	summ avg_success_flip if treatment == 1
	scalar avg_upper_flip = r(mean)
	summ avg_success_flip if treatment == 0
	scalar avg_lower_flip = r(mean)
		return scalar avg_success_diff_flip = avg_upper - avg_lower
	*calculate the difference between value added of treatment and control mediators shrunk
	summ va_s if treatment == 1
	scalar va_s_upper = r(mean)
	summ va_s if treatment == 0
	scalar va_s_lower = r(mean)
		return scalar va_s_diff = va_s_upper - va_s_lower
	*calculate the difference between value added of treatment and control mediators unshrunk
	summ va_u if treatment == 1
	scalar va_upper_unsh = r(mean)
	summ va_u if treatment == 0
	scalar va_lower_unsh = r(mean)
		return scalar va_u_diff = va_upper_unsh - va_lower_unsh

// Re-estimate VA with simulated case outcomes
	* Merge simulated outcomes with non-simulated
	use `rts_cases', clear
	sort mediator_id id case_no
	rename va_s va_s_nosimul
	rename va_u va_u_nosimul
	append using `sampled' 
	replace case_outcome_agreement_flip = case_outcome_agreement if experimental != 1
	* Shrunk - No flip
	egen med_year=group(mediator_id appt_year)
	local state = c(rngstate)
	vam case_outcome_agreement, teacher(mediator_id) year(appt_year) driftlimit(3) class(med_year) controls(i.appt_month_year i.casetype i.courttype i.courtstation i.referralmode) tfx_resid(mediator_id) data(merge tv)
	set rngstate `state'
	rename tv va_s_all
	* Shrunk - Flip
	local state = c(rngstate)
	vam case_outcome_agreement_flip, teacher(mediator_id) year(appt_year) driftlimit(3) class(med_year) controls(i.appt_month_year i.casetype i.courttype i.courtstation i.referralmode) tfx_resid(mediator_id) data(merge tv)
	set rngstate `state'
	rename tv va_s_all_flip
	* Unshrunk - No flip
	areg case_outcome_agreement i.appt_year i.casetype i.courttype i.courtstation i.referralmode, absorb(mediator_id)
	predict residuals, dr
	bys mediator_id: egen va_u_all =mean(residuals)
	drop residuals
	* Unshrunk - Flip
	areg case_outcome_agreement_flip i.appt_year i.casetype i.courttype i.courtstation i.referralmode, absorb(mediator_id)
	predict residuals, dr
	bys mediator_id: egen va_u_all_flip =mean(residuals)
	
//Do not use for the results mediators which are not used in the simulations
	egen va_s_nonsimul_possible = sum(va_s_nosimul), by(mediator_id)
	drop if va_s_nonsimul_possible == 0 
	
//Collapse at the mediator level
	collapse va_s_all va_s_all_flip va_s_nosimul va_u_all va_u_all_flip va_u_nosimul, by(mediator_id)
	
//Output
	gen diff_va_s = va_s_nosimul - va_s_all
	summ diff_va_s	
		return scalar diff_va_s = r(mean)
	gen diff_va_s_flip = va_s_nosimul - va_s_all_flip
	summ diff_va_s_flip	
		return scalar diff_va_s_flip = r(mean)
	gen diff_va_s_sq = (va_s_nosimul - va_s_all)^2
	summ diff_va_s_sq	
		return scalar diff_va_s_sq = r(mean) 
	gen diff_va_s_sq_flip = (va_s_nosimul - va_s_all_flip)^2
	summ diff_va_s_sq_flip	
		return scalar diff_va_s_sq_flip = r(mean) 
	gen diff_va_u = va_u_nosimul - va_u_all
	summ diff_va_u	
		return scalar diff_va_u = r(mean)
	gen diff_va_u_flip = va_u_nosimul - va_u_all_flip
	summ diff_va_u_flip	
		return scalar diff_va_u_flip = r(mean)
	gen diff_va_u_sq = (va_u_nosimul - va_u_all)^2
	summ diff_va_u_sq	
		return scalar diff_va_u_sq = r(mean) 
	gen diff_va_u_sq_flip = (va_u_nosimul - va_u_all_flip)^2
	summ diff_va_u_sq_flip	
		return scalar diff_va_u_sq_flip = r(mean) 
/*
// VA distrib
twoway  (kdensity va_s_nosimul) (kdensity va_s_all) (kdensity va_s_all_flip)
graph export "`path'/Output/power_calcs/kdens_1sim_va_s_p`p'_c`cases_exp'_m`min_cases'_pull`datapull'.png", as(png) replace 
twoway  (kdensity va_u_nosimul) (kdensity va_u_all) (kdensity va_u_all_flip)
graph export "`path'/Output/power_calcs/kdens_1sim_va_u_p`p'_c`cases_exp'_m`min_cases'_pull`datapull'.png", as(png) replace

// Diff VA distrib
twoway (kdensity diff_va_s) (kdensity diff_va_s_flip)
graph export "`path'/Output/power_calcs/kdens_1sim_diffva_s_p`p'_c`cases_exp'_m`min_cases'_pull`datapull'.png", as(png) replace
twoway (kdensity diff_va_u) (kdensity diff_va_u_flip)
graph export "`path'/Output/power_calcs/kdens_1sim_diffva_u_p`p'_c`cases_exp'_m`min_cases'_pull`datapull'.png", as(png) replace

// Sq Diff VA distrib
twoway (kdensity diff_va_s_sq) (kdensity diff_va_s_sq_flip)
graph export "`path'/Output/power_calcs/kdens_1sim_diffvasq_s_p`p'_c`cases_exp'_m`min_cases'_pull`datapull'.png", as(png) replace
twoway (kdensity diff_va_u_sq) (kdensity diff_va_u_sq_flip)
graph export "`path'/Output/power_calcs/kdens_1sim_diffvasq_u_p`p'_c`cases_exp'_m`min_cases'_pull`datapull'.png", as(png) replace
*/
end

//Runn the program the first time and store the results in different matrices
exp_effect
matrix avg_success = r(avg_success)
matrix avg_success_flip = r(avg_success_flip)
matrix avg_success_diff = r(avg_success_diff)
matrix avg_success_diff_flip = r(avg_success_diff_flip)
matrix brier_s = r(brier_s)
matrix brier_s_flip = r(brier_s_flip)
matrix pred_correct_s = r(brier_s)
matrix pred_correct_s_flip = r(brier_s_flip)
matrix t_s = r(va_s_diff)
matrix t_u = r(va_u_diff)
matrix b = r(b)
matrix b_flip = r(b)
matrix p = r(p)
matrix p_flip = r(p)
matrix diff_va_s = r(diff_va_s)
matrix diff_va_s_flip = r(diff_va_s_flip)
matrix diff_va_s_sq = r(diff_va_s_sq)
matrix diff_va_s_sq_flip = r(diff_va_s_sq_flip)
matrix diff_va_u = r(diff_va_u)
matrix diff_va_u_flip = r(diff_va_u_flip)
matrix diff_va_u_sq = r(diff_va_u_sq)
matrix diff_va_u_sq_flip = r(diff_va_u_sq_flip)

//Display the matrices to check that they all have values in the first run
matlist avg_success
matlist avg_success_flip
matlist avg_success_diff
matlist avg_success_diff_flip
matlist brier_s
matlist brier_s_flip
matlist pred_correct_s
matlist pred_correct_s_flip
matlist b
matlist b_flip
matlist p
matlist p_flip
matlist t_s
matlist t_u
matlist diff_va_s
matlist diff_va_s_flip
matlist diff_va_s_sq
matlist diff_va_s_sq_flip
matlist diff_va_u
matlist diff_va_u_flip
matlist diff_va_u_sq
matlist diff_va_u_sq_flip

//Simulate
simulate avg_success = r(avg_success) avg_success_flip = r(avg_success_flip) avg_success_diff=r(avg_success_diff) avg_success_diff_flip=r(avg_success_diff_flip)  brier_s = r(brier_s) brier_s_flip = r(brier_s_flip) pred_correct_s = r(pred_correct_s) pred_correct_s_flip = r(pred_correct_s_flip) b = r(b) b_flip = r(b_flip) p = r(p) p_flip = r(p_flip) t_s=r(va_s_diff) t_u=r(va_u_diff) diff_va_s = r(diff_va_s)  diff_va_s_flip = r(diff_va_s_flip) diff_va_s_sq = r(diff_va_s_sq) diff_va_s_sq_flip = r(diff_va_s_sq_flip) diff_va_u = r(diff_va_u)  diff_va_u_flip = r(diff_va_u_flip) diff_va_u_sq = r(diff_va_u_sq) diff_va_u_sq_flip = r(diff_va_u_sq_flip), reps(`n_sim') seed(45415): exp_effect 
bstat, stat(avg_success, avg_success_flip, avg_success_diff, avg_success_diff_flip, brier_s, brier_s_flip, pred_correct_s, pred_correct_s_flip, p, p_flip, b, b_flip, t_s, t_u, diff_va_s, diff_va_s_flip, diff_va_s_sq, diff_va_s_sq_flip, diff_va_u, diff_va_u_flip, diff_va_u_sq, diff_va_u_sq_flip)

//Significance
gen sig = 1 if p<0.05
replace sig = 0 if p>=0.05 & p!=.
replace sig = -99 if missing(sig)
label define signif 1 "Significant" 0 "Not significant" -99 "No result"
label values sig signif
tab sig,m

//Display the results of the simulation
eststo rts_final: estpost summ avg_success avg_success_flip avg_success_diff avg_success_diff_flip p p_flip brier_s brier_s_flip pred_correct_s pred_correct_s_flip b b_flip t_s t_u diff_va_s diff_va_s_flip diff_va_s_sq diff_va_s_sq_flip diff_va_u diff_va_u_flip diff_va_u_sq diff_va_u_sq_flip sig
esttab rts_final using "`path'/Output/power_calcs/p`p'_c`cases_exp'_m`min_cases'_nsim`n_sim'_pull`datapull'.rtf", cells("count mean sd min max") replace

// Graphs
	** Kdensity of Diff_VA and Diff_VA_sq
	* Difference VA shrunk
	qui twoway kdensity diff_va_s || kdensity diff_va_s_flip, ///
	xtitle("VA difference")  legend(label(1 "Diff VA") label(2 "Diff VA flip")) 
	graph export "`path'/Output/power_calcs/kdens_diff_s_p`p'_c`cases_exp'_m`min_cases'_nsim`n_sim'_pull`datapull'.png", as(png) replace
	* Difference VA unshrunk
qui twoway kdensity diff_va_u || kdensity diff_va_u_flip, xtitle("VA difference")  legend(label(1 "Diff VA") label(2 "Diff VA flip"))
graph export "`path'/Output/power_calcs/kdens_diff_u_p`p'_c`cases_exp'_m`min_cases'_nsim`n_sim'_pull`datapull'.png", as(png) replace
	* Difference sq VA shrunk
	qui twoway kdensity diff_va_s_sq || kdensity diff_va_s_sq_flip, /// 
	xtitle("Squared VA difference") legend(label(1 "Diff VA Sq") label(2 "Diff VA Sq flip"))
	graph export "`path'/Output/power_calcs/kdens_sqdiff_s_p`p'_c`cases_exp'_m`min_cases'_nsim`n_sim'_pull`datapull'.png", as(png) replace 
	* Difference sq VA unshrunk
	qui twoway kdensity diff_va_u_sq || kdensity diff_va_u_sq_flip, ///
	xtitle("Squared VA difference") legend(label(1 "Diff VA Sq") label(2 "Diff VA Sq flip"))
	graph export "`path'/Output/power_calcs/kdens_sqdiff_u_p`p'_c`cases_exp'_m`min_cases'_nsim`n_sim'_pull`datapull'.png", as(png) replace 
	
	** Kdensity Brier score
	qui twoway kdensity brier_s || kdensity brier_s_flip, xtitle("Brier Score") legend(label(1 "Brier score") label(2 "Brier score flip")) ytitle(Frequency)
	graph export "`path'/Output/simul_brier_s_p`p'_c`cases_exp'_m`min_cases'_nsim`n_sim'_pull`datapull'.png.png", as(png) replace

	** Kdensity Correct predictions
	qui twoway kdensity pred_correct_s || kdensity pred_correct_s_flip, ///
	xtitle("Percent correct predictions") legend(label(1 "Predictions") ///
	label(2 "Predictions flipped outcomes")) ytitle(Frequency)
	graph export "`path'/Output/simul_corrpred_s_p`p'_c`cases_exp'_m`min_cases'_nsim`n_sim'_pull`datapull'.png", as(png) replace
