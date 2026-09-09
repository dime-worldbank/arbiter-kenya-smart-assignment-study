

clear all

local path "C:\Users\didac\Dropbox\Arbiter Research\Data analysis"
local datapull = "20260219" 
use "`path'\Data_Clean\cases_cleaned_`datapull'.dta", clear

// Drop cases with data "issues" (same that are deleted in VA estimation)
	drop if issue1 == 1 // Missing mediator ID
	drop if issue2 == 2 // Appointment date missing but mediator appointed
	drop if issue3 == 3 // Conclusion date before mediator is assigned
	drop if issue4 == 4 // Pandemic cases

// Drop recent cases
	drop if date("`datapull'", "YMD") - med_appt_date < 180 // Drop recently appointed cases (< 180 days) 
	
//***  set dataset up for survival analysis
* define failure correctly
* note: fail =0 implies a case that did not end yet; we drop those. Below we estimate the survival model separately for fail ==1 (agreement) and fail ==2 (no agreement)
* drop cases that were terminated by the court due to a procedural error or other reasons.

drop if caseoutcome==4
gen fail = case_outcome_agreement
replace fail =2 if fail==0
stset case_days_med, id(id) failure(fail)

// Number of casetypes
quietly summarize casetype_simplified
local ctmax = r(max)


*sts graph if casetype==1 & fail==1, hazard  title(Children and custody) 

// set distribution function
// Loglogistic
local dist "loglogistic"
local estlist ""

tempfile lookup
tempname posth
postfile `posth' str20 model str244 casetype byte fail str20 outcome using `lookup', replace

forvalues i = 1/`ctmax'{
    local v : label (casetype_simplified) `i'

    * safe, short model names (always valid)
    local m_ag  = "ct`=string(`i',"%02.0f")'_ag"
    local m_nag = "ct`=string(`i',"%02.0f")'_nag"

	* Agreement
	capture streg if casetype_simplified==`i' & fail==1, distribution(`dist')
	if !_rc {
		estimates store `m_ag'
		local estlist "`estlist' `m_ag'"
		post `posth' ("`m_ag'") ("`v'") (1) ("agreement")
	}
	else di as error "Skipped ct`i' (`v'), agreement — streg rc=`=_rc''"

	* No agreement
	capture streg if casetype_simplified==`i' & fail==2, distribution(`dist')
	if !_rc {
		estimates store `m_nag'
		local estlist "`estlist' `m_nag'"
		post `posth' ("`m_nag'") ("`v'") (2) ("no agreement")
	}
	else di as error "Skipped ct`i' (`v'), no agreement — streg rc=`=_rc''"
}

postclose `posth'
local outfile "`path'\Output\Hazard\Casetypes_parameters_`dist'_`datapull'.xlsx"

* Main table (columns are ct01_ag, ct01_nag, ...)
etable, estimates(`estlist') column(estimates) ///
    export("`path'\Output\Hazard\Casetypes_parameters_`dist'_`datapull'.xlsx", replace)

* Lookup sheet
preserve
    use `lookup', clear
    order model casetype outcome fail
    export excel using "`outfile'", sheet("lookup") firstrow(variables) sheetreplace
restore


// Log normal
local dist "lognormal"
tempfile lookup
tempname posth
postfile `posth' str20 model str244 casetype byte fail str20 outcome using `lookup', replace

forvalues i = 1/`ctmax'{
    local v : label (casetype_simplified) `i'

    * safe, short model names (always valid)
    local m_ag  = "ct`=string(`i',"%02.0f")'_ag"
    local m_nag = "ct`=string(`i',"%02.0f")'_nag"

	* Agreement
	capture streg if casetype_simplified==`i' & fail==1, distribution(`dist')
	if !_rc {
		estimates store `m_ag'
		local estlist "`estlist' `m_ag'"
		post `posth' ("`m_ag'") ("`v'") (1) ("agreement")
	}
	else di as error "Skipped ct`i' (`v'), agreement — streg rc=`=_rc''"

	* No agreement
	capture streg if casetype_simplified==`i' & fail==2, distribution(`dist')
	if !_rc {
		estimates store `m_nag'
		local estlist "`estlist' `m_nag'"
		post `posth' ("`m_nag'") ("`v'") (2) ("no agreement")
	}
	else di as error "Skipped ct`i' (`v'), no agreement — streg rc=`=_rc''"
}

postclose `posth'
local outfile "`path'\Output\Hazard\Casetypes_parameters_`dist'_`datapull'.xlsx"

* Main table (columns are ct01_ag, ct01_nag, ...)
etable, estimates(`estlist') column(estimates) ///
    export("`path'\Output\Hazard\Casetypes_parameters_`dist'_`datapull'.xlsx", replace)

* Lookup sheet
preserve
    use `lookup', clear
    order model casetype outcome fail
    export excel using "`outfile'", sheet("lookup") firstrow(variables) sheetreplace
restore


