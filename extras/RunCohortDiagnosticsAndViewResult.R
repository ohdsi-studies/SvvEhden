# https://github.com/OHDSI/CohortDiagnostics

# RunningCohortDiagnostics.pdf:
#   https://raw.githubusercontent.com/OHDSI/CohortDiagnostics/master/inst/doc/RunningCohortDiagnostics.pdf
# ViewingResultsUsingDiagnosticsExplorer.pdf:
#   https://raw.githubusercontent.com/OHDSI/CohortDiagnostics/master/inst/doc/ViewingResultsUsingDiagnosticsExplorer.pdf


prepare_cohort_diagnostics = TRUE
run_cohort_diagnostics_shiny_interface = TRUE

if (!"CohortGenerator" %in% installed.packages()[, 1]) 
  remotes::install_github("OHDSI/CohortGenerator", INSTALL_opts = c('--no-multiarch', '--no-lock'), upgrade = "always")
if (!"FeatureExtraction" %in% installed.packages()[, 1]) 
  remotes::install_github("OHDSI/FeatureExtraction", INSTALL_opts = c('--no-multiarch', '--no-lock'), upgrade = "always")
if (!"CohortDiagnostics" %in% installed.packages()[, 1]) 
  remotes::install_github("OHDSI/CohortDiagnostics", INSTALL_opts = c('--no-multiarch', '--no-lock'), upgrade = "always")
library(dplyr)

# Make sure the working directory is the root of the SVVEHDEN OHDSI study package
tryCatch({
  setwd("./R")
}, error = function(e) {
  setwd("../R")
})

source("../extras/CustomFunctions.R")  # our own custom functions

# TODO: the following can be removed if we build this as our own package 
#       (need to handle CohortGeneratorCohortConstruction.R, as well, this function comes 
#        originally from CohortGenerator package)
source("CohortConstruction.R")  # loadCohortsFromCsvOutsidePackage()
source("CohortGeneratorCohortConstruction.R")  # generateCohortSet()
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

exportFolder <- "../export"

if(prepare_cohort_diagnostics) {
  ###########################################################################
  ### Configuring the connection to the server
  ###########################################################################
  connectionDetails <- DatabaseConnector::createConnectionDetails(dbms = "sql server", 
                                                                  server = "UMCDB06")
  cdmDatabaseSchema = "OmopCdm.synpuf5pct_20180710"
  tempEmulationSchema <- NULL
  cohortDatabaseSchema <- cdmDatabaseSchema
  cohortTable <- paste0("cohorts_",Sys.getenv("USERNAME"),"_CD")
  cohortToCreateFile = "../inst/settings/CohortsToCreate.csv"
  sqlFolder = "../inst/sql/sql_server/"
  jsonFolder = "../inst/cohorts/"
  fixed_TAR = 365 # time at risk in days
  
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
                                  incremental = FALSE)

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
                                                                                                                  temporalStartDays = c(-3650*10, -365, -180, -30, 0, 1, 31), 
                                                                                                                  temporalEndDays = c(-366, -181, -31, -1, 0, 30, 365)))

    # # Cohort Statistics Table Clean up
    # CohortGenerator::dropCohortStatsTables(connectionDetails = connectionDetails,
    #                                        cohortDatabaseSchema = cohortDatabaseSchema,
    #                                        cohortTableNames = cohortTableNames)
    
    ###########################################################################
    ### Convert all the csv files that are the precomputed output of Cohort Diagnostics into a .RData file
    ###########################################################################
    CohortDiagnostics::preMergeDiagnosticsFiles(exportFolder)
  }
  
  if(run_cohort_diagnostics_shiny_interface) {
    
    ###########################################################################
    ### Launch shiny app
    ###########################################################################
    launchDiagnosticsExplorerOutsidePackage(dataFolder = paste0("../../",exportFolder), 
                                            dataFile = "Premerged.RData",
                                            DecList = "../inst/settings/DecList.csv",
                                            connectionDetails = NULL,
                                            verbose = FALSE) # put verbose on for continuous printouts of what parts of the shiny server code is being executed
    
  }
  
