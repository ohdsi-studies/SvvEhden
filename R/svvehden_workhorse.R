# Copyright 2021 Observational Health Data Sciences and Informatics
#
# This file is part of SVVEHDEN
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

#' Execute 
#'
#' @details
#' This function executes.
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
#' @param databaseId                          A short string for identifying the database (e.g.
#'                                            'Synpuf').
#' @param databaseName                        The full name of the database (e.g. 'Medicare Claims
#'                                            Synthetic Public Use Files (SynPUFs)').
#' @param databaseDescription                 A short description (several sentences) of the database.
#'
#' @export
execute <- function(connectionDetails,
                    cdmDatabaseSchema,
                    cohortDatabaseSchema = cdmDatabaseSchema,      #DONE
                    #vocabularyDatabaseSchema = cdmDatabaseSchema, #I don't think we need this one
                    cohortTable = NULL, 
                    tempEmulationSchema = NULL,                    #TODO: make use of!!!!!!!
                    verifyDependencies = TRUE,                     #TODO: make use of???????
                    outputFolderPath,
                    databaseId = "Unknown",                        #TODO: make use of???????
                    databaseName = databaseId,                     #TODO: make use of???????
                    databaseDescription = databaseId,              #TODO: make use of???????
                    verbose = FALSE) {

  ## This is the workhorse-script that outputs html-files for each DEC
  
  # Setup 
  setwd(paste0(here::here(), "/R"))
  source("general_function_library.R")   
  saddle <- saddle_the_workhorse(connectionDetails = connectionDetails,
                                 cdmDatabaseSchema = cdmDatabaseSchema,
                                 cohortDatabaseSchema = cohortDatabaseSchema,
                                 cohortTable = cohortTable,
                                 outputFolderPath = outputFolderPath,
                                 overall_verbose = verbose)
  
  for(i in 1:nrow(saddle$dec_df)
      ){
    # i = 1
    
    result = tryCatch({
      tic("Total time for this DEC")
      
      cohort_list <- cohort_module(i, maximum_cohort_size=50,
                                   force_create_new = TRUE,
                                   only_create_cohorts = FALSE,
                                   saddle)
      # Build descriptive tables
      table1_list <- table1_module(i, cohort_list, saddle)
      
      #TODO: MOVE CHRONOGRAPH CODE OR PACKAGE IN ORDER TO USE!?
      # Get chronograph
      chronograph_plot <- chronograph_module(i, saddle)
      
      # Print to html
      print_to_html_module(i, table1_list, chronograph_plot, saddle)
      toc()
      
    }, error = function(e) {
      error_printer(e, i, saddle$output_path)
      
    })
  }
  
}

execute(
  connectionDetails = NULL,
  cdmDatabaseSchema = "OmopCdm.mini",
  cohortDatabaseSchema = NULL,
  cohortTable = NULL,
  tempEmulationSchema = NULL,
  outputFolderPath = NULL,
  verbose = FALSE
)


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

