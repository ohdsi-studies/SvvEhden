
###########################################################################
### CUSTOM DEFINED SETTINGS, PLEASE UPDATE THIS TO YOUR SETTING
###########################################################################
connectionDetails <- DatabaseConnector::createConnectionDetails(dbms = "sql server", 
                                                                server = "UMCDB06")
cdmDatabaseSchema = "OmopCdm.synpuf5pct_20180710"
tempEmulationSchema <- NULL
cohortDatabaseSchema <- cdmDatabaseSchema
cohortTable <- paste0("cohorts_",Sys.getenv("USERNAME"),"_CD")

# What part to run? 
# prepare_cohort_diagnostics = TRUE => reads from your database and prepare all aggregated data
# for CohortDiagnostics, and saves to the export folder.
# run_cohort_diagnostics_shiny_interface = TRUE => reads in the saved data in the export folder,
# and starts the shiny CohortDiagnostics app.
# Typically, the prepare_cohort_diagnostics only need to be set to TRUE the first time you run 
# this script for a database, and then can be set to  FALSE, if running the script again, if nothing
# in the setup changes. This first part also takes a lot of time to execute, depending on database size...
prepare_cohort_diagnostics = TRUE
run_cohort_diagnostics_shiny_interface = TRUE

###########################################################################
### END OF CUSTOM DEFINED SETTINGS
###########################################################################


if (!"CohortGenerator" %in% installed.packages()[, 1]) 
  remotes::install_github("OHDSI/CohortGenerator", INSTALL_opts = c('--no-multiarch', '--no-lock'), upgrade = "always")
if (!"FeatureExtraction" %in% installed.packages()[, 1]) 
  remotes::install_github("OHDSI/FeatureExtraction", INSTALL_opts = c('--no-multiarch', '--no-lock'), upgrade = "always")
# if (!"CohortDiagnostics" %in% installed.packages()[, 1]) 
#   remotes::install_github("OHDSI/CohortDiagnostics", INSTALL_opts = c('--no-multiarch', '--no-lock'), upgrade = "always")

# This installs the 2.2.3-version of CohortDiagnostics.
# Download file from here: https://github.com/OHDSI/CohortDiagnostics/releases/tag/v2.2.4
# install.packages(repos=NULL, pkgs="C:/Users/OskarG/Downloads/CohortDiagnostics-2.2.4.tar.gz", type="source", INSTALL_opts="--no-multiarch")
library(dplyr)

# Make sure the working directory is the root of the SVVEHDEN OHDSI study package
tryCatch({
  setwd("./R")
  root <- rprojroot::is_r_package
  root_file <- root$make_fix_file()
  path_to_project_root <- root_file()
}, error = function(e) {
  setwd("../R")
})


source("../extras/CustomFunctions.R")  # our own custom functions

# TODO: the following can be removed if we build this as our own package 
#       (need to handle CohortGeneratorCohortConstruction.R, as well, this function comes 
#        originally from CohortGenerator package)
source("CohortConstruction.R")  # loadCohortsFromCsvOutsidePackage()
source("CohortGeneratorCohortConstruction.R")  # generateCohortSet()
source("Chronograph.R")  # Three chronograph-related functions, modified from the IcTemporalPatternDiscovery package
source("Private.R")             # checkInputFileEncoding()
source("RunDiagnostics.R")      # executeDiagnostics()
source("ConceptSets.R")         # executeDiagnostics()
source("Incremental.R")         # executeDiagnostics()
source("MetaDataDiagnostics.R") # executeDiagnostics()
source("ConceptIds.R")          # executeDiagnostics()
source("CohortLevelDiagnostics.R")  # executeDiagnostics()
source("TimeDistributions.R")   # executeDiagnostics()
source("VisitContext.R")        # executeDiagnostics()
source("IncidenceRates.R")      # executeDiagnostics() 
source("CohortComparisonDiagnostics.R") # executeDiagnostics()
source("CohortCharacterizationDiagnostics.R") # executeDiagnostics()
source("exportCharacterization.R") # executeDiagnostics()
source("ResultsDataModel.R")    # getResultsDataModelSpecifications()
source("Shiny.R")               #launchDiagnosticsExplorer()

###########################################################################
### Settings
###########################################################################
cohortToCreateFile = "../inst/settings/CohortsToCreate.csv"
sqlFolder = "../inst/sql/sql_server/"
jsonFolder = "../inst/cohorts/"
fixed_TAR = 365 # time at risk in days
exportFolder <- "../export"
exportFolder_after_slash <- gsub("\\.\\.\\/", "",exportFolder)

if(prepare_cohort_diagnostics) {
  
  ###########################################################################
  ### Reset and create the cohort tables
  ###########################################################################
  cohortTableNames <- CohortGenerator::getCohortTableNames(cohortTable = cohortTable)
  # Next create the tables on the database
  CohortGenerator::createCohortTables(connectionDetails = connectionDetails,
                                      cohortTableNames = cohortTableNames,
                                      cohortDatabaseSchema = cohortDatabaseSchema,
                                      incremental = FALSE)
  
  ###########################################################################
  ### Create the any drug cohort that is the base of all comparator cohorts
  ###########################################################################
  # Run the any_drug_cohort.sql scipt to create the 999999-cohort with all drugs before matching,
  # and create the generic_comparator_drug_cohort.json-file for all concept_id's in the DRUG_EXPOSURE 
  # table in this database:
  all_drug_concepts <- prepare_any_drug_cohort(connectionDetails = connectionDetails, 
                                               cdmDatabaseSchema = cdmDatabaseSchema,
                                               cohortDatabaseSchema = cohortDatabaseSchema,
                                               cohortTable = cohortTable,
                                               tempEmulationSchema = tempEmulationSchema,
                                               fixed_TAR = fixed_TAR,
                                               sqlFolder = sqlFolder,
                                               generateAnyDrugCohortSql = "any_drug_cohort.sql",
                                               jsonFolder = jsonFolder,
                                               # comparatorDrugJson file name must correspond to "name" in CohortsToCreate.csv
                                               comparatorDrugJson = "generic_comparator_drug_cohort.json" 
                                               )
  
  ###########################################################################
  ### Loading cohort references
  ###########################################################################
  # # Loading cohort references from a package
  # cohortDefinitionSet <- loadCohortsFromPackage(packageName = "CohortDiagnostics",
  # cohortToCreateFile = "settings/CohortsToCreateForTesting.csv")
  
  # Loading cohort references from a Csv
  cohortDefinitionSet <- loadCohortsFromCsvOutsidePackage(cohortToCreateFile = cohortToCreateFile,
                                                          sqlFolder = sqlFolder, 
                                                          jsonFolder = jsonFolder,
                                                          allDrugConceptIds = all_drug_concepts$CONCEPT_ID,
                                                          fixed_TAR = fixed_TAR
                                                          )  
  
  ###########################################################################
  ### Cohorts must be generated before cohort diagnostics can be run.
  ###########################################################################
  # Generate the cohort set 
  # Use local version in order to feed in parameter
  generateCohortSetOutsidePackage(connectionDetails= connectionDetails,
                                  cdmDatabaseSchema = cdmDatabaseSchema,
                                  cohortDatabaseSchema = cohortDatabaseSchema,
                                  cohortTableNames = cohortTableNames,
                                  cohortDefinitionSet = cohortDefinitionSet,
                                  incremental = FALSE
                                  )
  
  ###########################################################################
  ### Executing cohort diagnostics
  ###########################################################################
  # Use the local function, not the package one
  executeDiagnosticsOutsidePackage(cohortDefinitionSet = cohortDefinitionSet,
                                   connectionDetails = connectionDetails,
                                   cohortTable = cohortTable,
                                   cohortDatabaseSchema = cohortDatabaseSchema,
                                   cdmDatabaseSchema = cdmDatabaseSchema,
                                   exportFolder = exportFolder,
                                   databaseId = cdmDatabaseSchema,
                                   minCellCount = 5,
                                   temporalCovariateSettings = FeatureExtraction::createTemporalCovariateSettings(useConditionOccurrence = TRUE, 
                                                                                                                  useDrugEraStart = TRUE, 
                                                                                                                  useProcedureOccurrence = TRUE, 
                                                                                                                  useMeasurement = TRUE,
                                                                                                                  temporalStartDays = c(-3650*10, -365, -180, -30, 0), 
                                                                                                                  temporalEndDays = c(-366, -181, -31, -1, 0))
                                   )

  ###########################################################################
  ### Calculate chronograph data
  ###########################################################################  
  # This wrapper calculates data needed to build temporal association graphs ("chronographs") similar to the IcTemporalPatternDiscovery-package. 
  # Aggregated data is saved in "inst/csv" with these settings.
  
  executeChronographWrapper(connectionDetails = connectionDetails,
                     cdmDatabaseSchema = cdmDatabaseSchema,
                     oracleTempSchema = NULL,
                     cohortDatabaseSchema = cdmDatabaseSchema,
                     cohortTable = cohortTable,
                     decList = "../inst/settings/DecList.csv", 
                     storePath = exportFolder_after_slash,
                     storeFileName = "chronograph_data.csv",
                     databaseId = cdmDatabaseSchema,
                     project_root_path = path_to_project_root,
                     create_pngs_in_extras_folder = TRUE) # If TRUE: Writes graphs to the extras folder for convenience. 
  
  
  # # Cohort Statistics Table Clean up
  # CohortGenerator::dropCohortStatsTables(connectionDetails = connectionDetails,
  #                                        cohortDatabaseSchema = cohortDatabaseSchema,
  #                                        cohortTableNames = cohortTableNames)
  
  ###########################################################################
  ### Convert all the csv files that are the precomputed output of Cohort Diagnostics into a .RData file
  ###########################################################################
  # This step should not be executed at the study site, but at UMC. 
  # https://github.com/ohdsi-studies/Covid19SubjectsAesiIncidenceRate/issues/5 
  # We keep it for now, to be able to test run our scripts though. 
  preMergeDiagnosticsFiles(exportFolder)

} 

if(run_cohort_diagnostics_shiny_interface) {

  ###########################################################################
  ### Launch shiny app
  ###########################################################################
  launchDiagnosticsExplorerOutsidePackage(dataFolder = paste0("../../",exportFolder), 
                                          dataFile = "Premerged.RData",
                                          DecList = "../inst/settings/DecList.csv",
                                          ChronographCsv = paste0(exportFolder,"/chronograph_data.csv"),
                                          connectionDetails = NULL,
                                          verbose = FALSE) # put verbose on for continuous printouts of what parts of the shiny server code is being executed

}


#################################################################
### Upload the results to the OHDSI SFTP server:
#################################################################
# Run if needed:
# remotes::install_github("ohdsi/OhdsiSharing", INSTALL_opts = c('--no-multiarch', '--no-lock'), upgrade="never")

# Set path to password key file, see this example:
# privateKeyFileName <- "C:/Users/OskarG/OneDrive - WHO Collaborating Centre for International Drug Monitoring/Desktop/study-data-site-svvehden"

# Use this userName:
# userName <- "study-data-site-svvehden"

# Set theFileName to where the output zip file exists, typically in the export folder. See this example:
# theFileName <- "C:/Users/OskarG/OneDrive - WHO Collaborating Centre for International Drug Monitoring/Rwd/SVVEHDEN/SVVEHDEN CohortDiagnosticsMod study package/export/Results_OmopCdm.synpuf5pct_20180710.zip"

# OhdsiSharing::sftpUploadFile(privateKeyFileName, userName, fileName = theFileName)
# beepr::beep(2)


