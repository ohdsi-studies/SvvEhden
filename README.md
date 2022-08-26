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
To setup the custom version of CohortDiagnostics used in this study, initiate a new project in Rstudio. Select "Version Control"
and provide the link to the study package github [link](https://github.com/ohdsi-studies/SvvEhden) to initiate the project. 

Once the project is initiated, the code is executed by running the script 'runCohortDiagnosticsAndViewResult.R' placed in the extras-folder. This script handles installation of the study specific CohortDiagnostics, creates cohorts, gather summary data needed for display in a shiny app, starts the shiny app and uploads data. 

For completeness, note that the name of the study package is CohortDiagnostics, not Svvehden, and that the description of the package is "CohortDiagnostics 2.2.1 modified by UMC", to be able to distinguish it from other version of CohortDiagnostics. Also, if issues during execution require us to update scripts, we will push new versions using git. To update older versions of the study package, you may either pull the latest version, e.g. using the Git-tab in Rstudio, upper right pane, or  remove the old Rstudio project folder and initiate a new one, which will use the latest version of the scripts.
      
The runCohortDiagnosticsAndViewResult-script is controlled by the following three parameters. 

* prepare_cohort_diagnostics_data (TRUE/FALSE: set to TRUE when preparing data to be displayed in CohortDiagnostics, typically the first time. Once this has fully executed once, you don't need to do this step again.)
* upload_data_to_server (TRUE/FALSE: set to TRUE when you want to upload data to the OHDSI SFTP server. Default is set to FALSE to encourage  examination of the aggregated data in the ShinyApp before uploading. Once this has fully executed one, you don't need to do this step again.)
* make_cohort_diagnostics_data_avaliable_to_shiny_interface (TRUE/FALSE: set to true the first time before you want to start the CohortDiagnostics app. Once this has fully executed once, you don't need to do this step again.)
* run_cohort_diagnostics_shiny_interface (TRUE/FALSE: set to TRUE to start the CohortDiagnostics shiny app)

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

