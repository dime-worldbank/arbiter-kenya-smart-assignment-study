/*****************************************************************
Project: World Bank Kenya Arbiter
PIs: Anja Sautmann and Antoine Deeb
Purpose: Compare VA shrunk and unshrunk
******************************************************************/

*ssc install vam

//Defining locals 
local path "C:\Users\didac\Dropbox\Arbiter Research\Data analysis"
local datapull = "15062023" // "11062023" //"05102022" //  "27022023" 
local min_cases = 4 

// Import data
use "`path'\Data_Clean\cases_cleaned_`datapull'.dta", clear

// Keep only cases relevant for the VA calculations 
	//Case status, drop pending cases
	drop if case_status == "PENDING"

	//Keep only relevant cases 
	keep if usable == 1 // Keeping only relevant case types
	drop if issue == 6 | issue == 7 // Dropping pandemic months and newest cases (cutoff)

//Keep only courtstations with >=10 cases
	bys courtstation:gen stationcases = _N
	drop if stationcases<10

//Keep only mediators with at least K total cases
	bys mediator_id: gen totalcases=_N //Total cases with relevant case types 
	keep if totalcases >= `min_cases'

	egen med_year=group(mediator_id appt_year)
	
// Generate half-calendar-year indicator variable
	gen appt_firsthalf_year = 1 if appt_month <= 6 // First half year
	replace appt_firsthalf_year = 0 if appt_month >=7 // Second half year
	egen appt_halfyear = group(appt_firsthalf_year appt_year) // half-year indicator variable
	
	
/*****************************************************************
	 VALUE ADDED: Calculate Shrunk and unshrunk
******************************************************************/
	
// Shrunk VA
	vam case_outcome_agreement, teacher(mediator_id) year(appt_year) class(med_year) controls(i.appt_year i.casetype i.courttype i.courtstation i.referralmode) tfx_resid(mediator_id) data(merge tv) // Use calendary-years
	*vam case_outcome_agreement, teacher(mediator_id) year(appt_halfyear) class(med_year) controls(i.appt_year i.casetype i.courttype i.courtstation i.referralmode) tfx_resid(mediator_id) data(merge tv) // Use half-calendar-years
	bys mediator_id: egen va_shrunk=mean(tv)
	
	
// Drop mediators for which VA cannot be calculated because they only have one "appointment year" (or half-year) i.e. all cases they worked in were referred the same year (or half-year) --> Don't drop them for this exercise
	*drop if va_shrunk == . 

// Unshrunk VA
	areg case_outcome_agreement i.appt_year i.casetype i.courttype i.courtstation i.referralmode, absorb(mediator_id)
	*areg case_outcome_agreement i.appt_halfyear i.casetype i.courttype i.courtstation i.referralmode, absorb(mediator_id)
	predict residuals, dr
	bys mediator_id: egen va_unshrunk=mean(residuals)
	predict fit_unsh, xbd
	predict fit_unsh2, xb
	
/*****************************************************************
	 PLOTS
******************************************************************/
	
// Predicted agreement probabilities plots hist
	// Unshrunk
		qui hist fit_unsh, freq xtitle(Predicted Agreement Probability) ///
			note("Unshrunk estimator. Data pull: June 15, 2023.")
		graph export "`path'/Output/predict_agr_unsh_`datapull'.png", as(png) replace
	// Shrunk
		qui gen fit_shrunk = fit_unsh2 + va_shrunk
		hist fit_shrunk, freq xtitle(Predicted Agreement Probability) ///
			note("Shrunk estimator. Data pull: June 15, 2023.")
		graph export "`path'/Output/predict_agr_sh_`datapull'.png", as(png) replace

// Predicted agreement probabilities vs actual outcomes	
	* Approach 1: Quadratic fit
	// Shrunk
	twoway (qfitci case_outcome_agreement fit_shrunk) ///
	(line fit_unsh fit_unsh if fit_unsh>0 & fit_unsh<1, sort lcolor(red) legend(off) ///
	xscale(range(0 1)) yscale(range(0 1)) xla(0 (.2) 1) yla(0 (.2) 1) aspectratio(1) /// 
	title("Quadratic fit. Shrunk estimator", size(medium)) xtitle("Predicted outcome") ytitle("Actual outcome") note("The red line is a 45 degree line for reference. ") ) 
	graph export "`path'/Output/predict_actual_qfit_sh_`datapull'.png", as(png) replace
	
	// Unshrunk
	twoway (qfitci case_outcome_agreement fit_unsh if fit_unsh>0 & fit_unsh<1) ///
	(line fit_unsh fit_unsh if fit_unsh>0 & fit_unsh<1, sort lcolor(red) legend(off) ///
	xscale(range(0 1)) yscale(range(0 1)) xla(0 (.2) 1) yla(0 (.2) 1) aspectratio(1) /// 
	title("Quadratic fit. Unshrunk estimator", size(medium)) xtitle("Predicted outcome") ytitle("Actual outcome") note("The red line is a 45 degree line for reference.""Some predicted values are above or below 1," "but not shown here.") ) 
	graph export "`path'/Output/predict_actual_qfit_unsh_`datapull'.png", as(png) replace
	
	* Approach 2: Kernel regression
	// Shrunk
	preserve
	lprobust case_outcome_agreement fit_shrunk, p(1) neval(100) genvars bwselect(mse-dpi) plot 
	summ lprobust_h
	local bw = round(r(mean), .01)
	tw (line lprobust_gx_us lprobust_eval, sort lcolor(blue)) ///
	(line lprobust_CI_l_rb lprobust_eval, sort lcolor(blue) lpattern(dash) mcolor(%30)) ///
	(line lprobust_CI_r_rb lprobust_eval, sort lcolor(blue) lpattern(dash) mcolor(%30)) ///
	(line fit_unsh fit_unsh if fit_unsh>0 & fit_unsh<1, sort lcolor(red) legend(off) ///
	xscale(range(0 1)) yscale(range(0 1)) xla(0 (.2) 1) yla(0 (.2) 1) aspectratio(1) ///
	title("Kernel Reg. Shrunk estimator", size(medium)) xtitle("Predicted outcome") ytitle("Actual outcome") note("Kernel: Epanechnikov. Pointwise bandwidths.""The mean bandwidth is `bw'" "The red line is a 45 degree line") )
	graph export "`path'/Output/predict_actual_kreg_sh_`datapull'.png", as(png) replace
	restore
	// Unshrunk
	preserve
	lprobust case_outcome_agreement fit_unsh, p(1) neval(100) genvars bwselect(mse-dpi) plot 
	summ lprobust_h
	local bw = round(r(mean), .01)
	tw (line lprobust_gx_us lprobust_eval, sort lcolor(blue)) ///
	(line lprobust_CI_l_rb lprobust_eval, sort lcolor(blue) lpattern(dash) mcolor(%30)) ///
	(line lprobust_CI_r_rb lprobust_eval, sort lcolor(blue) lpattern(dash) mcolor(%30) ) ///
	(line fit_unsh fit_unsh if fit_unsh>0 & fit_unsh<1, sort lcolor(red) legend(off) ///
	xscale(range(0 1)) yscale(range(0 1)) xla(0 (.2) 1) yla(0 (.2) 1) aspectratio(1) ///
	title("Kernel Reg. Unshrunk estimator", size(medium)) xtitle("Predicted outcome") ytitle("Actual outcome") note("Kernel: Epanechnikov. Pointwise bandwidths.""The mean bandwidth is `bw'" "The red line is a 45 degree line") )
	graph export "`path'/Output/predict_actual_kreg_unsh_`datapull'.png", as(png) replace
	restore

	* Method 3: Percent of agreement 
/*
	// Generate 0-0.1, 0.1-0.2... bins of predicted probabilites
	* Unshrunk
	/*gen fit_unsh_bin = "0 to 10" if fit_unsh >= 0 & fit_unsh < 0.1
	forvalues i = 20(10)100{
		local lb = `i' - 10
		local ub = `i'
		replace fit_unsh_bin = "`lb' to `ub'" if fit_unsh >= `lb'*0.01 & fit_unsh < `ub'*0.01
	}	*/
	gen fit_unsh_bin = 1 if fit_unsh >= 0 & fit_unsh < 0.1
	forvalues i = 2(1)10{
		local lb = `i'*0.1 - 0.1
		local ub = `i'*0.1 
		replace fit_unsh_bin = `i' if fit_unsh >= `lb' & fit_unsh < `ub'
	}	
	replace fit_unsh_bin = fit_unsh_bin * 0.1 - 0.05
	
	
	* Shrunk
	gen fit_sh_bin = 1 if fit_shrunk >= 0 & fit_shrunk < 0.1
	
	forvalues i = 2(1)10{
		local lb = `i'*0.1 - 0.1
		local ub = `i'*0.1 
		replace fit_sh_bin = `i' if fit_shrunk >= `lb' & fit_shrunk < `ub'
	}	
	replace fit_sh_bin = fit_sh_bin * 0.1 - 0.05
	
	// Bin average previous agreement rate
	* Unshrunk
	egen avg_agr_predict_bin_unsh = mean(case_outcome_agreement), by(fit_unsh_bin)
	* Shrunk
	egen avg_agr_predict_bin_sh = mean(case_outcome_agreement), by(fit_sh_bin)

	// Plot
	* Unshrunk
	*twoway (scatter avg_agr_predict_bin_unsh fit_unsh_bin, sort yscale(r(0 1)) xlabel(#10) mla(ones) ylabel(#10) xtitle("Predicted agreement probability bin") ytitle("Average previous agreement rate") legend(off) aspectratio(1)) (line fit_unsh_bin fit_unsh_bin, sort)
	bysort fit_unsh_bin: gen show = _N
	twoway (bar avg_agr_predict_bin_unsh fit_unsh_bin, sort barwidth(.1) yscale(r(0 1)) ///
	xlabel(0.05 "0-0.1" .15 "0.1-0.2" .25 "0.2-0.3" .35 "0.3-0.4" .45 "0.4-0.5" ///
	.55 "0.5-0.6" .65 "0.6-0.7" .75 "0.7-0.8" .85 "0.8-0.9" .95 "0.9-1", angle(45)) /// 
	ylabel(#10) legend(off) aspectratio(1) title("Predicted vs actual outcomes", size(medium)) ///
	xtitle("Predicted agreement probability bin") ytitle("Average previous agreement rate") ///
	note("Unshrunk estimator. Data pull: 15 June 2023. All cases are classified in 10 bins of predicted"  /// 
	"agreement probability based on the results of the unshrunk estimator. The blue bars represent the" ///
	"previous agreement rates of cases in each bin. Black numbers represent the number of" ///
	"observations in each bin. And the red connected line is a 45 degree line. If the predicted " ///
	"probability is below 0 or above 1 then that case is not included in the graph.", size(tiny)) ) ///
	(connected fit_unsh_bin fit_unsh_bin, sort mla(show) mlabposition(12) mlabcolor(black)) 
	graph export "`path'/Output/predict_actual_unsh_`datapull'.png", as(png) replace
	
	* Shrunk
	*twoway (bar avg_agr_predict_bin_sh fit_sh_bin, sort barwidth(.1) yscale(r(0 1)) xlabel(#10) ylabel(#10) xtitle("Predicted agreement probability") ytitle("Average previous agreement rate") title("Predicted outcomes vs actual outcomes") note("Shrunk estimator. Data pull: 15 June 2023. Half-calendar-year control. If the predicted probability is below 0 or above 1," "then that case is not included in the graph.")) 
	drop show
	bysort fit_sh_bin: gen show = _N
	twoway (bar avg_agr_predict_bin_sh fit_sh_bin, sort barwidth(.1) yscale(r(0 1)) ///
	xlabel(0.05 "0-0.1" .15 "0.1-0.2" .25 "0.2-0.3" .35 "0.3-0.4" .45 "0.4-0.5" ///
	.55 "0.5-0.6" .65 "0.6-0.7" .75 "0.7-0.8" .85 "0.8-0.9" .95 "0.9-1", angle(45)) /// 
	ylabel(#10) legend(off) aspectratio(1) title("Predicted vs actual outcomes", size(medium)) ///
	xtitle("Predicted agreement probability bin") ytitle("Average previous agreement rate") ///
	note("Shrunk estimator. Data pull: 15 June 2023. All cases are classified in 10 bins of predicted"  /// 
	"agreement probability based on the results of the shrunk estimator. The blue bars represent the" ///
	"previous agreement rates of cases in each bin. Black numbers represent the number of" ///
	"observations in each bin. And the red connected line is a 45 degree line. If the predicted " ///
	"probability is below 0 or above 1 then that case is not included in the graph.", size(tiny)) ) ///
	(connected fit_sh_bin fit_sh_bin, sort mla(show) mlabposition(12) mlabcolor(black)) 
	graph export "`path'/Output/predict_actual_sh_`datapull'.png", as(png) replace
	drop show
*/


/*****************************************************************
	 UNSHRUNK VS SHRUNK GROUPS
******************************************************************/	
	
// Collapse. Each observation becomes a mediator
	collapse va_shrunk va_unshrunk, by(mediator_id)
	
// VA groups
	// Unshrunk
	egen median_va_unshrunk = pctile(va_unshrunk), p(50) // Get the median
	gen group_va_unshrunk = 1 if va_unshrunk > median_va_unshrunk
	replace group_va_unshrunk = 0 if group_va_unshrunk ==.
	// Shrunk
	egen median_va_shrunk = pctile(va_shrunk), p(50) // Get the median
	gen group_va_shrunk = 1 if va_shrunk > median_va_shrunk
	replace group_va_shrunk = 0 if group_va_shrunk ==.
	
	// Differences in the groups
	gen diff_group = group_va_shrunk - group_va_unshrunk
	tab diff_group 
	
*hist va_shrunk 
*hist va_unshrunk

	
	
	
	