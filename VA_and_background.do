version 17
clear all

*ssc install coefplot, replace
*ssc install outreg2

//Define locals 
local path "C:\Users\didac\Dropbox\Arbiter Research\Data analysis"
local datapull = "15062023" // "11062023" //"05102022" //  "27022023" 

/*******************************************************************************
	IMPORT AND PREPARE DATA
*******************************************************************************/

*** Shrunk VA
import delimited using "`path'\Output\va_groups_pull`datapull'.csv"
rename tv va_s
rename group_tv group_va_s
tempfile va_s_groups // tempfile for merge
save `va_s_groups'

*** Unhrunk VA
import delimited using "`path'\Output\va_u_groups_pull`datapull'.csv", clear
tempfile va_u_groups // tempfile for merge
save `va_u_groups'

*** Mediators main
import delimited using "`path'\Data_Raw\Vw_All_Mediators_31012023.csv", clear
gen age2 = age^2 // Age squared to be used in the regression
encode gender, gen(genderenc) // encode for regression
rename id mediator_id // rename for merge
tempfile med_main // tempfile for merge
save `med_main'

*** Mediators Professions simplified
import delimited using "`path'\Data_Raw\mediator_professions_amended_Anja.csv", clear
*encode profession_short, gen(profession_shortenc) // encode for regression
collapse (first) profession_short, by(professionid profession)
tempfile profession_matching
save `profession_matching'

*** Mediators Professions
import delimited using "`path'\Data_Raw\Vw_Mediators_Professions_31012023.csv", clear
	* Merge with info on professions simplified
	merge m:1 professionid using `profession_matching'
	drop _merge
rename mediatorid mediator_id // rename for merge
	* Drop duplicates of pressions per person
	duplicates drop mediator_id profession_short, force
		*duplicates tag mediator_id profession_short, generate(dup) // check
	encode profession_short, gen(profession_shortenc) 
	replace profession_shortenc = 0 if profession_shortenc ==.
	drop profession professionid createdat updatedat
	reshape wide profession_short, i(mediator_id) j(profession_shortenc)
	forvalues i=1(1)14{
		encode profession_short`i', gen(profession_short_`i') // encode for regression
		drop profession_short`i'
		replace profession_short_`i' = 0 if profession_short_`i' == .
	}

tempfile profession
save `profession'

*** Mediators Languages
import delimited using "`path'\Data_Raw\Vw_Mediators_Language_31012023.csv", clear
rename mediatorid mediator_id // rename for merge

egen numspeak = count(mediator_id), by(language) // Number of speakers
gen minlang = 1 if numspeak <100 // Minority language indicator
gen veryminlang = 1 if numspeak<20 // Very minority language indicator

encode language, gen(languageenc_) // encode for regression
replace languageenc_ = 43 if minlang == 1
replace languageenc_ = 44 if veryminlang == 1

drop language createdat updatedat numspeak minlang veryminlang languageid
duplicates drop mediator_id languageenc_, force

clonevar langenc_ = languageenc_
reshape wide langenc_, i(mediator_id) j(languageenc_)

foreach i in 10 11 12 14 18 31 39 43 44{
	replace langenc_`i' = 0 if langenc_`i' == .
}

tempfile language
save `language'

*** Mediators Religion
import delimited using "`path'\Data_Raw\Vw_Mediators_Religions_31012023.csv", clear
rename mediatorid mediator_id // rename for merge
tempfile religion // tempfile for merge
save `religion'

*** Merge all datasets except profession
merge 1:1 mediator_id using `med_main'
drop _merge
merge 1:1 mediator_id using `va_s_groups'
drop _merge
merge 1:1 mediator_id using `va_u_groups'
drop _merge
merge 1:1 mediator_id using `language'
drop _merge
merge 1:1 mediator_id using `profession'
drop _merge


*** Label variables
label var age2 "Age squared"

label var langenc_10 "Dholuo"
label var langenc_11 "Ekegusii"
label var langenc_12 "English"
label var langenc_14 "Gikuyu"
label var langenc_18 "Kamba"
label var langenc_31 "Oluluyia"
label var langenc_39 "Swahili"
label var langenc_43 "Minority language"
label var langenc_44 "Very minority language"

label var profession_short_1 "Administrative"
label var profession_short_2 "Business, Administration, Finance"
label var profession_short_3 "Clergy"
label var profession_short_4 "Counselling, Therapy, Coaching"
label var profession_short_5 "Education"
label var profession_short_6 "Engineering"
label var profession_short_7 "Farming, land management, resources management"
label var profession_short_8 "HR"
label var profession_short_9 "Humanities, Social Sciences, Research"
label var profession_short_10 "Legal, criminology"
label var profession_short_11 "Mediation related"
label var profession_short_12 "Medical, veterinary, nursing"
label var profession_short_13 "Penal system"
label var profession_short_14 "Training"

label define religionlab 1 "Christianity" 2 `"Islam"' 9 `"No religion"' 
label values religionid religionlab


/*******************************************************************************
	ANALYSIS: Regressions of VA on different covariates
*******************************************************************************/

drop langenc_12 // drop English
*drop profession_short_6 // Drop Engineering. No one with VA studied Engineering

*** Shrunk

* Reg 1: Only gender
reg va_s i1.genderenc if va_s !=., vce(robust)
outreg2 using "`path'\Output\Reg_background_VA.doc", replace label

* Reg 2: Gender + basic controls
reg va_s i1.genderenc age i.religionid if va_s !=., vce(robust)
outreg2 using "`path'\Output\Reg_background_VA.doc", append label

* Reg 3: Gender + basic controls + lang
reg va_s i1.genderenc age i.religionid langenc_* if va_s !=., vce(robust)
outreg2 using "`path'\Output\Reg_background_VA.doc", append label

* Reg 4: Gender + basic controls + prof
reg va_s i1.genderenc age i.religionid profession_short_* if va_s !=., vce(robust)
outreg2 using "`path'\Output\Reg_background_VA.doc", append label

* Reg 5: Gender + basic controls + lang + prof
reg va_s i1.genderenc age i.religionid langenc_* profession_short_* if va_s !=., vce(robust)
coefplot, drop(_cons) title(VA and background variables) subtitle(Shrunk VA)
graph export "`path'/Output/Background_VA_shrunk.png", as(png) replace
outreg2 using "`path'\Output\Reg_background_VA.doc", append label


*** Unshrunk

* Reg 1: Only gender
reg va_u i1.genderenc if va_u !=., vce(robust)
outreg2 using "`path'\Output\Reg_background_VA.doc", append label

* Reg 2: Gender + basic controls
reg va_u i1.genderenc age i.religionid if va_u !=., vce(robust)
outreg2 using "`path'\Output\Reg_background_VA.doc", append label

* Reg 3: Gender + basic controls + lang
reg va_u i1.genderenc age i.religionid langenc_* if va_u !=., vce(robust)
outreg2 using "`path'\Output\Reg_background_VA.doc", append label

* Reg 4: Gender + basic controls + prof
reg va_u i1.genderenc age i.religionid profession_short_* if va_u !=., vce(robust)
outreg2 using "`path'\Output\Reg_background_VA.doc", append label

* Reg 5: Gender + basic controls + lang + prof
reg va_u i1.genderenc age i.religionid langenc_* profession_short_* if va_u !=., vce(robust)
coefplot, drop(_cons) title(VA and background variables) subtitle(Unshrunk VA)
graph export "`path'/Output/Background_VA_unshrunk.png", as(png) replace
outreg2 using "`path'\Output\Reg_background_VA.doc", append label
