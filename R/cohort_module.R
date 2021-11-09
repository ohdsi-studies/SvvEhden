########################################################################
# cohort_module: function that creates the cohorts for a DEC of interest
# 
# This function is called from the workhorse script, and will use the 
# generic_cohort_definition_script.sql to create the cohorts for the dec_input.
# 
# Input parameters:
#   i: The index variable in the for-loop.
#   maximum_cohort_size: Restricts the cohort size for cohorts 22, 32, 42.
#   force_create_new: if TRUE, data will be read from db, even if file
#                     exists. If FALSE, data will be read from saved 
#                     files from previous runs, if file exists, otherwise
#                     from db.
#   only_create_cohorts: If TRUE, to save time, only cohorts are created, no covariates are retrieved. Useful for the chronograph.
# Other input arguments, passed via the saddle-list:
#   saddle$dec_input:   c(drug_name, event_name, drug_id, event_id)
#   saddle$all_drugs:   list with drug-ids
#   saddle$db_name:     string with name of database
#   saddle$schema_name: string with schema_name in database
#   saddle$resultsDatabaseSchema: string with schema_name where the results are to be stored
#   saddle$resultsTableName: string with table_name where the results are to be stored (set in saddle_the_workhorse to "cohorts_*username*")
#   saddle$verbose:          If TRUE, some messages are written every time covariates are retrieved from a cohort. 
#
# Output: A list containing studyPopulation, cohortMethodData, cohort11, cohort21, cohort31, cohort41.
# 
# See the generic_cohort_definition_script for details on the cohorts.
#########################################################################


cohort_module <- function(i,
                          maximum_cohort_size = 100,
                          force_create_new = TRUE, 
                          only_create_cohorts = FALSE,
                          saddle){
  
  cat("\n Now Running DEC nr", i, ",", saddle$dec_df$drug_and_event_name[i], "\r\n")
  
  # Unpack the things needed from the saddle-list
  dec_input <- saddle$dec_df[i,]
  all_drugs <- saddle$all_drugs
  connectionDetails <- saddle$connectionDetails
  db_name <- saddle$db_name
  schema_name <- saddle$schema_name
  resultsDatabaseSchema <- saddle$resultsDatabaseSchema 
  resultsTableName <- saddle$resultsTableName
  verbose <- saddle$overall_verbose
  
  # # For debugging:
  # dec_input <- dec_df[1,]
  # db_name = "OmopCdm"
  # schema_name = "synpuf5pct_20180710"
  # force_create_new = FALSE
  # verbose=saddle$overall_verbose
  # only_create_cohorts=FALSE
  # maximum_cohort_size = 50
  # force_create_new = TRUE
  
  tic("Cohort_module")
  conn <- suppressMessages(invisible(DatabaseConnector::connect(connectionDetails)))
  cdmDatabaseSchema = paste0(db_name,".",schema_name)  # Where the OMOP-data is stored, note the database-name
  tempTableName = resultsTableName
  
  # Unpack the input
  c(drug_name, event_name, drug_id, event_id) %<-% dec_input[1:4]
  drug_id = gsub(pattern = '|', replacement = ',', x=drug_id, fixed = TRUE) # split with commas if several
  event_id = gsub(pattern = '|', replacement = ',', x=event_id, fixed = TRUE) # split with commas if several
  
  #Create the cohorts in a table in the database
  sql <- readSql("..\\inst\\sql\\generic_cohort_definition_script.sql")
  
  sql <- SqlRender::render(sql, 
                           cdmDatabaseSchema = cdmDatabaseSchema,
                           resultsDatabaseSchema = resultsDatabaseSchema,
                           tempTableName = tempTableName, 
                           exposure_drug_ids = drug_id,
                           comparator_drug_ids = all_drugs,
                           event_ids = event_id,
                           maximum_cohort_size = maximum_cohort_size)
  
  # writeLines(sql)
  suppressMessages(executeSql(conn, sql, progressBar = FALSE))
  
  # querySql(conn, "SELECT * FROM OmopCdm.synpuf5pct_20180710.cohorts_OskarG WHERE COHORT_DEFINITION_ID=11")
  
  #debug part: if you want to run it manually
  fileConn<-file("..\\inst\\sql\\last_create_cohort_definition_script.sql")
  write(sql, fileConn)
  close(fileConn)
  
  if(only_create_cohorts){
    return(NULL)
  }
  
  # Documentation says that the cohort-defining features can't be covariates 
  # https://ohdsi.github.io/FeatureExtraction/reference/createCovariateSettings.html
  # TODO: make sure we include what we need here
  covSettings <- suppressMessages(custom_createCovariateSettings(exclude_these = c(str_split(event_id, fixed(",")), str_split(drug_id, fixed(","))))) #for cohort1-3: exclude event and drug from covariates
  attributes(covSettings)$fun = "custom_getDbDefaultCovariateData"
  
  covSettings4 <- suppressMessages(custom_createCovariateSettings(exclude_these = c(str_split(event_id, fixed(",")), all_drugs))) #for cohort4: exclude all drug_ids from covariates
  attributes(covSettings4)$fun = "custom_getDbDefaultCovariateData"
  
  
  ##########################
  # #Check for glucose
  # analysisDetails <- createAnalysisDetails(analysisId = 1,
  #                                          sqlFileName = "DomainConcept.sql",
  #                                          parameters = list(analysisId = 1,
  #                                                            analysisName = "Custom Concept",
  #                                                            domainId = "Drug",
  #                                                            domainConceptId = "drug_concept_id" ),
  #                                          includedCovariateConceptIds = c(1560524),
  #                                          addDescendantsToInclude = TRUE,
  #                                          excludedCovariateConceptIds = c(event_id, drug_id),
  #                                          addDescendantsToExclude = FALSE,
  #                                          includedCovariateIds = c())
  # covSettings <- createDetailedCovariateSettings(list(analysisDetails))
  
  #########################
  
  # detailed_analysis <- convertPrespecSettingsToDetailedSettings(covSettings)
  # settings <- createDetailedCovariateSettings(list(detailed_analysis))
  # settings$analyses[[1]]$analyses[[4]]$parameters$description
  # "One covariate per drug rolled up to ATC groups in the drug_era table overlapping with any part of the long term window."
  
  if (!file.exists("cohort_data")) { dir.create("cohort_data", recursive = TRUE) } #TODO:change location of this folder!
  
  ########################################################################
  #cohort 1: drug + event
  drugEventString = paste0(drug_id, "-" ,event_id)
  filename = paste0("cohort_data/",schema_name,"_cohortMethodData-",drugEventString,".Rdata")
  filename2 = paste0("cohort_data/", schema_name, "_cohort11-", drugEventString, ".Rdata")
  filename3 = paste0("cohort_data/",schema_name,"_studyPopulation-",drugEventString,".Rdata")
  
  tic()
  if (!file.exists(filename) | !file.exists(filename2) | !file.exists(filename3) | force_create_new){
    # compute cohort and save to file
    if(verbose) { print(paste0("Retrieving covariates for cohort 11 from scratch, saving to : ", filename)) }
    
    #TODO: make sure this is the correct settings for us
    #TODO: wrap this up into a new function, where we can only change inputs of interest, in
    #      order to make it a bit more readable
    cohortMethodData <- suppressMessages(custom_getDbCohortMethodData(
      connectionDetails = connectionDetails,
      cdmDatabaseSchema = cdmDatabaseSchema,
      targetId = 21,
      comparatorId = 41,
      outcomeIds = 31,
      studyStartDate = "",
      studyEndDate = "",
      exposureDatabaseSchema = resultsDatabaseSchema,
      exposureTable = tempTableName,
      outcomeDatabaseSchema =  resultsDatabaseSchema,
      outcomeTable = tempTableName,
      cdmVersion = 5,
      firstExposureOnly = FALSE,
      removeDuplicateSubjects = "keep all",
      restrictToCommonPeriod = FALSE,
      washoutPeriod = 0,
      covariateSettings = covSettings,
      verbose=FALSE))

    #TODO: make sure this is the correct settings for us
    studyPopulation <- suppressMessages(createStudyPopulation(cohortMethodData = cohortMethodData,
                                                              outcomeId = 31,
                                                              firstExposureOnly = FALSE,
                                                              restrictToCommonPeriod = FALSE,
                                                              washoutPeriod = 0,
                                                              removeDuplicateSubjects = "keep all",
                                                              removeSubjectsWithPriorOutcome = FALSE,
                                                              priorOutcomeLookback = 99999,
                                                              minDaysAtRisk = 0,
                                                              riskWindowStart = 0,
                                                              startAnchor = "cohort start",
                                                              riskWindowEnd = 30,
                                                              endAnchor = "cohort end",
                                                              censorAtNewRiskWindow = FALSE))

    #TODO: make sure this corresponds to the exact same data as in the above cohortMethodData
    cohort11 <- suppressMessages(getDbCovariateData(
      connectionDetails = connectionDetails,
      cdmDatabaseSchema = cdmDatabaseSchema,
      cohortDatabaseSchema = resultsDatabaseSchema,
      cohortTable = tempTableName,
      cohortId = c(11),
      covariateSettings = covSettings,
      aggregated = FALSE))

    suppressMessages(saveCohortMethodData(cohortMethodData, file = filename))
    suppressMessages(saveCovariateData(cohort11, file = filename2))
    suppressMessages(saveRDS(studyPopulation, file = filename3))
  }  
  cohortMethodData <- suppressMessages(loadCohortMethodData(file = filename))
  cohort11 <- suppressMessages(loadCovariateData(file = filename2))
  studyPopulation <- suppressMessages(readRDS(file = filename3))
  
  
  ########################################################################
  # cohort 21: drug
  
  tic()
  filename = paste0("cohort_data/",schema_name,"_cohort21-",drug_id,".Rdata")
  if (!file.exists(filename) | force_create_new){
    # compute cohort and save to file
    if(verbose) {print(paste0("Retrieving covariates for cohort 21 from scratch, saving to : ", filename)) }
    
    #TODO: make sure this is the correct settings for us
    #TODO: implement only including one random occurrence of each person
    cohort21 <- suppressMessages(getDbCovariateData(connectionDetails = connectionDetails,
                                                    cdmDatabaseSchema = cdmDatabaseSchema,
                                                    cohortDatabaseSchema = resultsDatabaseSchema,
                                                    cohortTable = tempTableName,
                                                    cohortId = 21,
                                                    covariateSettings = covSettings,
                                                    aggregated = FALSE))
    
    suppressMessages(saveCovariateData(cohort21, file = filename))
  }  
  cohort21 <- loadCovariateData(file = filename)
  
  ########################################################################
  # cohort 31: event
  filename = paste0("cohort_data/",schema_name,"_cohort31-",event_id,".Rdata")
  if (!file.exists(filename) | force_create_new){
    # compute cohort and save to file
    if(verbose) { print(paste0("Retrieving covariates for cohort 3 from scratch, saving to : ", filename)) }
    
    #TODO: make sure this is the correct settings for us
    #TODO: implement only including one random occurence of each person
    cohort31 <- suppressMessages(getDbCovariateData(connectionDetails = connectionDetails,
                                                    cdmDatabaseSchema = cdmDatabaseSchema,
                                                    cohortDatabaseSchema = resultsDatabaseSchema,
                                                    cohortTable = tempTableName,
                                                    cohortId = 31,
                                                    covariateSettings = covSettings,
                                                    aggregated = FALSE))
    
    suppressMessages(saveCovariateData(cohort31, file = filename))
  }  
  cohort31 <- loadCovariateData(file = filename)
  
  ########################################################################
  #cohort 41: any drug
  cohort41 = NULL
  filename = paste0("cohort_data/",schema_name,"_cohort41-anydrug.Rdata")
  if (!file.exists(filename) | force_create_new){
    # compute cohort and save to file
    if(verbose) { print(paste0("Retrieving covariates for cohort 41 from scratch, saving to : ", filename)) }
    
    #TODO: make sure this is the correct settings for us
    #TODO: implement only including one random occurence of each person
    cohort41 <- suppressMessages(getDbCovariateData(connectionDetails = connectionDetails,
                                                    cdmDatabaseSchema = cdmDatabaseSchema,
                                                    cohortDatabaseSchema = resultsDatabaseSchema,
                                                    cohortTable = tempTableName,
                                                    cohortId = 41,
                                                    covariateSettings = covSettings4,
                                                    aggregated = FALSE))
    
    suppressMessages(saveCovariateData(cohort41, file = filename))
  }
  cohort41 <- suppressMessages(loadCovariateData(file = filename))
  
  toc()
  
  if(verbose) { print("All cohort covariates created or loaded.") }
  
  return(list(studyPopulation, cohortMethodData, cohort11, cohort21, cohort31, cohort41))
}


