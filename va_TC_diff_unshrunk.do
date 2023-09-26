/*****************************************************************
Project: World Bank Kenya Arbiter
PIs: Anja Sautmann and Antoine Deeb
Purpose: Compare VA shrunk and unshrunk
******************************************************************/

ssc install vam

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
	*vam case_outcome_agreement, teacher(mediator_id) year(appt_halfyear) class(med_year) controls(i.appt_year i.casetype i.courttype i.courtstation i.referralmode) tfx_resid(mediator_id) data(merge tv) // Use calendary-years
	vam case_outcome_agreement, teacher(mediator_id) year(appt_halfyear) class(med_year) controls(i.appt_year i.casetype i.courttype i.courtstation i.referralmode) tfx_resid(mediator_id) data(merge tv) // Use half-calendar-years
	bys mediator_id: egen va_shrunk=mean(tv)
	// Predicted agreement probabilites
		*matrix list e(b)
		*predict score, sc
		*predict fitted, xb
		*predict residuals //, dr

// Drop mediators for which VA cannot be calculated because they only have one "appointment year" (or half-year) i.e. all cases they worked in were referred the same year (or half-year) --> Don't drop them for this exercise
	*drop if va_shrunk == . 

// Unshrunk VA
	areg case_outcome_agreement i.appt_halfyear i.casetype i.courttype i.courtstation i.referralmode, absorb(mediator_id)
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
			note("Unshrunk estimator. Data pull: June 15, 2023. Half-calendar-year control.")
		graph export "`path'/Output/predict_agr_unsh_`datapull'.png", as(png) replace
	// Shrunk
		qui gen fit_shrunk = fit_unsh2 + va_shrunk
		hist fit_shrunk, freq xtitle(Predicted Agreement Probability) ///
			note("Shrunk estimator. Data pull: June 15, 2023. Half-calendar-year control.")
		graph export "`path'/Output/predict_agr_sh_`datapull'.png", as(png) replace

// Predicted agreement probabilities vs actual outcomes	
	// Generate 0-0.1, 0.1-0.2... bins of predicted probabilites
	* Unshrunk
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
	twoway (bar avg_agr_predict_bin_unsh fit_unsh_bin, sort barwidth(.1) yscale(r(0 1)) xlabel(#10) ylabel(#10) xtitle("Predicted agreement probability") ytitle("Average previous agreement rate") title("Predicted outcomes vs actual outcomes") note("Unshrunk estimator. Data pull: 15 June 2023. Half-calendar-year control. If the predicted probability is below 0 or above 1," "then that case is not included in the graph. ")) 
	graph export "`path'/Output/predict_actual_agr_unsh_`datapull'.png", as(png) replace
	* Shrunk
	twoway (bar avg_agr_predict_bin_sh fit_sh_bin, sort barwidth(.1) yscale(r(0 1)) xlabel(#10) ylabel(#10) xtitle("Predicted agreement probability") ytitle("Average previous agreement rate") title("Predicted outcomes vs actual outcomes") note("Shrunk estimator. Data pull: 15 June 2023. Half-calendar-year control. If the predicted probability is below 0 or above 1," "then that case is not included in the graph.")) 
	graph export "`path'/Output/predict_actual_sh_`datapull'.png", as(png) replace

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

	
	
	
	