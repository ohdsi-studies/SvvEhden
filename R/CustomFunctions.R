###################
#' @title
#' Title
#'
#' @description
#' This function loads the csvs created by CohortDiagnostics into an (initiated manually outside of this function) PostGreSQL-database. This serves as a backend to the shiny app which hosts CohortDiagnostics. The function takes all csv-files in the export folder and tries to load them into the specified schema of the PostGreSQL database. 
#'
#' @param connectionDetails     An R object of type \code{ConnectionDetails} created using the
#'                                 function \code{createConnectionDetails} in the
#'                                 \code{DatabaseConnector} package.
#' @param project_root_path  A string containing the path to the root of the Rstudio project.
#' @param schema  A string of the schema where the CohortDiagnostics-backend data is to be placed.
#'
#' @return
#' Returns nothing. 
#'
#' @export

loadCsvIntoPostGreSQL <- function(connectionDetails = postGresConnectionDetails,
                                  project_root_path = 'path_to_project_root',
                                  export_folder = exportFolder_after_slash,
                                  schema = schema_to_insert_into,
                                  dropTableIfExists = TRUE){
  
  checkmate::qassert(project_root_path, "s1")
  checkmate::qassert(schema, "s1")
  export_folder_path <- paste0(project_root_path, "//", export_folder)
  
  connection <- connect(connectionDetails)
  DatabaseConnector::executeSql(connection, paste0("CREATE SCHEMA IF NOT EXISTS ", schema, ";"))
  
  # Get the full paths name for reading in
  full_path_all_objects_in_export_folder <- dir(export_folder_path, full.names=TRUE)
  full_path_csvs_in_export_folder <- stringr::str_subset(full_path_all_objects_in_export_folder, ".csv")  
  
  # Get the names of each data table for insertion in DB
  all_objects_in_export_folder <- dir(export_folder_path, full.names=FALSE)
  csvs_in_export_folder <- stringr::str_subset(all_objects_in_export_folder, ".csv")  
  csvs_in_export_folder <- stringr::str_replace(csvs_in_export_folder, ".csv", "")
  
  # According to Martijn, PostGres prefers lowercase names for tables and schemas
  schema <- tolower(schema)
  csvs_in_export_folder <- tolower(csvs_in_export_folder)
  
  if(length(csvs_in_export_folder) != length(csvs_in_export_folder)){
    "The number of csv-paths does not match the number of csv table names."
  }
  
  N_csvs_to_write <- length(csvs_in_export_folder)
  
  for (i in 1:N_csvs_to_write) {
    
    # i = 19 
    path_i = full_path_csvs_in_export_folder[i]
    table_name_i = csvs_in_export_folder[i]
    
    table_df_i <- data.table::fread(path_i, data.table=FALSE)
    table_df_i[is.na(table_df_i)] = ""
    
    writeLines(paste("Inserting table ", table_name_i))
    
    DatabaseConnector::insertTable(connection = connection,
                                   tableName = paste(schema, table_name_i, sep = "."),
                                   data = table_df_i,
                                   dropTableIfExists = dropTableIfExists,
                                   createTable = dropTableIfExists,
                                   tempTable = FALSE,
                                   progressBar = TRUE,
                                   camelCaseToSnakeCase = TRUE)
  }
  
  # These scripts convert the INT-columns to numeric. If there are "" in INT-columns, postgres crashes,
  # but for numeric it seems to work.
  # There's probably a much better way of doing this, using these functions, but I haven't gotten there yet:
  # Column names of a table:
  
#   connection <- connect(postGresConnectionDetails)  
#   schema_with_right_types <- "synpuf_premerge_3tar_1db"
#   
#   tables <- DatabaseConnector::querySql(connection, "SELECT * FROM INFORMATION_SCHEMA.tables WHERE table_schema = 'synpuf_premerge_3tar_1db';")$TABLE_NAME
#   list_of_all_tables <- list()
#   
#   for(i in 1:length(tables)){
#     # i = 1
#     t = tables[i]
#     column_names <- DatabaseConnector::querySql(connection, paste0("SELECT * FROM synpuf_premerge_3tar_1db.", t ," WHERE FALSE;"))
#     colnames_per_table <- names(column_names)
#     
#     table_with_colnames <- cbind.data.frame(rep(t, length(colnames_per_table)), colnames_per_table)
#     colnames(table_with_colnames) = c("tablename", "colname")
#     table_with_colnames$type = NA
#     
#     for(j in 1:nrow(table_with_colnames)){
#       table_with_colnames$type[j] <- DatabaseConnector::querySql(connection, paste0("SELECT pg_typeof(", table_with_colnames$colname[j],") FROM synpuf_premerge_3tar_1db.",  table_with_colnames$tablename[j] ," LIMIT 1"))
#     }
#     list_of_all_tables[[i]] = table_with_colnames
#   }
#   
# long_df <- do.call(bind_rows, list_of_all_tables)
# 
# integer_df <- long_df %>% filter(type == "integer")
# 
# for( i in 1:nrow(integer_df)){
#   # i = 1
#   cat(integer_df$tablename, " : ", integer_df$colname)
#   DatabaseConnector::executeSql(connection, paste0("ALTER TABLE ", "test_schema" ,".", integer_df$tablename[i],
#   " ALTER COLUMN ", integer_df$colname[i] ,"  TYPE NUMERIC"))
# }
  
  
  # column_names <- DatabaseConnector::querySql(connection, "SELECT * FROM test_schema.analysis_ref WHERE FALSE;")
  # Type of a column:
  # DatabaseConnector::querySql(connection, "SELECT pg_typeof(analysis_id) FROM test_schema.ANALYSIS_REF LIMIT 1")
  # (Need a way tp get all table names as well to do exhaustive full ALTER of all INT-columns.)
  
  # We probably need to expand this list as we debug further, with more tables
  
#   DatabaseConnector::executeSql(connection, paste0("ALTER TABLE ", schema ,".TEMPORAL_ANALYSIS_REF
# ALTER COLUMN ANALYSIS_ID TYPE NUMERIC"))
#   
#   DatabaseConnector::executeSql(connection, paste0("ALTER TABLE ", schema ,".TEMPORAL_COVARIATE_REF
# ALTER COLUMN COVARIATE_ID TYPE NUMERIC"))
#   
#   DatabaseConnector::executeSql(connection, paste0("ALTER TABLE ", schema ,".TEMPORAL_COVARIATE_VALUE
# ALTER COLUMN COHORT_ID TYPE NUMERIC,
# ALTER COLUMN TIME_ID TYPE NUMERIC,
# ALTER COLUMN COVARIATE_ID TYPE NUMERIC,
# ALTER COLUMN SUM_VALUE TYPE NUMERIC"))
#   
#   
#   ######### Covariate table casting 
#   
#   DatabaseConnector::executeSql(connection, paste0("ALTER TABLE ", schema ,".COVARIATE_REF
# ALTER COLUMN COVARIATE_ID TYPE NUMERIC,
# ALTER COLUMN ANALYSIS_ID TYPE NUMERIC,
# ALTER COLUMN CONCEPT_ID TYPE NUMERIC"))
#   
#   DatabaseConnector::executeSql(connection, paste0("ALTER TABLE ", schema ,".COVARIATE_VALUE
# ALTER COLUMN COHORT_ID TYPE NUMERIC,
# ALTER COLUMN COVARIATE_ID TYPE NUMERIC,
# ALTER COLUMN SUM_VALUE TYPE NUMERIC"))
#   
#   DatabaseConnector::executeSql(connection, paste0("ALTER TABLE ", schema ,".COVARIATE_VALUE_DIST
# ALTER COLUMN cohort_id TYPE NUMERIC,
# ALTER COLUMN covariate_id TYPE NUMERIC,
# ALTER COLUMN count_value TYPE NUMERIC,
# ALTER COLUMN min_value TYPE NUMERIC,
# ALTER COLUMN max_value TYPE NUMERIC,
# ALTER COLUMN median_value TYPE NUMERIC,
# ALTER COLUMN p_10_value TYPE NUMERIC,
# ALTER COLUMN p_25_value TYPE NUMERIC,
# ALTER COLUMN p_75_value TYPE NUMERIC,
# ALTER COLUMN p_90_value  TYPE NUMERIC"))
  
  #   
  #   DatabaseConnector::executeSql(connection, paste0("ALTER TABLE ", schema ,".analysis_ref
  # ALTER COLUMN analysis_id TYPE NUMERIC,
  # ALTER COLUMN start_day TYPE NUMERIC,
  # ALTER COLUMN end_day TYPE NUMERIC"))
  #   
  #   DatabaseConnector::executeSql(connection, paste0("ALTER TABLE ", schema ,".incidence_rate
  # ALTER COLUMN cohort_count TYPE NUMERIC,
  # ALTER COLUMN calendar_year TYPE NUMERIC,
  # ALTER COLUMN cohort_id TYPE NUMERIC"))
  #   
  #   DatabaseConnector::executeSql(connection, paste0("ALTER TABLE ", schema ,".chronograph_data
  # ALTER COLUMN periodid TYPE NUMERIC,
  # ALTER COLUMN observed TYPE NUMERIC,
  # ALTER COLUMN comparatorcohortid TYPE NUMERIC,
  # ALTER COLUMN outcomecohortid TYPE NUMERIC,
  # ALTER COLUMN targetcohortid TYPE NUMERIC"))
  
  
  disconnect(connection)  
}

convertPostGresTypes <- function(connection){
  connection <- connect(postGresConnectionDetails)  
  schema_with_right_types <- "synpuf_premerge_3tar_1db"
  
  tables <- DatabaseConnector::querySql(connection, "SELECT * FROM INFORMATION_SCHEMA.tables WHERE table_schema = 'synpuf_premerge_3tar_1db';")$TABLE_NAME
  list_of_all_tables <- list()
  
  for(i in 1:length(tables)){
    # i = 1
    t = tables[i]
    column_names <- DatabaseConnector::querySql(connection, paste0("SELECT * FROM synpuf_premerge_3tar_1db.", t ," WHERE FALSE;"))
    colnames_per_table <- names(column_names)
    
    table_with_colnames <- cbind.data.frame(rep(t, length(colnames_per_table)), colnames_per_table)
    colnames(table_with_colnames) = c("tablename", "colname")
    table_with_colnames$type = NA
    
    for(j in 1:nrow(table_with_colnames)){
      table_with_colnames$type[j] <- DatabaseConnector::querySql(connection, paste0("SELECT pg_typeof(", table_with_colnames$colname[j],") FROM synpuf_premerge_3tar_1db.",  table_with_colnames$tablename[j] ," LIMIT 1"))
    }
    list_of_all_tables[[i]] = table_with_colnames
  }
  
  long_df <- do.call(bind_rows, list_of_all_tables)
  
  integer_df <- long_df %>% filter(type == "integer")
  
  for( i in 1:nrow(integer_df)){
    # i = 2
    cat(integer_df$tablename[i], " : ", integer_df$colname[i])
    DatabaseConnector::executeSql(connection, paste0("ALTER TABLE ", "test_schema" ,".", integer_df$tablename[i],
                                                     " ALTER COLUMN ", tolower(integer_df$colname[i]) ," TYPE NUMERIC"))
  }
  
} 


#' @export
compress_all_result_batches <- function(mainFolder = "C:/users/sarahe/OneDrive - WHO Collaborating Centre for International Drug Monitoring/GitProjects/SVVEHDEN/SVVEHDEN CohortDiagnosticsMod study package",
                                        exportFolder = "export",
                                        databaseId = "dummydatabaseid" ) {

  exportFolders = list.files(mainFolder, pattern = paste0(exportFolder,"[0-9]+$"), full.names=TRUE)
  batch_zip_files = list()
  for(i in 1:length(exportFolders)) {
    
    fileName <- list.files(exportFolders[[i]], pattern = "Results_.*zip$", full.names=TRUE)
    if (length(fileName) == 0) {
      warning(paste0("Could not find results file in folder. Did you run (and complete) execute? \n",exportFolders[[i]]))
    } else if (length(fileName) > 1) {
      warning(paste0("Multiple results files found. Don't know which one to upload \n",exportFolders[[i]]))
    } else {
      batch_zip_files[[length(batch_zip_files)+1]] = fileName
    }
    
  }
  
  dir.create(file.path(mainFolder,exportFolder), showWarnings = FALSE)
  zipName <- file.path(mainFolder,exportFolder, paste0("Results_allBatches_", databaseId, ".zip"))
  files <- batch_zip_files
  wd <- getwd()
  on.exit(setwd(wd), add = TRUE)
  setwd( file.path(mainFolder,exportFolder) )
  DatabaseConnector::createZipFile(zipFile = zipName, files = files)
  ParallelLogger::logInfo("Results are ready for sharing at: ", zipName)
}

#' @export
prepare_any_drug_cohort <- function(connectionDetails,
                                    cdmDatabaseSchema,
                                    cohortDatabaseSchema,
                                    cohortTable,
                                    tempEmulationSchema,
                                    fixed_TARs = c(365),
                                    sqlFolder,
                                    generateAnyDrugCohortSql = "any_drug_cohort.sql",
                                    jsonFolder,
                                    comparatorDrugJson = "generic_comparator_drug_cohort.json"
) {
  conn <- DatabaseConnector::connect(connectionDetails)
  
  for (TAR in fixed_TARs){
    # create any drug base cohort in database
    sql <- SqlRender::readSql(file.path(sqlFolder,generateAnyDrugCohortSql))
    DatabaseConnector::renderTranslateExecuteSql(
      connection = conn,
      sql = sql,
      tempEmulationSchema = tempEmulationSchema,
      progressBar = FALSE,
      reportOverallTime = FALSE,
      cdm_database_schema = cdmDatabaseSchema,
      target_database_schema = cohortDatabaseSchema,
      target_cohort_table = cohortTable,
      fixed_TAR = TAR
    )
  }
  
  #debug part: if you want to run it manually
  #fileConn<-file(paste0("..\\inst\\sql\\sql_server\\last_create_any_drug_cohort.sql"))
  #write(sql, fileConn)
  #close(fileConn)
  
  # create comparator drug json file, based on any drug cohort
  sql <- SqlRender::readSql(file.path(sqlFolder,"generate_all_drug_concepts.sql"))
  all_drug_concepts <- DatabaseConnector::renderTranslateQuerySql(
    conn, 
    sql,
    tempEmulationSchema = tempEmulationSchema,
    cdm_database_schema = cdmDatabaseSchema
  )
  json1 <- paste(readLines(file.path(jsonFolder, "json_template_1.json")), collapse = "\n")
  json2 <- paste(readLines(file.path(jsonFolder, "json_template_2.json")), collapse = "\n")
  json3 <- paste(readLines(file.path(jsonFolder, "json_template_3.json")), collapse = "\n")
  
  json2_full <- ""
  json4_full <- ""
  for(i in 1:nrow(all_drug_concepts)) {
    json2_replaced <- gsub(pattern = "||concept_id||",   replacement = all_drug_concepts$CONCEPT_ID[i], x = json2, fixed = TRUE)
    json2_replaced <- gsub(pattern = "||concept_code||",   replacement = all_drug_concepts$CONCEPT_CODE[i], x = json2_replaced, fixed = TRUE)
    json2_replaced <- gsub(pattern = "||concept_name||",   replacement = all_drug_concepts$CONCEPT_NAME[i], x = json2_replaced, fixed = TRUE) 
    
    if(i == 1) json2_full <- paste0(json2_full,      json2_replaced)
    else       json2_full <- paste0(json2_full, ",", json2_replaced)
  }
  write.table(paste0(json1, json2_full, json3), 
              file = file.path(jsonFolder, comparatorDrugJson), 
              sep = "", 
              row.names = FALSE,
              col.names = FALSE,
              quote = FALSE,
              append = FALSE)
  return(all_drug_concepts)
}

#' @export
get_tar_options <- function(cohortToCreateFile = "settings/cohortsToCreate.csv") {
  errorMessage = checkmate::makeAssertCollection()
  displayErrors <- FALSE
  
  if (is.null(errorMessage) |
      !class(errorMessage) == 'AssertColection') {
    displayErrors <- TRUE
    errorMessage <- checkmate::makeAssertCollection()
  }
  pathToCsv <-cohortToCreateFile
  checkmate::assertFileExists(
    x = pathToCsv,
    access = "r",
    extension = "csv",
    add = errorMessage
  )
  
  tar_options <- readr::read_csv(pathToCsv,
                                 col_types = readr::cols(),
                                 guess_max = min(1e7))$fixed_TAR %>% unique()
  
  return(tar_options[tar_options != 0])
}

###################
#' @title
#' Divide output csv-files into smaller csv-files by DEC groups
#'
#' @description
#' Reads in all output csv files, and creates separate zip-files for each DEC.
#'
#' @param folder_path               The path to where the csv-files to slice-and-dice lives.
#' @param cohortids_per_dec          A data frame containing two integer columns cohort_id and dec
#' 
#'
#' @return
#' Nothing, but stores as many folders as there are DECs on the folderPath.
#'
#' @export

divide_csv_output_by_DEC <- function(folder_path = "export" ,
                                     cohortids_per_dec = NULL){
  
  # Prel inputs 
  cohortids_per_dec <- data.frame(cohort_id = c(1,2,3,4), dec = c(1,1,2,2))
  folder_path = "C:/Users/OskarG/OneDrive - WHO Collaborating Centre for International Drug Monitoring/Rwd/SVVEHDEN/SVVEHDEN CohortDiagnosticsMod study package/export"
  
  # Input checks
  checkmate::qassert(folder_path, "S1[1,]")
  
  paths_to_csvs <- dir(folder_path, full.names=T)
  N_csvs <- length(paths_to_csvs)
  
  for(i in 1:N_csvs){
    # i = 1
    temp_df <- data.table::fread(paths_to_csvs[i])
    colnames(temp_df)
    
    
    
  }
  
  
} 
