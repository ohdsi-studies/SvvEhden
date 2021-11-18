########################################################################
# cohort_module: A function that uses IcTemporalPatternDiscovery::getChronographData from AzureDevOps, to create the chronograph based on the cohorts.

#   i: The index variable in the for-loop.
#   Input parameters contained in the saddle-list:
#   cohort_table_name:  table where the cohorts are stored, found in saddle$resultsTableName, defaults to "cohorts_*username*".
#   saddle$overall_verbose: print informative messages? 
########################################################################

chronograph_module <- function(i, saddle, cohort_list){
  
  # tic("Chronograph module")
  
  # Unpack the saddle 
  schema_name <- saddle$databaseSchema
  cohortDatabaseSchema <- saddle$resultsDatabaseSchema 
  cohort_table_name <- saddle$resultsTableName
  verbose <- saddle$overall_verbose
  if(verbose) { print("Create chronograph data") }

  connectionDetails <- saddle$connectionDetails
  #con <- suppressMessages(connect(connectionDetails))
  
  test_data <- getChronographData(connectionDetails = connectionDetails,
                                  cdmDatabaseSchema = schema_name,
                                  exposureIds = c(42,22), #background
                                  outcomeIds = c(32),
                                  exposureOutcomePairs = data.frame(exposureId=c(22), outcomeId=c(32)),
                                  exposureDatabaseSchema = cohortDatabaseSchema,
                                  outcomeDatabaseSchema = cohortDatabaseSchema,
                                  exposureTable = cohort_table_name,
                                  outcomeTable = cohort_table_name)
  
  if(verbose) { print("Create chronograph plot") }
  plot <- plotChronograph(data = test_data,
                          exposureId = 22,
                          outcomeId = 32)
  
  if(verbose) { print("Chronograph created") }
  
  # toc()
  return(plot)
}
