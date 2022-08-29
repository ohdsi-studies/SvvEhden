################################################
# Execution parameters 
################################################
# prepare_cohort_diagnostics = TRUE => reads from your database and prepare all aggregated datapostGresConnectionDetails
# for CohortDiagnostics, and saves to the export folder as csv files.
prepare_cohort_diagnostics_data = TRUE

# make_cohort_diagnostics_data_avaliable_to_shiny_interface = TRUE => Converts prepared csv files 
# for shiny interface, by either creating an .RData file or using PostGreSQL as backend.
make_cohort_diagnostics_data_avaliable_to_shiny_interface = FALSE

# upload_data_to_server = TRUE => This uploads the aggregated data to the OHDSI SFTP-server
upload_data_to_server = TRUE

# run_cohort_diagnostics_shiny_interface = TRUE => reads in the saved data in the export folder,
# and starts the shiny CohortDiagnostics app.
# Typically, the above parameters only need to be set to TRUE the first time you run 
# this script for a database, and then can be set to  FALSE, if running the script again, if nothing
# in the setup changes. This first part also takes a lot of time to execute, depending on database size.
run_cohort_diagnostics_shiny_interface = FALSE

###########################################################################
### CUSTOM DEFINED SETTINGS, PLEASE UPDATE THIS TO YOUR SETTING
###########################################################################

# Enter server related information specific to your setup. The inputs currently here are intended as helpful examples.

# ---------------------------------------------------------------
# Connection to Omop database:
# ---------------------------------------------------------------
connectionDetails <- DatabaseConnector::createConnectionDetails(dbms = "sql server", server = "UMCDB06")

# The place where the OmopCdmData lives
cdmDatabaseSchema = "OmopCdm.synpuf5pct_20180710" 

# The place where the cohort table is to be created
cohortDatabaseSchema <- cdmDatabaseSchema

# Set the tablename to use when storing created cohorts on your server
cohortTable <- paste0("cohorts_", Sys.getenv("USERNAME"), "_CD")

# For Oracle, Spark or Google Big Query users
tempEmulationSchema <- NULL

# ---------------------------------------------------------------
# Upload to ohdsi-server:
# ---------------------------------------------------------------
# Enter the file path to the data upload server keyword file, provided by email. The example path below needs to be modified.
privateKeyFileName <- "C:/Users/JaneDoe/Desktop/study-data-site-svvehden"

# ---------------------------------------------------------------
# Use PostGreSQL or .RData to load the data into CohortDiagnostics?
# ---------------------------------------------------------------
use_postgreSQL_as_backend = FALSE

pathToDriver = ""
# If use_postgreSQL_as_backend = TRUE and you don't use PostGreSQL for the Omop Data, 
# you need to specify the driver-JAR-folder accordingly here to point to JAR-files for PostGreSQL:
# If use_postgreSQL_as_backend = TRUE, specify schema name and connection details
postGreSQL_schema = "test_schema_2"
postGresConnectionDetails <- DatabaseConnector::createConnectionDetails(dbms = "postgresql",
                                                                        server = "localhost/postgres",
                                                                        user = "postgres",
                                                                        password = Sys.getenv("pwPostgres"),
                                                                        pathToDriver = pathToDriver) 


# This concludes data partner specific input, no edits should be required below this line
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
if ("CohortDiagnostics" %in% (.packages())) {detach("package:CohortDiagnostics", unload = TRUE)}
if ("CohortDiagnostics" %in% installed.packages()[,1]) {remove.packages("CohortDiagnostics")}

# If you don't use windows, you might want to build the package yourself before installing it, by running the next outcommented line:
# pkgbuild::build(dest_path=path_to_project_root, binary=TRUE, args="--no-multiarch")
install.packages(repos=NULL, pkgs="../CohortDiagnostics_2.2.1.zip", INSTALL_opts="--no-multiarch", dependencies=TRUE, type="win.binary")
library("CohortDiagnostics")


###########################################################################
### Settings
###########################################################################
testset = "20" 
sqlFolder = "../inst/sql/sql_server/"
jsonFolder = "../inst/cohorts/"
exportFolder <- "../export"
exportFolder_after_slash <- gsub("\\.\\.\\/", "",exportFolder)
decListFile <- file.path(path_to_project_root, "inst", "settings", paste0("DecList_",testset,".csv"))

cohortToCreateFiles <- list.files(file.path(path_to_project_root, "inst", "settings"), paste0("CohortsToCreate_",testset,"_[0-9]+.csv$"), full.names = TRUE)
no_of_batches = length(cohortToCreateFiles)
fixed_TARs = get_tar_options(cohortToCreateFile = cohortToCreateFiles[1])

# debug:
# no_of_batches = 2

for (batch in 1:no_of_batches) {
  cohortToCreateFile = cohortToCreateFiles[batch]
  
  if(prepare_cohort_diagnostics_data) {
    
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
                              decs_to_process = batch:batch,
                              storePath = paste0(exportFolder_after_slash, batch),
                              storeFileName = "chronograph_data.csv",
                              databaseId = cdmDatabaseSchema,
                              project_root_path = path_to_project_root,
                              create_pngs_in_extras_folder = FALSE) # If TRUE: Writes graphs to the extras folder for convenience.
    
    ###########################################################################
    ### Executing cohort diagnostics
    ###########################################################################
    # Use the local function, not the package one
    executeDiagnosticsOutsidePackage(cohortDefinitionSet = cohortDefinitionSet,
                                     connectionDetails = connectionDetails,
                                     cohortTable = cohortTable,
                                     cohortDatabaseSchema = cohortDatabaseSchema,
                                     cdmDatabaseSchema = cdmDatabaseSchema,
                                     exportFolder = paste0(exportFolder, batch),
                                     databaseId = cdmDatabaseSchema,
                                     minCellCount = 5,
                                     temporalCovariateSettings = FeatureExtraction::createTemporalCovariateSettings(useConditionOccurrence = TRUE, 
                                                                                                                    useDrugEraStart = TRUE, 
                                                                                                                    useProcedureOccurrence = TRUE, 
                                                                                                                    useMeasurement = TRUE,
                                                                                                                    temporalStartDays = c(-3650*10, -365, -180, -30, 0), 
                                                                                                                    temporalEndDays = c(-366, -181, -31, -1, 0)),
                                     zip_file_name_prefix = paste0(testset, batch)
    )
    
    # Cohort Statistics Table Clean up
    CohortGenerator::dropCohortStatsTables(connectionDetails = connectionDetails,
                                           cohortDatabaseSchema = cohortDatabaseSchema,
                                           cohortTableNames = cohortTableNames)
  } 
  
  #################################################################
  ### Convert all the csv files that are the precomputed output, either by PostGreSQL Backend or into a .RData file
  #################################################################
  if(make_cohort_diagnostics_data_avaliable_to_shiny_interface){
    
    if(! use_postgreSQL_as_backend){
      # This step should not be executed at the study site, but at UMC. 
      # https://github.com/ohdsi-studies/Covid19SubjectsAesiIncidenceRate/issues/5 
      # We keep it for now, to be able to test run our scripts though.   
      preMergeDiagnosticsFiles(paste0(exportFolder,batch))
      
    } else {
      
      if(batch == 1){ 
        dropTableIfExists = TRUE
      } else {
        dropTableIfExists = FALSE
      }
      
      loadCsvIntoPostGreSQL(connectionDetails = postGresConnectionDetails,
                            project_root_path = path_to_project_root,
                            export_folder = paste0(exportFolder_after_slash, batch),#exportFolder_after_slash,
                            schema = postGreSQL_schema,
                            dropTableIfExists = dropTableIfExists)
      
      # Inspect if the writing seems succesful:
      # connection <- connect(postGresConnectionDetails)
      # DatabaseConnector::querySql(connection, "SELECT json FROM test_schema.COHORT LIMIT 1;")
      
    }
  }
  
} # end of batching


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
  
  compress_all_result_batches(mainFolder = path_to_project_root,
                              exportFolder = exportFolder_after_slash,
                              databaseId = cdmDatabaseSchema)
  fileName <- list.files(exportFolder, "^Results_.*.zip$", full.names = TRUE)
  
  if (length(fileName) == 0) {
    stop("Could not find results file in folder. Did you run (and complete) execute?")
  }
  if (length(fileName) > 1) {
    stop("Multiple results files found. Don't know which one to upload")
  }
  OhdsiSharing::sftpUploadFile(privateKeyFileName = privateKeyFileName,
                               userName = userName,
                               remoteFolder = cdmDatabaseSchema,
                               fileName = fileName[length(fileName)])
}


###########################################################################
### Launch shiny app
###########################################################################
if(run_cohort_diagnostics_shiny_interface) {
  
  
  if(! use_postgreSQL_as_backend){
    
    batch = 1
    launchDiagnosticsExplorerOutsidePackage(dataFolder = file.path(path_to_project_root, paste0(exportFolder_after_slash,batch)),
                                            DecList = decListFile,
                                            ChronographCsv = file.path(path_to_project_root, paste0(exportFolder_after_slash,batch), "chronograph_data.csv"),
                                            TarOptions = fixed_TARs,
                                            connectionDetails = NULL,
                                            verbose = FALSE) # put verbose on for continuous printouts of what parts of the shiny server code is being executed
    
  } else {
    
    # debug 
    # decListFile = file.path(path_to_project_root, "inst", "settings", "DecList_full_debugOnly2.csv")
    
    original_DATABASECONNECTOR_JAR_FOLDER = Sys.getenv("DATABASECONNECTOR_JAR_FOLDER")
    if (pathToDriver != ""){ Sys.setenv("DATABASECONNECTOR_JAR_FOLDER" = pathToDriver)}
    
    launchDiagnosticsExplorerOutsidePackage(DecList = decListFile,
                                            TarOptions = fixed_TARs,
                                            connectionDetails = postGresConnectionDetails,
                                            verbose = FALSE,
                                            resultsDatabaseSchema = postGreSQL_schema)
    
    Sys.setenv("DATABASECONNECTOR_JAR_FOLDER" = original_DATABASECONNECTOR_JAR_FOLDER)
  }    
  
}
