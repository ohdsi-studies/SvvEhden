########################################################################
# cohort_module: A function that uses IcTemporalPatternDiscovery::getChronographData from AzureDevOps, to create the chronograph based on the cohorts.

#   i: The index variable in the for-loop.
#   Input parameters contained in the saddle-list:
#   saddle$db_name:     string with name of database
#   saddle$schema_name: string with schema_name in database
#   cohort_table_name:  table where the cohorts are stored, found in saddle$resultsTableName, defaults to "cohorts_*username*".
#   saddle$overall_verbose: print informative messages? 
########################################################################

chronograph_module <- function(i, saddle){
  
  # tic("Chronograph module")
  
  # Unpack the saddle 
  db_name <- saddle$db_name
  schema_name <- saddle$schema_name
  cohortDatabaseSchema <- saddle$resultsDatabaseSchema 
  cohort_table_name <- saddle$resultsTableName
  verbose <- saddle$overall_verbose
  if(verbose) { print("Create chronograph data") }

  connectionDetails <- saddle$connectionDetails
  #con <- suppressMessages(connect(connectionDetails))
  
  test_data <- getChronographData(connectionDetails = connectionDetails,
                                  cdmDatabaseSchema = paste(db_name, schema_name, sep="."),
                                  exposureIds = c(42,22), #background
                                  outcomeIds = c(32),
                                  exposureOutcomePairs = data.frame(exposureId=c(22), outcomeId=c(32)),
                                  exposureDatabaseSchema = cohortDatabaseSchema,
                                  outcomeDatabaseSchema = cohortDatabaseSchema,
                                  exposureTable = cohort_table_name,
                                  outcomeTable = cohort_table_name)
  
  if(verbose) { print("Create chronograph plot") }
  
  plot <- plotChronograph(test_data,
                  exposureId = 22,
                  outcomeId = 32)
  
  if(verbose) { print("Chronograph created") }
  
  # toc()
  return(plot)
}
