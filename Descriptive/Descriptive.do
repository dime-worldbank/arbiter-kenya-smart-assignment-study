/*******************************************************************************
	DESCRIPTIVE STATISTICS
*******************************************************************************/

	version 17
	clear all

	* Locals
	local path "C:\Users\didac\Dropbox\Arbiter Research\Data analysis"
	local datapull =  "02062024" //"05102022" // "15062023" // "11062023" //  
	local casetypes `" "Children Custody and Maintenance" "Civil Appeals" "Civil Cases" "Commercial Cases" "Criminal Cases" "Divorce and Separation" "Employment and Labour Relations Cases (ELRC)" "Environment and Land Cases (ELC)" "Family Appeals" "Family Miscellaneous" "Matrimonial Property Cases" "Succession (Probate & Administration - P&A)" "'

/*******************************************************************************
	IMPORT & PREPARE HISTORICAL DATA
*******************************************************************************/

	use "`path'/Data_Clean/cases_cleaned_`datapull'.dta"
	
*** Drop some cases with issues
	drop if issue1 ==1 | issue2 ==2 | issue3 ==3 | issue4 ==4 | issue5 ==5 
	
*** Handy 1's variable
	gen case = 1 
	
/*******************************************************************************
	FIGURES 1 & 2: MONTHLY CASES
*******************************************************************************/

*** Gen num of cases x month
	egen ref_month_yearTOT = count(case), by(ref_month_year) // All monthly cases
	egen ref_month_yearTOTSA = count(case) if relevantcase == 1 & ///
	stationcases !=., by(ref_month_year) // 

*** Graphs	
	* All cases (from 2021)
	graph twoway bar ref_month_yearTOT ref_month_year if ref_year >= 2021, ///
	xtitle("Month") ytitle("Number of cases") 
	graph export "`path'/Output/cases_monthly.png", as(png) replace

	* Only relevant case types, in 10+ courts (from 2021) -> SA cases
	graph twoway bar ref_month_yearTOTSA ref_month_year if ref_year >=2021, ///
	xtitle("Month") ytitle("Number of cases") yscale(range(0 100))
	graph export "`path'/Output/cases_rel_monthly.png", as(png) replace
	
/* Casetypes trends
	twoway (line ref_month_yearTOTtype ref_month_year if casetype == 1) ///
	(line ref_month_yearTOTtype ref_month_year if casetype == 2) ///
	(line ref_month_yearTOTtype ref_month_year if casetype == 3) ///
	(line ref_month_yearTOTtype ref_month_year if casetype == 4) ///
	(line ref_month_yearTOTtype ref_month_year if casetype == 5) ///
	(line ref_month_yearTOTtype ref_month_year if casetype == 6) ///
	(line ref_month_yearTOTtype ref_month_year if casetype == 7) ///
	(line ref_month_yearTOTtype ref_month_year if casetype == 8) 
*/

/*******************************************************************************
	FIGURES 3 & 4: CASES PER MEDIATOR
*******************************************************************************/

*** Gen num of cases x mediator
	egen cases_mediator_TOT = count(case), by(mediator_id) // All cases x mediator
	egen cases_mediator_TOTSA = count(case) if relevantcase == 1 ///
	& stationcases !=. & case_status != "PENDING", by(mediator_id) // Only
	// relevant finished cases, in courts in SA
	
	replace cases_mediator_TOT = 80 if cases_mediator_TOT >80
	
*** Graphs	
	preserve 
	collapse cases_mediator_TOT cases_mediator_TOTSA, by(mediator_id)

	* All cases
	hist cases_mediator_TOT, freq width(2) ///
	xtitle("Cases") ytitle("Number of mediators") width(1)
	graph export "`path'/Output/casesxmediator.png", as(png) replace

	* Only relevant cases, in 10+ courts
	hist cases_mediator_TOTSA, freq width(2) ///
	xtitle("Cases") ytitle("Number of mediators") width(1)
	graph export "`path'/Output/casesxmediator_rel.png", as(png) replace
	restore

	
/*******************************************************************************
	TABLE X: COURTS
	(NOT USED NOW)
*******************************************************************************/
	
	/*
	egen TOT_court_cases = count(case) if ref_year >= 2021, by(courtstation)
	egen avg_succ_court = mean(case_outcome_agreement), by(courtstation)	

	preserve

	collapse TOT_court_cases avg_succ_court, by(mediator_id court_station)
	eststo courts1: estpost tabstat	TOT_court_cases, by(court_station) st(mean) // 	Total cases by court
	eststo courts2: estpost tabstat	avg_succ_court, by(court_station) st(n mean) // Mediators by court, success rate by court
	esttab courts1 courts2 using "`path'/Output/courts_descr.tex", cells("count(fmt(0)) mean(fmt(2))") label replace

	restore
	*/
	
/*******************************************************************************
	TABLE 1: CASETYPES
*******************************************************************************/	
	
*** Create variables
	* Total cases by type since year 2021
	egen TOT_type = count(case) if ref_year >= 2021, by(case_type)
	* Agreement rate by case type
	egen avg_agreement_type = mean(case_outcome_agreement) ///
	if ref_year >= 2021, by(case_type)
	* Duration by case type & whether agreement is reached or not
	egen avg_case_days_med = mean(case_days_med), by(casetype)
	egen avg_case_days_med_agree = mean(case_days_med) ///
	if case_outcome_agreement == 1, by(casetype) // Agreement
	egen avg_case_days_med_dis = mean(case_days_med) ///
	if case_outcome_agreement == 0, by(casetype) // No agreement

*** Create table
	preserve

	collapse TOT_type avg_agreement_type avg_case_days_med ///
	avg_case_days_med_agree avg_case_days_med_dis, by(case_type)
	
	eststo types1: estpost tabstat TOT_type avg_agreement_type ///
	avg_case_days_med avg_case_days_med_agree avg_case_days_med_dis, ///
	by(case_type) st(mean)  
	
	esttab types1 using "`path'/Output/casetypes_descr.tex", ///
	cells("TOT_type(fmt(0)) avg_agreement_type(fmt(2)) avg_case_days_med(fmt(2)) avg_case_days_med_agree(fmt(2)) avg_case_days_med_dis(fmt(2))") ///
	label replace noobs
	
	restore

/*******************************************************************************
	FIGURE X: DURATION BY CASE TYPE
*******************************************************************************/	

	local casetypes `" "Children Custody and Maintenance" "Civil Appeals" "Civil Cases" "Commercial Cases" "Criminal Cases" "Divorce and Separation" "Employment and Labour Relations Cases (ELRC)" "Environment and Land Cases (ELC)" "Family Appeals" "Family Miscellaneous" "Matrimonial Property Cases" "Succession (Probate & Administration - P&A)" "'

*** Single graphs
	local num = 0	
	foreach ct in `casetypes'{
		local num = `num' + 1
		tw (hist case_days_med if case_days_med < 750 ///
		& case_type == "`ct'" & case_outcome_agreement == 1, ///
		width(5) color(green%30) lwidth(0) freq) ///
		(hist case_days_med if case_days_med < 750 ///
		& case_type == "`ct'" & case_outcome_agreement == 0, ///
		width(5) color(red%30) lwidth(0) freq)	///
		(kdensity case_days_med if case_days_med < 750 & case_type == "`ct'" ///
		& case_outcome_agreement == 1, yaxis(2) lcolor(green)) ///
		(kdensity case_days_med if case_days_med < 750 & case_type == "`ct'" ///
		& case_outcome_agreement == 0, yaxis(2) lcolor(red) ///
		legend(order(1 "Agreement freq" 3 "No agreement freq" ///
		2 "No agreement density" 4 "No agreement density") cols(4) position(6) ///
		forces size(tiny)) ///
		ytitle("") ytitle("", axis(2)) ///
		xtitle("") title("`ct'", size(medsmall)) ///
		name("gra`num'", replace)) 
}

*** Combine graphs
	grc1leg gra1 gra2 gra3 gra4 gra5 gra6 gra7 gra8 gra9 gra10 gra11 gra12, ///
	cols(3) legendfrom(gra1) /*note("Left y-axis: Histrogram frequency. Right y-axis: Kernel density. X-axis: Case duration from appointment to conclusion", size(tiny) pos(7))*/ xcommon ysize(9) xsize(6.5)
	graph display, ysize(9) xsize(10)
	graph export "`path'/Output/durations_casetype.png", as(png) replace
	

/*******************************************************************************
	TABLE 2: ACCREDITATION & CASE TYPE MAP
	
	This table shows for each accreditation which case types a mediator can work 
	in
*******************************************************************************/
local path "C:\Users\didac\Dropbox\Arbiter Research\Data analysis"
	* Info with mapping of case types and accreditations
	import delimited "`path'\Data_Raw\Case_Type_Eligible_Accreditation_Categrories_21062024.csv", clear

/*
	Accreditations
	1- Children
	2- Civil
	3- Commercial
	4- Copyright
	5- Employment
	6- Environment
	7- Family
	8- Labor
	9- Land
	10- Tribunal
	
	Casetype
	1 Matrimonial Property Cases
	2 Criminal Cases
	3 Commercial Cases
	4 Employment and Labour Relations Cases (ELRC)
	5 Family Appeals
	6 Civil Cases
	7 Children Custody and Maintenance
	8 Civil Appeals
	9 Divorce and Separation
	10 Succession (Probate & Administration - P&A)
	11 Family Miscellaneous
	12 Environment and Land Cases (ELC)
	13	Judicial Review
	14	Constitution and Human Rights
	15	Anti-Corruption
	*/	
	
	* Reshape: each row one casetype, each column one accreditation
	reshape wide id, i(casetypeid) j(accreditationcategoryid)
	
	* Rename casetypes nums to words
	tostring casetypeid, replace
	replace casetypeid = "Matrimonial Property Cases" if casetypeid == "1"
	replace casetypeid = "Criminal Cases" if casetypeid == "2"
	replace casetypeid = "Commercial Cases" if casetypeid == "3"
	replace casetypeid = "Employment and Labour Relations Cases (ELRC)" ///
	if casetypeid == "4"
	replace casetypeid = "Family Appeals" if casetypeid == "5"
	replace casetypeid = "Civil Cases" if casetypeid == "6"
	replace casetypeid = "Children Custody and Maintenance" if casetypeid == "7"
	replace casetypeid = "Civil Appeals" if casetypeid == "8"
	replace casetypeid = "Divorce and Separation" if casetypeid == "9"
	replace casetypeid = "Succession (Probate and Administration)" ///
	if casetypeid == "10"
	replace casetypeid = "Family Miscellaneous" if casetypeid == "11"
	replace casetypeid = "Environment and Land Cases (ELC)" if casetypeid == "12"
	replace casetypeid = "Judicial Review" if casetypeid == "13"
	replace casetypeid = "Constitution and Human Rights" if casetypeid == "14"
	replace casetypeid = "Anti-Corruption" if casetypeid == "15"
	
	rename casetypeid case_type
	
	
	forvalues i=1(1)9{
		replace  id`i' = 1 if  id`i' !=.
	}
	
	* Rename variables, each of them is one 
	rename id1 Children
	rename id2 Civil
	rename id3 Commercial
	rename id4 Copyright
	rename id5 Employment
	rename id6 Environment
	rename id7 Family
	rename id8 Labor
	rename id9 Land
	
	gen Tribunal = . 
	
*** Table
	* Header
	file open tab_accredctype using "`path'/Output/accred_type_map.tex", write text replace
	file write tab_accredctype "\begin{tabular}{lccccccccc}" _n
	file write tab_accredctype "\toprule"  _n
	file write tab_accredctype "& & & & & \textbf{Accreditation} \\" _n
	file write tab_accredctype " \textbf{Case type}  & Children & Civil & Commercial & Copyright & Employment & Environment & Family & Labor & Land  \\" _n
	file write tab_accredctype "\midrule" _n
	
	* Body
	local accred Children Civil Commercial Copyright Employment Environment Family Labor Land
	local ctypes `" "Matrimonial Property Cases" "Criminal Cases" "Commercial Cases" "Employment and Labour Relations Cases (ELRC)" "Family Appeals" "Civil Cases" "Children Custody and Maintenance" "Civil Appeals" "Divorce and Separation" "Succession (Probate and Administration)" "Family Miscellaneous" "Environment and Land Cases (ELC)" "Judicial Review" "Constitution and Human Rights" "Anti-Corruption" "'

foreach j of local ctypes {	
foreach i of local accred {
	summ `i' if case_type == "`j'"
	local X = `r(N)'
	if `X' == 1 {
		local x_`i' = "x"
	}
	else {
		local x_`i' = ""
	}
}
file write tab_accredctype "`j'" `"  & `x_Children' & `x_Civil' & `x_Commercial' & `x_Copyright' & `x_Employment' & `x_Environment' & `x_Family' & `x_Labor' & `x_Land' \\ "' _n
	
}
	
	* Bottom
	file write tab_accredctype "\bottomrule" _n
	file write tab_accredctype "\end{tabular}"
	file close tab_accredctype
	
	tempfile accred_type
	save `accred_type'
	


	
	
	*restore
	
* Casetype: N, Mean success by case type
* Court: N, mean success, mediators
* Inactive mediators 
* Trend case types year?
* Only active mediators in cases per mediator?

* 