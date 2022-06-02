
#' @export
prepare_any_drug_cohort <- function(connectionDetails,
                                    cdmDatabaseSchema,
                                    cohortDatabaseSchema,
                                    cohortTable,
                                    tempEmulationSchema,
                                    fixed_TAR = 365,
                                    sqlFolder,
                                    generateAnyDrugCohortSql = "any_drug_cohort.sql",
                                    jsonFolder,
                                    comparatorDrugJson = "generic_comparator_drug_cohort.json"
                                    ) {
  conn <- DatabaseConnector::connect(connectionDetails)
  
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
    fixed_TAR = fixed_TAR
  )
  
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

