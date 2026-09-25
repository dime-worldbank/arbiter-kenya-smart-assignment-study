/*******************************************************************************
	This .do file creates the data for clustering
	(Total link version: Total link = Shared_A&B * [Cases_A/Mediators_A + Cases_B/Mediators_B])
*******************************************************************************/

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

	*** Valid cs_ct universe (used to filter cases AND to restrict the final
	*** pairwise output below, so cs_ct combos outside the valid universe don't
	*** leak through with missing case counts)
	import delimited "`path'\Output\Clusters\2clusters_louv_res1p1_`datapull'.csv", clear
	keep cs_ct
	duplicates drop
	tempfile clusters
	save `clusters'


/*******************************************************************************
	CASE COUNTS PER cs_ct  (gives Cases_A / Cases_B)
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

	* Case count per cs_ct = Cases_A / Cases_B
	gen n_cases = 1
	collapse (sum) n_cases, by(cs_ct)
	save "`path'\Data_Clean\cs_ct_withcases_`datapull'.dta", replace
	export delimited using "`path'\Data_Clean\cs_ct_withcases_`datapull'.csv", replace
	tempfile casecounts
	save `casecounts'


/*******************************************************************************
	LICENSED-MEDIATOR MATRIX  (gives Mediators_A / Mediators_B and Shared_A&B)
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

	mata:
		medvars = tokens(st_local("medvars"))
		cslist  = tokens(st_local("cslist"))

		st_view(M=., ., medvars)          // mediators x cs_ct, 0/1 licensed indicator

		MtM = M' * M                      // MtM[i,j] = # mediators licensed in BOTH i and j
		N   = diagonal(MtM)                // N[i]    = # mediators licensed in combo i

		st_matrix("MtM_mat", MtM)
		st_matrix("N_mat", N)
	end

	matrix rownames MtM_mat = `cslist'
	matrix colnames MtM_mat = `cslist'

	* Matrix -> dataset: one row per cs_ct, one shared_ variable per target combo,
	* plus mediators_lic = total licensed mediators for that cs_ct (Mediators_A)
	clear
	svmat MtM_mat, names(col)

	gen cs_ct = ""
	local obs = 1
	foreach c of local cslist {
		replace cs_ct = "`c'" in `obs'
		local obs = `obs' + 1
	}
	order cs_ct

	foreach c of local cslist {
		rename `c' shared_`c'
	}

	svmat N_mat
	rename N_mat1 mediators_lic

	save "`path'\Data_Clean\cs_ct_shared_`datapull'.dta", replace


/*******************************************************************************
	BUILD PAIRWISE TOTAL LINK
*******************************************************************************/

	use "`path'\Data_Clean\cs_ct_shared_`datapull'.dta", clear

	* mediators_lic is "i-level" (constant within cs_ct); reshape carries it
	* along automatically for every cs_ct1 row.
	reshape long shared_, i(cs_ct mediators_lic) j(cs_ct1) string
	rename shared_ n_shared_mediators
	rename mediators_lic mediators_lic_a

	* Bring in Mediators_B (licensed mediator count for cs_ct1)
	preserve
		use "`path'\Data_Clean\cs_ct_shared_`datapull'.dta", clear
		keep cs_ct mediators_lic
		rename (cs_ct mediators_lic) (cs_ct1 mediators_lic_b)
		tempfile medlic_b
		save `medlic_b'
	restore
	merge m:1 cs_ct1 using `medlic_b'
	drop _merge

	* Bring in Cases_A
	merge m:1 cs_ct using `casecounts'
	drop _merge
	rename n_cases n_cases_a

	* Bring in Cases_B
	preserve
		use `casecounts', clear
		rename (cs_ct n_cases) (cs_ct1 n_cases_b)
		tempfile casecounts_b
		save `casecounts_b'
	restore
	merge m:1 cs_ct1 using `casecounts_b'
	drop _merge

	* Restrict to the valid cs_ct universe on BOTH sides of the pair. Without
	* this, cs_ct/cs_ct1 combos outside the valid universe (present in the
	* med_info licensing columns but not in the clusters file) would carry
	* through with missing n_cases_a/n_cases_b, making link_strength/total_link
	* missing rather than a genuine 0 or a properly-excluded row.
	preserve
		use `clusters', clear
		rename cs_ct cs_ct1
		tempfile clusters_b
		save `clusters_b'
	restore
	merge m:1 cs_ct using `clusters', keep(match) nogenerate
	merge m:1 cs_ct1 using `clusters_b', keep(match) nogenerate

	* Now that only valid-universe combos remain, any still-missing n_cases_a/
	* n_cases_b reflect a genuine 0 cases (that cs_ct had no cases at all in
	* the raw data), not an invalid combo - so fill those in as 0.
	replace n_cases_a = 0 if missing(n_cases_a)
	replace n_cases_b = 0 if missing(n_cases_b)

	* Total link = Shared_A&B * [(Cases_A/Mediators_A) + (Cases_B/Mediators_B)]
	gen link_strength = (n_cases_a / mediators_lic_a) + (n_cases_b / mediators_lic_b)
	gen total_link = n_shared_mediators * link_strength

	order cs_ct cs_ct1 n_shared_mediators n_cases_a mediators_lic_a n_cases_b mediators_lic_b link_strength total_link

	save "`path'\Data_Clean\clusterdata_strength_`datapull'.dta", replace
	export delimited using "`path'\Data_Clean\clusterdata_strength_`datapull'.csv", replace