###################################################################3
# The execute-function is the workhorse/main method of this repo.

#' Execute
#'
#' @details
#' This function collects the aggregated data for the SvvEHDEN-studyathon planned for Dec 2021.
#'
#' @param connectionDetails                   An object of type \code{connectionDetails} as created
#'                                            using the
#'                                            \code{\link[DatabaseConnector]{createConnectionDetails}}
#'                                            function in the DatabaseConnector package.
#' @param cdmDatabaseSchema                   Schema name where your patient-level data in OMOP CDM
#'                                            format resides. Note that for SQL Server, this should
#'                                            include both the database and schema name, for example
#'                                            'cdm_data.dbo'.
#' @param cohortDatabaseSchema                Schema name where intermediate data can be stored. You
#'                                            will need to have write privileges in this schema. Note
#'                                            that for SQL Server, this should include both the
#'                                            database and schema name, for example 'cdm_data.dbo'.
#' @param vocabularyDatabaseSchema            Schema name where your OMOP vocabulary data resides. This
#'                                            is commonly the same as cdmDatabaseSchema. Note that for
#'                                            SQL Server, this should include both the database and
#'                                            schema name, for example 'vocabulary.dbo'.
#' @param cohortTable                         The name of the table that will be created in the work
#'                                            database schema. This table will hold the exposure and
#'                                            outcome cohorts used in this study. If set to NULL the
#'                                            name will be "cohorts_[USERNAME]".
#' @param tempEmulationSchema                 Some database platforms like Oracle and Impala do not
#'                                            truly support temp tables. To emulate temp tables,
#'                                            provide a schema with write privileges where temp tables
#'                                            can be created.
#' @param verifyDependencies                  Check whether correct package versions are installed?
#' @param outputFolderPath                    Name of local folder to place results; make sure to use
#'                                            forward slashes (/). Do not use a folder on a network
#'                                            drive since this greatly impacts performance.
#' @param databaseName                        The full name of the database (e.g. 'Medicare Claims
#'                                            Synthetic Public Use Files (SynPUFs)').
#' @param maxNumberOfCombinations             If used it will limit the number of combinations run.
#' @param verbose                             Decides whether informative messages should be printed.
#' @export

execute <- function(connectionDetails,
                    cdmDatabaseSchema,
                    cohortDatabaseSchema = cdmDatabaseSchema,
                    vocabularyDatabaseSchema = cdmDatabaseSchema,   
                    cohortTable = NULL,
                    tempEmulationSchema = cohortDatabaseSchema,     
                    verifyDependencies = FALSE,                     
                    outputFolderPath,
                    databaseName = strsplit(cdmDatabaseSchema, split = ".", fixed = TRUE)[[1]][1],
                    maxNumberOfCombinations = 100000,
                    verbose = FALSE) {
  
  # # For debugging
  # connectionDetails = connectionDetails
  # cdmDatabaseSchema = cdmDatabaseSchema
  # cohortDatabaseSchema = cohortDatabaseSchema
  # cohortTable = cohortTable
  # outputFolderPath = outputFolderPath
  # verbose = FALSE
  
  ## This is the workhorse-script that outputs html-files for each DEC
  
  # Setup 
  saddle <- saddle_the_workhorse(connectionDetails = connectionDetails,
                                 cdmDatabaseSchema = cdmDatabaseSchema,
                                 cohortDatabaseSchema = cohortDatabaseSchema,
                                 cohortTable = cohortTable,
                                 outputFolderPath = outputFolderPath,
                                 persistence_window = 390,
                                 overall_verbose = verbose)
  
  createEras(saddle)
  
  for(i in 1:2 #min(maxNumberOfCombinations, nrow(saddle$dec_df))
  ){  # i = 1
    
    result = tryCatch({
      tictoc::tic("Total time for this DEC")
      
      cohort_list <- cohort_module(i, 
                                   maximum_cohort_size=50,
                                   force_create_new = TRUE,
                                   only_create_cohorts = FALSE,
                                   saddle)
      
      if(length(cohort_list) == 0){next}
      
      # Build descriptive tables
      table1_list <- table1_module(i, cohort_list, saddle)
      
      # Get chronograph
      chronograph_plot <- chronograph_module(i, saddle)
      
      # Print to html
      print_to_html_module(i, table1_list, chronograph_plot, saddle)
      
    }, error = function(e) {
      error_printer(e, i, saddle$output_path)
    })
    tictoc::toc()
  }
  # Add all to zip file -------------------------------------------------------------------------------
  ParallelLogger::logInfo("Adding results to zip file")
  zipName <-
    file.path(outputFolderPath, paste0("Results_", databaseName, "_", Sys.Date(), ".zip"))
  files <- list.files(outputFolderPath, pattern = ".*\\.html$")
  files[[length(files)+1]] <- list.files(outputFolderPath, pattern = ".*\\.txt$") # append error file
  oldWd <- setwd(outputFolderPath)
  on.exit(setwd(oldWd), add = TRUE)
  DatabaseConnector::createZipFile(zipFile = zipName, files = files)
  ParallelLogger::logInfo("Results are ready for sharing at: ", zipName)
}


#                         _(\_/) 
#                       ,((((^`\
#                       ((((  (6 \ 
#                     ,((((( ,    \
#                   ,(((((  /"._  ,`,
# ((((\\ ,...       ,((((   /    `-.-'
# )))  ;'    `"'"'""((((   (      
#  ((  /            (((      \
# ))  |                      |
#  ((  |        .       '     |
#  ))  \     _ '      `    ,.')
#  (   |   y;- -,-""'"-.\   \/  
#  )   / ./  ) /         `\  \
#     |./   ( (           / /'
#     ||     \\          //'|
#     ||      \\       _//'||
#     ||       ))     |_/  ||
#     \_\     |_/       
# https://www.asciiart.eu/animals/horses