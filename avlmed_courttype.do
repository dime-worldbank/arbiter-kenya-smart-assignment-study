version 17
clear all

//Defining locals 
local path "C:\Users\didac\Dropbox\Arbiter Research\Data analysis"


/*****************************************************************
	 
******************************************************************/

import delimited "`path'\Data_Raw\Vw_all_mediators_20032024.csv", clear

keep if status=="Active"

rename courtstations cs
rename accreditioncategories accr

split accr, p(", ")
split cs, p(", ")

* Fix court names that cannot become variable names
forvalues i=1(1)17{
	replace cs`i' = "ELDAMARAVINE" if cs`i' == "ELDAMA RAVINE"
	replace cs`i' = "MUKURWEINI" if cs`i' == "MUKURWE-INI"
	replace cs`i' = "MURANGA" if cs`i' == "MURANG'A"
	replace cs`i' = "OLKALOU" if cs`i' == "OL KALOU"
}



* Gen 
foreach court in "BARICHO" "BOMET" "BONDO"  "BUNGOMA" "BUSIA" "BUTALI" "BUTERE" "CHUKA" "ELDAMARAVINE" "ELDORET" "EMBU" "GARISSA" "GARSEN" "GATUNDU" "GICHUGU" "GITHONGO" "GITHUNGURI" "HAMISI" "HOMABAY" "ISIOLO" "ITEN" "JKIA" "KABARNET" "KABIYET" "KAHAWA" "KAJIADO" "KAKAMEGA" "KAKUMA" "KALOLENI" "KANGUNDO" "KANDARA" "KAPENGURIA" "KAPSABET" "KARATINA" "KEHANCHA" "KENOL" "KERICHO" "KEROKA" "KERUGOYA" "KIAMBU" "KIBERA" "KIKUYU" "KILGORIS" "KILIFI" "KIMILILI" "KILUNGU" "KISII" "KISUMU" "KITALE" "KITHIMANI" "KITUI" "KWALE" "LAMU" "LIMURU" "LODWAR" "MACHAKOS" "MAKADARA" "MAKINDU" "MAKUENI" "MALINDI" "MARARAL" "MARIAKANI" "MANDERA" "MASENO" "MAVOKO" "MERU" "MIGORI" "MILIMANI" "MOLO" "MOMBASA" "MUKURWEINI"  "MUMIAS" "MURANGA" "NAIVASHA" "NAKURU" "NANYUKI" "NAROK" "NDHIWA" "NGONG" "NYAHURURU" "NYAMIRA" "NYERI" "OGEMBO" "OLKALOU" "OTHAYA" "OYUGIS" "RONGO" "RUIRU" "RUMURUTI" "RUNYENJES"  "SHANZU" "SIAKAGO" "SIAYA" "SOTIK" "TAVETA" "THIKA" "TONONOKA" "UKWALA" "VIHIGA" "VOI" "WAJIR" "WEBUYE" "WINAM" "WUNDANYI"{
	
	foreach accred in "Children" "Civil" "Commercial" "Copyright" "Employment" "Environment" "Family" "Labor" "Land" "Tribunal" {
	
	if "`accred'" == "Children"{
		local num = 1
	}
	else if "`accred'" == "Civil"{
		local num = 2
	}
	else if "`accred'" == "Commercial"{
		local num = 3
	}
	else if "`accred'" == "Copyright"{
		local num = 4
	}
	else if "`accred'" == "Employment"{
		local num = 5
	}
	else if "`accred'" == "Environment"{
		local num = 6
	}
	else if "`accred'" == "Family"{
		local num = 7
	}
	else if "`accred'" == "Labor"{
		local num = 8
	}
	else if "`accred'" == "Land"{
		local num = 9
	}
	else if "`accred'" == "Tribunal"{
		local num = 10
	}
	
	/*local num = 1 if "`accred'" == "Civil"
	local num = 2 if "`accred'" == "Commercial"
	local num = 3 if "`accred'" == "Copyright"
	local num = 4 if "`accred'" == "Employment"
	local num = 5 if "`accred'" == "Environment"
	local num = 6 if "`accred'" == "Family"
	local num = 7 if "`accred'" == "Labor"
	local num = 8 if "`accred'" == "Land"
	local num = 9 if "`accred'" == "Tribunal"*/
		
	egen n_`court'_`num' = sum( (cs1=="`court'" | cs2=="`court'" | cs3=="`court'" | cs4=="`court'" | cs5=="`court'" | cs6=="`court'" | cs7=="`court'" | cs8=="`court'" | cs9=="`court'" | cs10=="`court'" | cs11=="`court'" | cs12=="`court'" | cs13=="`court'" | cs14=="`court'" | cs15=="`court'" | cs16=="`court'" | cs17=="`court'")  & ///
	(accr1 == "`accred'" | accr2 == "`accred'" | accr3 == "`accred'" | accr4 == "`accred'" | accr5 == "`accred'" | accr6 == "`accred'" | accr7 == "`accred'" | accr8 == "`accred'" | accr9 == "`accred'" | accr10 == "`accred'") )
}
}



keep n_*

gen ii = 1

keep if _n == 1


reshape long n_BARICHO_ n_BOMET_ n_BONDO_ n_BUNGOMA_ n_BUSIA_ n_BUTALI_ n_BUTERE_ n_CHUKA_ n_ELDAMARAVINE_ n_ELDORET_ n_EMBU_ n_GARISSA_ n_GARSEN_ n_GATUNDU_ n_GICHUGU_ n_GITHONGO_ n_GITHUNGURI_ n_HAMISI_ n_HOMABAY_ n_ISIOLO_ n_ITEN_ n_JKIA_ n_KABARNET_ n_KABIYET_ n_KAHAWA_ n_KAJIADO_ n_KAKAMEGA_ n_KAKUMA_ n_KALOLENI_ n_KANGUNDO_ n_KANDARA_ n_KAPENGURIA_ n_KAPSABET_ n_KARATINA_ n_KEHANCHA_ n_KENOL_ n_KERICHO_ n_KEROKA_ n_KERUGOYA_ n_KIAMBU_ n_KIBERA_ n_KIKUYU_ n_KILGORIS_ n_KILIFI_ n_KIMILILI_ n_KILUNGU_ n_KISII_ n_KISUMU_ n_KITALE_ n_KITHIMANI_ n_KITUI_ n_KWALE_ n_LAMU_ n_LIMURU_ n_LODWAR_ n_MACHAKOS_ n_MAKADARA_ n_MAKINDU_ n_MAKUENI_ n_MALINDI_ n_MARARAL_ n_MARIAKANI_ n_MANDERA_ n_MASENO_ n_MAVOKO_ n_MERU_ n_MIGORI_ n_MILIMANI_ n_MOLO_ n_MOMBASA_ n_MUKURWEINI_ n_MUMIAS_ n_MURANGA_ n_NAIVASHA_ n_NAKURU_ n_NANYUKI_ n_NAROK_ n_NDHIWA_ n_NGONG_ n_NYAHURURU_ n_NYAMIRA_ n_NYERI_ n_OGEMBO_ n_OLKALOU_ n_OTHAYA_ n_OYUGIS_ n_RONGO_ n_RUIRU_ n_RUMURUTI_ n_RUNYENJES_ n_SHANZU_ n_SIAKAGO_ n_SIAYA_ n_SOTIK_ n_TAVETA_ n_THIKA_ n_TONONOKA_ n_UKWALA_ n_VIHIGA_ n_VOI_ n_WAJIR_ n_WEBUYE_ n_WINAM_ n_WUNDANYI_, i(ii) j(accreditation)

tostring accreditation, replace
replace accreditation = "Children" if accreditation == "1"
replace accreditation = "Civil" if accreditation == "2"
replace accreditation = "Commercial" if accreditation == "3"
replace accreditation = "Copyright" if accreditation == "4"
replace accreditation = "Employment" if accreditation == "5"
replace accreditation = "Environment" if accreditation == "6"
replace accreditation = "Family" if accreditation == "7"
replace accreditation = "Labor" if accreditation == "8"
replace accreditation = "Land" if accreditation == "9"
replace accreditation = "Tribunal" if accreditation == "10"

drop ii 

export excel "`path'/Output/avlmed_courttype.xlsx", firstrow(variables) replace

/* 
keep n_*

"ELDAMA RAVINE"
"MUKURWE-INI"
"MURANG'A"
"OL KALOU"

* Works
foreach accred in "Civil" "Commercial" "Copyright" "Employment" "Environment" "Family" "Labor" "Land" "Tribunal" {
egen n_Milimani_`accred' = sum( (cs1=="MILIMANI" | cs2=="MILIMANI" | cs3=="MILIMANI" | cs4=="MILIMANI" | cs5=="MILIMANI" | cs6=="MILIMANI" | cs7=="MILIMANI" | cs8=="MILIMANI" | cs9=="MILIMANI" | cs10=="MILIMANI" | cs11=="MILIMANI" | cs12=="MILIMANI" | cs13=="MILIMANI" | cs14=="MILIMANI" | cs15=="MILIMANI" | cs16=="MILIMANI" | cs17=="MILIMANI")  & ///
(accr1 == "`accred'" | accr2 == "`accred'" | accr3 == "`accred'" | accr4 == "`accred'" | accr5 == "`accred'" | accr6 == "`accred'" | accr7 == "`accred'" | accr8 == "`accred'" | accr9 == "`accred'" | accr10 == "`accred'") )
}

egen n_Milimani_Civil = sum( (cs1=="MILIMANI" | cs2=="MILIMANI" | cs3=="MILIMANI" | cs4=="MILIMANI" | cs5=="MILIMANI" | cs6=="MILIMANI" | cs7=="MILIMANI" | cs8=="MILIMANI" | cs9=="MILIMANI" | cs10=="MILIMANI" | cs11=="MILIMANI" | cs12=="MILIMANI" | cs13=="MILIMANI" | cs14=="MILIMANI" | cs15=="MILIMANI" | cs16=="MILIMANI" | cs17=="MILIMANI") & ///
(accr1 == "Civil" | accr2 == "Civil" | accr3 == "Civil" | accr4 == "Civil" | accr5 == "Civil" | accr6 == "Civil" | accr7 == "Civil" | accr8 == "Civil" | accr9 == "Civil" | accr10 == "Civil") )



gen nmed = _N if, by(accreditioncategories1)


   
   
gen nmed_milimani = _N if courtstations1 == "Milimani"

BARICHO 
BOMET 
BONDO 
            BUNGOMA"
              BUSIA"
             BUTALI"
             BUTERE"
              CHUKA
      ELDAMA RAVINE
            ELDORET
               EMBU
            GARISSA |         18        1.22       35.75
             GARSEN |          7        0.47       36.23
            GATUNDU |         18        1.22       37.45
            GICHUGU |          1        0.07       37.52
           GITHONGO |          1        0.07       37.58
         GITHUNGURI |         24        1.63       39.21
            HOMABAY |         29        1.97       41.18
             ISIOLO |          8        0.54       41.72
               JKIA |          2        0.14       41.86
           KABARNET |          1        0.07       41.93
             KAHAWA |          1        0.07       41.99
            KAJIADO |         76        5.16       47.15
           KAKAMEGA |         47        3.19       50.34
           KALOLENI |          9        0.61       50.95
            KANDARA |          4        0.27       51.22
           KANGUNDO |          1        0.07       51.29
KANGUNDO DO NOT USE |          2        0.14       51.42
         KAPENGURIA |          1        0.07       51.49
           KAPSABET |          2        0.14       51.63
           KARATINA |         44        2.99       54.61
           KEHANCHA |          1        0.07       54.68
              KENOL |          2        0.14       54.82
            KERICHO |         14        0.95       55.77
             KEROKA |         25        1.70       57.46
           KERUGOYA |          8        0.54       58.01
             KIAMBU |        115        7.80       65.81
             KIBERA |          5        0.34       66.15
             KIKUYU |          4        0.27       66.42
           KILGORIS |          1        0.07       66.49
             KILIFI |         39        2.65       69.13
            KILUNGU |          1        0.07       69.20
              KISII |         58        3.93       73.13
             KISUMU |         30        2.04       75.17
             KITALE |          3        0.20       75.37
          KITHIMANI |          2        0.14       75.51
              KITUI |         28        1.90       77.41
              KWALE |          4        0.27       77.68
               LAMU |          2        0.14       77.82
             LIMURU |          1        0.07       77.88
           MACHAKOS |         66        4.48       82.36
           MAKADARA |          4        0.27       82.63
            MAKUENI |          1        0.07       82.70
            MALINDI |         14        0.95       83.65
             MAVOKO |          2        0.14       83.79
               MERU |          7        0.47       84.26
           MILIMANI |        176       11.94       96.20
               MOLO |          9        0.61       96.81
            MOMBASA |          9        0.61       97.42
           MURANG'A |          1        0.07       97.49
           NAIVASHA |          5        0.34       97.83
             NAKURU |         23        1.56       99.39
            NANYUKI |          2        0.14       99.53
            NYAMIRA |          1        0.07       99.59
              NYERI |          3        0.20       99.80
             TAVETA |          2        0.14       99.93
              THIKA |          1        0.07      100.00

			  
"BARICHO" "BOMET" "BONDO" "BUNGOMA" "BUSIA" "BUTALI" "BUTERE" "CHUKA" "ELDAMA RAVINE" "ELDORET" "EMBU" "GARISSA" "GARSEN" "GATUNDU" "GICHUGU" "GITHONGO" "GITHUNGURI" "HAMISI" "HOMABAY" "ISIOLO" "ITEN" "JKIA" "KABARNET" "KABIYET" "KAHAWA" "KAJIADO" "KAKAMEGA" "KAKUMA" "KALOLENI" "KANGUNDO" "KANDARA" "KAPENGURIA" "KAPSABET" "KARATINA" "KEHANCHA" "KENOL" "KERICHO" "KEROKA" "KERUGOYA" "KIAMBU" "KIBERA"  "KIKUYU" "KILGORIS" "KILIFI" "KIMILILI" "KILUNGU" "KISII" "KISUMU" "KITALE" "KITHIMANI" "KITUI" "KWALE" "LAMU" "LIMURU" "LODWAR" "MACHAKOS" "MAKADARA" "MAKINDU" "MAKUENI" "MALINDI" "MARARAL" "MARIAKANI" "MANDERA" "MASENO" "MAVOKO" "MERU" "MIGORI" "MILIMANI" "MOLO" "MOMBASA" "MUKURWE-INI" "MUMIAS" "MURANG'A" "NAIVASHA" "NAKURU" "NANYUKI" "NAROK" "NDHIWA" "NGONG" "NYAHURURU" "NYAMIRA" "NYERI" "OGEMBO" "OL KALOU" "OTHAYA" "OYUGIS" "RONGO" "RUIRU" "RUMURUTI" "RUNYENJES"  "SHANZU" "SIAKAGO" "SIAYA" "SOTIK" "TAVETA" "THIKA" "TONONOKA" "UKWALA" "VIHIGA" "VOI" "WAJIR" "WEBUYE" "WINAM" "WUNDANYI"



