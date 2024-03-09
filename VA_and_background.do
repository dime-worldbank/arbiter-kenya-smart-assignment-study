version 17
clear all

*ssc install coefplot, replace
*ssc install outreg2

//Define locals 
local path "C:\Users\didac\Dropbox\Arbiter Research\Data analysis"
local datapull = "15062023" // "11062023" //"05102022" //  "27022023" 

/*******************************************************************************
	IMPORT AND PREPARE DATA
*******************************************************************************/

*** Shrunk VA
import delimited using "`path'\Output\va_groups_pull`datapull'.csv"
rename tv va_s
rename group_tv group_va_s
tempfile va_s_groups // tempfile for merge
save `va_s_groups'

*** Unhrunk VA
import delimited using "`path'\Output\va_u_groups_pull`datapull'.csv", clear
tempfile va_u_groups // tempfile for merge
save `va_u_groups'

*** Mediators main
import delimited using "`path'\Data_Raw\Vw_All_Mediators_31012024.csv", clear
gen age2 = age^2 // Age squared to be used in the regression
encode gender, gen(genderenc) // encode for regression
rename id mediator_id // rename for merge
tempfile med_main // tempfile for merge
save `med_main'

*** Mediators Professions simplified
import delimited using "`path'\Data_Raw\mediator_professions_amended_Anja.csv", clear
*encode profession_short, gen(profession_shortenc) // encode for regression
collapse (first) profession_short, by(professionid profession)
tempfile profession_matching
save `profession_matching'

*** Mediators Professions
import delimited using "`path'\Data_Raw\Vw_Mediators_Professions_31012023.csv", clear
	* Merge with info on professions simplified
	merge m:1 professionid using `profession_matching'
	drop _merge
rename mediatorid mediator_id // rename for merge
	* Drop duplicates of pressions per person
	duplicates drop mediator_id profession_short, force
		*duplicates tag mediator_id profession_short, generate(dup) // check
	encode profession_short, gen(profession_shortenc) 
	replace profession_shortenc = 0 if profession_shortenc ==.
	drop profession professionid createdat updatedat
	reshape wide profession_short, i(mediator_id) j(profession_shortenc)
	forvalues i=1(1)14{
		encode profession_short`i', gen(profession_short_`i') // encode for regression
		drop profession_short`i'
		replace profession_short_`i' = 0 if profession_short_`i' == .
	}

tempfile profession
save `profession'

*** Mediators Languages
import delimited using "`path'\Data_Raw\Vw_Mediators_Language_31012023.csv", clear
rename mediatorid mediator_id // rename for merge

egen numspeak = count(mediator_id), by(language) // Number of speakers
gen minlang = 1 if numspeak <100 // Minority language indicator
gen veryminlang = 1 if numspeak<20 // Very minority language indicator

encode language, gen(languageenc_) // encode for regression
replace languageenc_ = 43 if minlang == 1
replace languageenc_ = 44 if veryminlang == 1

drop language createdat updatedat numspeak minlang veryminlang languageid
duplicates drop mediator_id languageenc_, force

clonevar langenc_ = languageenc_
reshape wide langenc_, i(mediator_id) j(languageenc_)

foreach i in 10 11 12 14 18 31 39 43 44{
	replace langenc_`i' = 0 if langenc_`i' == .
}

tempfile language
save `language'

*** Mediators Religion
import delimited using "`path'\Data_Raw\Vw_Mediators_Religions_31012023.csv", clear
rename mediatorid mediator_id // rename for merge
tempfile religion // tempfile for merge
save `religion'

*** Merge all datasets except profession
merge 1:1 mediator_id using `med_main'
drop _merge
merge 1:1 mediator_id using `va_s_groups'
drop _merge
merge 1:1 mediator_id using `va_u_groups'
drop _merge
merge 1:1 mediator_id using `language'
drop _merge
merge 1:1 mediator_id using `profession'
drop _merge


*** Label variables
label var age2 "Age squared"

label var langenc_10 "Dholuo"
label var langenc_11 "Ekegusii"
label var langenc_12 "English"
label var langenc_14 "Gikuyu"
label var langenc_18 "Kamba"
label var langenc_31 "Oluluyia"
label var langenc_39 "Swahili"
label var langenc_43 "Minority language"
label var langenc_44 "Very minority language"

label var profession_short_1 "Administrative"
label var profession_short_2 "Business, Administration, Finance"
label var profession_short_3 "Clergy"
label var profession_short_4 "Counselling, Therapy, Coaching"
label var profession_short_5 "Education"
label var profession_short_6 "Engineering"
label var profession_short_7 "Farming, land management, resources management"
label var profession_short_8 "HR"
label var profession_short_9 "Humanities, Social Sciences, Research"
label var profession_short_10 "Legal, criminology"
label var profession_short_11 "Mediation related"
label var profession_short_12 "Medical, veterinary, nursing"
label var profession_short_13 "Penal system"
label var profession_short_14 "Training"

label define religionlab 1 "Christianity" 2 `"Islam"' 9 `"No religion"' 
label values religionid religionlab


* Keep only VA and background
keep mediator_id va_s va_u genderenc age age2 religionid langenc_* profession_short_* 
keep if va_s !=. | va_u !=.
drop langenc_12 // drop English

* Tempsave for later analysis
tempfile va_controls // tempfile for merge
save `va_controls'

/*******************************************************************************
	PRE-ANALYSIS: Return percentiles of VA distributions
*******************************************************************************/

* VA shrunk
 _pctile va_s, p(25, 75)
 return list
 * 25th-pctl = -.0188586842268705
 * 75th-pctl = .0144229400902987
 * Diff = 0.0332816243171692
 
* VA unshrunk
 _pctile va_u, p(25, 75)
 return list
 * 25th-pctl = -.1557433307170868
 * 75th-pctl = .1046634465456009
 * Diff = 0.260406777262686



/*******************************************************************************
	ANALYSIS: Regressions of VA on different covariates
*******************************************************************************/

*drop profession_short_6 // Drop Engineering. No one with VA studied Engineering

*** Shrunk

* Reg 1: Only gender
reg va_s i1.genderenc if va_s !=., vce(robust)
outreg2 using "`path'\Output\Background_VA_Reg.doc", replace label

* Reg 2: Gender + basic controls
reg va_s i1.genderenc age age2 i.religionid if va_s !=., vce(robust)
outreg2 using "`path'\Output\Background_VA_Reg.doc", append label

* Reg 3: Gender + basic controls + lang
reg va_s i1.genderenc age age2 i.religionid langenc_* if va_s !=., vce(robust)
outreg2 using "`path'\Output\Background_VA_Reg.doc", append label

* Reg 4: Gender + basic controls + prof
reg va_s i1.genderenc age age2 i.religionid profession_short_* if va_s !=., vce(robust)
outreg2 using "`path'\Output\Background_VA_Reg.doc", append label

* Reg 5: Gender + basic controls + lang + prof
reg va_s i1.genderenc age age2 i.religionid langenc_* profession_short_* if va_s !=., vce(robust)
coefplot, drop(_cons) title(VA and background variables) subtitle(Shrunk VA)
graph export "`path'/Output/Background_VA_coeffs_shrunk.png", as(png) replace
outreg2 using "`path'\Output\Background_VA_Reg.doc", append label


*** Unshrunk

* Reg 1: Only gender
reg va_u i1.genderenc if va_u !=., vce(robust)
outreg2 using "`path'\Output\Background_VA_Reg.doc", append label

* Reg 2: Gender + basic controls
reg va_u i1.genderenc age age2 i.religionid if va_u !=., vce(robust)
outreg2 using "`path'\Output\Background_VA_Reg.doc", append label

* Reg 3: Gender + basic controls + lang
reg va_u i1.genderenc age age2 i.religionid langenc_* if va_u !=., vce(robust)
outreg2 using "`path'\Output\Background_VA_Reg.doc", append label

* Reg 4: Gender + basic controls + prof
reg va_u i1.genderenc age age2 i.religionid profession_short_* if va_u !=., vce(robust)
outreg2 using "`path'\Output\Background_VA_Reg.doc", append label

* Reg 5: Gender + basic controls + lang + prof
reg va_u i1.genderenc age age2 i.religionid langenc_* profession_short_* if va_u !=., vce(robust)
coefplot, drop(_cons) title(VA and background variables) subtitle(Unshrunk VA)
graph export "`path'/Output/Background_VA_coeffs_unshrunk.png", as(png) replace
outreg2 using "`path'\Output\Background_VA_Reg.doc", append label


/*******************************************************************************
	ANALYSIS: Regressions of Numb of assigned cases on a 4 month period
	on VA and different covariates
*******************************************************************************/

* Use dataset with case data
use "`path'\Data_Clean\cases_cleaned_07022024", clear
merge m:1 mediator_id using `va_controls'

* Keep only dates after VA calc and start of Smart assignment
keep if med_appt_date > date("15Jun2023","DMY")
keep if med_appt_date < date("13Oct2023","DMY")

* Number of assigned cases during the 4 month period
egen numcases = count(med_appt_date), by(mediator_id)

* Collapse
collapse va_s va_u numcases genderenc age age2 religionid langenc_* profession_short_*, by(mediator_id)

*** VA Shrunk 
** Regressions
	reg numcases va_s, vce(robust)
	outreg2 using "`path'\Output\Background_VA_assign_Reg.doc", replace label
	reg numcases va_s i1.genderenc c.va_s#i1.genderenc, vce(robust)
	outreg2 using "`path'\Output\Background_VA_assign_Reg.doc", append label
	reg numcases va_s i1.genderenc c.va_s#i1.genderenc age age2 i.religionid langenc_*, vce(robust)
	outreg2 using "`path'\Output\Background_VA_assign_Reg.doc", append label
	reg numcases va_s i1.genderenc c.va_s#i1.genderenc age age2 i.religionid profession_short_*, vce(robust)
	outreg2 using "`path'\Output\Background_VA_assign_Reg.doc", append label
	reg numcases va_s i1.genderenc c.va_s#i1.genderenc age age2 i.religionid langenc_* profession_short_*, vce(robust)
	outreg2 using "`path'\Output\Background_VA_assign_Reg.doc", append label

** Plot va_s and number cases
	* lprobust
	lprobust numcases va_s, p(1) neval(30) genvars bwselect(mse-dpi) plot
	tw (scatter numcases va_s, msize(vsmall)) ///
	(line lprobust_gx_us lprobust_eval, ///
	msize(vtiny) sort xtitle("Shrunk VA") ytitle("Number of cases") ///
	legend(label(1 "Mediator") label(2 "Kernel regression") position(6) cols(2) ) )
	graph export "`path'/Output/Background_VA_assign_kern_shrunk.png", as(png) replace
	/*
	tw (scatter numcases va_s, msize(vsmall)) ///
	(line lprobust_gx_us lprobust_eval, msize(vtiny) sort  legend(off) ) ///
	(line lprobust_CI_l_rb lprobust_eval, lcolor(red) lpattern(dash)) ///
	(line lprobust_CI_r_rb lprobust_eval, lcolor(red) lpattern(dash) legend(off) )
	* npregress
	npregress kernel numcases va_s
	tw (scatter numcases va_s, msize(vsmall) ) (line _Mean_numcases va_s , sort)

	* lpoly
	lpoly numcases va_s, degree(1) n(150)  generate(numcases_estim va_s_grid) 
*/
	* Lfit 
	tw  (lfitci numcases va_s, msize(vtiny)  ) ///
	(scatter numcases va_s, msize(vsmall) color(midblue) ///
	xtitle("Shrunk VA") ytitle("Number of cases") ///
	legend(label(1 "Confidence interval") label(2 "Linear") ///
	label(3 "Mediator") position(6) cols(3) ) )
	graph export "`path'/Output/Background_VA_assign_lfit_shrunk.png", as(png) replace
	* Qfit
	tw  (qfitci numcases va_s, msize(vtiny)  ) ///
	(scatter numcases va_s, msize(vsmall) color(midblue) ///
	xtitle("Shrunk VA") ytitle("Number of cases") ///
	legend(label(1 "Confidence interval") label(2 "Quadratic fit") ///
	label(3 "Mediator") position(6) cols(3) ) )
	graph export "`path'/Output/Background_VA_assign_qfit_shrunk.png", as(png) replace
	
drop lprobust_*	

*** VA unshrunk	
** Regressions
	reg numcases va_u, vce(robust)
	outreg2 using "`path'\Output\Background_VA_assign_Reg.doc", append label
	reg numcases va_u i1.genderenc c.va_u#i1.genderenc, vce(robust)
	outreg2 using "`path'\Output\Background_VA_assign_Reg.doc", append label
	reg numcases va_u i1.genderenc c.va_u#i1.genderenc age age2 i.religionid langenc_*, vce(robust)
	outreg2 using "`path'\Output\Background_VA_assign_Reg.doc", append label
	reg numcases va_u i1.genderenc c.va_u#i1.genderenc age age2 i.religionid profession_short_* , vce(robust)
	outreg2 using "`path'\Output\Background_VA_assign_Reg.doc", append label
	reg numcases va_u i1.genderenc c.va_u#i1.genderenc age age2 i.religionid langenc_* profession_short_*, vce(robust)
	outreg2 using "`path'\Output\Background_VA_assign_Reg.doc", append label

** Plot va_u and number cases
	* lprobust
	lprobust numcases va_u, p(1) neval(30) genvars bwselect(mse-dpi) plot
	tw (scatter numcases va_u, msize(vsmall)) ///
	(line lprobust_gx_us lprobust_eval, ///
	msize(vtiny) sort xtitle("Unshrunk VA") ytitle("Number of cases") ///
	legend(label(1 "Mediator") label(2 "Kernel regression") position(6) cols(2) ) )
	graph export "`path'/Output/Background_VA_assign_kern_unshrunk.png", as(png) replace
	* Lfit 
	tw  (lfitci numcases va_u, msize(vtiny)  ) ///
	(scatter numcases va_u, msize(vsmall) color(midblue) ///
	xtitle("Unshrunk VA") ytitle("Number of cases") ///
	legend(label(1 "Confidence interval") label(2 "Linear") ///
	label(3 "Mediator") position(6) cols(3) ) )
	graph export "`path'/Output/Background_VA_assign_lfit_unshrunk.png", as(png) replace
	* Qfit
	tw  (qfitci numcases va_u, msize(vtiny)  ) ///
	(scatter numcases va_u, msize(vsmall) color(midblue) ///
	xtitle("Unshrunk VA") ytitle("Number of cases") ///
	legend(label(1 "Confidence interval") label(2 "Quadratic fit") ///
	label(3 "Mediator") position(6) cols(3) ) )
	graph export "`path'/Output/Background_VA_assign_qfit_unshrunk.png", as(png) replace


	
/*******************************************************************************
	ANALYSIS: Regressions of mean daily cases on a 4 month period
	on VA and different covariates
*******************************************************************************/

local datapull = "07022024" // "11062023" //"05102022" //  "27022023" 
local date_va = "15062023"
local first_data_date "15062023" // DMY "
local last_data_date "13102023" // DMY
local total_data_months = "3"

//Import data
use "`path'/Data_Clean/cases_cleaned_`datapull'.dta", clear

	// Add to each mediator info on VA and controls
	merge m:1 mediator_id using `va_controls'
	
	keep if va_s !=. | va_u !=.
	
	/* Number of mediators for whom we know their VA
	collapse va_s va_u, by(mediator_id) 
	count if va_u !=. // N= 270
	count if va_s !=. // N= 222*/
	
//Create some useful variables and drop some observations
	// Gen first_case_assn: First date a mediator was assigned a case
	bys mediator_id: egen first_case_assn = min(med_appt_date)
	format first_case_assn %td
	
	// Convert the dataset into a dataset where each observation is a case-day
	expand case_days_med // Create an observation for every day a case lasted. 
						 // So if a case lasted 10 days, there will be 10 
						 // (equal for the moment) observations.
	bys id: gen day = _n - 1 // "day" indicates the days that passed since the 
							// appointment for each observation. If a case 
							// lasted 10 days there will be 11 observations, and 
							// in each of them "day" will be different (from 0 to 10)
	

	// Create variables that contains the date of each observation
	gen num_days = med_appt_date + day
	format num_days %td
	gen num_month = month(num_days)
	format num_month %tm
	gen num_year = year(num_days)
	format num_year %ty
	gen num_month_year = ym(num_year,num_month)
	format num_month_year %tm 
	
	// Keep only cases from Jan 2022 to May 2023 
	keep if num_days >= date("`first_data_date'","DMY")
	drop if num_days >= date("`last_data_date'","DMY")
	
	/* Number of mediators who worked on a case during this period
	collapse va_s va_u, by(mediator_id) 
	count if va_u !=. // N= 181
	count if va_s !=. // N= 149
	*/
	
// Collapse at mediator-day level
collapse (count) id (mean) va_s va_u genderenc age age2 religionid langenc_* profession_short_*, by(mediator_id num_days)
rename id caseload_daily // daily caseload variable

// Create observations for the days in which the mediators had no case
tsset mediator_id num_days
tsfill, full
replace caseload_daily = 0 if caseload_daily == . // Assign 0 caseload
egen va_ss = mean(va_s), by(mediator_id) // Fill VA 
egen va_uu = mean(va_u), by(mediator_id) // Fill VA 
drop va_s va_u
rename (va_ss va_uu) (va_s va_u)


/*
	reg caseload_daily va_s if va_s !=., vce(robust)
	reg caseload_daily va_s i1.genderenc if va_s !=., vce(robust)
	reg caseload_daily va_s i1.genderenc age i.religionid langenc_* if va_s !=., vce(robust)
	reg caseload_daily va_s i1.genderenc age i.religionid profession_short_*  if va_s !=., vce(robust)
	reg caseload_daily va_s i1.genderenc age i.religionid langenc_* profession_short_*  if va_s !=., vce(robust)
	reg caseload_daily va_u if va_s !=., vce(robust)
	reg caseload_daily va_u i1.genderenc if va_s !=., vce(robust)
	reg caseload_daily va_u i1.genderenc age i.religionid langenc_* if va_s !=., vce(robust)
	reg caseload_daily va_u i1.genderenc age i.religionid profession_short_*  if va_s !=., vce(robust)
	reg caseload_daily va_u i1.genderenc age i.religionid langenc_* profession_short_*  if va_s !=., vce(robust)
*/
	
// Create mean caseload during this period
collapse (mean) caseload_daily va_s va_u genderenc age age2 religionid langenc_* profession_short_*, by(mediator_id)

// Regressions
	// Shrunk
	reg caseload_daily va_s if va_s !=., vce(robust)
	outreg2 using "`path'\Output\Background_VA_caseload_Reg.doc", replace label
	reg caseload_daily va_s i1.genderenc c.va_s#i1.genderenc if va_s !=., vce(robust)
	outreg2 using "`path'\Output\Background_VA_caseload_Reg.doc", append label
	reg caseload_daily va_s i1.genderenc c.va_s#i1.genderenc age age2 i.religionid langenc_* if va_s !=., vce(robust)
	outreg2 using "`path'\Output\Background_VA_caseload_Reg.doc", append label
	reg caseload_daily va_s i1.genderenc c.va_s#i1.genderenc age age2 i.religionid profession_short_*  if va_s !=., vce(robust)
	outreg2 using "`path'\Output\Background_VA_caseload_Reg.doc", append label
	reg caseload_daily va_s i1.genderenc c.va_s#i1.genderenc age age2 i.religionid langenc_* profession_short_*  if va_s !=., vce(robust)
	outreg2 using "`path'\Output\Background_VA_caseload_Reg.doc", append label
	// Unshrunk
	reg caseload_daily va_u, vce(robust)
	outreg2 using "`path'\Output\Background_VA_caseload_Reg.doc", append label
	reg caseload_daily va_u i1.genderenc c.va_u#i1.genderenc , vce(robust)
	outreg2 using "`path'\Output\Background_VA_caseload_Reg.doc", append label
	reg caseload_daily va_u i1.genderenc c.va_u#i1.genderenc age age2 i.religionid langenc_*, vce(robust)
	outreg2 using "`path'\Output\Background_VA_caseload_Reg.doc", append label
	reg caseload_daily va_u i1.genderenc c.va_u#i1.genderenc age age2 i.religionid profession_short_* , vce(robust)
	outreg2 using "`path'\Output\Background_VA_caseload_Reg.doc", append label
	reg caseload_daily va_u i1.genderenc c.va_u#i1.genderenc age age2 i.religionid langenc_* profession_short_*, vce(robust)
	outreg2 using "`path'\Output\Background_VA_caseload_Reg.doc", append label
	

/*******************************************************************************
	ANALYSIS: Case duration
*******************************************************************************/

local path "C:\Users\didac\Dropbox\Arbiter Research\Data analysis"
local datapull = "07022024" // "11062023" //"05102022" //  "27022023" 
local date_va = "15062023"
local first_data_date "15062023" // DMY "
local last_data_date "13102023" // DMY
local total_data_months = "3"

//Import data
use "`path'/Data_Clean/cases_cleaned_`datapull'.dta", clear

	// Add to each mediator info on VA and controls
	merge m:1 mediator_id using `va_controls'
	
	keep if case_days_med >= 0
	keep if va_s !=. | va_u !=.
	
	keep if med_appt_date >= date("`first_data_date'","DMY")
	drop if med_appt_date >= date("`last_data_date'","DMY")
	
	
collapse (mean)	case_days_med va_s va_u, by(mediator_id)


reg case_days_med va_s

reg case_days_med va_u

corr va_s va_u case_days_med

scatter case_days_med va_s
 
tw (scatter case_days_med va_s) (lfitci case_days_med va_s) 

tw (scatter case_days_med va_u) (lfitci case_days_med va_u) 


