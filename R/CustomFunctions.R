
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
