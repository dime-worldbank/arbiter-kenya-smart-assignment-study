/*******************************************************************************
	SET UP
*******************************************************************************/

	version 17
	clear all
	set maxvar 120000
	set maxvar 120000, permanently

	*** Define locals 
	local path "C:\Users\didac\Dropbox\Arbiter Research\Data analysis"
	local datapull =  "20260513" 

	*** Create Courtstation list local
	import delimited "`path'\Data_Raw\Court_Station_County_loc_`datapull'.csv", clear
	levelsof courtstation, local(cs_list)

	*** Use accr2ct data to extract locals
	use "`path'\Data_Clean\accred2ct_`datapull'.dta", clear
	
		* Local: Toal case type num
		ds ct_*, not
		ds ct_*
		local ct_num: word count `r(varlist)'
		
		* Local: case type names	
		forvalue i=1(1)`ct_num' {
			local varname = "ct_`i'"
			local ct_`i'_label : variable label `varname'
			di "`ct_`i'_label'"
		}
	
	*import delimited "`path'\Data_Raw\cluster_2_arm_map_8_clusters_`datapull'.csv", clear	
	*import delimited "`path'\Data_Raw\cluster_2_arm_map_20_clusters_`datapull'.csv", clear	
	*import delimited "`path'\Data_Raw\cluster_2_arm_map_30_clusters_`datapull'.csv", clear
	import delimited "`path'\Data_Raw\cluster_2_arm_map_40_clusters_`datapull'.csv", clear
	tempfile clusters2arm
	save `clusters2arm'
	
	
	*import delimited "`path'\Output\Clusters\2clusters_louv_res1p1_`datapull'.csv", clear
	*import delimited "`path'\Output\Clusters\2clusters_louv_res3p5_`datapull'.csv", clear
	*import delimited "`path'\Output\Clusters\2clusters_louv_res4p6_`datapull'.csv", clear
	import delimited "`path'\Output\Clusters\2clusters_louv_res5p9_`datapull'.csv", clear

	tempfile clusters
	save `clusters'		

/*******************************************************************************
	CREATE LIST cs_ct vs cs1_ct1:
	- All possible combinations of cs_ct with other cs1_ct1 in one dataset
******************************************************************************/
/*
foreach cs of local cs_list {
    forvalues ct = 1/`ct_num' {
        gen `cs'_`ct' = .
    }
}

xpose, varname clear
keep _varname
rename _varname cs_ct

tempfile list_cs_ct
save `list_cs_ct'

rename cs_ct cs_ct1

cross using `list_cs_ct'

save "`path'\Data_Clean\csct_csct1_`datapull'.dta", replace
*/
/*******************************************************************************
	CREATE LIST cs_ct vs cs1_ct1:
	- All possible combinations of cs_ct with other cs1_ct1 in one dataset
*******************************************************************************/

	***  Import cases data
	import delimited "`path'\Data_Raw\vw_deidentified_case_w_appointer_`datapull'.csv", clear
	
	* Create mediator appointment date
	gen med_appt_date = date(mediator_appointment_date, "YMD")
	format med_appt_date %td
	
	* Create Casetype (encoding has to match original)
	gen casetype = 0
		forvalue i=1(1)`ct_num' {
		replace casetype = `i' if case_type == "`ct_`i'_label'"
	}
	
	keep if med_appt_date > date("13May2024", "DMY")
	egen medcases = count(mediator_id), by(mediator_id)
	*keep if medcases >2
	

	*drop if session_type == "Virtual"
	
	* 
		replace court_station = "MUKURWEINI" if court_station == "MUKURWE-INI"
		replace court_station = "MURANGA" if court_station == "MURANG'A"
		replace court_station = "WANGURU" if court_station == "WANG'URU"
		replace court_station = "OLKALOU" if court_station == "OL KALOU"
		replace court_station = "ELDAMARAVINE" if court_station == "ELDAMA RAVINE"
		replace court_station = "MTITOANDEI" if court_station == "MTITO ANDEI"
		replace court_station = "KANGUNDO" if court_station == "KANGUNDO DO NOT USE"
		replace court_station = "PORTVICTORIA" if court_station == "PORT VICTORIA"
		replace court_station = "WANGURU" if court_station == "WANG'URU"
		replace court_station = "MARARAL" if court_station == "MARALAL"
		
	/* To be fixed - cs that do not appear in the cs list
		drop if court_station == "KAMWANGI" | court_station == "MALABA" | court_station == "NYANDARUA" | court_station =="WAMUNYU"*/
			
	* Drop missing mediator_id (cases that have no mediator assigned)
	drop if mediator_id == . 

	* Keep only the relevant variables
	keep id mediator_id court_station casetype 
	
	* Create variable with case cs_ct using info from other variables
	egen cs_ct = concat(court_station casetype), punct("_")
	
	* merge with clusters
	merge m:1 cs_ct using `clusters'
	keep if _merge == 3
	drop _merge
	merge  m:1 cluster using `clusters2arm'
	drop _merge
	
	preserve
	gen n_cases = 1
	collapse (sum) n_cases, by(cs_ct)
	export delimited using "`path'\Data_Clean\cs_ct_withcases_`datapull'.csv", replace
	restore
	
	* Generate indicator for the cs_ct that the mediator worked in
	foreach cs of local cs_list {
	forvalues ct = 1/`ct_num' /* 1/14 / 1/12 */ {
		qui gen cc_`cs'_`ct' = 1 if (court_station == "`cs'") & casetype == `ct'	
		qui egen ccc_`cs'_`ct' = max(cc_`cs'_`ct'), by(mediator_id)
		drop cc_`cs'_`ct'
	}
	}
	
	* Generate indicator for the arms that the mediator worked indicator
	gen treat = 1 if arm == "Treatment"
	qui egen treatment = max(treat), by(mediator_id)
	gen cont = 1 if arm == "Control"
	qui egen control = max(cont), by(mediator_id)
	drop treat cont

	* Collapse. For each observation cs_ct we get the number of cases in that 
	* cs_ct that could be managed by other cs_ct (variables). And total cases 
	* in that cs_ct
	gen totalcases_cs_ct = 1
	ds id mediator_id court_station cs_ct v1 cluster arm /*cs* accr* */ court_station casetype /*ct_1 ct_2 ct_3 ct_4 ct_5 ct_6 ct_7 ct_8 ct_9 ct_10 ct_11 ct_12 ct_13 ct_14 ct_15 ct_num */ /*weight _merge*/, not
	collapse (sum) `r(varlist)' (first) cluster (first) arm, by(cs_ct)	
		 
	* Convert into percents
	ds cs_ct totalcases_cs_ct treatment control cluster arm, not
	local varlist `r(varlist)'  // Store the variable list in a local macro
	foreach csct of local varlist {  
		replace `csct' = `csct' / totalcases_cs_ct
	}
	
	gen control_pct = control / totalcases_cs_ct
	gen treatment_pct = treatment / totalcases_cs_ct
	gen connect_opposite_arm = control_pct if arm == "Treatment"
	replace connect_opposite_arm = treatment_pct if arm == "Control"

	drop ccc_*
	export delimited using "`path'\Output\Clusters\cl_connect2arm_40_`datapull'.csv", replace
