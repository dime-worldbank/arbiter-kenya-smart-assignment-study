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
		

/*******************************************************************************
	CREATE LIST cs_ct vs cs1_ct1:
	- All possible combinations of cs_ct with other cs1_ct1 in one dataset
******************************************************************************/
/*
clear	
insobs 1 // Insert observation
display `:word count `cs_list'' * `ct_num'
* Create a dataset that contains a list of all cs_ct
foreach cs of local cs_list {
	*di "`cs'"
forvalues ct = 1(1)`ct_num' {
	*di `ct'
	qui gen `cs'_`ct' = .	
}
}
xpose, varname clear
keep _varname
rename _varname cs_ct1
gen link = 1
tempfile list_cs_ct
save `list_cs_ct'  // cs_ct1 & link

* Create "Empty" dataset where to save all links
gen cs_ct = ""
drop if _n >0
tempfile data_c
save `data_c' // cs_ct1, cs_ct (empty str) & link

* Add all cs_ct vs cs_ct1 connections
foreach cs of local cs_list {
	di "`cs'"
	forvalues ct = 1(1)`ct_num' {
	use `list_cs_ct', clear
	qui keep if cs_ct1 == "`cs'_`ct'"
	rename cs_ct1 cs_ct
	qui merge 1:m link using  `list_cs_ct'
	drop _merge
	append using `data_c'
	tempfile data_c
	qui save `data_c'
}
}
drop if cs_ct == ""
tempfile csct_csct1_all
save `csct_csct1_all'

save "`path'\Data_Clean\csct_csct1_`datapull'.dta", replace
*/

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
		
			
	* Drop missing mediator_id (cases that have no mediator assigned)
	drop if mediator_id == . 

	* Keep only the relevant variables
	keep id mediator_id court_station casetype 
	
	* Create variable with case cs_ct using info from other variables
	egen cs_ct = concat(court_station casetype), punct("_")
	
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

	* Collapse. For each observation cs_ct we get the number of cases in that 
	* cs_ct that could be managed by other cs_ct (variables). And total cases 
	* in that cs_ct
	gen totalcases_cs_ct = 1
	ds id mediator_id court_station cs_ct /*cs* accr* */ court_station casetype /*ct_1 ct_2 ct_3 ct_4 ct_5 ct_6 ct_7 ct_8 ct_9 ct_10 ct_11 ct_12 ct_13 ct_14 ct_15 ct_num */ /*weight _merge*/, not
	collapse (sum) `r(varlist)', by(cs_ct)	
		 
	* Convert into percents
	ds cs_ct totalcases_cs_ct, not
	local varlist `r(varlist)'  // Store the variable list in a local macro

	foreach csct of local varlist {  
		replace `csct' = `csct' / totalcases_cs_ct
	}
	
	* Reshape
	reshape long ccc_, i(cs_ct) j(cs_ct1) string
	rename ccc_ w1
	
	*** Create the max

	* Create a unique identifier for each pair, ensuring order does not matter
	gen pair_id = cond(cs_ct < cs_ct1, cs_ct + "_" + cs_ct1, cs_ct1 + "_" + cs_ct)
	
	* Gen w1, wmin and wmax
	egen w_max = max(w1), by(pair_id)
	egen w_min = min(w1), by(pair_id)
	
	*** Export dataset A: with connections, no 0's
	export delimited using "`path'\Data_Clean\clusterdata_a_`datapull'.csv", replace
	save "`path'\Data_Clean\clusterdata_a_`datapull'.dta", replace

	*** Export dataset B with connections, no 0's, and no repetitions of  the type:
	* (cs_ct,cs_ct1)=(cs_ct1,cs_ct)
	
	* Keep only the first occurrence of each unique pair
	bysort pair_id: keep if _n == 1

	* Drop helper variable
	drop pair_id	
	export delimited using "`path'\Data_Clean\clusterdata_b_`datapull'.csv", replace
	save "`path'\Data_Clean\clusterdata_b_`datapull'.dta", replace
	

	*** Add in 0's to dataset A
	use "`path'\Data_Clean\clusterdata_a_`datapull'.dta", clear
	merge 1:1 cs_ct cs_ct1 using "`path'\Data_Clean\csct_csct1_`datapull'.dta"
	replace w1 = 0 if w1==.
	replace totalcases_cs_ct = 0 if totalcases_cs_ct==.
	replace w_max = 0 if w_max==.
	replace w_min = 0 if w_min==.	
	export delimited using "`path'\Data_Clean\clusterdata_a_0_`datapull'.csv", replace
	
	*** Add in 0's to dataset B
	*use "`path'\Data_Clean\csct_csct1_20250729.dta", clear
	use "`path'\Data_Clean\clusterdata_b_`datapull'.dta", clear
	merge 1:1 cs_ct cs_ct1 using "`path'\Data_Clean\csct_csct1_`datapull'.dta"
	replace w1 = 0 if w1==.
	replace totalcases_cs_ct = 0 if totalcases_cs_ct==.
	replace w_max = 0 if w_max==.
	replace w_min = 0 if w_min==.
	gen pair_id = cond(cs_ct < cs_ct1, cs_ct + "_" + cs_ct1, cs_ct1 + "_" + cs_ct)
	bysort pair_id: keep if _n == 1 | pair_id == ""
	drop /*link*/ _merge
	export delimited using "`path'\Data_Clean\clusterdata_b_0_`datapull'.csv", replace
	
	
	/*
	Dataset A: All connections
	Dataset B: Only max (half the size)
	*/
		