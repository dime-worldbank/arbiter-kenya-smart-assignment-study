/*******************************************************************************
	This .do file creates the "Strength of connection" arm-level data.

	Total link (cell A, opposite Arm) =
	    Shared_mediators_A&Arm * [(Cases_A/Mediators_A) + (Cases_Arm/Mediators_Arm)]

	Counting only status=="Active" (licensed) mediators - the plain "Active"
	definition, NOT the hybrid one. Mirrors 02_cluster_data_prep_strength.do,
	but the counterpart of a cs_ct cell here is the OPPOSITE arm (union of
	all its cs_ct cells) instead of a single other cs_ct.

	Shared_mediators_A&Arm : # of Active mediators licensed in cell A who are
	    ALSO Active in >=1 cs_ct cell of the opposite arm.
	Mediators_A            : # of Active mediators licensed in cell A.
	Mediators_Arm          : # of DISTINCT Active mediators licensed in >=1
	    cs_ct cell of the opposite arm (not summed across cells, to avoid
	    double-counting a mediator licensed in several cells of that arm).
	Cases_A                : # of cases in cell A.
	Cases_Arm              : # of cases summed across all cs_ct cells of the
	    opposite arm.

	Universe: cs_ct cells in the valid cluster universe AND with a defined
	arm assignment.
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

		* Local: Total case type num
		ds ct_*, not
		ds ct_*
		local ct_num: word count `r(varlist)'

		* Local: case type names
		forvalue i=1(1)`ct_num' {
			local varname = "ct_`i'"
			local ct_`i'_label : variable label `varname'
			di "`ct_`i'_label'"
		}

	*** Cluster -> arm map
	** Baseline
	*import delimited "`path'\Data_Raw\cluster_2_arm_map_8_clusters_`datapull'.csv", clear	
	*import delimited "`path'\Data_Raw\cluster_2_arm_map_20_clusters_`datapull'.csv", clear	
	*import delimited "`path'\Data_Raw\cluster_2_arm_map_30_clusters_`datapull'.csv", clear
	*import delimited "`path'\Data_Raw\cluster_2_arm_map_40_clusters_`datapull'.csv", clear
	*tempfile clusters2arm
	*save `clusters2arm'
	
	** Strength
	import delimited "`path'\Data_Raw\cluster_2_arm_map_20_clusters_str_`datapull'.csv", clear	
	*import delimited "`path'\Data_Raw\cluster_2_arm_map_40_clusters_str_`datapull'.csv", clear
	tempfile clusters2arm
	save `clusters2arm'	
	
	*** cs_ct -> cluster map (valid cluster universe)
	** Baseline
	*import delimited "`path'\Output\Clusters\2clusters_louv_res1p1_`datapull'.csv", clear
	*import delimited "`path'\Output\Clusters\2clusters_louv_res3p5_`datapull'.csv", clear
	*import delimited "`path'\Output\Clusters\2clusters_louv_res4p6_`datapull'.csv", clear
	*import delimited "`path'\Output\Clusters\2clusters_louv_res5p9_`datapull'.csv", clear
	*tempfile clusters
	*save `clusters'
	
	** Strength
	*** cs_ct -> cluster map 
	*import delimited "`path'\Output\Clusters\2clusters_louv_res1p6_str_`datapull'.csv", clear
	import delimited "`path'\Output\Clusters\2clusters_louv_res2p7_str_`datapull'.csv", clear
	*import delimited "`path'\Output\Clusters\2clusters_louv_res3p48_str_`datapull'.csv", clear
	*import delimited "`path'\Output\Clusters\2clusters_louv_res3p82_str_`datapull'.csv", clear
	tempfile clusters
	save `clusters'

	*** cs_ct -> arm crosswalk
	use `clusters', clear
	merge m:1 cluster using `clusters2arm', keep(match) nogenerate
	keep cs_ct cluster arm
	tempfile cs_ct_arm_map
	save `cs_ct_arm_map'


/*******************************************************************************
	CASE COUNTS PER cs_ct AND PER ARM (gives Cases_A and Cases_Arm)
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

	* Court station name cleanup
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

	* Drop missing mediator_id (cases that have no mediator assigned)
	drop if mediator_id == .

	* Keep only the relevant variables
	keep id mediator_id court_station casetype

	* Create variable with case cs_ct using info from other variables
	egen cs_ct = concat(court_station casetype), punct("_")

	* Restrict to valid cs_ct universe
	merge m:1 cs_ct using `clusters'
	keep if _merge == 3
	drop _merge

	* Case count per cs_ct = Cases_A
	gen n_cases = 1
	collapse (sum) n_cases, by(cs_ct)
	tempfile casecounts
	save `casecounts'

	* Case count per arm = Cases_Arm (sum of Cases_A across all cells in the arm)
	merge 1:1 cs_ct using `cs_ct_arm_map'
	keep if _merge == 3
	drop _merge
	collapse (sum) n_cases, by(arm)
	rename n_cases n_cases_arm
	rename arm arm1
	tempfile casecounts_arm
	save `casecounts_arm'


/*******************************************************************************
	LICENSED-MEDIATOR MATRIX (gives Mediators_A, Mediators_Arm and
	Shared_A&Arm)
*******************************************************************************/

	use "`path'/Data_Clean/med_info_`datapull'.dta", clear
	rename csct_* medlic_*

	keep if status == "Active"

	ds medlic_*
	local medvars `r(varlist)'

	* Parallel local: strip "medlic_" to get the cs_ct label for each var
	local cslist ""
	foreach v of local medvars {
		local this = subinstr("`v'", "medlic_", "", 1)
		local cslist `cslist' `this'
	}

	keep mediator_id `medvars'

	* Restrict to cs_ct that actually have an arm assignment
	preserve
		use `cs_ct_arm_map', clear
		levelsof cs_ct, local(valid_cs_ct_list) clean
		levelsof cs_ct if arm == "Treatment", local(treat_cs_ct_list) clean
		levelsof cs_ct if arm == "Control", local(control_cs_ct_list) clean
	restore

	local medvars2 ""
	local cslist2 ""
	foreach v of local medvars {
		local this = subinstr("`v'", "medlic_", "", 1)
		local hit : list this in valid_cs_ct_list
		if `hit' {
			local medvars2 `medvars2' `v'
			local cslist2 `cslist2' `this'
		}
	}
	local medvars `medvars2'
	local cslist `cslist2'

	keep mediator_id `medvars'

	* Arm-level indicator per mediator: Active in >=1 cs_ct of that arm
	* (used to get Mediators_Arm as a DISTINCT count, not summed per-cell)
	local treat_vars ""
	foreach c of local treat_cs_ct_list {
		capture confirm variable medlic_`c'
		if !_rc local treat_vars `treat_vars' medlic_`c'
	}
	local control_vars ""
	foreach c of local control_cs_ct_list {
		capture confirm variable medlic_`c'
		if !_rc local control_vars `control_vars' medlic_`c'
	}

	egen medlic_Treatment = rowmax(`treat_vars')
	egen medlic_Control   = rowmax(`control_vars')
	replace medlic_Treatment = 0 if missing(medlic_Treatment)
	replace medlic_Control   = 0 if missing(medlic_Control)

	mata:
		medvars = tokens(st_local("medvars"))
		cslist  = tokens(st_local("cslist"))

		st_view(M=., ., medvars)                                   // mediators x cs_ct, 0/1 licensed & active
		st_view(Arm=., ., ("medlic_Treatment","medlic_Control"))   // mediators x 2

		N             = colsum(M)'       // cs_ct x 1: Mediators_A (active mediators per cell)
		CrossArm      = M' * Arm         // cs_ct x 2: Shared_A&Arm (raw overlap counts, NOT %)
		Mediators_Arm = colsum(Arm)      // 1 x 2: Mediators_Arm (distinct active mediators per arm)

		st_matrix("CrossArm_mat", CrossArm)
		st_matrix("N_mat", N)
		st_matrix("MediatorsArm_mat", Mediators_Arm)
	end

	matrix rownames CrossArm_mat = `cslist'
	matrix colnames CrossArm_mat = "shared_Treatment" "shared_Control"
	matrix colnames MediatorsArm_mat = "Treatment" "Control"

	clear
	svmat CrossArm_mat, names(col)
	svmat N_mat
	rename N_mat1 mediators_lic_a

	gen cs_ct = ""
	local obs = 1
	foreach c of local cslist {
		replace cs_ct = "`c'" in `obs'
		local obs = `obs' + 1
	}
	order cs_ct

	* Bring in Mediators_Arm (same 2 constants for every row)
	gen mediators_lic_Treatment = MediatorsArm_mat[1,1]
	gen mediators_lic_Control   = MediatorsArm_mat[1,2]

	* Attach each cell's own arm, then compute the OPPOSITE arm's Shared/Mediators
	merge 1:1 cs_ct using `cs_ct_arm_map'
	drop if _merge == 2
	drop _merge

	gen shared_opposite           = shared_Control           if arm == "Treatment"
	replace shared_opposite        = shared_Treatment          if arm == "Control"

	gen mediators_lic_opposite    = mediators_lic_Control     if arm == "Treatment"
	replace mediators_lic_opposite = mediators_lic_Treatment   if arm == "Control"

	* Bring in Cases_A
	merge 1:1 cs_ct using `casecounts'
	drop _merge
	rename n_cases n_cases_a

	* Bring in Cases_Arm (the OPPOSITE arm's total case count)
	gen arm1 = cond(arm == "Treatment", "Control", "Treatment")
	merge m:1 arm1 using `casecounts_arm'
	drop _merge
	drop arm1

	* Total link = Shared_A&Arm * [(Cases_A/Mediators_A) + (Cases_Arm/Mediators_Arm)]
	gen link_strength = (n_cases_a / mediators_lic_a) + (n_cases_arm / mediators_lic_opposite)
	gen total_link = shared_opposite * link_strength

	order cs_ct cluster arm shared_opposite n_cases_a mediators_lic_a n_cases_arm mediators_lic_opposite link_strength total_link

	save "`path'\Output\Clusters\cl_connect2arm_strength_20_`datapull'.dta", replace
	export delimited using "`path'\Output\Clusters\cl_connect2arm_strength_20_`datapull'.csv", replace
