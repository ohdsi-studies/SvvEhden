SVVEHDEN modification of CohortDiagnostics
==========================================

Introduction
============
This is an R package based on the CohortDiagnostics package. All essential parts are the same. The CohortDiagnostics ais used for performing various study diagnostics, many of which are not specific to any particular study design.

How-to-prepare and run
=======================
Run the extras/RunCohortDiagnosticsAndViewResult.R script to create all cohorts and input needed for the Shiny app, as well as start the shiny app.

On UMC side thefollowing preprocessing steps must first to be done to create the input files needed for the RunCohortDiagnosticsAndViewResult.R:
	* The combinations list is fetched from the SignalData_EhdenStudyathonMiniSprint_2022Spring database
	* For all MedDRA PT events, phenotypes must be:
		- linked as a row in the inst/settings/phenotype-meddra-conversion.csv
		- corresponding sql and json files with the name of the phenotype id 
 		  (used in the csv above) must be placed in the folders inst/sql/sql_server and inst/cohorts.
	* extras/Preprocessing.R script must be run. This will create the two files inst/settings/DecList.csv 
	  and inst/settings/CohortsToCreate.csv used by the extras/RunCohortDiagnosticsAndViewResult.R script.

Features
========
- Show cohort inclusion rule attrition. 
- List all source codes used when running a cohort definition on a specific database.
- Find orphan codes, (source) codes that should be, but are not included in a particular concept set.
- Compute cohort incidence across calendar years, age, and gender.
- Break down index events into the specific concepts that triggered them.
- Compute overlap between two cohorts.
- Characterize cohorts, and compare these characterizations. Perform cohort comparison and temporal comparisons. 
- Explore patient profiles of a random sample of subjects in a cohort.

Screenshot
==========
![The Diagnostics Explorer Shiny app](vignettes/shiny.png)

Technology
==========
The CohortDiagnostics package is an R package.

System Requirements
===================
Requires R. Some of the packages used by CohortDiagnostics require Java.

Installation
=============

1. See the instructions [here](https://ohdsi.github.io/Hades/rSetup.html) for configuring your R environment, including Java.

License
=======
CohortDiagnostics is licensed under Apache License 2.0

Development
===========
CohortDiagnostics is being developed in R Studio.

### Development status

<<<<<<< HEAD
Stable
=======
Unknown
>>>>>>> 02f4a6591e403409109941ecab676d06097d6ba7
