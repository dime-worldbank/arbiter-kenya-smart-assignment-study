
version 17
clear all

*net install grc1leg, from( http://www.stata.com/users/vwiggins/)

//Defining locals 
local path "C:\Users\didac\Dropbox\Arbiter Research\Data analysis"
local datapull = "15062023" // "11062023" //"05102022" //  "27022023" 
local min_cases = 4 



*** Import and tempsave VA groups
import delimited "`path'\Output\va_groups_pull15062023.csv", clear
tempfile va_groups
save `va_groups'



/*****************************************************************
	 Smart Assignment
******************************************************************/

*import delimited "`path'\Data_Raw\study_case_last_action_2024-03-13T09_25_08.693152Z.csv", clear

import delimited "`path'\Data_Raw\Vw_All_Random_Study_Case_20032024.csv", clear

drop if istest == "true" // Drop technical testing cases


/*****************************************************************
	 Smart Assignment
******************************************************************/

*** Pct rejected by appointer
preserve

drop if rejectreason == "COURT_NAMED" | rejectreason == "PARTIES_REQUESTED"

egen appointer_count = count(acceptanceorerrorstatus) if acceptanceorerrorstatus=="rejected" | acceptanceorerrorstatus=="accepted", by(appointeruserid)
egen appointer_rejcount = count(acceptanceorerrorstatus) if acceptanceorerrorstatus=="rejected", by(appointeruserid)
egen appointer_rejcountt = mean(appointer_rejcount), by(appointeruserid)
replace appointer_rejcountt = 0 if appointer_rejcountt ==.
gen appointer_pctrej = appointer_rejcountt / appointer_count
drop if appointer_pctrej ==.

collapse appointer_pctrej appointer_rejcountt appointer_count, by(appointeruserid)
sort appointer_pctrej
restore 

/*
If we ignore cases in which all mediators were ineligible, and also the cases in which the rejection reason was "Court named" or "Parties requested", we see that court officers generally accepted the Smart Assignment recommendations. Even though there are some exceptions of Court Officers rejecting more than others. I attach here the list with the percent of rejection by Appointing court officer
*/


/*
6 missing appointeruserid
*/


tab group if acceptanceorerrorstatus == "accepted"

/*
      Group |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |        114       48.72       48.72
          1 |        120       51.28      100.00
------------+-----------------------------------
      Total |        234      100.00
*/

tab group if acceptanceorerrorstatus == "rejected"

/*

      Group |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |         65       51.18       51.18
          1 |         62       48.82      100.00
------------+-----------------------------------
      Total |        127      100.00
	  
*/


summ recommendationrank if group == 0 & acceptanceorerrorstatus == "accepted"
summ recommendationrank if group == 1 & acceptanceorerrorstatus == "accepted"

*** All inelegible
tab courtstation if acceptanceorerrorstatus == "all ineligible"
sort acceptanceorerrorstatus courtstation

/*

      Court |
    Station |      Freq.     Percent        Cum.
------------+-----------------------------------
      BOMET |         27       65.85       65.85
    ELDORET |          7       17.07       82.93
      KISII |          1        2.44       85.37
     OTHAYA |          5       12.20       97.56
    SIAKAGO |          1        2.44      100.00
------------+-----------------------------------
      Total |         41      100.00

- All Bomet same referraldate, all in control. 
- 39 cases in Bomet
	  
*/

*** Active mediators in BOMET
import delimited "`path'\Data_Raw\Vw_all_mediators_20032024.csv", clear
rename id mediator_id

rename courtstations cs_
split cs_, p(", ")

keep if cs_1 =="BOMET" | cs_2 =="BOMET" | cs_3 =="BOMET" | cs_4 =="BOMET" | cs_5 =="BOMET" | cs_6 =="BOMET" | cs_7 =="BOMET" | cs_8 =="BOMET" | cs_9 =="BOMET" | cs_10 =="BOMET" | cs_11 =="BOMET" | cs_12 =="BOMET" | cs_13 =="BOMET" | cs_14 =="BOMET" | cs_15 =="BOMET" | cs_16 =="BOMET" | cs_17 =="BOMET"


	* Merge with active-inactive changes
	merge m:1 mediator_id using `va_groups'
	drop if _merge==1
	drop _merge
	
/*
11 Smart assignment mediators in Bomet
9 Treatment (8 active). 2 Control (1 active). Active status checked March 20.
2 a
*/