/*******************************************************************************
	SET UP
*******************************************************************************/

	version 17
	clear all
	
	*** Define locals 
	local path "C:\Users\didac\Dropbox\Arbiter Research\Data analysis"
	local datapull =  "20260513" 
	local cluster_n = 40
	
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
	
	**** IMPORT BIAS
	

	
	*** 8 CLUSTERS
	if `cluster_n' == 8{
		import delimited "`path'\Data_Clean\bias\cell_agreement_bias_8clusters.csv", clear
	}
	
	*** 20 CLUSTERS
	else if `cluster_n' == 20{
		
		* Baseline clusters
		*import delimited "`path'\Data_Clean\bias\cell_agreement_bias_20clusters.csv", clear
		
		/* Baseline clusters update
		import delimited "`path'\Data_Clean\bias\cell_agreement_bias_20clusters_control_june30.csv", clear
		tempfile 20control
		save `20control'
		import delimited "`path'\Data_Clean\bias\cell_agreement_bias_20clusters_treatment_june30.csv", clear
		append using `20control'*/
		
		* Strenght
		import delimited "`path'\Data_Clean\bias\cell_agreement_bias_newcluster_20clusters_control_june30.csv", clear
		tempfile 20control
		save `20control'
		import delimited "`path'\Data_Clean\bias\cell_agreement_bias_newcluster_20clusters_treatment_june30.csv", clear
		append using `20control'
	
	}
	
	*** 30 CLUSTERS
	else if `cluster_n' == 30{
		
		* Baseline clusters
		import delimited "`path'\Data_Clean\bias\cell_agreement_bias_30clusters_control_cells.csv", clear
		gen arm_side = "control"
		tempfile 30control
		save `30control'
		import delimited "`path'\Data_Clean\bias\cell_agreement_bias_30clusters_treatment_cells.csv", clear
		gen arm_side = "treatment"
		append using `30control'
	}
	
	
	*** 40 CLUSTERS
	else if `cluster_n' == 40{
		
		* Baseline clusters
		*import delimited "`path'\Data_Clean\bias\cell_agreement_bias_40clusters_control_cells.csv", clear
	*gen arm_side = "control"
		*tempfile 40control
		*save `40control'
		*import delimited "`path'\Data_Clean\bias\cell_agreement_bias_40clusters_treatment_cells.csv", clear
		*gen arm_side = "treatment"	
		*append using `40control'
		
		/* Baseline clusters update
		import delimited "`path'\Data_Clean\bias\cell_agreement_bias_40clusters_control_june30.csv", clear		  
		tempfile 40control
		save `40control'		
		import delimited "`path'\Data_Clean\bias\cell_agreement_bias_40clusters_treatment_june30.csv", clear		
		append using `40control'*/
	
		* Strength
		import delimited "`path'\Data_Clean\bias\cell_agreement_bias_newcluster_40clusters_control_june30.csv", clear	
		tempfile 40control
		save `40control'
		* Strength
		import delimited "`path'\Data_Clean\bias\cell_agreement_bias_newcluster_40clusters_treatment_june30.csv", clear
		append using `40control'
	}
	
	
	rename legacy_type casetype
	rename court courtstation
	
	tempfile bias
	save `bias'

	
	*** IMPORT CELL CONNECTIONS
	*import delimited "`path'\Output\Clusters\cl_connect2arm_`cluster_n'_`datapull'.csv", clear
	
	import delimited "`path'\Output\Clusters\cl_connect2arm_strength_`cluster_n'_`datapull'.csv", clear
	rename n_cases_a totalcases_cs_ct
	*rename arm arm_side
	replace arm_side = "treatment" if arm_side == "Treatment"
	replace arm_side = "control" if arm_side == "Control"
	rename total_link connect_opposite_arm
	
	/*import delimited "`path'\Output\Clusters\cl_connect2arm_shared_`cluster_n'_`datapull'.csv", clear
	rename n_active_mediators totalcases_cs_ct
	rename arm arm_side
	replace arm_side = "treatment" if arm_side == "Treatment"
	replace arm_side = "control" if arm_side == "Control"
	rename connection_opposite_arm connect_opposite_arm
	*/
	*import delimited "`path'\Output\Clusters\cl_connect2arm_hybrid_`cluster_n'_`datapull'.csv", clear
	
	split cs_ct, parse(_)
	rename cs_ct1 courtstation
	rename cs_ct2 case_type
	
	gen casetype = ""
		forvalue i=1(1)`ct_num' {
		replace casetype = "`ct_`i'_label'" if case_type == "`i'"
	}
	
	*** Merge
	merge 1:1 courtstation casetype using `bias'
	
/*******************************************************************************
	RESULTS
*******************************************************************************/
	
	*** Regressions
	
	** Baseline
	reg bias connect_opposite_arm [aw=totalcases_cs_ct] if arm_side == "treatment", vce(cluster cluster) 
	predict yhat_treat_baseline if e(sample), xb
	reg bias connect_opposite_arm [aw=totalcases_cs_ct] if arm_side == "control", vce(cluster cluster) 
	predict yhat_control_baseline if e(sample), xb
	
	** Restrict to only 20+ cells
	reg bias connect_opposite_arm [aw=totalcases_cs_ct] if arm_side == "treatment" & totalcases_cs_ct > 20, vce(cluster cluster) 
	predict yhat_treat_20p if e(sample), xb
	reg bias connect_opposite_arm [aw=totalcases_cs_ct] if arm_side == "control" & totalcases_cs_ct > 20, vce(cluster cluster) 
	predict yhat_control_20p if e(sample), xb
	
	** vce(robust)
	reg bias connect_opposite_arm [aw=totalcases_cs_ct] if arm_side == "treatment", vce(robust) 
	reg bias connect_opposite_arm [aw=totalcases_cs_ct] if arm_side == "control", vce(robust) 	
	
	** Absolute value
	gen bias_abs = abs(bias)
	reg bias_abs connect_opposite_arm [aw=totalcases_cs_ct], ///
		vce(cluster cluster)
	predict yhat_abs_baseline, xb
	
	** Absolute value 20p
	reg bias_abs connect_opposite_arm [aw=totalcases_cs_ct] if totalcases_cs_ct > 20, ///
		vce(cluster cluster)
	predict yhat_abs_20p, xb

	* Arm side
	gen arm_side_num = 1 if arm_side == "treatment"
	replace arm_side_num = 0 if arm_side == "control"
	reg bias arm_side_num [aw=totalcases_cs_ct], vce(cluster cluster) 
	
	* Arm side 20p
	reg bias arm_side_num [aw=totalcases_cs_ct] if totalcases_cs_ct > 20, vce(cluster cluster) 
	
	**** EXCLUDE OBSERVATIONS
	* Arm side - Exclude highest connections
	_pctile connect_opposite_arm, p(70)
	local p1 = r(r1)
	di `p1'

	reg bias arm_side_num [aw=totalcases_cs_ct] ///
		if connect_opposite_arm <= `p1', ///
		vce(cluster cluster)
		
	/* Arm side 20p - Exclude highest connections
	_pctile connect_opposite_arm if totalcases_cs_ct > 20, p(20 80)
	local p20 = r(r1)
	local p80 = r(r2)
	reg bias arm_side_num [aw=totalcases_cs_ct] ///
		if connect_opposite_arm >= `p20' & ///
		   connect_opposite_arm <= `p80' & ///
		   totalcases_cs_ct > 20, ///
		vce(cluster cluster)	*/	
	
	
	*** Graphs
	* Histogram bias T vs C
	twoway ///
    (histogram bias if arm_side == "treatment", ///
		frequency ///
        start(-0.2) ///
        width(0.01) ///
        fcolor(navy%35) ///
        lcolor(navy)) ///
    (histogram bias if arm_side == "control", ///
		frequency ///
        start(-0.2) ///
        width(0.01) ///
        fcolor(maroon%35) ///
        lcolor(maroon)), ///
    xscale(range(-0.2 0.2)) ///
    yscale(range(0 100)) ///
    ylabel(0(20)100) ///
	ytitle("Frequency") ///
	legend(order(1 "Treatment" 2 "Control") ///
		   cols(2) position(6) ring(1)) ///
    title("`cluster_n' clusters")
	graph export "`path'\Output\Bias\Hist_bias_`cluster_n'.png", replace
	
	* Histogram bias T vs C only 20 or more
	twoway ///
    (histogram bias if arm_side == "treatment" & totalcases_cs_ct > 20, ///
		frequency ///
        start(-0.2) ///
        width(0.01) ///
        fcolor(navy%35) ///
        lcolor(navy)) ///
    (histogram bias if arm_side == "control" & totalcases_cs_ct > 20, ///
		frequency ///
        start(-0.2) ///
        width(0.01) ///
        fcolor(maroon%35) ///
        lcolor(maroon)), ///
    xscale(range(-0.2 0.2)) ///
    yscale(range(0 100)) ///
    ylabel(0(20)100) ///
	ytitle("Frequency") ///
	legend(order(1 "Treatment" 2 "Control") ///
		   cols(2) position(6) ring(1)) ///
    title("`cluster_n' clusters")
	graph export "`path'\Output\Bias\Hist_bias_`cluster_n'c_20p.png", replace
	
	* Histogram connections
	hist connect_opposite_arm, ///
	frequency ///
    width(0.05) ///
    fcolor(navy%65) ///
    lcolor(navy) ///
    ytitle("Frequency") ///
    xtitle("Connection to the opposite arm") ///
    yscale(range(0 400) noextend) ///
    ylabel(0(50)400) ///
    title("`cluster_n' clusters")
	graph export "`path'\Output\Bias\Hist_conn_`cluster_n'.png", replace
	
	* Histogram connections - use cases
	hist connect_opposite_arm [fw=totalcases_cs_ct], ///
    frequency ///
    width(0.05) ///
    fcolor(navy%65) ///
    lcolor(navy) ///
    ytitle("Number of cases") ///
    xtitle("Connection to the opposite arm") ///
    yscale(range(0 4000) noextend) ///
    ylabel(0(500)4000) ///
    title("`cluster_n' clusters")
	graph export "`path'\Output\Bias\Hist_conncases_`cluster_n'.png", replace
	
	* Scatterplot Bias & connections 
	twoway ///
		(scatter bias connect_opposite_arm [aw=totalcases_cs_ct] ///
			if arm_side=="treatment" & inrange(bias,-0.075,0.075), ///
			mcolor(navy%40)) ///
		(line yhat_treat_baseline connect_opposite_arm ///
			if arm_side=="treatment" & inrange(bias,-0.075,0.075), ///
			sort lcolor(navy) lwidth(medthick)) ///
		(scatter bias connect_opposite_arm [aw=totalcases_cs_ct] ///
			if arm_side=="control" & inrange(bias,-0.075,0.075), ///
			mcolor(maroon%40)) ///
		(line yhat_control_baseline connect_opposite_arm ///
			if arm_side=="control" & inrange(bias,-0.075,0.075), ///
			sort lcolor(maroon) lwidth(medthick)), ///
		legend(order(1 "Treatment" 3 "Control") ///
			   cols(2) position(6) ring(1)) ///
		ytitle("Bias") ///
		xtitle("Connection to the opposite arm") ///
		yscale(range(-0.075 0.075) noextend) ///
		ylabel(-0.075(0.25)0.075) ///
		note("Note: Outliers outside [-.0.075,-0.075] are not shown") ///
		title("`cluster_n' clusters")
	graph export "`path'\Output\Bias\Scatter_biasconn_`cluster_n'c.png", replace
		
	* Scatterplot Bias & connections - 20 or more
	twoway ///
		(scatter bias connect_opposite_arm [aw=totalcases_cs_ct] ///
			if arm_side=="treatment" & totalcases_cs_ct > 20, ///
			mcolor(navy%40)) ///
		(line yhat_treat_20p connect_opposite_arm ///
			if arm_side=="treatment" & totalcases_cs_ct > 20, ///
			sort lcolor(navy) lwidth(medthick)) ///
		(scatter bias connect_opposite_arm [aw=totalcases_cs_ct] ///
			if arm_side=="control" & totalcases_cs_ct > 20, ///
			mcolor(maroon%40)) ///
		(line yhat_control_20p connect_opposite_arm ///
			if arm_side=="control" & totalcases_cs_ct > 20, ///
			sort lcolor(maroon) lwidth(medthick)), ///
		legend(order(1 "Treatment" 3 "Control") cols(2) position(6) ring(1)) ///
		ytitle("Bias") ///
		xtitle("Connection to the opposite arm") ///
		yscale(range(-0.075 0.075) noextend) ///
		ylabel(-0.075(0.025)0.075) ///
		title("`cluster_n' clusters") ///
		subtitle("Only cells with more than 20 cases")
	graph export "`path'\Output\Bias\Scatter_biasconn_`cluster_n'c_20p.png", replace
	
	* Scatterplot absolute value
	twoway ///
		(scatter bias_abs connect_opposite_arm [aw=totalcases_cs_ct] ///
			if inrange(bias_abs,0,0.08), ///
			mcolor(navy%40)) ///
		(line yhat_abs_baseline connect_opposite_arm ///
			if inrange(bias_abs,0,0.08), ///
			sort lcolor(navy) lwidth(medthick)), ///
		legend(off) ///
		ytitle("Absolute bias") ///
		xtitle("Connection to the opposite arm") ///
		yscale(range(0 0.08) noextend) ///
		ylabel(0(0.01)0.08) ///
		note("Note: Outliers above 0.05 are not shown") ///
		title("`cluster_n' clusters")
	graph export "`path'\Output\Bias\Scatter_absbiasconn_`cluster_n'c.png", replace
		
	* Scatterplot absolute value 20 plus
	twoway ///
		(scatter bias_abs connect_opposite_arm [aw=totalcases_cs_ct] ///
			if totalcases_cs_ct > 20 & inrange(bias_abs,0,0.08), ///
			mcolor(navy%40)) ///
		(line yhat_abs_20p connect_opposite_arm ///
			if totalcases_cs_ct > 20 & inrange(bias_abs,0,0.08), ///
			sort lcolor(navy) lwidth(medthick)), ///
		legend(off) ///
		ytitle("Absolute bias") ///
		xtitle("Connection to the opposite arm") ///
		yscale(range(0 0.08) noextend) ///
		ylabel(0(0.01)0.08) ///
		note("Note: Outliers above 0.08 are not shown") ///
		title("`cluster_n' clusters") ///
		subtitle("Only cells with more than 20 cases")
	graph export "`path'\Output\Bias\Scatter_absbiasconn_`cluster_n'c_20p.png", replace
		
		