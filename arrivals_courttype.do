version 17
clear all

//Defining locals 
local path "C:\Users\didac\Dropbox\Arbiter Research\Data analysis"

// Import data
use "`path'\Data_Clean\cases_cleaned_20032024", clear

keep if med_appt_date > date("20Jun2023","DMY")

egen numcas_courtstat_casetype = count(id), by(casetype court_station)

collapse numcas_courtstat_casetype, by(casetype courtstation)


rename numcas_courtstat_casetype n_
reshape wide n_, i(courtstation) j(casetype)

rename n_1 ChildrenCustodyAndMaintenance
rename n_2 CivilAppeals 
rename n_3 CivilCases 
rename n_4 CommercialCases  
rename n_5 CriminalCases
rename n_6 DivorceAndSeparation 
rename n_7 EmploymentAndLabourRelations
rename n_8 EnvironmentAndLandCases
rename n_9 FamilyAppeals  
rename n_10 FamilyMiscellaneous
rename n_11 MatrimonialPropertyCases
rename n_12 Succession

export excel "`path'/Output/arrivals_courttype.xlsx", firstrow(variables) replace


