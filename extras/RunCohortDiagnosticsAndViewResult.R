################################################
# Execution parameters 
################################################
# prepare_cohort_diagnostics = TRUE => reads from your database and prepare all aggregated data
# for CohortDiagnostics, and saves to the export folder.
prepare_cohort_diagnostics = TRUE

# upload_data_to_server = TRUE => This uploads the data to the OHDSI SFTP-server
upload_data_to_server = FALSE

# run_cohort_diagnostics_shiny_interface = TRUE => reads in the saved data in the export folder,
# and starts the shiny CohortDiagnostics app.
# Typically, the prepare_cohort_diagnostics only need to be set to TRUE the first time you run 
# this script for a database, and then can be set to  FALSE, if running the script again, if nothing
# in the setup changes. This first part also takes a lot of time to execute, depending on database size.
run_cohort_diagnostics_shiny_interface = TRUE

###########################################################################
### CUSTOM DEFINED SETTINGS, PLEASE UPDATE THIS TO YOUR SETTING
###########################################################################
# Enter server related information specific to your setup. The inputs currently here are intended as helpful examples.
connectionDetails <- DatabaseConnector::createConnectionDetails(dbms = "sql server", server = "UMCDB06")

# The place where the OmopCdmData lives
cdmDatabaseSchema = "OmopCdm.synpuf5pct_20180710" 

# The place where the cohort table is to be created
cohortDatabaseSchema <- cdmDatabaseSchema

# Set the tablename to use when storing created cohorts on your server
cohortTable <- paste0("cohorts_", Sys.getenv("USERNAME"), "_CD")

# For Oracle, Spark or Google Big Query users
tempEmulationSchema <- NULL

# Enter the file path to the data upload server keyword file, provided by email. The example path below needs to be modified.
privateKeyFileName <- "C:/Users/JaneDoe/Desktop/study-data-site-svvehden"

# This concludes study site specific input, no edits should be required below this line
##########################################################################################

# Make sure the working directory is the root of the study package
if(! "rprojroot" %in% rownames(installed.packages())){install.packages("rprojroot")}
tryCatch({
  setwd("./R")
}, error = function(e) {
  setwd("../R")
})
root <- rprojroot::is_r_package
root_file <- root$make_fix_file()
path_to_project_root <- root_file()

# This installs the custom CohortDiagnostics-package.
detach("package:CohortDiagnostics", unload = TRUE)
remove.packages("CohortDiagnostics")
#pkgbuild::build(dest_path=path_to_project_root, binary=TRUE, args="--no-multiarch")
tryCatch({
  install.packages(repos=NULL, pkgs="../CohortDiagnostics_2.2.1.zip", INSTALL_opts="--no-multiarch", dependencies=TRUE)
})
library("CohortDiagnostics")


###########################################################################
### Settings
###########################################################################
testset = "mediumtestset" # choose one of:  "smalltestset", "mediumtestset", "full"
cohortToCreateFile = file.path(path_to_project_root, "inst", "settings", paste0("CohortsToCreate_", testset, ".csv"))
decListFile = file.path(path_to_project_root, "inst", "settings", paste0("DecList_", testset, ".csv"))
sqlFolder = "../inst/sql/sql_server/"
jsonFolder = "../inst/cohorts/"
fixed_TARs = get_tar_options(cohortToCreateFile = cohortToCreateFile)
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
                                               fixed_TARs = fixed_TARs,
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
                                                          allDrugConceptIds = all_drug_concepts$CONCEPT_ID
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
                            decList = decListFile, 
                            storePath = exportFolder_after_slash,
                            storeFileName = "chronograph_data.csv",
                            databaseId = cdmDatabaseSchema,
                            project_root_path = path_to_project_root,
                            create_pngs_in_extras_folder = TRUE) # If TRUE: Writes graphs to the extras folder for convenience. 
  
  
  # Cohort Statistics Table Clean up
  CohortGenerator::dropCohortStatsTables(connectionDetails = connectionDetails,
                                         cohortDatabaseSchema = cohortDatabaseSchema,
                                         cohortTableNames = cohortTableNames)
  
  ###########################################################################
  ### Convert all the csv files that are the precomputed output of Cohort Diagnostics into a .RData file
  ###########################################################################
  # This step should not be executed at the study site, but at UMC. 
  # https://github.com/ohdsi-studies/Covid19SubjectsAesiIncidenceRate/issues/5 
  # We keep it for now, to be able to test run our scripts though. 
  preMergeDiagnosticsFiles(exportFolder)
  
} 


#################################################################
### Upload the results to the OHDSI SFTP server:
#################################################################
if(upload_data_to_server){
  
  
  # If needed, install OhdsiSharing which handles the upload
  if(! "OhdsiSharing" %in% rownames(installed.packages())){
    remotes::install_github("ohdsi/OhdsiSharing", INSTALL_opts = c('--no-multiarch', '--no-lock'), upgrade="never")
  }
  
  # Upload the contents
  userName <- "study-data-site-svvehden"
  privateKeyFileName <- "C:/Users/OskarG/OneDrive - WHO Collaborating Centre for International Drug Monitoring/Desktop/study-data-site-svvehden"
  OhdsiSharing::sftpUploadFile(privateKeyFileName, userName, fileName = theFileName)
}


###########################################################################
### Launch shiny app
###########################################################################
if(run_cohort_diagnostics_shiny_interface) {
  launchDiagnosticsExplorerOutsidePackage(dataFolder = file.path(path_to_project_root, exportFolder_after_slash), 
                                          DecList = decListFile,
                                          ChronographCsv = file.path(path_to_project_root, exportFolder_after_slash, "chronograph_data.csv"),
                                          TarOptions = fixed_TARs,
                                          connectionDetails = NULL,
                                          verbose = FALSE) # put verbose on for continuous printouts of what parts of the shiny server code is being executed
  
}
