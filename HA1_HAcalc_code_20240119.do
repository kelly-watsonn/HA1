
// PROJECT: Height-age as an alternative growth outcome
// PROGRAM: HA1_HAcalc_code_20240119
// TASK: EXAMPLE STATA CODE TO DETERMINE HEIGHT-AGE FROM MEAN LENGTH/HEIGHT
// CREATED BY: Kelly Watson, The Hospital for Sick Children
// DATE: January 19, 2024


/* Table of contents: 
PART 1: If access to individual participant data (IPD)
PART 2: If access to study-level data only and sex proportion known
PART 3: If access to study-level data only and sex proportion NOT known
*/

*****************************************
*****************************************

** PART 1: If access to IPD 

*** IPD preprocessing requirements: 
* Variables needed: length/height (cm), sex (male/female)
* Before generating height‐age, generate the summary mean length/height for your sample at an age of interest, disaggregated by sex

use "MYIPD.dta"
drop if Sex=="boys" 
save "MYIPD_girls.dta" // dataset with girls only 
ci means Length, level(95) // note the mean length with 95% CI for girls
clear // now creating new dataset with mean length values for girls
gen length = . // input noted length values (mean, 95% CI LB, 95% CI UB)  
gen label =. // input labels "mean", "95LB" and "95UB"
gen HA_days = .
gen row_count = _n 
save "MYIPD_girls_meanlength.dta"
clear

* Download the WHO‐GS LMS table for the 0‐5 year range (lenanthro.dta file from: https://github.com/unicef-drp/igrowup_update)

use "lenanthro.dta" // WHO-GS LMS table for 0-5 year range
drop if __000001 == 1 // dropping values for boys
gen merger = 1 // this variable is to help facilitate merging with the mean length/height data
save "lenanthro_girls.dta"

* Calculate mean height-age with 95% CIs from mean length with 95% CIs

forvalues counter = 1 (1) 3 {
use "MYIPD_girls_meanlength.dta", clear 
	gen merger = 1
	keep if row_count==`counter'
	joinby merger using "lenanthro_girls.dta"
	drop HA_days
	bysort _agedays: egen minabs_diff = min(abs(length - m)) 
	sort minabs_diff
	gen HA_days = _agedays[1]
	drop if _n != 1
	keep row_count HA_days 
	merge 1:1 row_count using "MYIPD_girls_meanlength.dta" 
	drop _merge
	save "MYIPD_girls_meanlength.dta", replace 
	clear
}

* REPEAT STEPS FOR BOYS *


*****************************************
*****************************************

** PART 2: If access to study-level data only and sex proportion known

*** Dataset preprocessing requirements: 
* Variables needed: length/height (mean, 95% CI UB, 95% CI LB) measured in (cm), proportion of males:females
* Before generating height‐age, generate proportion of girls (or boys) to generate a sex-weight WHO-GS LMS table

use "STDYLVL.dta" // dataset with mean length and 95% CI reported combining sex
gen girlsprop = # // input known proportion of girls in the sample
scalar girls_prop=girlsprop

use "lenanthro.dta", clear 
rename __000001 Sex
generate prop_m=m*girls_prop if Sex==2 // m adjusted for proportion of girls
replace prop_m=m*(1-girls_prop) if Sex==1 // m adjusted for proportion of boys
bysort _agedays: egen wt_m=sum(prop_m) // weighted average of "m"
generate prop_s=s*girls_prop if Sex==2 // s adjusted for proportion of girls
replace prop_s=s*(1-girls_prop) if Sex==1 // s adjusted for proportion of boys
bysort _agedays: egen wt_s=sum(prop_s) // weighted average of "s"
collapse (mean) l wt_m wt_s, by(_agedays)
rename wt_m m
rename wt_s s
gen merger =1 
save "lenanthro_wtd.dta", replace

* Calculate mean height-age with 95% CIs from mean length with 95% CIs

use "STDYLVL.dta"
gen HA_days = .
gen row_count = _n
save, replace 

forvalues counter = 1 (1) 3 {
use "STDYLVL.dta", clear 
	gen merger = 1
	keep if row_count==`counter'
	joinby merger using "lenanthro_wtd.dta"
	drop HA_days
	bysort _agedays: egen minabs_diff = min(abs(length - m)) 
	sort minabs_diff
	gen HA_days = _agedays[1]
	drop if _n != 1
	keep row_count HA_days 
	merge 1:1 row_count using "STDYLVL.dta" 
	drop _merge
	save "STDYLVL.dta", replace 
	clear
}


*****************************************
*****************************************

** PART 3: If access to study-level data only and sex proportion NOT known

*** Dataset preprocessing requirements: 
* Variables needed: length/height (mean, 95% CI UB, 95% CI LB) measured in (cm)
* Before generating height‐age, generate an overall WHO-GS LMS table, assuming an equal proportion of males to females in the sample

use "lenanthro.dta" 
collapse (mean) l m s, by(_agedays loh) // this collapses the dataset so that instead of having LMS by sex, we have LMS overall
gen merger = 1 
save "lenanthro_overall.dta"

* Calculate height-age using same code from step (2), but using "lenanthro_overall.dta" instead of "lenanthro_wtd.dta".
