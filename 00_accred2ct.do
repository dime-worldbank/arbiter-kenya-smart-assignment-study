/*******************************************************************************
	CREATE CORRESPONDENCES OF ACCREDITATION TO CASETYPES:
	
	Create a dataset where each row is an accreditation, and there are several
	variables, one for each casetype. And in the variables it is indicated 
	whether that accreditation allows to work in that casetype. 
	
	The final dataset looks like: 
		accr | accr_name | ct# 
*******************************************************************************/

/*******************************************************************************
	LOAD ALL DATA AND MERGE 
*******************************************************************************/	

	*** SET UP
	version 17
	clear all
	local path "C:\Users\didac\Dropbox\Arbiter Research\Data analysis"
	local datapull = "20260709"  
	
	*** DATA 1: List of accreditations
	import delimited "`path'\Data_Raw\data_accreditationcategory_`datapull'.csv", ///
	clear delimiters(",")
	rename (id name) (accr accr_name) 
	* Add labels to each accr
	keep accr accr_name
	tempfile accr // tempsave it
	save `accr'
		
	*** DATA 2: List of casetypes
	import delimited "`path'\Data_Raw\data_casetype_`datapull'.csv", ///
	clear delimiters(",")	
	rename (id name) (ct ct_name)
	keep ct ct_name
	tempfile ct // tempsave it
	save `ct'	
	
	*** DATA 3: Correspondence accreditation to casetype
	import delimited  "`path'\Data_Raw\data_casetype_eligible_accreditation_categories_`datapull'.csv", clear
	rename (casetype_id accreditationcategory_id) (ct accr)
	keep ct accr
	
/*******************************************************************************
	MERGE ALL DATASETS
*******************************************************************************/

	*** Merge all 
	merge m:1 accr using `accr'
	drop _merge
	merge m:1 ct using `ct'
	drop _merge	
	
	* Local: Number of ct
	summ ct
	local ct_num = `r(max)'
	
	* Local: Create ct labels
	forvalues i=1(1)`ct_num'{
		levelsof ct_name if ct == `i', local(lbl`i')
	}	
	
/*******************************************************************************
	CREATE FINAL DATASET
*******************************************************************************/
	
	*** Create the final dataset (with no labels yet)
	* Create dummy variables for each ct	
	forvalues i=1(1)`ct_num' {
		gen ct_`i' = (ct == `i')
	}

	* Collapse to one row per accr
	collapse (max) ct_1-ct_`ct_num', by(accr accr_name)

	*** Add labels
	* Add labels to ct
	forvalues i=1(1)`ct_num'{
		label variable ct_`i' `lbl`i''
	}
	
	export delimited "`path'\Data_Clean\accred2ct_`datapull'.csv", replace
	
	* Add labels to accr
	levelsof accr, local(accrlist)
	foreach i of local accrlist {
		quietly levelsof accr_name if accr == `i', local(lbl)
		label define accr_lbl `i' `lbl', add
	}
	label values accr accr_lbl	
	
	
	save "`path'\Data_Clean\accred2ct_`datapull'.dta", replace
	
	
		