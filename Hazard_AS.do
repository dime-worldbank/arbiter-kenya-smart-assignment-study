

clear all

// Setting path
cd "C:/Users/wb474201/Dropbox/02_Research/Arbiter Research/Data analysis/Output/Hazard_analysis"
*cd "/Users/AnjaSautmann/Dropbox/02_Research/Arbiter Research/Data analysis/Output/Hazard_analysis"

use "../../Data_Clean/cases_cleaned_02062024.dta", clear


// *** selecting cases

// drop cases with various issues
drop if exclusion==1
// drop cases that are not concluded yet
keep if case_status=="CONCLUDED"
// drop cases that are too new or came in during Covid
drop if issue6==1 | issue7==1

//***  set dataset up for survival analysis
* define failure correctly
* note: fail =0 implies a case that did not end yet; we drop those. Below we estimate the survival model separately for fail ==1 (agreement) and fail ==2 (no agreement)
* drop cases that were terminated by the court due to a procedural error or other reasons.

drop if caseoutcome==4

gen fail = case_outcome_agreement
replace fail =2 if fail==0
stset case_days_med, id(id) failure(fail)



******************************************************************************
// Number of observation by case type
bysort casetype: gen obs=_N

 /*              Type of case (encoded) |      Freq.     Percent        Cum.
----------------------------------------+-----------------------------------
       Children Custody and Maintenance |      2,752       16.56       16.56
                          Civil Appeals |         85        0.51       17.07
                            Civil Cases |      2,325       13.99       31.06
                       Commercial Cases |        643        3.87       34.93
                         Criminal Cases |      1,524        9.17       44.10
                 Divorce and Separation |        152        0.91       45.01
Employment and Labour Relations Cases ( |      1,792       10.78       55.79
       Environment and Land Cases (ELC) |      2,382       14.33       70.13
                         Family Appeals |         32        0.19       70.32
                   Family Miscellaneous |         67        0.40       70.72
             Matrimonial Property Cases |        204        1.23       71.95
Succession (Probate & Administration -  |      4,662       28.05      100.00
*/



********************************************************************************


// create excel sheet with average duration, duration SD, and share of cases agreement/no agreement
preserve
	collapse (mean)  duration_mean=case_days_med (sd) duration_sd=case_days_med (count) N_f=case_days_med, by(case_type fail)
	bysort case_type: egen N = total(N_f)
	gen share=N_f/N
	drop N N_f
	sort case_outcome_agreement duration_mean
	export excel using "Casetypes_summary_by_agreement.xlsx", firstrow(variables) replace
restore
preserve
	collapse (mean) duration_mean=case_days_med (sd) duration_sd=case_days_med (mean) share=case_outcome_agreement, by(case_type )
	sort share
	export excel using "Casetypes_summary.xlsx", firstrow(variables) replace
restore

******************************************************************************
// Fitting a parametric hazard model and showing goodness of fit graphs

*sts graph if casetype==1 & fail==1, hazard  title(Children and custody) 

// set distribution function
local dist "loglogistic"


local graphlist ""	
foreach i in 1 4 5 7 8 11 13 14  {
	local v : label (casetype_simplified) `i'
	* survival regression when agreement was reached
	streg if casetype_simplified==`i' & fail==1, distribution(`dist')
		est sto GOF_case`i'_ag_`dist'
	* plotting residuals
	estat gofplot, title("`v', agreement", size(small)) xtitle("") ytitle("")
		graph save "GOF_case`i'_ag_`dist'", replace
	* survival regression when no agreement was reached 
	streg if casetype_simplified==`i' & fail==2, distribution(`dist')
	est sto GOF_case`i'_nag_`dist'
	* plotting residuals
	estat gofplot, title("`v', no agreement", size(small))  xtitle("") ytitle("")
		graph save "GOF_case`i'_nag_`dist'", replace
	local graphlist "`graphlist' GOF_case`i'_ag_`dist'.gph GOF_case`i'_nag_`dist'.gph"
	local estlist "`estlist' GOF_case`i'_ag_`dist' GOF_case`i'_nag_`dist'"
}
graph combine `graphlist', title("Assumed `dist' distribution function", size(medsmall)) caption("Goodness of fit: plot of Cox-Snell residuals against the cumulative hazard (Nelson-Aalen)", size(small)) ycommon xcommon
graph export "Casetypes_GOF_`dist'.pdf", as(pdf) replace

* exporting parameter estimates
etable, estimates(`estlist') export(Casetypes_parameters_`dist'.xlsx, replace) 


 
local dist "lognormal"
local graphlist ""
local estlist ""	
estimates clear
foreach i in 1 4 5 7 8 11 13 14  {
	local v : label (casetype_simplified) `i'
	streg if casetype_simplified==`i' & fail==1, distribution(`dist')
	est sto GOF_case`i'_ag_`dist'
	estat gofplot, title("`v', agreement", size(small)) xtitle("") ytitle("")
	graph save "GOF_case`i'_ag_`dist'", replace
	streg if casetype_simplified==`i'  & fail==2, distribution(`dist')
	est sto GOF_case`i'_nag_`dist'
	estat gofplot, title("`v', no agreement", size(small))  xtitle("") ytitle("")
	graph save "GOF_case`i'_nag_`dist'", replace
	local graphlist "`graphlist' GOF_case`i'_ag_`dist'.gph GOF_case`i'_nag_`dist'.gph"
	local estlist "`estlist' GOF_case`i'_ag_`dist' GOF_case`i'_nag_`dist'"
}
graph combine `graphlist', title("Assumed `dist' distribution function", size(medsmall)) caption("Goodness of fit: plot of Cox-Snell residuals against the cumulative hazard (Nelson-Aalen)", size(small)) ycommon xcommon
graph export "Casetypes_GOF_`dist'.pdf", as(pdf) replace
etable, estimates(`estlist') export(Casetypes_parameters_`dist'.xlsx, replace) 

 local dist "ggamma"
local graphlist ""
local estlist ""		
estimates clear
foreach i in 1 4 5 7 8 11 13 14  {
	local v : label (casetype_simplified) `i'
	streg if casetype_simplified==`i' & fail==1, distribution(`dist')
	est sto GOF_case`i'_ag_`dist'
	estat gofplot, title("`v', agreement", size(small)) xtitle("") ytitle("")
	graph save "GOF_case`i'_ag_`dist'", replace
	streg if casetype_simplified==`i' & fail==2, distribution(`dist')
	est sto GOF_case`i'_nag_`dist'
	estat gofplot, title("`v', no agreement", size(small))  xtitle("") ytitle("")
	graph save "GOF_case`i'_nag_`dist'", replace
	local graphlist "`graphlist' GOF_case`i'_ag_`dist'.gph GOF_case`i'_nag_`dist'.gph"
	local estlist "`estlist' GOF_case`i'_ag_`dist' GOF_case`i'_nag_`dist'"
}
graph combine `graphlist', title("Assumed `dist' distribution function", size(medsmall)) caption("Goodness of fit: plot of Cox-Snell residuals against the cumulative hazard (Nelson-Aalen)", size(small)) ycommon xcommon
graph export "Casetypes_GOF_`dist'.pdf", as(pdf) replace
etable, estimates(`estlist') export(Casetypes_parameters_`dist'.xlsx, replace) 

