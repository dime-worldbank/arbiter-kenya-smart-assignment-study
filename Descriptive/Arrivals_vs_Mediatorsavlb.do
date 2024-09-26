/*******************************************************************************
	ARRIVALS OF CASES VS AVAILABLE MEDIATORS
*******************************************************************************/

/* 

	*** PURPOSE
	
	- Create an excel file with several sheets that contain info on the number
	of available mediators available in each courtstation and the number of
	cases that arrive in each courtstation. Results are shown by different 
	accreditations and case types. 
	
	- Create also .tex files to be used in overleaf. 

	*** TO DO 

	- Accomodate new case types: judiciary review, anti-corruption, constitution 
	and human rights. At the moment it is not a problem because the data has 
	none of those cases. But once they arrive, it will be an issue.
	
	- Add a local at the beginning with datapull date and make it so that the 
	results are correct with any new datapull. For that it is necessary to fix
	the previous point, otherwise new case types WILL make current results 
	wrong.
	
	- Potentially add MONTHLY case arrivals, instead of total.
	
	- Potentially use only active mediators.
*/


/*******************************************************************************
	SET UP
*******************************************************************************/

	version 17
	clear all

	*** Define locals 
	local path "C:\Users\didac\Dropbox\Arbiter Research\Data analysis"
	local datapull =  "24042024" 

	* Case type list
	local ct_list_n ChildrenCustodyAndMaintenance CivilAppeals CivilCases ///
	CommercialCases CriminalCases DivorceAndSeparation ///
	EmploymentAndLabourRelations EnvironmentAndLandCases FamilyAppeals ///
	FamilyMiscellaneous MatrimonialPropertyCases Succession JudicialReview ///
	ConstitutionHR AntiCorruption

	* Accreditation list
	local accr_list Children Civil Commercial Copyright Employment ///
	Environment Family Labor Land Tribunal

	* Courtstation list - Use full list of courts 
	import delimited "`path'\Data_Raw\Court_Station_22062024.csv", clear
		* Replace some names that will later become variables and cannot
		* contain some characters
		replace name = "MUKURWEINI" if name == "MUKURWE-INI"
		replace name = "MURANGA" if name == "MURANG'A"
		replace name = "WANGURU" if name == "WANG'URU"
		replace name = "OLKALOU" if name == "OL KALOU"
		replace name = "ELDAMARAVINE" if name == "ELDAMA RAVINE"
		replace name = "MTITOANDEI" if name == "MTITO ANDEI"
		drop if name == "KANGUNDO DO NOT USE"
		levelsof name, local(cs_list)
		display `cs_list'
		
	* Courtstation list with an n_ at the start of the name
	gen n_ = "n_"
	egen n_name = concat(n_ name)
	levelsof n_name, local(cs_list_n)
	
	* Number of courtstations
	local cs_num = `:word count `cs_list''

/*******************************************************************************
	PREPARE DATA 1: MEDIATORS COURTSTATIONS DATA
	
	- Use mediators info dataset
	- Transform it so that we have several variables "csnum" and in each of them
	info on the courtstations mediators can work in
	
*******************************************************************************/

*** Import dataset with all mediators info
import delimited "`path'\Data_Raw\Vw_All_Mediators_24042024.csv", clear

	* Keep only active mediators
	keep if status=="Active" 

	* Split courtstation and accreditation variables - Not organized yet
	rename courtstations cs
	rename accreditioncategories accr
	split accr, p(", ") 
	split cs, p(", ")

	* Fix court names that cannot become variable names (spaces, hyphens, 
	* apostrophs)
	forvalues i=1(1)17{
		replace cs`i' = "ELDAMARAVINE" if cs`i' == "ELDAMA RAVINE"
		replace cs`i' = "MUKURWEINI" if cs`i' == "MUKURWE-INI"
		replace cs`i' = "MURANGA" if cs`i' == "MURANG'A"
		replace cs`i' = "OLKALOU" if cs`i' == "OL KALOU"
	}

	tempfile data_med
	save `data_med'
	
/*******************************************************************************
	 PREPARE DATASET 2: ARRIVALS DATA
	 - Use cleaned cases dataset
	 - Transform it so that it observation becomes a courtstation and in the 
	 variables we have data on the number of case arrivals by case type
*******************************************************************************/

	***  Import data
	use "`path'\Data_Clean\cases_cleaned_02062024", clear

	* Keep only if mediator appointed after X date
	keep if med_appt_date > date("01Apr2022","DMY")

	* Number of cases by type and courtstation
	egen numcas_courtstat_casetype = count(id), by(casetype court_station)

	* Collapse at courtstation and casetype level
	collapse numcas_courtstat_casetype, by(casetype courtstation)

	* Reshape: Each observation becomes a courtstation, 12 different variables 
	* each case type
	rename numcas_courtstat_casetype n_
	reshape wide n_, i(courtstation) j(casetype)
	forvalues i=1(1)12{
	replace n_`i' = 0 if n_`i'==. // Add 0's
	*replace n_`i' = n_`i' / 24 if n_`i'!=. // Turn to monthly arrivals
	*replace n_`i' = round(n_`i', 0.01) // Round for display
	*format n_`i' %6.2f
	}

	* Rename variables. a=arrival. 
	rename n_1 a_ChildrenCustodyAndMaintenance
	rename n_2 a_CivilAppeals 
	rename n_3 a_CivilCases 
	rename n_4 a_CommercialCases  
	rename n_5 a_CriminalCases
	rename n_6 a_DivorceAndSeparation 
	rename n_7 a_EmploymentAndLabourRelations
	rename n_8 a_EnvironmentAndLandCases
	rename n_9 a_FamilyAppeals  
	rename n_10 a_FamilyMiscellaneous
	rename n_11 a_MatrimonialPropertyCases
	rename n_12 a_Succession

/*
gen ad_ChildrenCustodyAndMaintenance = a_ChildrenCustodyAndMaintenance * 54.88 * 12 * 30
gen ad_CivilAppeals = a_CivilAppeals * 113.14 * 12 * 30
gen ad_CivilCases = a_CivilCases * 98.78 * 12 * 30
gen ad_CommercialCases = a_CommercialCases * 144.49 * 12 * 30
gen ad_CriminalCases = a_CriminalCases * 36 * 12 * 30
gen ad_DivorceAndSeparation = a_DivorceAndSeparation * 66.7 * 12 * 30
gen ad_EmploymentAndLabourRelations = a_EmploymentAndLabourRelations * 105.75 * 12 * 30
gen ad_EnvironmentAndLandCases = a_EnvironmentAndLandCases * 91.2 * 12 * 30
gen ad_FamilyAppeals = a_FamilyAppeals * 98.09 * 12 * 30
gen ad_FamilyMiscellaneous = a_FamilyMiscellaneous * 71.54 * 12 * 30
gen ad_MatrimonialPropertyCases = a_MatrimonialPropertyCases * 124.54 * 12 * 30
gen ad_Succession = a_Succession * 74.46 * 12 * 30

drop a_* //temp
*/

	* Rename to merge with number of mediators
	rename courtstation cs
	decode cs, gen(courtstation)
	drop cs

	replace courtstation = "MUKURWEINI" if courtstation == "MUKURWE-INI"
	replace courtstation = "MURANGA" if courtstation == "MURANG'A"
	replace courtstation = "WANGURU" if courtstation == "WANG'URU"
	replace courtstation = "MTITOANDEI" if courtstation == "MTITO ANDEI"
	
	tempfile data_arrivals
	save `data_arrivals'
	
/*******************************************************************************
	 TABLE: SHARED MEDIATORS ACCROSS COURTSTATIONS
	 - Save in excel two sheets. One with percent of mediators shared accross
	 courtstations, the other with the numbers
*******************************************************************************/
	
	use `data_med', clear
	
	keep cs*
	drop cs
	*gen ccss = ""
	
	* Initialize excel save
	qui putexcel set "`path'\Output\Arrivals_vs_Mediators\Arrivals_vs_Mediators.xlsx", ///
	sheet("Num shared med") replace
	qui putexcel set "`path'\Output\Arrivals_vs_Mediators\Arrivals_vs_Mediators.xlsx", ///
	sheet("Pct shared med") modify

	
	* Add courtstation names in rows and columns
	matrix B = J(`cs_num',`cs_num'+1,.) // Create an empty matrix of 
									  // size cs_num x cs_num 
	matrix colnames B  = "Num mediators" `cs_list' // courstations names as 
												   // column names 
	matrix rownames B  = `cs_list' // courstations names as row names 
	qui putexcel A2 = matrix(B), rownames // Save 
	qui putexcel B1 = matrix(B), colnames // Save 
	qui putexcel set "`path'\Output\Arrivals_vs_Mediators\Arrivals_vs_Mediators.xlsx", ///
	sheet("Num shared med") modify
	qui putexcel A2 = matrix(B), rownames // Save 
	qui putexcel B1 = matrix(B), colnames // Save 
	
	
	* Initialize matrix 
	matrix A = J(1,`cs_num'+1,.) // 1-row-matrix that will save the shared 
								 // mediators of courtsation
	matrix C = J(1,`cs_num'+1,.) // 1-row-matrix that will save the shared 
								 // mediators of courtsation
						  
	local nnum = 1 // "cc" courtstation indicator
	foreach cc of local cs_list{ // For all courstations

		local nnum = `nnum' + 1
	
		preserve
		
		* Keep only mediators that work in courtstation "cc"
		qui keep if cs1 == "`cc'" | cs2 == "`cc'" | cs3 == "`cc'" | ///
		cs4 =="`cc'" | cs5 == "`cc'" | cs6 == "`cc'" | cs7 == "`cc'" | ///
		cs8 == "`cc'" | cs9 == "`cc'" | cs10 == "`cc'" | cs11 == "`cc'" | ///
		cs12== "`cc'" | cs13 == "`cc'" | cs14 == "`cc'" | cs15 == "`cc'" | ///
		cs16 == "`cc'" | cs17 == "`cc'"
		
		* Gen number of mediators in the courtstation "cc"
		gen num_mediators = _N
		
		
		local num = 1
			* Number of mediators shared with each courtstation "c"
			foreach c of local cs_list{
			local num = `num' + 1
			egen num_`c' = sum(cs1 == "`c'" | cs2 == "`c'" | cs3 == "`c'" | ///
			cs4 == "`c'" | cs5 == "`c'" | cs6 == "`c'" | cs7 == "`c'" | ///
			cs8 == "`c'" | cs9 == "`c'" | cs10 == "`c'" | cs11 == "`c'" | ///
			cs12== "`c'" | cs13 == "`c'" | cs14 == "`c'" | cs15 == "`c'" | ///
			cs16 == "`c'" | cs17 == "`c'")
			* Fill row matrix with results
			qui summ num_`c'
			local mm = r(mean)
			qui matrix A[1,`num'] = `mm'
			
			
			* Pct of mediators shared
			gen pct_`c' = num_`c' / num_mediators
			qui summ pct_`c'
			local nn = r(mean)
			qui matrix C[1,`num'] = `nn'
			}
	qui putexcel set "`path'\Output\Arrivals_vs_Mediators\Arrivals_vs_Mediators.xlsx", ///
	sheet("Num shared med") modify
	qui putexcel B`nnum' = matrix(A)
	qui putexcel B`nnum' = num_mediators
	qui putexcel set "`path'\Output\Arrivals_vs_Mediators\Arrivals_vs_Mediators.xlsx", ///
	sheet("Pct shared med") modify
	qui putexcel B`nnum' = matrix(C)
	qui putexcel B`nnum' = num_mediators
	
	restore
	}
	
	* Final notes to explain the table
	local nnumm = `nnum' + 2
	qui putexcel set "`path'\Output\Arrivals_vs_Mediators\Arrivals_vs_Mediators.xlsx", ///
	sheet("Pct shared med") modify
	qui putexcel A`nnumm' = "Note: The second column contains the number of mediators in each courstation of the first column. The other cells contain the percent of mediators of row X that are also present in column Y. Notice no symmetry."
	qui putexcel set "`path'\Output\Arrivals_vs_Mediators\Arrivals_vs_Mediators.xlsx", ///
	sheet("Num shared med") modify
	qui putexcel A`nnumm' = "Note: The second column contains the number of mediators in each courstation of the first column. The other cells contain the number of mediators of row X that are also present in column Y. Notice symmetry."

	
/*******************************************************************************
	 TABLE: NUMBER OF MEDIATORS WITH EACH ACCREDITATION BY COURT
*******************************************************************************/

	use `data_med', clear

*** Gen number of mediators by courtstation and accreditation
	foreach court of local cs_list{
	local num = 0
	foreach accred of local accr_list{
	local num = `num' + 1
	
	* Number of mediatiors by court and accreditation
	egen n_`court'`num' = sum( (cs1=="`court'" | cs2=="`court'" | ///
	cs3=="`court'" | cs4=="`court'" | cs5=="`court'" | cs6=="`court'" | ///
	cs7=="`court'" | cs8=="`court'" | cs9=="`court'" | cs10=="`court'" | ///
	cs11=="`court'" | cs12=="`court'" | cs13=="`court'" | cs14=="`court'" | ///
	cs15=="`court'" | cs16=="`court'" | cs17=="`court'")  & ///
	///
	(accr1 == "`accred'" | accr2 == "`accred'" | accr3 == "`accred'" | ///
	accr4 == "`accred'" | accr5 == "`accred'" | accr6 == "`accred'" | ///
	accr7 == "`accred'" | accr8 == "`accred'" | accr9 == "`accred'" | ///
	accr10 == "`accred'") )
	}
	}

*** Simplify data. Get rid of unnecessary info
	keep n_* // Keep only the relevant variables
	keep if _n == 1 // Only one observation is enough (contains all info)

*** Reshape: Each observation becomes an accreditation, variables are 
	* courtstations
	gen ii = 1 // Need one indicator
	display `cs_list_n'
	reshape long `cs_list_n', i(ii) j(accreditation)

*** Transpose: Each observation becomes a courtstation, variables are accred
	xpose , varname  clear
	drop if _n==1 | _n == 2 // These 2 don't contain courtstations info
	rename _varname courtstation
	* Get rid of "n_" in the names of courtstation 
	split courtstation, p("_")
	drop courtstation1 courtstation
	rename courtstation2 courtstation

*** Rename variables by informative names (case types)
	rename v1 Children
	rename v2 Civil
	rename v3 Commercial
	rename v4 Copyright
	rename v5 Employment
	rename v6 Environment
	rename v7 Family
	rename v8 Labor
	rename v9 Land
	rename v10 Tribunal

*** Export excel with mediators by courstation
	order courtstation
	export excel "`path'/Output/Arrivals_vs_Mediators/Arrivals_vs_Mediators.xlsx", sheet("Meds court accred", modify) firstrow(variables) 

/*******************************************************************************
	 TABLE: NUMBER OF MEDIATORS THAT CAN WORK IN EACH CASE TYPE BY COURTSATION
*******************************************************************************/

	use `data_med', clear

*** Create variables that indicate if a mediator can work in each case type
	* Children custody and maintenance
	gen ChildrenCustodyAndMaintenance = 1 if strpos(accr, "Children") | ///
	strpos(accr, "Family")
	replace ChildrenCustodyAndMaintenance=0 if ChildrenCustodyAndMaintenance ==.
	* Civil appeals
	gen CivilAppeals = 1 if strpos(accr, "Civil") 
	replace CivilAppeals = 0 if CivilAppeals ==.
	* Civil cases
	gen CivilCases  = 1 if strpos(accr, "Civil")
	replace CivilCases = 0 if CivilCases ==.
	* Commercial cases
	gen CommercialCases = 1 if strpos(accr, "Commercial")
	replace CommercialCases = 0 if CommercialCases ==.
	* Criminal cases
	gen CriminalCases =1 if strpos(accr, "Children") | strpos(accr, "Civil") ///
	| strpos(accr, "Commercial") | strpos(accr, "Copyright") | ///
	strpos(accr, "Employment") | strpos(accr, "Environment") | ///
	strpos(accr, "Family") | strpos(accr, "Labor") | strpos(accr, "Land") 
	replace CriminalCases = 0 if CriminalCases ==.
	* Divorce and separation
	gen DivorceAndSeparation = 1 if strpos(accr, "Family")
	replace DivorceAndSeparation = 0 if DivorceAndSeparation ==.
	* Employment and labour relations
	gen EmploymentAndLabourRelations = 1 if strpos(accr, "Employment") | ///
	strpos(accr, "Labor")
	replace EmploymentAndLabourRelations = 0 if EmploymentAndLabourRelations ==.
	* Environment and land cases
	gen EnvironmentAndLandCases = 1 if strpos(accr, "Environment") | ///
	strpos(accr, "Land")
	replace EnvironmentAndLandCases = 0 if EnvironmentAndLandCases ==.
	* Family appeals
	gen FamilyAppeals  = 1 if strpos(accr, "Family")
	replace FamilyAppeals = 0 if FamilyAppeals ==.
	* Family miscellaneous
	gen FamilyMiscellaneous = 1 if strpos(accr, "Family")
	replace FamilyMiscellaneous = 0 if FamilyMiscellaneous ==.
	* Matrimonial property cases
	gen MatrimonialPropertyCases = 1 if strpos(accr, "Civil") | ///
	strpos(accr, "Family")
	replace MatrimonialPropertyCases = 0 if MatrimonialPropertyCases ==.
	* Succession
	gen Succession = 1 if strpos(accr, "Civil") | strpos(accr, "Family")
	replace Succession = 0 if Succession ==.
	* Judicial Review
	gen JudicialReview = 1 if strpos(accr, "Civil") 
	replace JudicialReview = 0 if JudicialReview ==.
	* Constitution and Human Rights
	gen ConstitutionHR = 1 if strpos(accr, "Civil") 
	replace ConstitutionHR = 0 if ConstitutionHR ==.
	* Anti-Corruption
	gen AntiCorruption = 1 if strpos(accr, "Civil") 
	replace AntiCorruption = 0 if AntiCorruption ==.
	
	/*
	gen num_casetypes = ChildrenCustodyAndMaintenance + CivilAppeals + ///
	CivilCases + CommercialCases + CriminalCases + DivorceAndSeparation + ///
	EmploymentAndLabourRelations + EnvironmentAndLandCases + FamilyAppeals + ///
	FamilyMiscellaneous + MatrimonialPropertyCases + Succession
	
	gen aa = (30*12*3) / (num_casetypes*numberofcourtstations)
	replace aa = 0 if aa ==.*/
	
*** Gen number of mediators by courtstation and case type
	foreach court of local cs_list{
	local num = 0
	foreach type of local ct_list_n {
	local num = `num' + 1

	* Number of mediatiors by court and case type
	egen n_`court'`num' = sum( (cs1=="`court'" | cs2=="`court'" | ///
	cs3=="`court'" | cs4=="`court'" | cs5=="`court'" | cs6=="`court'" | ///
	cs7=="`court'" | cs8=="`court'" | cs9=="`court'" | cs10=="`court'" | ///
	cs11=="`court'" | cs12=="`court'" | cs13=="`court'" | cs14=="`court'" | ///
	cs15=="`court'" | cs16=="`court'" | cs17=="`court'")  & ///
	(`type' ==1 ) )
	
	
	*egen ndd_`court'`num' = sum( aa ) if (cs1=="`court'" | cs2=="`court'" | cs3=="`court'" | cs4=="`court'" | cs5=="`court'" | cs6=="`court'" | cs7=="`court'" | cs8=="`court'" | cs9=="`court'" | cs10=="`court'" | cs11=="`court'" | cs12=="`court'" | cs13=="`court'" | cs14=="`court'" | cs15=="`court'" | cs16=="`court'" | cs17=="`court'")  & ///
	*(`type' ==1 )
	
	*egen nd_`court'`num' = mean(ndd_`court'`num')
	*replace nd_`court'`num' = 0 if nd_`court'`num' ==.
	*drop ndd_`court'`num'
}
}

	*** Simplify
	keep n_* // nd_* // Keep only relevant variables
	keep if _n == 1 // Only one observation is enough

	*** Reshape: Each observation becomes one case type, each variable a 
	* courtstation
	gen ii = 1 // Need one indicator
	reshape long `cs_list_n', i(ii) j(type)
/*nd_BARICHO nd_BOMET nd_BONDO nd_BUNGOMA nd_BUSIA nd_BUTALI nd_BUTERE nd_CHUKA nd_ELDAMARAVINE nd_ELDORET nd_EMBU nd_GARISSA nd_GARSEN nd_GATUNDU nd_GICHUGU nd_GITHONGO nd_GITHUNGURI nd_HAMISI nd_HOMABAY nd_ISIOLO nd_ITEN nd_JKIA nd_KABARNET nd_KABIYET nd_KAHAWA nd_KAJIADO nd_KAKAMEGA nd_KAKUMA nd_KALOLENI nd_KANGUNDO nd_KANDARA nd_KAPENGURIA nd_KAPSABET nd_KARATINA nd_KEHANCHA nd_KENOL nd_KERICHO nd_KEROKA nd_KERUGOYA nd_KIAMBU nd_KIBERA nd_KIKUYU nd_KILGORIS nd_KILIFI nd_KIMILILI nd_KILUNGU nd_KISII nd_KISUMU nd_KITALE nd_KITHIMANI nd_KITUI nd_KWALE nd_LAMU nd_LIMURU nd_LODWAR nd_MACHAKOS nd_MAKADARA nd_MAKINDU nd_MAKUENI nd_MALINDI nd_MARARAL nd_MARIAKANI nd_MANDERA nd_MASENO nd_MAVOKO nd_MERU nd_MIGORI nd_MILIMANI nd_MOLO nd_MOMBASA nd_MUKURWEINI nd_MUMIAS nd_MURANGA nd_NAIVASHA nd_NAKURU nd_NANYUKI nd_NAROK nd_NDHIWA nd_NGONG nd_NKUBU nd_NYAHURURU nd_NYAMIRA nd_NYERI nd_OGEMBO nd_OLKALOU nd_OTHAYA nd_OYUGIS nd_RONGO nd_RUIRU nd_RUMURUTI nd_RUNYENJES nd_SHANZU nd_SIAKAGO nd_SIAYA nd_SOTIK nd_TAVETA nd_THIKA nd_TONONOKA nd_UKWALA nd_VIHIGA nd_VOI nd_WAJIR nd_WEBUYE nd_WINAM nd_WUNDANYI nd_KIGUMO nd_MAUA nd_MSAMBWENI nd_NYANDO nd_TIGANIA*/

	*** Transpose: Each observation becomes a courtstation, variables casetypes
	xpose , varname  clear
	drop if _n==1 | _n == 2 // These 2 don't contain courtstations info
	rename _varname courtstation
	* Get rid of "n_" in the names of courtstation 
	split courtstation, p("_") 
	*drop if courtstation1 == "n" // temp
	drop courtstation1 courtstation
	rename courtstation2 courtstation

	*** Rename variables by informative names (case types)
	rename v1 ChildrenCustodyAndMaintenance
	rename v2 CivilAppeals
	rename v3 CivilCases
	rename v4 CommercialCases
	rename v5 CriminalCases
	rename v6 DivorceAndSeparation
	rename v7 EmploymentAndLabourRelations
	rename v8 EnvironmentAndLandCases
	rename v9 FamilyAppeals 
	rename v10 FamilyMiscellaneous
	rename v11 MatrimonialPropertyCases
	rename v12 Succession
	rename v13 JudicialReview
	rename v14 ConstitutionHR
	rename v15 AntiCorruption

	* Save excel
	order courtstation
	export excel "`path'/Output/Arrivals_vs_Mediators/Arrivals_vs_Mediators.xlsx", sheet("Meds court casetype", modify) firstrow(variables)

	tempfile data_med_csct
	save `data_med_csct'


/*****************************************************************
	 TABLE: ARRIVALS
******************************************************************/
	
	use `data_arrivals', clear
	order courtstation
	export excel "`path'/Output/Arrivals_vs_Mediators/Arrivals_vs_Mediators.xlsx", sheet("Arrivals court casetype", modify) firstrow(variables) 

/*****************************************************************
	 TABLE: NUMBER OF MEDIATORS THAT CAN WORK IN EACH CASE TYPE BY COURTSATION + ARRIVALS
******************************************************************/


	use `data_arrivals', clear
	
	merge 1:1 courtstation using `data_med_csct'
/*

    Result                      Number of obs
    -----------------------------------------
    Not matched                            35
        from master                         0  (_merge==1)
        from using                         35  (_merge==2)

    Matched                                98  (_merge==3)
    -----------------------------------------

* Master only = No case has arrived for this time period
	MANDERA	
	LODWAR	
	LAMU	
	OLKALOU	
	WAJIR	
	JKIA	
	KILUNGU	
	ELDAMARAVINE	
	MAKADARA	
	BUTERE	
	KAHAWA	
	RUMURUTI	
	SHANZU	
	MARARAL	
	KAKUMA	
	KEHANCHA	
*/
	*drop if _merge !=3
	*drop _merge

	
* Header
	file open tab_arrivalsvsmediator using "`path'//Output/Arrivals_vs_Mediators/Arrivals_vs_Mediators.tex", write text replace
	file write tab_arrivalsvsmediator "\begin{tabular}{lcccccccccccc}" _n
	file write tab_arrivalsvsmediator "\toprule"  _n
	file write tab_arrivalsvsmediator "& & & & & & \textbf{Case Type} \\" _n
	file write tab_arrivalsvsmediator "  & Children & Civil & Civil & Commercial & Criminal & Divorce & Employment & Environment & Family & Family & Matrimonial & Succession  \\" _n
	file write tab_arrivalsvsmediator " \textbf{Court station}  &  & appeals & cases & & &  & & and land & appeals & miscellaneous  \\" _n
	file write tab_arrivalsvsmediator "\midrule" _n
	
	* Body
	local ctypes ChildrenCustodyAndMaintenance CivilAppeals CivilCases ///
	CommercialCases CriminalCases DivorceAndSeparation ///
	EmploymentAndLabourRelations EnvironmentAndLandCases ///
	FamilyAppeals FamilyMiscellaneous MatrimonialPropertyCases Succession
	di `cs_list'
foreach i of local cs_list {
foreach j of local ctypes {	

	* Number of mediators
	summ `j' if courtstation == "`i'"
	local X_`j' = string(`r(mean)')
	
	* Number of arrivals
	replace a_`j' = 0 if a_`j' ==.
	summ a_`j' if courtstation == "`i'"
	*summ ad_`j' if courtstation == "`i'"
	local Y_`j' = string(`r(mean)')
	
	
	*local Z_`j' = `X_`j'' / `Y_`j'' 
	di `Y_`j''
	di `X_`j''
	*di `Z_`j''
}
file write tab_arrivalsvsmediator "`i'" `" & `Y_ChildrenCustodyAndMaintenance' (`X_ChildrenCustodyAndMaintenance')  & `Y_CivilAppeals'  (`X_CivilAppeals')  & `Y_CivilCases' (`X_CivilCases')  & `Y_CommercialCases' (`X_CommercialCases')  & `Y_CriminalCases' (`X_CriminalCases')  & `Y_DivorceAndSeparation' (`X_DivorceAndSeparation')  & `Y_EmploymentAndLabourRelations' (`X_EmploymentAndLabourRelations')  & `Y_EnvironmentAndLandCases' (`X_EnvironmentAndLandCases')  & `Y_FamilyAppeals' (`X_FamilyAppeals')  &  `Y_FamilyMiscellaneous' (`X_FamilyMiscellaneous')  & `Y_MatrimonialPropertyCases' (`X_MatrimonialPropertyCases')  & `Y_Succession' (`X_Succession')  \\ "' _n

*& `Y_JudicialReview' (`X_JudicialReview') & `Y_ConstitutionHR' (`X_ConstitutionHR') & `Y_AntiCorruption' (`X_AntiCorruption')

*file write tab_arrivalsvsmediator "`i'" `" & `Z_ChildrenCustodyAndMaintenance'   & `Z_CivilAppeals'    & `Z_CivilCases'   & `Z_CommercialCases'  & `Z_CriminalCases' & `Z_DivorceAndSeparation'   & `Z_EmploymentAndLabourRelations'   & `Z_EnvironmentAndLandCases'  & `Z_FamilyAppeals'   &  `Z_FamilyMiscellaneous'  & `Z_MatrimonialPropertyCases'   & `Z_Succession'	 \\ "' _n
	
}
	
	* Bottom
	file write tab_arrivalsvsmediator "\bottomrule" _n
	file write tab_arrivalsvsmediator "\end{tabular}"
	file close tab_arrivalsvsmediator
	

	
/*****************************************************************
	FIGURES
******************************************************************/
/*
	tw scatter a_ChildrenCustodyAndMaintenance ChildrenCustodyAndMaintenance, xtitle("Active mediators available") ytitle("Mean monthly arrivals") title(Children custody and maintenance) name(child)
	tw scatter a_CivilAppeals CivilAppeals, xtitle("Active mediators available") ytitle("Mean monthly arrivals") title(Civil appeals) name(civilapp)
	tw scatter a_CivilCases CivilCases, xtitle("Active mediators available") ytitle("Mean monthly arrivals") title(Civil cases) name(civilcas)
	
	tw scatter a_CommercialCases CommercialCases, xtitle("Active mediators available") ytitle("Mean monthly arrivals") title(Commercial cases) name(commercial)
	tw scatter a_CriminalCases CriminalCases, xtitle("Active mediators available") ytitle("Mean monthly arrivals") title(Criminal cases) name(criminal)
	tw scatter a_DivorceAndSeparation DivorceAndSeparation, xtitle("Active mediators available") ytitle("Mean monthly arrivals") title(Divorce and separation) name(divorce)
	tw scatter a_EmploymentAndLabourRelations EmploymentAndLabourRelations, xtitle("Active mediators available") ytitle("Mean monthly arrivals") title(Employment and labour relations) name(empl)
	tw scatter a_EnvironmentAndLandCases EnvironmentAndLandCases, xtitle("Active mediators available") ytitle("Mean monthly arrivals") title(Environment and land cases) name(envir)
	
	tw scatter a_FamilyAppeals FamilyAppeals, xtitle("Active mediators available") ytitle("Mean monthly arrivals") title(Family appeals) name(familyapp)
	tw scatter a_FamilyMiscellaneous FamilyMiscellaneous, xtitle("Active mediators available") ytitle("Mean monthly arrivals") title(Family miscellaneous) name(familymisc)
	tw scatter a_MatrimonialPropertyCases MatrimonialPropertyCases, xtitle("Active mediators available") ytitle("Mean monthly arrivals") title(Matrimonial property cases) name(matrimprop)
	tw scatter a_Succession Succession, xtitle("Active mediators available") ytitle("Mean monthly arrivals") title(Succession) name(success)

	gr combine child civilapp civilcas commercial criminal divorce empl envir familyapp familymisc matrimprop success
	graph export "`path'\Output\Arrivals_vs_Mediators\arrivals_vs_mediators_scatter.png", width(8000) replace
	
	
*courtstation
*"BARICHO" "BOMET" "BONDO" "BUNGOMA" "BUSIA" "BUTALI" "CHUKA" "ELDORET" "EMBU" "GARISSA" "GARSEN" "GATUNDU" "GICHUGU" "GITHONGO" "GITHUNGURI" "HAMISI" "HOMABAY" "ISIOLO" "ITEN" "KABARNET" "KAJIADO" "KAKAMEGA" "KALOLENI" "KANDARA" "KANGUNDO" "KAPENGURIA" "KAPSABET" "KARATINA" "KENOL" "KERICHO" "KEROKA" "KERUGOYA" "KIAMBU" "KIBERA" "KIGUMO" "KIKUYU" "KILGORIS" "KILIFI" "KIMILILI" "KISII" "KISUMU" "KITALE" "KITHIMANI" "KITUI" "KWALE" "LIMURU" "MACHAKOS" "MAKINDU" "MAKUENI" "MALINDI" "MARIAKANI" "MASENO" "MAUA" "MAVOKO" "MERU" "MIGORI" "MILIMANI" "MOLO" "MOMBASA" "MSAMBWENI" "MUKURWEINI" "MUMIAS" "MURANGA" "NAIVASHA" "NAKURU" "NANYUKI" "NAROK" "NDHIWA" "NGONG" "NKUBU" "NYAHURURU" "NYAMIRA" "NYANDO" "NYERI" "OGEMBO" "OTHAYA" "OYUGIS" "RONGO" "RUIRU" "RUNYENJES" "SIAKAGO" "SIAYA" "SOTIK" "TAVETA" "THIKA" "TIGANIA" "TONONOKA" "UKWALA" "VIHIGA" "VOI" "WEBUYE" "WINAM" "WUNDANYI"
	
	
	local cs `" "BARICHO" "BOMET" "BONDO" "BUNGOMA" "BUSIA" "BUTALI" "CHUKA" "ELDORET" "EMBU" "GARISSA" "GARSEN" "GATUNDU" "GICHUGU" "GITHONGO" "GITHUNGURI" "HAMISI" "HOMABAY" "ISIOLO" "ITEN" "KABARNET" "KAJIADO" "KAKAMEGA" "KALOLENI" "KANDARA" "KANGUNDO" "KAPENGURIA" "KAPSABET" "KARATINA" "KENOL" "KERICHO" "KEROKA" "KERUGOYA" "KIAMBU" "KIBERA" "KIGUMO" "KIKUYU" "KILGORIS" "KILIFI" "KIMILILI" "KISII" "KISUMU" "KITALE" "KITHIMANI" "KITUI" "KWALE" "LIMURU" "MACHAKOS" "MAKINDU" "MAKUENI" "MALINDI" "MARIAKANI" "MASENO" "MAUA" "MAVOKO" "MERU" "MIGORI" "MILIMANI" "MOLO" "MOMBASA" "MSAMBWENI" "MUKURWEINI" "MUMIAS" "MURANGA" "NAIVASHA" "NAKURU" "NANYUKI" "NAROK" "NDHIWA" "NGONG" "NKUBU" "NYAHURURU" "NYAMIRA" "NYANDO" "NYERI" "OGEMBO" "OTHAYA" "OYUGIS" "RONGO" "RUIRU" "RUNYENJES" "SIAKAGO" "SIAYA" "SOTIK" "TAVETA" "THIKA" "TIGANIA" "TONONOKA" "UKWALA" "VIHIGA" "VOI" "WEBUYE" "WINAM" "WUNDANYI" "'	
	


* Show table with available mediators & mean monthly arrivals.
* The table only includes courtstations in which there are currently active mediators and there has been a case arrival in the last 2 years

* RE-DO courtstations tables
* - Available mediators from mediators table. 

