/*******************************************************************************
	DURATION REGRESSIONS
*******************************************************************************/

	version 17
	clear all

	* Locals
	local path "C:\Users\didac\Dropbox\Arbiter Research\Data analysis"
	local datapull =  "02062024" //"05102022" // "15062023" // "11062023" //  


/*******************************************************************************
	IMPORT & PREPARE HISTORICAL DATA
*******************************************************************************/

	use "`path'/Data_Clean/cases_cleaned_all_`datapull'.dta"
	
*** Drop some cases with issues
	drop if issue1 ==1 | issue2 ==2 | issue3 ==3 | issue4 ==4 | issue5 ==5 
	
*** Standardize VA's
egen va_s_postSA_std = std(va_s_postSA)
	
/*******************************************************************************
	REGRESSION OF DURATION ON SEVERAL VARIABLES
*******************************************************************************/

	** No Interaction
	* No controls 
	eststo mod1: reg case_days_med i.case_outcome_agreement va_s_postSA_std, ///
	vce(robust)
	* Controls
	eststo mod2: reg case_days_med i.case_outcome_agreement  va_s_postSA_std ///
	i.appt_month_year i.casetype i.courttype i.courtstation i.referralmode, vce(robust)
	** Interaction
	* No controls 
	eststo mod3: reg case_days_med i.case_outcome_agreement va_s_postSA_std ///
	i.case_outcome_agreement#c. va_s_postSA_std, vce(robust)
	* Controls
	eststo mod4: reg case_days_med i.case_outcome_agreement va_s_postSA_std ///
	i.case_outcome_agreement#c. va_s_postSA_std /// 
	i.appt_month_year i.casetype i.courttype i.courtstation i.referralmode, vce(robust)

esttab mod1 mod2 mod3 mod4 using "`path'\Output\duration_reg.tex", se tex replace	
