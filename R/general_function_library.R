########################
# Function library
#########################

# This function library is sourced in the beginning of the workhorse-script, that's sourced by the Rmarkdown-script. 
# It contains basic functions that the workhorse needs to run the other scripts. 
# The modules (demographics, comedications, comorbidities, chronograph) are sourced separately when needed. 

install_if_missing <- function(package_vec = c("package_A", 
                                               "package_B")) {
  for (i in 1:length(package_vec)) {
    if (!package_vec[i] %in% installed.packages()[, 1]) {
      suppressMessages(invisible(install.packages(package_vec[i], 
                                                  repos = "http://cran.us.r-project.org")))
    }
  }
}

library_packages <- function (package_vec = NULL){
  # Install some packages from OHDSIs github
  if(any(! c("drat", "FeatureExtraction", "CohortMethod") %in% installed.packages()[,1])){
    drat::addRepo("OHDSI")
    install.packages("FeatureExtraction")
    install.packages("CohortMethod")
  }
  
  package_vec <- c("plyr", "dplyr", "magrittr", "data.table", "stringr", "lubridate", "here", "ggplot2", 
                   "DT", "forcats", "gridExtra", "kableExtra", "knitr", "RColorBrewer","ggnewscale", "egg",
                   "plotly", "xlsx", "reshape2", "zeallot", "DatabaseConnector", "OhdsiSharing",
                   "SqlRender", "tidyr", "tictoc", "jquerylib")
  
  install_if_missing(package_vec)
  invisible(suppressMessages(lapply(package_vec, library, character.only = T)))
}

# library_packages(package_vec)

get_all_drugs <- function(conn, databaseSchema){
  
  # Will find these parameters from the workhorse scope
  sql_query <- "SELECT DISTINCT drug_concept_id FROM @databaseSchema.[drug_era]"
  drug_ids <- querySql(conn, SqlRender::render(sql_query, databaseSchema=databaseSchema)) %>% dplyr::pull(DRUG_CONCEPT_ID)
  return(drug_ids)
}

# This function is needed in the custom_getDbCohortMethodData

getCounts <- function(population, description = "") {
  targetPersons <- length(unique(population$personSeqId[population$treatment == 1]))
  comparatorPersons <- length(unique(population$personSeqId[population$treatment == 0]))
  targetExposures <- length(population$personSeqId[population$treatment == 1])
  comparatorExposures <- length(population$personSeqId[population$treatment == 0])
  counts <- dplyr::tibble(description = description,
                          targetPersons = targetPersons,
                          comparatorPersons = comparatorPersons,
                          targetExposures = targetExposures,
                          comparatorExposures = comparatorExposures)
  return(counts)
}


##############################################################################

# Changed in the call to getDbCovariates: rowIdField = "subject_id"
custom_getDbCohortMethodData <- function (connectionDetails, cdmDatabaseSchema, oracleTempSchema = NULL, 
                                          tempEmulationSchema = getOption("sqlRenderTempEmulationSchema"), 
                                          targetId, comparatorId, outcomeIds, studyStartDate = "", 
                                          studyEndDate = "", exposureDatabaseSchema = cdmDatabaseSchema, 
                                          exposureTable = "drug_era", outcomeDatabaseSchema = cdmDatabaseSchema, 
                                          outcomeTable = "condition_occurrence", cdmVersion = "5", 
                                          excludeDrugsFromCovariates = NULL, firstExposureOnly = FALSE, 
                                          removeDuplicateSubjects = FALSE, restrictToCommonPeriod = FALSE, 
                                          washoutPeriod = 0, maxCohortSize = 0, covariateSettings, verbose=FALSE) 
{
  if (!is.null(excludeDrugsFromCovariates)) {
    warning("The excludeDrugsFromCovariates argument has been deprecated. Please explicitly exclude the drug concepts in the covariate settings")
  }
  else {
    excludeDrugsFromCovariates = FALSE
  }
  if (!is.null(oracleTempSchema) && oracleTempSchema != "") {
    warning("The 'oracleTempSchema' argument is deprecated. Use 'tempEmulationSchema' instead.")
    tempEmulationSchema <- oracleTempSchema
  }
  if (is.null(studyStartDate)) {
    studyStartDate <- ""
  }
  if (is.null(studyEndDate)) {
    studyEndDate <- ""
  }
  if (studyStartDate != "" && regexpr("^[12][0-9]{3}[01][0-9][0-3][0-9]$", 
                                      studyStartDate) == -1) 
    stop("Study start date must have format YYYYMMDD")
  if (studyEndDate != "" && regexpr("^[12][0-9]{3}[01][0-9][0-3][0-9]$", 
                                    studyEndDate) == -1) 
    stop("Study end date must have format YYYYMMDD")
  if (is.logical(removeDuplicateSubjects)) {
    if (removeDuplicateSubjects) 
      removeDuplicateSubjects <- "remove all"
    else removeDuplicateSubjects <- "keep all"
  }
  if (!(removeDuplicateSubjects %in% c("keep all", "keep first", 
                                       "remove all"))) 
    stop("removeDuplicateSubjects should have value \"keep all\", \"keep first\", or \"remove all\".")
  if(verbose==T){ ParallelLogger::logTrace("Getting cohort method data for target ID ", 
                                           targetId, " and comparator ID ", comparatorId)}
  connection <- DatabaseConnector::connect(connectionDetails)
  on.exit(DatabaseConnector::disconnect(connection))
  if (excludeDrugsFromCovariates) {
    if (exposureTable != "drug_era") 
      warning("Removing drugs from covariates, but not sure if exposure IDs are valid drug concepts")
    sql <- "SELECT descendant_concept_id FROM @cdm_database_schema.concept_ancestor WHERE ancestor_concept_id IN (@target_id, @comparator_id)"
    sql <- SqlRender::render(sql = sql, cdm_database_schema = cdmDatabaseSchema, 
                             target_id = targetId, comparator_id = comparatorId)
    sql <- SqlRender::translate(sql, targetDialect = connectionDetails$dbms)
    conceptIds <- DatabaseConnector::querySql(connection, 
                                              sql, snakeCaseToCamelCase = TRUE)
    conceptIds <- conceptIds$descendantConceptId
    if(verbose==T){ParallelLogger::logDebug("Excluding concept Ids from covariates: ", 
                                            paste(conceptIds, collapse = ", "))}
    if (is(covariateSettings, "covariateSettings")) {
      covariateSettings$excludedCovariateConceptIds <- c(covariateSettings$excludedCovariateConceptIds, 
                                                         conceptIds)
    }
    else if (is.list(covariateSettings)) {
      for (i in 1:length(covariateSettings)) {
        covariateSettings[[i]]$excludedCovariateConceptIds <- c(covariateSettings[[i]]$excludedCovariateConceptIds, 
                                                                conceptIds)
      }
    }
  }
  if(verbose==T){ParallelLogger::logInfo("Constructing target and comparator cohorts")}
  renderedSql <- SqlRender::loadRenderTranslateSql("CreateCohorts.sql", 
                                                   packageName = "CohortMethod", dbms = connectionDetails$dbms, 
                                                   tempEmulationSchema = tempEmulationSchema, cdm_database_schema = cdmDatabaseSchema, 
                                                   exposure_database_schema = exposureDatabaseSchema, exposure_table = exposureTable, 
                                                   cdm_version = cdmVersion, target_id = targetId, comparator_id = comparatorId, 
                                                   study_start_date = studyStartDate, study_end_date = studyEndDate, 
                                                   first_only = firstExposureOnly, remove_duplicate_subjects = removeDuplicateSubjects, 
                                                   washout_period = washoutPeriod, restrict_to_common_period = restrictToCommonPeriod)
  suppressMessages(DatabaseConnector::executeSql(connection, renderedSql, progressBar = FALSE))
  sampled <- FALSE
  if (maxCohortSize != 0) {
    renderedSql <- SqlRender::loadRenderTranslateSql("CountCohorts.sql", 
                                                     packageName = "CohortMethod", dbms = connectionDetails$dbms, 
                                                     tempEmulationSchema = tempEmulationSchema, cdm_version = cdmVersion, 
                                                     target_id = targetId)
    counts <- DatabaseConnector::querySql(connection, renderedSql, 
                                          snakeCaseToCamelCase = TRUE)
    if(verbose==T){ParallelLogger::logDebug("Pre-sample total row count is ", 
                                            sum(counts$rowCount))}
    preSampleCounts <- dplyr::tibble(dummy = 0)
    idx <- which(counts$treatment == 1)
    if (length(idx) == 0) {
      preSampleCounts$targetPersons = 0
      preSampleCounts$targetExposures = 0
    }
    else {
      preSampleCounts$targetPersons = counts$personCount[idx]
      preSampleCounts$targetExposures = counts$rowCount[idx]
    }
    idx <- which(counts$treatment == 0)
    if (length(idx) == 0) {
      preSampleCounts$comparatorPersons = 0
      preSampleCounts$comparatorExposures = 0
    }
    else {
      preSampleCounts$comparatorPersons = counts$personCount[idx]
      preSampleCounts$comparatorExposures = counts$rowCount[idx]
    }
    preSampleCounts$dummy <- NULL
    if (preSampleCounts$targetExposures > maxCohortSize) {
      if(verbose==T){ParallelLogger::logInfo("Downsampling target cohort from ", 
                                             preSampleCounts$targetExposures, " to ", 
                                             maxCohortSize)}
      sampled <- TRUE
    }
    if (preSampleCounts$comparatorExposures > maxCohortSize) {
      if(verbose==T){ParallelLogger::logInfo("Downsampling comparator cohort from ", 
                                             preSampleCounts$comparatorExposures, " to ", 
                                             maxCohortSize)}
      sampled <- TRUE
    }
    if (sampled) {
      renderedSql <- SqlRender::loadRenderTranslateSql("SampleCohorts.sql", 
                                                       packageName = "CohortMethod", dbms = connectionDetails$dbms, 
                                                       tempEmulationSchema = tempEmulationSchema, cdm_version = cdmVersion, 
                                                       max_cohort_size = maxCohortSize)
      suppressMessages(DatabaseConnector::executeSql(connection, renderedSql, progressBar))
    }
  }
  if(verbose==T){ParallelLogger::logInfo("Fetching cohorts from server")}
  start <- Sys.time()
  cohortSql <- SqlRender::loadRenderTranslateSql("GetCohorts.sql", 
                                                 packageName = "CohortMethod", dbms = connectionDetails$dbms, 
                                                 tempEmulationSchema = tempEmulationSchema, cdm_version = cdmVersion, 
                                                 target_id = targetId, sampled = sampled)
  cohorts <- DatabaseConnector::querySql(connection, cohortSql, 
                                         snakeCaseToCamelCase = TRUE)
  if(verbose==T){ ParallelLogger::logDebug("Fetched cohort total rows in target is ", 
                                           sum(cohorts$treatment), ", total rows in comparator is ", 
                                           sum(!cohorts$treatment))}
  if (nrow(cohorts) == 0) {
    warning("Target and comparator cohorts are empty")
  } else if (sum(cohorts$treatment == 1) == 0) {
    warning("Target cohort is empty")
  } else if (sum(cohorts$treatment == 0) == 0) {
    warning("Comparator cohort is empty")
  }
  metaData <- list(targetId = targetId, comparatorId = comparatorId, 
                   studyStartDate = studyStartDate, studyEndDate = studyEndDate)
  if (firstExposureOnly || removeDuplicateSubjects != "keep all" || 
      washoutPeriod != 0) {
    rawCountSql <- SqlRender::loadRenderTranslateSql("CountOverallExposedPopulation.sql", 
                                                     packageName = "CohortMethod", dbms = connectionDetails$dbms, 
                                                     tempEmulationSchema = tempEmulationSchema, cdm_database_schema = cdmDatabaseSchema, 
                                                     exposure_database_schema = exposureDatabaseSchema, 
                                                     exposure_table = tolower(exposureTable), cdm_version = cdmVersion, 
                                                     target_id = targetId, comparator_id = comparatorId, 
                                                     study_start_date = studyStartDate, study_end_date = studyEndDate)
    rawCount <- suppressMessages(DatabaseConnector::querySql(connection, rawCountSql, 
                                                             snakeCaseToCamelCase = TRUE))
    if (nrow(rawCount) == 0) {
      counts <- dplyr::tibble(description = "Original cohorts", 
                              targetPersons = 0, comparatorPersons = 0, targetExposures = 0, 
                              comparatorExposures = 0)
    } else {
      counts <- dplyr::tibble(description = "Original cohorts", 
                              targetPersons = rawCount$exposedCount[rawCount$treatment == 
                                                                      1], comparatorPersons = rawCount$exposedCount[rawCount$treatment == 
                                                                                                                      0], targetExposures = rawCount$exposureCount[rawCount$treatment == 
                                                                                                                                                                     1], comparatorExposures = rawCount$exposureCount[rawCount$treatment == 
                                                                                                                                                                                                                        0])
    }
    metaData$attrition <- counts
    label <- c()
    if (firstExposureOnly) {
      label <- c(label, "first exp. only")
    }
    if (removeDuplicateSubjects == "remove all") {
      label <- c(label, "removed subs in both cohorts")
    } else if (removeDuplicateSubjects == "keep first") {
      label <- c(label, "first cohort only")
    }
    if (restrictToCommonPeriod) {
      label <- c(label, "restrict to common period")
    }
    if (washoutPeriod) {
      label <- c(label, paste(washoutPeriod, "days of obs. prior"))
    }
    label <- paste(label, collapse = " & ")
    substring(label, 1) <- toupper(substring(label, 1, 1))
    if (sampled) {
      preSampleCounts$description <- label
      metaData$attrition <- rbind(metaData$attrition, preSampleCounts)
      metaData$attrition <- rbind(metaData$attrition, getCounts(cohorts, 
                                                                "Random sample"))
    } else {
      metaData$attrition <- rbind(metaData$attrition, getCounts(cohorts, 
                                                                label))
    }
  } else {
    if (sampled) {
      preSampleCounts$description <- "Original cohorts"
      metaData$attrition <- preSampleCounts
      metaData$attrition <- rbind(metaData$attrition, getCounts(cohorts, 
                                                                "Random sample"))
    } else {
      metaData$attrition <- getCounts(cohorts, "Original cohorts")
    }
  }
  delta <- Sys.time() - start
  if(verbose==T){ParallelLogger::logInfo("Fetching cohorts took ", signif(delta, 
                                                                          3), " ", attr(delta, "units"))}
  if (sampled) {
    cohortTable <- "#cohort_sample"
  } else {
    cohortTable <- "#cohort_person"
  }
  # print(tempEmulationSchema)
  # print(cdmDatabaseSchema)
  covariateData <- FeatureExtraction::getDbCovariateData(connection = connection, #getDbCovariateData_debug(connection = connection,
                                                         oracleTempSchema = tempEmulationSchema, 
                                                         cdmDatabaseSchema = cdmDatabaseSchema, 
                                                         cdmVersion = cdmVersion, 
                                                         cohortTable = cohortTable, 
                                                         cohortTableIsTemp = TRUE, 
                                                         rowIdField = "subject_id", 
                                                         covariateSettings = covariateSettings)
  
  if(verbose==T){ParallelLogger::logDebug("Fetched covariates total count is ", 
                                          covariateData$covariates %>% count() %>% pull())}
  if(verbose==T){ParallelLogger::logInfo("Fetching outcomes from server")}
  start <- Sys.time()
  outcomeSql <- SqlRender::loadRenderTranslateSql("GetOutcomes.sql", 
                                                  packageName = "CohortMethod", dbms = connectionDetails$dbms, 
                                                  tempEmulationSchema = tempEmulationSchema, cdm_database_schema = cdmDatabaseSchema, 
                                                  outcome_database_schema = outcomeDatabaseSchema, outcome_table = outcomeTable, 
                                                  outcome_ids = outcomeIds, cdm_version = cdmVersion, sampled = sampled)
  outcomes <- DatabaseConnector::querySql(connection, outcomeSql, 
                                          snakeCaseToCamelCase = TRUE)
  metaData$outcomeIds = outcomeIds
  delta <- Sys.time() - start
  if(verbose==T){ParallelLogger::logInfo("Fetching outcomes took ", 
                                         signif(delta, 3), " ", attr(delta, "units"))}
  if(verbose==T){ParallelLogger::logDebug("Fetched outcomes total count is ", 
                                          nrow(outcomes))}
  renderedSql <- SqlRender::loadRenderTranslateSql("RemoveCohortTempTables.sql", 
                                                   packageName = "CohortMethod", dbms = connectionDetails$dbms, 
                                                   tempEmulationSchema = tempEmulationSchema, sampled = sampled)
  DatabaseConnector::executeSql(connection, renderedSql, progressBar = FALSE, 
                                reportOverallTime = FALSE)
  covariateData$cohorts <- cohorts
  covariateData$outcomes <- outcomes
  attr(covariateData, "metaData") <- append(attr(covariateData, 
                                                 "metaData"), metaData)
  class(covariateData) <- "CohortMethodData"
  attr(class(covariateData), "package") <- "CohortMethod"
  return(covariateData)
}

##############################################################################

custom_createCovariateSettings <- function(exclude_these){
  
  output <- FeatureExtraction::createCovariateSettings(
    
    # Demographics
    useDemographicsGender = TRUE,
    useDemographicsAge = TRUE,
    useDemographicsAgeGroup = TRUE,
    useDemographicsRace = FALSE,
    useDemographicsEthnicity = FALSE,
    useDemographicsIndexYear = FALSE,
    useDemographicsIndexMonth = FALSE,
    useDemographicsPriorObservationTime = FALSE,
    useDemographicsPostObservationTime = FALSE,
    useDemographicsTimeInCohort = FALSE,
    useDemographicsIndexYearMonth = FALSE,
    
    # Condition occurrence 
    useConditionOccurrenceAnyTimePrior = FALSE,
    useConditionOccurrenceLongTerm = TRUE, #### 
    useConditionOccurrenceMediumTerm = FALSE,
    useConditionOccurrenceShortTerm = FALSE,
    useConditionOccurrencePrimaryInpatientAnyTimePrior = FALSE,
    useConditionOccurrencePrimaryInpatientLongTerm = FALSE,
    useConditionOccurrencePrimaryInpatientMediumTerm = FALSE,
    useConditionOccurrencePrimaryInpatientShortTerm = FALSE,
    
    # Condition era
    useConditionEraAnyTimePrior = FALSE,
    useConditionEraLongTerm = FALSE,
    useConditionEraMediumTerm = FALSE,
    useConditionEraShortTerm = FALSE,
    useConditionEraOverlapping = FALSE,
    useConditionEraStartLongTerm = FALSE,
    useConditionEraStartMediumTerm = FALSE,
    useConditionEraStartShortTerm = FALSE,
    
    # Condition group
    useConditionGroupEraAnyTimePrior = FALSE,
    useConditionGroupEraLongTerm = TRUE, ####,    
    useConditionGroupEraMediumTerm = FALSE, 
    useConditionGroupEraShortTerm = FALSE, 
    useConditionGroupEraOverlapping = FALSE,
    useConditionGroupEraStartLongTerm = FALSE,
    useConditionGroupEraStartMediumTerm = FALSE,
    useConditionGroupEraStartShortTerm = FALSE,
    
    # DrugExposure
    useDrugExposureAnyTimePrior = FALSE,
    useDrugExposureLongTerm = FALSE,
    useDrugExposureMediumTerm = FALSE,
    useDrugExposureShortTerm = FALSE,
    useDrugEraAnyTimePrior = FALSE,
    useDrugEraLongTerm = FALSE,
    useDrugEraMediumTerm = FALSE,
    useDrugEraShortTerm = FALSE,
    useDrugEraOverlapping = FALSE,
    useDrugEraStartLongTerm = FALSE,
    useDrugEraStartMediumTerm = FALSE,
    useDrugEraStartShortTerm = FALSE,
    
    # Groups of drugs
    useDrugGroupEraAnyTimePrior = FALSE,
    useDrugGroupEraLongTerm = TRUE, ####,
    useDrugGroupEraMediumTerm = FALSE, 
    useDrugGroupEraShortTerm = FALSE, 
    useDrugGroupEraOverlapping = FALSE,
    useDrugGroupEraStartLongTerm = FALSE,
    useDrugGroupEraStartMediumTerm = FALSE,
    useDrugGroupEraStartShortTerm = FALSE,
    
    # Procedures
    useProcedureOccurrenceAnyTimePrior = FALSE,
    useProcedureOccurrenceLongTerm = FALSE,
    useProcedureOccurrenceMediumTerm = FALSE,
    useProcedureOccurrenceShortTerm = FALSE,
    
    # Devices
    useDeviceExposureAnyTimePrior = FALSE,
    useDeviceExposureLongTerm = FALSE,
    useDeviceExposureMediumTerm = FALSE,
    useDeviceExposureShortTerm = FALSE,
    
    # Measurements
    useMeasurementAnyTimePrior = FALSE,
    useMeasurementLongTerm = FALSE,
    useMeasurementMediumTerm = FALSE,
    useMeasurementShortTerm = FALSE,
    useMeasurementValueAnyTimePrior = FALSE,
    useMeasurementValueLongTerm = FALSE,
    useMeasurementValueMediumTerm = FALSE,
    useMeasurementValueShortTerm = FALSE,
    useMeasurementRangeGroupAnyTimePrior = FALSE,
    useMeasurementRangeGroupLongTerm = FALSE,
    useMeasurementRangeGroupMediumTerm = FALSE,
    useMeasurementRangeGroupShortTerm = FALSE,
    
    # Observation
    useObservationAnyTimePrior = FALSE,
    useObservationLongTerm = FALSE,
    useObservationMediumTerm = FALSE,
    useObservationShortTerm = FALSE,
    
    # Indexes
    useCharlsonIndex = FALSE,
    useDcsi = FALSE,
    useChads2 = FALSE,
    useChads2Vasc = FALSE,
    useHfrs = FALSE,
    
    # Counts
    useDistinctConditionCountLongTerm = FALSE,
    useDistinctConditionCountMediumTerm = FALSE,
    useDistinctConditionCountShortTerm = FALSE,
    useDistinctIngredientCountLongTerm = FALSE,
    useDistinctIngredientCountMediumTerm = FALSE,
    useDistinctIngredientCountShortTerm = FALSE,
    useDistinctProcedureCountLongTerm = FALSE,
    useDistinctProcedureCountMediumTerm = FALSE,
    useDistinctProcedureCountShortTerm = FALSE,
    useDistinctMeasurementCountLongTerm = FALSE,
    useDistinctMeasurementCountMediumTerm = FALSE,
    useDistinctMeasurementCountShortTerm = FALSE,
    useDistinctObservationCountLongTerm = FALSE,
    useDistinctObservationCountMediumTerm = FALSE,
    useDistinctObservationCountShortTerm = FALSE,
    useVisitCountLongTerm = FALSE,
    useVisitCountMediumTerm = FALSE,
    useVisitCountShortTerm = FALSE,
    useVisitConceptCountLongTerm = FALSE,
    useVisitConceptCountMediumTerm = FALSE,
    useVisitConceptCountShortTerm = FALSE,
    
    # Time limits
    longTermStartDays = -round(180),
    mediumTermStartDays = -180,
    shortTermStartDays = -3*30,
    endDays = -1,
    includedCovariateConceptIds = c(),
    addDescendantsToInclude = TRUE,
    includedCovariateIds = c(),
    excludedCovariateConceptIds = exclude_these, 
    addDescendantsToExclude = TRUE)
  return(output)
}

shorten_to_file_path <- function(str = "NONAME") {
  new_str = stringr::str_replace_all(str, "[^a-zA-Z\\d\\s]", "")
  if (nchar(new_str) > 15) { 
    new_str = substr(new_str,0,15) 
  } 
  return(new_str)
}

#####################################################
# interactive barplots comparing cohorts
#####################################################

interactive_barplot <- function(internal_cohort_list, name_list, covariate_list){
  
  #internal_cohort_list = c(cohort1a, cohort2, cohort3, cohort4)
  #name_list = c("1: DEC cohort", "2: drug cohort", "3: event cohort", "4: All drugs cohort")
  #covariate_list = c("gender = FEMALE", "gender = MALE")
  
  summarized_df = data.frame()
  for (i in 1:length(internal_cohort_list)){
    # i = 1
    covariates_for_cohort_i <- as.data.frame(internal_cohort_list[i][[1]]$covariates)
    covariateRef_for_cohort_i <- as.data.frame(internal_cohort_list[i][[1]]$covariateRef)
    covariates_for_cohort_i %<>% 
      dplyr::rename(subject_id = rowId) %>% 
      left_join(covariateRef_for_cohort_i, by="covariateId") %>% 
      select(subject_id, name=covariateName, value=covariateValue, concept_id = conceptId)
    
    cohort_i_df <- covariates_for_cohort_i %>% dplyr::filter(name %in% covariate_list) %>% dplyr::count(name) %>% mutate(Percentage=round(100*n/sum(n)))
    colnames(cohort_i_df)=c("Category","n","Percentage")
    if( length(cohort_i_df$Category) > 0 ) { #ignore if cohort contains 0 rows
      cohort_i_df$Cohort = name_list[i][[1]]
      summarized_df <- rbind(summarized_df, cohort_i_df)
    }
  }
  
  # Add hover-text
  summarized_df$text <- paste0("n = ", summarized_df$n)
  
  # Prepare plot
  g1 <- ggplot2::ggplot(summarized_df, ggplot2::aes(Category, Percentage, text=text)) +   
    ggplot2::geom_bar(ggplot2::aes(fill = Cohort), position = ggplot2::position_dodge(width = 0.9), stat="identity") + ggplot2::xlab("") + ggplot2::ylab("Percentage within each cohort") + ggplot2::coord_flip() 
  
  # Finalize and print
  g1 <- g1 + ggplot2::guides(fill=ggplot2::guide_legend(reverse=T,  title=""))
  html_plot <- plotly::ggplotly(g1, tooltip="text") %>%  plotly::style(hoverlabel = list(bgcolor = "white"))
  html_plot[["x"]][["data"]] <- rev(html_plot[["x"]][["data"]])
  
  #TODO: reverse order! BUT HOW TO? Ordered in alphabetical order, can this be changed?
  
  return (html_plot)
}

error_printer <- function(e, i, output_path){
  
  # This function takes care of printing error messages into the console and a log-txt-file.
  # i = The DEC i in the workhorse script.
  # e = Abbreviation of the error message.
  
  print(paste0("ERROR ON DEC ", i,"!"))
  print(e)
  write(paste0("DEC ", i, ": ", e),file=paste0(output_path,"DEC-error-log.txt"),append=TRUE)
  
}

# R script to set up new eras (drug_ and condition_era_pw390)

# Script taken and modified from:
# https://ohdsi.github.io/CommonDataModel/sqlScripts.html#drug_eras

createEras <- function(saddle){
  
  conn <- suppressMessages(invisible(DatabaseConnector::connect(saddle$connectionDetails)))
  
  # Check whether the database has a drug-era-table with persistence window 390 days already.
  sql <- "SELECT TOP 10 * FROM @TARGET_CDMV5_SCHEMA.@DRUG_ERA_TABLE_NAME;"
  sql <- SqlRender::translate(sql, saddle$connectionDetails$dbms)
  sql <- SqlRender::render(sql, "TARGET_CDMV5_SCHEMA" = saddle$databaseSchema,
                                "DRUG_ERA_TABLE_NAME" = saddle$custom_drugEraTableName)
  result <- tryCatch({DatabaseConnector::querySql(conn, sql)}, error = function(e) {
    e
  })

  # If the output contains "error" in the class, then we treat it as there was no drug_era_pw390:
  if(any(grepl("error", class(result), ignore.case = T))){
      # Create the eras
    sql <- SqlRender::readSql("..\\inst\\sql\\createEraScript.sql")
    sql <- SqlRender::translate(sql, saddle$connectionDetails$dbms)
    sql <- SqlRender::render(sql, "TARGET_CDMV5_SCHEMA" = saddle$databaseSchema, 
                                  "DRUG_ERA_TABLE_NAME" = saddle$custom_drugEraTableName,
                                  "PERSISTENCE_WINDOW_IN_DAYS" = saddle$persistence_window)
    
    fileConn <- file("..\\inst\\sql\\last_createEraScript.sql")
    write(sql, fileConn)
    close(fileConn)
    
    DatabaseConnector::executeSql(conn, sql)
    }
}


saddle_the_workhorse <- function(connectionDetails = NULL,
                                 cdmDatabaseSchema = NULL,
                                 cohortDatabaseSchema = NULL,
                                 cohortTable = NULL,
                                 outputFolderPath = NULL,
                                 persistence_window = 390,
                                 overall_verbose = NULL){
  
  # This function initiates, sources and does everything needed to run the workhorse for-loop
  # Input arguments: 
  # overall_verbose: Should a lot of messages be printed to console?
  # foldername_for_input: where in the SWEHDEN-sprint folder on teams should the output be 
  # saved. Defaults to a folder "output_*your username*".
  
  source("cohort_module.R")   
  source("table1_module.R")  
  source("chronograph_module.R")  
  source("Chronograph.R")    
  source("print_to_html_module.R")    
  
  output_path = outputFolderPath
  if (!exists("outputFolderPath") || is.null(outputFolderPath)){  
    # If no foldername_for_output is supplied in call to saddle to workhorse, the username is used instead
    username <- Sys.getenv("USERNAME")
    foldername_for_output <- paste0("output_", username) 
    path_string <- "C:\\Users\\%s\\WHO Collaborating Centre for International Drug Monitoring\\EHDEN - SWEDHEN-SPRINT\\%s\\"
    output_path = sprintf(path_string, username, foldername_for_output )
  } 
  if(endsWith(output_path, "\\") || endsWith(output_path, "/")) {
    output_path = substr(output_path, 1, nchar(output_path)-1)
  }
  if (!file.exists(output_path)) { dir.create(output_path, recursive = TRUE) }
  output_path = paste0(output_path, "\\")
  
  if(!exists("overall_verbose") || is.null(overall_verbose)){ overall_verbose = FALSE }
  
  # Setup and clear error-file
  write("",file=paste0(output_path,"DEC-error-log.txt"),append=FALSE)
  
  # Set up the connection for the db to be used
  if(!exists("connectionDetails") || is.null(connectionDetails)) {
    connectionDetails <- DatabaseConnector::createConnectionDetails(dbms = "sql server",
                                                 server = "UMCDB06")
  }
  con <- suppressMessages(DatabaseConnector::connect(connectionDetails))

  databaseSchema = cdmDatabaseSchema
  if(!exists("cdmDatabaseSchema") || is.null(cdmDatabaseSchema)) {
    databaseSchema = "OmopCdm.synpuf5pct_20180710" # "mini"
  }
  
  resultsDatabaseSchema = cohortDatabaseSchema
  if(!exists("cohortDatabaseSchema") || is.null(cohortDatabaseSchema)) {
    resultsDatabaseSchema = databaseSchema # Where you want the results to end up
  }

  resultsTableName = cohortTable
  if(!exists("cohortTable") || is.null(cohortTable)) { 
    resultsTableName = paste0("cohorts_",Sys.getenv("USERNAME"),"") 
  }
  
  # Read in the DEC-csv
  if(databaseSchema == "OmopCdm.mini") {
    dec_df <- read.csv("..\\inst\\input\\fake_DEC_list_mini.csv", sep=";")[,-1]
  } else if(connectionDetails$dbms == "sqlite" & exists(which_database) & which_database == "sqlite"){
    dec_df <- read.csv("..\\inst\\input\\eunomia_dec_df.csv")
    dec_df <- dplyr::bind_cols("drug_name" = "fakedrug", "event_name" = "fakeevent", dec_df)
    colnames(dec_df)[3:4] = paste0(colnames(dec_df)[3:4], "_id")
  } else if(grepl(pattern = "synpuf", x = databaseSchema, fixed=TRUE)) {
    dec_df <- read.csv("..\\inst\\input\\fake_DEC_list.csv", sep=";")[,-1] # This one is for our synpuf-data
  } else {
    dec_df <- read.csv("..\\inst\\input\\minisprint_DEC_list_v4.csv", sep=",")[,-1] # this is the "true" combinations list
  }
  
  dec_df$drug_and_event_name <- apply(dec_df[,1:2], 1, 
                                      function(x){
                                        paste0(as.character(x), collapse = " & ")
                                      })
  
  drugEraTableName = paste0("drug_era_pw", persistence_window)
  
  # get drugs from db
  all_drugs <- get_all_drugs(con, databaseSchema)
  
  list("output_path"=output_path, "dec_df"=dec_df, "all_drugs"=all_drugs, 
       "databaseSchema" = databaseSchema, "resultsDatabaseSchema"= resultsDatabaseSchema, 
       "resultsTableName"=resultsTableName, "overall_verbose"=overall_verbose,
       "connectionDetails" = connectionDetails, "persistence_window" = persistence_window,
       "custom_drugEraTableName" = drugEraTableName)
}  

custom_aggregateCovariates <- function(covariateData, verbose=FALSE) 
{
  if (!FeatureExtraction::isCovariateData(covariateData)) 
    stop("Data not of class CovariateData")
  if (!Andromeda::isValidAndromeda(covariateData)) 
    stop("CovariateData object is closed")
  if (FeatureExtraction::isAggregatedCovariateData(covariateData)) 
    stop("Data appears to already be aggregated")
  if (FeatureExtraction::isTemporalCovariateData(covariateData)) 
    stop("Aggregation for temporal covariates is not yet implemented")
  start <- Sys.time()
  result <- Andromeda::andromeda(covariateRef = covariateData$covariateRef, 
                                 analysisRef = covariateData$analysisRef)
  attr(result, "metaData") <- attr(covariateData, "metaData")
  class(result) <- "CovariateData"
  attr(class(result), "package") <- "FeatureExtraction"
  populationSize <- attr(covariateData, "metaData")$populationSize
  result$covariates <- covariateData$analysisRef %>% dplyr::filter(rlang::sym("isBinary") == 
                                                              "Y") %>% dplyr::inner_join(covariateData$covariateRef, 
                                                                                  by = "analysisId") %>% dplyr::inner_join(covariateData$covariates, 
                                                                                                                    by = "covariateId") %>%  dplyr::group_by(rlang::sym("covariateId")) %>% 
    dplyr::summarize(sumValue = sum(rlang::sym("covariateValue"), 
                             na.rm = TRUE), averageValue = sum(rlang::sym("covariateValue")/populationSize, 
                                                               na.rm = TRUE))
  computeStats <- function(data) {
    zeroFraction <- 1 - (nrow(data)/populationSize)
    allProbs <- c(0, 0.1, 0.25, 0.5, 0.75, 0.9, 1)
    probs <- allProbs[allProbs >= zeroFraction]
    probs <- (probs - zeroFraction)/(1 - zeroFraction)
    quants <- quantile(data$covariateValue, probs = probs, 
                       type = 1)
    quants <- c(rep(0, length(allProbs) - length(quants)), 
                quants)
    result <- tibble(covariateId = data$covariateId[1], countValue = nrow(data), 
                     minValue = quants[1], maxValue = quants[7], averageValue = mean(data$covariateValue) * 
                       (1 - zeroFraction), standardDeviation = sqrt((populationSize * 
                                                                       sum(data$covariateValue^2) - sum(data$covariateValue)^2)/(populationSize * 
                                                                                                                                   (populationSize - 1))), medianValue = quants[4], 
                     p10Value = quants[2], p25Value = quants[3], p75Value = quants[5], 
                     p90Value = quants[6])
  }
  covariatesContinuous1 <- covariateData$analysisRef %>% filter(rlang::sym("isBinary") == 
                                                                  "N" & rlang::sym("missingMeansZero") == "Y") %>% 
    inner_join(covariateData$covariateRef, by = "analysisId") %>% 
    inner_join(covariateData$covariates, by = "covariateId") %>% 
    Andromeda::groupApply("covariateId", computeStats) %>% 
    dplyr::bind_rows()
  computeStats <- function(data) {
    probs <- c(0, 0.1, 0.25, 0.5, 0.75, 0.9, 1)
    quants <- quantile(data$covariateValue, probs = probs, 
                       type = 1)
    result <- tibble(covariateId = data$covariateId[1], countValue = length(data$covariateValue), 
                     minValue = quants[1], maxValue = quants[7], averageValue = mean(data$covariateValue), 
                     standardDeviation = sd(data$covariateValue), medianValue = quants[4], 
                     p10Value = quants[2], p25Value = quants[3], p75Value = quants[5], 
                     p90Value = quants[6])
  }
  covariatesContinuous2 <- covariateData$analysisRef %>% filter(rlang::sym("isBinary") == 
                                                                  "N" & rlang::sym("missingMeansZero") == "N") %>% 
    inner_join(covariateData$covariateRef, by = "analysisId") %>% 
    inner_join(covariateData$covariates, by = "covariateId") %>% 
    Andromeda::groupApply("covariateId", computeStats) %>% 
    dplyr::bind_rows()
  covariatesContinuous <- dplyr::bind_rows(covariatesContinuous1, 
                                    covariatesContinuous2)
  if (nrow(covariatesContinuous) > 0) {
    result$covariatesContinuous <- covariatesContinuous
  }
  delta <- Sys.time() - start
  if(verbose){
    writeLines(paste("Aggregating covariates took", signif(delta, 3), attr(delta, "units")))}
  return(result)
}

################################
custom_getDbDefaultCovariateData <- function (connection, oracleTempSchema = NULL, cdmDatabaseSchema, 
                                              cohortTable = "#cohort_person", cohortId = -1, cdmVersion = "5", 
                                              rowIdField = "subject_id", covariateSettings, targetDatabaseSchema, 
                                              targetCovariateTable, targetCovariateRefTable, targetAnalysisRefTable, 
                                              aggregated = FALSE) 
{
  if (!is(covariateSettings, "covariateSettings")) {
    stop("Covariate settings object not of type covariateSettings")
  }
  if (cdmVersion == "4") {
    stop("Common Data Model version 4 is not supported")
  }
  if (!missing(targetCovariateTable) && !is.null(targetCovariateTable) && 
      aggregated) {
    stop("Writing aggregated results to database is currently not supported")
  }
  settings <- FeatureExtraction:::.toJson(covariateSettings)
  rJava::J("org.ohdsi.featureExtraction.FeatureExtraction")$init(system.file("", 
                                                                             package = "FeatureExtraction"))
  json <- rJava::J("org.ohdsi.featureExtraction.FeatureExtraction")$createSql(settings, 
                                                                              aggregated, cohortTable, rowIdField, rJava::.jarray(as.character(cohortId)), 
                                                                              cdmDatabaseSchema)
  todo <- FeatureExtraction:::.fromJson(json)
  if (length(todo$tempTables) != 0) {
    # ParallelLogger::logInfo("Sending temp tables to server")
    for (i in 1:length(todo$tempTables)) {
      DatabaseConnector::insertTable(connection, tableName = names(todo$tempTables)[i], 
                                     data = as.data.frame(todo$tempTables[[i]]), dropTableIfExists = TRUE, 
                                     createTable = TRUE, tempTable = TRUE, oracleTempSchema = oracleTempSchema)
    }
  }
  # ParallelLogger::logInfo("Constructing features on server")
  sql <- SqlRender::translate(sql = todo$sqlConstruction, targetDialect = attr(connection, 
                                                                               "dbms"), oracleTempSchema = oracleTempSchema)
  profile <- (!is.null(getOption("dbProfile")) && getOption("dbProfile") == 
                TRUE)
  DatabaseConnector::executeSql(connection, sql, profile = profile, progressBar = FALSE)
  if (missing(targetCovariateTable) || is.null(targetCovariateTable)) {
    # ParallelLogger::logInfo("Fetching data from server")
    start <- Sys.time()
    covariateData <- Andromeda::andromeda()
    if (!is.null(todo$sqlQueryFeatures)) {
      sql <- SqlRender::translate(sql = todo$sqlQueryFeatures, 
                                  targetDialect = attr(connection, "dbms"), 
                                  oracleTempSchema = oracleTempSchema)
      DatabaseConnector::querySqlToAndromeda(connection = connection, 
                                             sql = sql, andromeda = covariateData, andromedaTableName = "covariates", 
                                             snakeCaseToCamelCase = TRUE)
    }
    if (!is.null(todo$sqlQueryContinuousFeatures)) {
      sql <- SqlRender::translate(sql = todo$sqlQueryContinuousFeatures, 
                                  targetDialect = attr(connection, "dbms"), 
                                  oracleTempSchema = oracleTempSchema)
      DatabaseConnector::querySqlToAndromeda(connection = connection, 
                                             sql = sql, andromeda = covariateData, andromedaTableName = "covariatesContinuous", 
                                             snakeCaseToCamelCase = TRUE)
    }
    sql <- SqlRender::translate(sql = todo$sqlQueryFeatureRef, 
                                targetDialect = attr(connection, "dbms"), oracleTempSchema = oracleTempSchema)
    DatabaseConnector::querySqlToAndromeda(connection = connection, 
                                           sql = sql, andromeda = covariateData, andromedaTableName = "covariateRef", 
                                           snakeCaseToCamelCase = TRUE)
    sql <- SqlRender::translate(sql = todo$sqlQueryAnalysisRef, 
                                targetDialect = attr(connection, "dbms"), oracleTempSchema = oracleTempSchema)
    DatabaseConnector::querySqlToAndromeda(connection = connection, 
                                           sql = sql, 
                                           andromeda = covariateData, 
                                           andromedaTableName = "analysisRef", 
                                           snakeCaseToCamelCase = TRUE)
    if (!is.null(todo$sqlQueryTimeRef)) {
      sql <- SqlRender::translate(sql = todo$sqlQueryTimeRef, 
                                  targetDialect = attr(connection, "dbms"), 
                                  oracleTempSchema = oracleTempSchema)
      DatabaseConnector::querySqlToAndromeda(connection = connection, 
                                             sql = sql, andromeda = covariateData, andromedaTableName = "timeRef", 
                                             snakeCaseToCamelCase = TRUE)
    }
    delta <- Sys.time() - start
    # ParallelLogger::logInfo("Fetching data took ", 
    #                         signif(delta, 3), " ", attr(delta, "units"))
  }
  else {
    ParallelLogger::logInfo("Writing data to table")
    start <- Sys.time()
    convertQuery <- function(sql, databaseSchema, table) {
      if (missing(databaseSchema) || is.null(databaseSchema)) {
        tableName <- table
      }
      else {
        tableName <- paste(databaseSchema, table, sep = ".")
      }
      return(sub("FROM", paste("INTO", tableName, 
                               "FROM"), sql))
    }
    if (!is.null(todo$sqlQueryFeatures)) {
      sql <- convertQuery(todo$sqlQueryFeatures, targetDatabaseSchema, 
                          targetCovariateTable)
      sql <- SqlRender::translate(sql = sql, targetDialect = attr(connection, 
                                                                  "dbms"), oracleTempSchema = oracleTempSchema)
      DatabaseConnector::executeSql(connection, sql, progressBar = FALSE, 
                                    reportOverallTime = FALSE)
    }
    if (!missing(targetCovariateRefTable) && !is.null(targetCovariateRefTable)) {
      sql <- convertQuery(todo$sqlQueryFeatureRef, targetDatabaseSchema, 
                          targetCovariateRefTable)
      sql <- SqlRender::translate(sql = sql, targetDialect = attr(connection, 
                                                                  "dbms"), oracleTempSchema = oracleTempSchema)
      DatabaseConnector::executeSql(connection, sql, progressBar = FALSE, 
                                    reportOverallTime = FALSE)
    }
    if (!missing(targetAnalysisRefTable) && !is.null(targetAnalysisRefTable)) {
      sql <- convertQuery(todo$sqlQueryAnalysisRef, targetDatabaseSchema, 
                          targetAnalysisRefTable)
      sql <- SqlRender::translate(sql = sql, targetDialect = attr(connection, 
                                                                  "dbms"), oracleTempSchema = oracleTempSchema)
      DatabaseConnector::executeSql(connection, sql, progressBar = FALSE, 
                                    reportOverallTime = FALSE)
    }
    delta <- Sys.time() - start
    # ParallelLogger::logInfo("Writing data took", signif(delta, 
    #                                                     3), " ", attr(delta, "units"))
  }
  sql <- SqlRender::translate(sql = todo$sqlCleanup, targetDialect = attr(connection, 
                                                                          "dbms"), oracleTempSchema = oracleTempSchema)
  DatabaseConnector::executeSql(connection, sql, progressBar = FALSE, 
                                reportOverallTime = FALSE)
  if (length(todo$tempTables) != 0) {
    for (i in 1:length(todo$tempTables)) {
      sql <- "TRUNCATE TABLE @table;\nDROP TABLE @table;\n"
      sql <- SqlRender::render(sql, table = names(todo$tempTables)[i])
      sql <- SqlRender::translate(sql = sql, targetDialect = attr(connection, 
                                                                  "dbms"), oracleTempSchema = oracleTempSchema)
      DatabaseConnector::executeSql(connection, sql, progressBar = FALSE, 
                                    reportOverallTime = FALSE)
    }
  }
  if (missing(targetCovariateTable) || is.null(targetCovariateTable)) {
    attr(covariateData, "metaData") <- list()
    if (is.null(covariateData$covariates) && is.null(covariateData$covariatesContinuous)) {
      warning("No data found, probably because no covariates were specified.")
      covariateData <- createEmptyCovariateData(cohortId = cohortId, 
                                                aggregated = aggregated, temporal = covariateSettings$temporal)
    }
    class(covariateData) <- "CovariateData"
    attr(class(covariateData), "package") <- "FeatureExtraction"
    return(covariateData)
  }
}

from_covariateId_to_conceptId <- function(input_covariateId = 30361210, cohort) {
  
  # cohort is a CovariateData-object produced by featureExtraction. Examples are cohort1, cohort2, and so on in the table1_module.
  # It seems as if The covariateID is just the conceptId + the analysisId, but this is way to go from covariateId to conceptId. 
  # 30361 is conceptId for hyperglycemia, the analysisId is 210, giving the covariateId used as default input above (just as an example).
  
  cohort$covariateRef %>% filter(covariateId == input_covariateID) %>% pull(conceptId)
  
}


clean_output_tables <- function(table_i=table1_list$table_1_output){
  
  # Put the content on a single column, remove empty row with "age group" 
  table_i <- bind_rows(table_i[-1, 1:4],
                        table_i[,5:8])
  
  table_i <- table_i[! table_i$Characteristic %in% 
  c("Medication use",
  "Medical history: General",
  "Medical history: Cardiovascular disease",									
  "Medical history: Neoplasms",
  "Medication use", 
  "Gender: female", "Gender: male"),]
  
  # Drop the ages
  table_i <- table_i[!grepl(" - ", table_i$Characteristic),]
  
  return(table_i)}

