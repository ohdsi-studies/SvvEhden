# Copyright 2019 Observational Health Data Sciences and Informatics
#
# This file is part of IcTemporalPatternDiscovery
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

###################
#' @title
#' Wrapper to execute chronograph scripts
#'
#' @description
#' A for-loop wrapper to execute chronograph script on a list of drug-event-combinations (DECs).
#'
#' @param connectionDetails     An R object of type \code{ConnectionDetails} created using the
#'                                 function \code{createConnectionDetails} in the
#'                                 \code{DatabaseConnector} package.
#' @param cdmDatabaseSchema        A string with the name of database schema that contains OMOP CDM and vocabulary.  
#'                                 For sql server, append the schema name to the database name as "[database_name].[schema_name]" 
#'                                 and use as cdmDatabaseSchema.
#' @param oracleTempSchema         For Oracle only: A string with the name of the database schema where you want all
#'                                 temporary tables to be managed. Requires create/insert permissions
#'                                 to this database.
#' @param cohortDatabaseSchema     A string with the name of the database schema that is the location where the
#'                                 cohort data is available.  For sql server, append the schema name to 
#'                                 the database name as "[database_name].[schema_name]" and use as 
#'                                 cohortDatabaseSchema. If not specified, cdmDatabaseSchema will be used.
#' @param decList        A path to the Drug-event-combination list. 
#' @param storePath      If not specified defaults to "export"
#' @param storeFileName  If not specified defaults to chronograph_data.csv
#' @param project_root_path The path to the project root
#' @param create_pngs_in_extras_folder A quick-fix - save the chronograph plots in the extras folder?
#'
#' @return
#' Nothing, but stores a csv with all chronograph data. 
#'
#' @export


executeChronographWrapper <- function(connectionDetails,
                                      cdmDatabaseSchema,
                                      oracleTempSchema = NULL,
                                      cohortDatabaseSchema = cdmDatabaseSchema,
                                      cohortTable = paste0("cohorts_",Sys.getenv("USERNAME"),"_CD"),
                                      decList = "../inst/settings/DecList.csv", 
                                      storePath = "export",
                                      storeFileName = "chronograph_data.csv",
                                      databaseId = cdmDatabaseSchema,
                                      project_root_path = NULL,
                                      create_pngs_in_extras_folder = FALSE
){
  
  # connectionDetails = connectionDetails
  # cdmDatabaseSchema = cdmDatabaseSchema
  # oracleTempSchema = NULL
  # cohortDatabaseSchema = cdmDatabaseSchema
  # cohortTable = paste0("cohorts_",Sys.getenv("USERNAME"),"_CD")
  # decList = "../inst/settings/DecList.csv"
  # storePath = "export"
  # storeFileName = "chronograph_data.csv"
  # databaseId = cdmDatabaseSchema
  # create_pngs_in_extras_folder = FALSE
  
  DEC_df <- read.csv(decList)
  path_w_filename <- paste0(storePath, "/" ,storeFileName)
  
  chronograph_list <- list()
  chronograph_list[1:nrow(DEC_df)] = NA 
  
  for(i in 1:nrow(DEC_df)){
    
    # i = 1
    cat(i, "\n")
    DEC_i_cohort_ids <- DEC_df[i, c("cohortId_1", "cohortId_2", "cohortId_3")] %>%  as.numeric() # target, comparator, outcome in that order
    
    chronograph_list[[i]] <- executeChronograph(connectionDetails,
                                                cdmDatabaseSchema = cdmDatabaseSchema,
                                                cohortTable = cohortTable,
                                                targetCohortId = DEC_i_cohort_ids[1],
                                                comparatorCohortId = DEC_i_cohort_ids[2],
                                                outcomeCohortId = DEC_i_cohort_ids[3],
                                                project_root_path = project_root_path)
    
    if(create_pngs_in_extras_folder == TRUE){
      plotChronograph(data = chronograph_list[[i]], 
                      DEC_i_cohort_ids[1], 
                      DEC_i_cohort_ids[2], 
                      DEC_i_cohort_ids[3], 
                      title = DEC_df[i,1], 
                      fileName = paste0(project_root_path, paste0("/extras", "/" , DEC_df[i,1], ".jpeg")))
    }
  }
  
  chronograph_data_all_decs <- do.call("rbind", chronograph_list)
  
  # add databaseId to dataframe 
  chronograph_data_all_decs$databaseId = databaseId
  
  # Join all chronograph DEC-data and print it
  data.table::fwrite(chronograph_data_all_decs, file=paste0(project_root_path, "/", path_w_filename))
}

#' @title
#' Get the data for chronographs from the server.
#'
#' @description
#' Get the data for creating chronographs from the server.
#'
#' @param connectionDetails        An R object of type \code{ConnectionDetails} created using the
#'                                 function \code{createConnectionDetails} in the
#'                                 \code{DatabaseConnector} package.
#' @param cdmDatabaseSchema        A string with the name of database schema that contains OMOP CDM and vocabulary.  
#'                                 For sql server, append the schema name to the database name as "[database_name].[schema_name]" 
#'                                 and use as cdmDatabaseSchema.
#' @param oracleTempSchema         For Oracle only: A string with the name of the database schema where you want all
#'                                 temporary tables to be managed. Requires create/insert permissions
#'                                 to this database.
#' @param cohortDatabaseSchema     A string with the name of the database schema that is the location where the
#'                                 cohort data is available.  For sql server, append the schema name to 
#'                                 the database name as "[database_name].[schema_name]" and use as 
#'                                 cohortDatabaseSchema. If not specified, cdmDatabaseSchema will be used.
#' @param cohortTable              The tablename that contains the three required cohorts.
#' @param targetCohortId           A numeric variable containing the CohortID of the target cohort. 
#' @param comparatorCohortId       A numeric variable containing the CohortID of the comparator cohort. 
#' @param outcomeCohortId          A numeric variable containing the CohortID of the outcome cohort. 
#' @param cdmVersion               Define the OMOP CDM version used: currently supports "5".                                  
#' @param shrinkage                Shrinkage used in IRR calculations, required >0 to deal with 0 case
#'                                 counts, but larger number means more shrinkage. default is 0.5
#' @param icPercentile             The lower bound of the credibility interval for the IC values
#'                                 (IClow). default is 0.025,
#' @param project_root_path        The path to the project root. 
#' @param verbose                  Should informative messages be printed?
#'
#' @return
#' A data frame with observed and expected outcome counts in periods relative to the exposure
#' initiation date, for each outcome and exposure.
#'
#' @export
executeChronograph <- function(connectionDetails,
                               cdmDatabaseSchema,
                               oracleTempSchema=NULL,
                               cohortDatabaseSchema = cdmDatabaseSchema,
                               cohortTable = c(),
                               targetCohortId = c(),
                               comparatorCohortId = c(),
                               outcomeCohortId = c(),
                               cdmVersion = "5",
                               shrinkage = 0.5,
                               icPercentile = 0.025,
                               project_root_path = project_root_path,
                               verbose = FALSE) {
  
  start <- Sys.time()
  
  ## For debugging:
  # connectionDetails <- DatabaseConnector::createConnectionDetails(dbms = "sql server", server = "UMCDB06")
  # cdmDatabaseSchema = "OmopCdm.synpuf5pct_20180710"
  # oracleTempSchema = NULL
  # cohortTable = paste0("cohorts_",Sys.getenv("USERNAME"),"_CD")
  # cohortDatabaseSchema = cdmDatabaseSchema
  # targetCohortId = 22
  # comparatorCohortId = 42
  # outcomeCohortId = 32
  # cdmVersion = "5"
  # shrinkage = 0.5
  # icPercentile = 0.025
  # verbose = FALSE
  
  # data = chronograph_data_all_decs
  # targetCohortId = DEC_i_cohort_ids[1]
  # comparatorCohortId = DEC_i_cohort_ids[2]
  # outcomeCohortId = DEC_i_cohort_ids[3]
  
  # Check input arguments
  checkmate::qassert(cdmDatabaseSchema, "S1[1,]")
  checkmate::qassert(oracleTempSchema, c("0", "S1[1,]"))
  checkmate::qassert(cohortDatabaseSchema, "S1[1,]")
  checkmate::qassert(cohortTable, "S1[1,]")
  checkmate::qassert(targetCohortId, "N1[0,]")
  checkmate::qassert(comparatorCohortId, "N1[0,]")
  checkmate::qassert(outcomeCohortId, "N1[0,]")
  checkmate::qassert(cdmVersion, "S1[1,]")
  checkmate::qassert(shrinkage, "N1[0,]")
  checkmate::qassert(icPercentile, "N1[0,1]")
  checkmate::qassert(project_root_path, "S1[1,]")
  checkmate::qassert(verbose, "B1")

  
  # Use these names to find the right names in cohort table below
  cohortStartField <- "cohort_start_date"
  cohortDefinitionField <- "cohort_definition_id"
  cohortPersonIdField <- "subject_id"
  
  # Insert a table to the database with the "periods", used for number of bars and bar width in the chronograph plot
  periodLength <- 30 # Number of days per bar
  numberOfPeriods <- 25 # Number of months we follow patients periodLength days * numberOfPeriods, e.g. 30 * 48 month = +/- 2 years 
  periodStarts <- c(
    seq(-periodLength*numberOfPeriods, -1L, by=periodLength), by=periodLength)
  
  periodEnds <- periodStarts + periodLength - 1L
  periodEnds[periodStarts == 0L] <- 0L
  periods <- data.frame(periodStart = as.numeric(periodStarts)[-length(periodStarts)],
                        periodEnd = as.numeric(periodEnds)[-length(periodEnds)],
                        periodId = c((1-numberOfPeriods):(0L)))
  periodsForDb <- periods
  colnames(periodsForDb) <- SqlRender::camelCaseToSnakeCase(colnames(periodsForDb))
  
  conn <- suppressMessages(DatabaseConnector::connect(connectionDetails))
  on.exit(DatabaseConnector::disconnect(conn))
  
  if(verbose){ParallelLogger::logTrace("Inserting period_chronograph table")}
  DatabaseConnector::insertTable(connection = conn,
                                 tableName = "period_ICTPD",
                                 databaseSchema = cdmDatabaseSchema,
                                 data = periodsForDb,
                                 dropTableIfExists = TRUE,
                                 createTable = TRUE,
                                 tempTable = FALSE,
                                 oracleTempSchema = oracleTempSchema,
  )
  
  # Time to count the observed and the three counts required to calculate the expected  
  if(verbose){ParallelLogger::logTrace("Creating cohort counts tables")}  
  sql <- SqlRender::readSql(paste0(project_root_path, "/inst/sql/sql_server/CreateChronographData.sql"))
  sql <- SqlRender::translate(sql, targetDialect = connectionDetails$dbms)    
  sql <- SqlRender::render(sql, 
                           cdm_database_schema = cdmDatabaseSchema,
                           cohort_database_schema = cohortDatabaseSchema,
                           cohort_table = cohortTable,
                           exposure_cohort_id = targetCohortId,
                           comparator_cohort_id = comparatorCohortId,
                           outcome_cohort_id = outcomeCohortId,
                           cohort_start_field = cohortStartField,
                           cohort_id_field = cohortDefinitionField,
                           cohort_person_id_field = cohortPersonIdField
  )
  
  if(verbose){ParallelLogger::logInfo("Creating counts on server")}
  # writeLines(sql)
  DatabaseConnector::executeSql(conn, sql, progressBar=FALSE)
  
  # Counts have been created, extract them
  sql <- SqlRender::readSql(paste0(project_root_path, "/inst/sql/sql_server/ExtractChronographTable.sql"))
  sql <- SqlRender::translate(sql, targetDialect = connectionDetails$dbms)    
  sql <- SqlRender::render(sql,
                           cohort_database_schema = cohortDatabaseSchema)
  
  if(verbose){ParallelLogger::logInfo("Creating counts on server")}
  result_df <- DatabaseConnector::querySql(conn, sql)
  # writeLines(sql)
  colnames(result_df) = tolower(colnames(result_df))
  
  # Clean up all tables that we created
  sql <- SqlRender::readSql(paste0(project_root_path, "/inst/sql/sql_server/DropChronographTables.sql"))
  sql <- SqlRender::translate(sql, targetDialect = connectionDetails$dbms)    
  sql <- SqlRender::render(sql, cohort_database_schema = cohortDatabaseSchema)
  DatabaseConnector::executeSql(conn, sql, progressBar = FALSE, reportOverallTime = FALSE)

  # Check if less than 5 periods with data were returned (might not have been any data for the DEC)
  if(nrow(result_df) < 5){
    
    result_df <- cbind.data.frame("period_id" = periodsForDb[,3], 
                                  "observed" = NA, 
                                  "expected" = NA, 
                                  "ic" = NA,
                                  "ic_lower_bound" = NA, 
                                  "ic_higher_bound" = NA) 
    colnames(result_df) = SqlRender::snakeCaseToCamelCase(colnames(result_df))
    result_df$targetCohortId = targetCohortId
    result_df$comparatorCohortId = comparatorCohortId
    result_df$outcomeCohortId = outcomeCohortId
    
    return(result_df)
  }
  
  
  # Done with SQL, now calculate expected and IC credibility intervals for all periods
  result_df$expected <- as.numeric(result_df$exposed_count) * result_df$comparator_outcome_count/result_df$comparator_count
  result_df <- result_df %>% rename(observed = outcome_count)
  
  ic_calculator <- function(obs, exp, shrinkage = 0.5, percentile = 0.025) {
    
    # Check input arguments
    checkmate::qassert(obs, "N[0,]")
    checkmate::qassert(exp, "N[0,]")
    checkmate::qassert(shrinkage, "N1[0,]")
    checkmate::qassert(percentile, "N1[0,1]")
    
    ic <- log2((obs + shrinkage)/(exp + shrinkage))
    # To use vectorization, we repeat the same line but with different percentiles
    ic_lower_bound <- log2(qgamma(p = percentile, shape = (obs + shrinkage), rate = (exp + shrinkage)))
    ic_higher_bound <- log2(qgamma(p = 1-percentile, shape = (obs + shrinkage), rate = (exp + shrinkage)))
    
    return(list(ic = ic, ic_lower_bound = ic_lower_bound, ic_higher_bound = ic_higher_bound))
  }
  
  ic <- ic_calculator(obs = result_df$observed,
                      exp = result_df$expected,
                      shrinkage = shrinkage,
                      percentile = icPercentile)
  
  result_df$ic <- ic$ic
  result_df$ic_lower_bound <- ic$ic_lower_bound
  result_df$ic_higher_bound <- ic$ic_higher_bound
  
  # Clean up the output a bit, add the cohortIds
  result_df <- result_df %>% arrange(period_id) %>%  select(period_id, observed, expected, ic, ic_lower_bound, ic_higher_bound)
  colnames(result_df) = SqlRender::snakeCaseToCamelCase(colnames(result_df))
  result_df$targetCohortId = targetCohortId
  result_df$comparatorCohortId = comparatorCohortId
  result_df$outcomeCohortId = outcomeCohortId
  
  delta <- Sys.time() - start
  if(verbose){ParallelLogger::logInfo(paste("Getting data took", signif(delta, 3), attr(delta, "units")))}
  return(result_df)
}

#' @title
#' Plot a chronograph
#'
#' @description
#' Creates a plot showing the observed and expected number of outcomes for each month in the specified time interval 
#' before and after initiation of the exposure, as well as the IC. See references for further details. 
#'
#' @param data                 Data as generated using the \code{getChronographData} function.
#' @param targetCohortId       The cohortID for the target cohort
#' @param comparatorCohortId   The cohortID for the comparator cohort 
#' @param outcomeCohortId      The cohortID for the outcome 
#' @param title                The title to show above the plot.
#' @param fileName             Name of the file where the plot should be saved, with file format ending, e.g. 'plot.png'. See the
#'                             function \code{ggsave} in the ggplot2 package for supported file formats.
#' @references
#' Noren GN, Hopstadius J, Bate A, Star K, Edwards R, Temporal pattern discovery in longitudinal
#' electronic patient records, Data Mining and Knowledge Discovery, May 2010, Volume 20, Issue 3, pp
#' 361-387.
#'
#' @export
#' 
plotChronograph <- function(data=result_df, 
                            targetCohortId, 
                            comparatorCohortId, 
                            outcomeCohortId, 
                            title = "", 
                            fileName = NULL) {
  
  # For debugging  
  # data = chronograph_data_all_decs
  # targetCohortId = DEC_i_cohort_ids[1]
  # comparatorCohortId = DEC_i_cohort_ids[2]
  # outcomeCohortId = DEC_i_cohort_ids[3]
  # title = ""
  
  # Check input arguments
  checkmate::qassert(targetCohortId, "N1[0,]")
  checkmate::qassert(comparatorCohortId, "N1[0,]")
  checkmate::qassert(outcomeCohortId, "N1[0,]")
  checkmate::qassert(title, c("S1[0,]", 0))
  
  # In case the data frame contains many cohort, we filter on the cohortIDs
  cohortIds <- c(targetCohortId, comparatorCohortId, outcomeCohortId)
  data <- data %>% filter(targetCohortId %in% cohortIds[1] & comparatorCohortId %in% cohortIds[2] & outcomeCohortId %in% cohortIds[3])
  
  # In case the data frame does not contain any data at all
  if(all(is.na(data$observed))){
    cat("All observed counts are NA for this DEC. \n")
  } else {
    
    negData <- data[data$periodId < 0, ]
    posData <- data[data$periodId > 0, ]
    zeroData <- data[data$periodId == 0, ]
    
    # Set some ad hoc y-limit bounds
    if (max(data$icHigherBound) + 0.5 < 1) {
      yMax <- 1
    } else {
      yMax <- max(data$icHigherBound) + 0.5
    }
    if (min(data$icLowerBound) - 1 > -1) {
      yMin <- -1
    } else {
      yMin <- min(data$icLowerBound) - 1
    }
    
    # # We do not use this panel in the EHDEN Studyathon.
    topPanel <- with(data, ggplot2::ggplot() +
                       ggplot2::geom_hline(yintercept = 0, color = "black", size = 0.2, linetype = 2) +
                       ggplot2::geom_errorbar(ggplot2::aes(x = periodId, ymax = icHigherBound, ymin = icLowerBound),
                                              color = "grey50",
                                              size = 0.35,
                                              data = negData) +
                       ggplot2::geom_errorbar(ggplot2::aes(x = periodId, ymax = icHigherBound, ymin = icLowerBound),
                                              color = "grey50",
                                              size = 0.35,
                                              data = posData) +
                       ggplot2::geom_line(ggplot2::aes(x = periodId, y = ic),
                                          color = rgb(0, 0, 0.8),
                                          size = 0.7,
                                          data = negData) +
                       ggplot2::geom_line(ggplot2::aes(x = periodId, y = ic),
                                          color = rgb(0, 0, 0.8),
                                          size = 0.7,
                                          data = posData) +
                       ggplot2::geom_point(ggplot2::aes(x = periodId, y = ic),
                                           color = rgb(0, 0, 0.8),
                                           size = 6,
                                           shape = "*",
                                           data = zeroData) +
                       ggplot2::scale_x_continuous(name = "Months relative to first prescription",
                                                   breaks = (-5:5) * 12) +
                       ggplot2::ylab("IC") +
                       ggplot2::coord_cartesian(ylim = c(yMin, yMax)) +
                       ggplot2::theme(axis.title.x = ggplot2::element_blank())
    )
    
    bottomPanel <- with(data, ggplot2::ggplot() +
                          ggplot2::geom_bar(ggplot2::aes(x = periodId, y = observed, fill = "Observed"),
                                            stat = "identity",
                                            color = "black",
                                            size = 0.4,
                                            width = 1,
                                            data = data) +
                          ggplot2::geom_line(ggplot2::aes(x = periodId,
                                                          y = expected,
                                                          color = "Expected"), size = 0.7, data = negData) +
                          ggplot2::geom_line(ggplot2::aes(x = periodId, y = expected),
                                             color = rgb(0, 0, 0.8),
                                             size = 0.7,
                                             data = posData) +
                          # This star denotes day zero: 
                           ggplot2::geom_point(ggplot2::aes(x = periodId, y = expected),
                                               color = rgb(0, 0, 0.8),
                                               size = 6,
                                               shape = "*",
                                               data = zeroData) +
                          ggplot2::scale_x_continuous(name = "Months relative to first exposure",
                                                      breaks = (-5:5) * 12) +
                          ggplot2::scale_fill_manual(name = "", values = c(rgb(0.3, 0.7, 0.8, alpha = 0.5))) +
                          ggplot2::scale_color_manual(name = "", values = c(rgb(0, 0, 0.8))) +
                          ggplot2::ylab("Number of outcomes") +
                          ggplot2::theme(legend.justification = c(0, 1),
                                         legend.position = c(0.1, 0.9),
                                         legend.direction = "horizontal",
                                         legend.box = "vertical",
                                         legend.key.height = ggplot2::unit(0.4, units = "lines"),
                                         legend.key = ggplot2::element_rect(fill = "transparent", color = NA),
                                         legend.background = ggplot2::element_rect(fill = "white", color = "black", size = 0.2))
    )
    plots <- list(topPanel,  # No top panel
      bottomPanel)
    grobs <- widths <- list()
    for (i in 1:length(plots)) {
      grobs[[i]] <- ggplot2::ggplotGrob(plots[[i]])
      widths[[i]] <- grobs[[i]]$widths[2:5]
    }
    
    maxwidth <- do.call(grid::unit.pmax, widths)
    for (i in 1:length(grobs)) {
      grobs[[i]]$widths[2:5] <- as.list(maxwidth)
    }
    plot <- gridExtra::grid.arrange(grobs[[1]], grobs[[2]], # Just the first plot will do 
                                    top = grid::textGrob(title))
    
    if (!is.null(fileName)){
      ggplot2::ggsave(fileName, plot, width = 7, height = 5, dpi = 400)
    }
    
    return(bottomPanel + ggplot2::ggtitle(title))
  }
}
