Pharmacovigilance Use Case, Work package 1
==========================================

Introduction
============
This R study package is a modified version of CohortDiagnostics, designed for use in the pharmacovigilance use case in Work package 1 EHDEN. 

Overall, CohortDiagnostics is used for performing various study diagnostics. The modifications include adding a tab with a temporal display for event occurrence, the so called "Chronograph", and some study specific cohort and outcome (phenotype) definitions.

Overview
=======================
CohortDiagnostics relies on packages commonly used in OHDSI network studies, such as DatabaseConnector, FeatureExtraction and CohortGenerator. Overall, CohortDiagnostics produces an output file with aggregate statistics, which can be displayed in a shiny interface. The output file is to be shared to the study organizer using the OHDSI SFTP-server. 

Prerequisites
=======================
For setting up R and Java, we refer to these [instructions](https://ohdsi.github.io/Hades/rSetup.html).

For setting up the DatabaseConnector package, we refer to these [instructions](http://ohdsi.github.io/DatabaseConnector/articles/Connecting.html#obtaining-drivers).

Windows and SQL Server users might also be interested in setting up Windows authentication as described [here](http://ohdsi.github.io/DatabaseConnector/reference/connect.html#windows-authentication-for-sql-server-1).

This concludes the prerequisites.

How-to-prepare and run
=======================
The study package is executed by running the script 'runCohortDiagnosticsAndViewResult.R' placed in the extras-folder. This script handles installation of the study specific CohortDiagnostics, creates cohorts, gather summary data needed for display in a shiny app, starts the shiny app and uploads data. This is controlled by the following three parameters. 

* prepare_cohort_diagnostics (TRUE/FALSE: set to TRUE when preparing data to be displayed in CohortDiagnostics, typically the first time)
* upload_data_to_server = FALSE (set to TRUE when you want to upload data to the OHDSI SFTP server. Default is set to FALSE to encourage  examination of the aggregated data in the ShinyApp before uploading.)
* run_cohort_diagnostics_shiny_interface (TRUE/FALSE: default is set to TRUE to start the CohortDiagnostics shiny app)

Further details around these are available in comments in the script 'runCohortDiagnosticsAndViewResult.R' where these values are set. 

To set up the connection to the study site server, at least some of the following five parameters require modification. Please see the comments in the script 'runCohortDiagnosticsAndViewResult.R' for more details on how these parameters are to be specified.

* connectionDetails 
* cdmDatabaseSchema 
* tempEmulationSchema
* cohortDatabaseSchema 
* cohortTable

Please note that any prior installation of CohortDiagnostics is removed by executing the study script, and CohortDiagnostics will need to be restored manually to the previous version by the user once the study is executed. If the latest version is wanted, this can be achieved for instance by running:

remove.packages("CohortDiagnostics")
remotes::install_github("OHDSI/CohortDiagnostics")

Features
========
- Includes a Chronograph tab in the shiny interface, displaying temporal patterns of event occurrence. 
- See CohortDiagnostics 2.2.1 for further details.

Screenshot
==========
![The Diagnostics Explorer Shiny app](vignettes/shiny.png)

Technology
==========
The CohortDiagnostics package is an R package.

System Requirements
===================
Requires R. Some of the packages used by CohortDiagnostics require Java.

License
=======
CohortDiagnostics is licensed under Apache License 2.0

Development
===========
CohortDiagnostics is being developed in R Studio.

