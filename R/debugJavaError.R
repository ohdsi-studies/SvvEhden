

connectionDetails <- createConnectionDetails(dbms = "sql server", server = "UMCDB06")
drug_concept_id = "1139699"
condition_concept_id = "31317"

covariateSettings <- FeatureExtraction::createCovariateSettings(useConditionGroupEraLongTerm = TRUE, 
                                                                excludedCovariateConceptIds = c(condition_concept_id, drug_concept_id))

cdmDatabaseSchema <- "OmopCdm.synpuf5pct_20180710"
covSettings <- suppressMessages(custom_createCovariateSettings(exclude_these = c(drug_concept_id, condition_concept_id))) #for cohort1-3: exclude event and drug from covariates
attributes(covSettings)$fun = "custom_getDbDefaultCovariateData"

CohortMethod::getDbCohortMethodData(connectionDetails = connectionDetails,
                                    cdmDatabaseSchema = cdmDatabaseSchema,
                                    targetId = drug_concept_id,
                                    comparatorId = 1560524,
                                    outcomeIds = condition_concept_id,
                                    studyStartDate = "",
                                    studyEndDate = "",
                                    exposureDatabaseSchema = cdmDatabaseSchema,
                                    exposureTable = "drug_era",
                                    outcomeDatabaseSchema = cdmDatabaseSchema,
                                    outcomeTable = "condition_era",
                                    covariateSettings = covSettings)

resultsDatabaseSchema = cdmDatabaseSchema
cohortTableName = "cohort_table"
conn <- suppressMessages(invisible(DatabaseConnector::connect(connectionDetails)))

sql <- SqlRender::render("
                          {DEFAULT @exposure_drug_ids = ''} -- the concept id for the drug of interest
                          {DEFAULT @comparator_drug_ids = ''} -- the concept ids for comparator drugs (typically all drugs in the database)
                          {DEFAULT @event_ids = ''} -- concept ids for the outcome/event ID
                          {DEFAULT @resultsDatabaseSchema = ''} -- the schema that will hold all cohorts
                          {DEFAULT @cohortTableName = ''} -- the table name where the final cohort tables will reside
                          {DEFAULT @cdmDatabaseSchema = ''} -- the schema where the OMOP data is located   
                          
                          IF OBJECT_ID('@resultsDatabaseSchema.@cohortTableName', 'U') IS NOT NULL
                          DROP TABLE @resultsDatabaseSchema.@cohortTableName;
                          CREATE TABLE @resultsDatabaseSchema.@cohortTableName (
                            cohort_definition_id INT,
                            cohort_start_date    DATE,
                            cohort_end_date      DATE,
                            subject_id           BIGINT
                            )
                          
                          INSERT INTO @resultsDatabaseSchema.@cohortTableName
                          SELECT 2            AS cohort_definition_id, 
                          drug_era_start_date AS cohort_start_date,
                          drug_era_end_date   AS cohort_end_date,
                          person_id           AS subject_id
                          FROM @cdmDatabaseSchema.drug_era
                          WHERE drug_concept_id IN (@exposure_drug_ids);
                          
                          INSERT INTO @resultsDatabaseSchema.@cohortTableName
                          SELECT 3                 AS cohort_definition_id, 
                          condition_era_start_date AS cohort_start_date,
                          condition_era_end_date   AS cohort_end_date,
                          person_id                AS subject_id
                          FROM @cdmDatabaseSchema.condition_era
                          WHERE condition_concept_id IN ( SELECT descendant_concept_id
                                                                        FROM @cdmDatabaseSchema.concept_ancestor
                                                                        WHERE ancestor_concept_id IN (@event_ids) )    
                          
                          INSERT INTO @resultsDatabaseSchema.@cohortTableName         
                          SELECT 4            AS cohort_definition_id, 
                          drug_era_start_date AS cohort_start_date,
                          drug_era_end_date   AS cohort_end_date,
                          person_id           AS subject_id
                          FROM @cdmDatabaseSchema.drug_era
                          WHERE drug_concept_id IN (@comparator_drug_ids);
                         ", 
                         cdmDatabaseSchema = cdmDatabaseSchema,
                         resultsDatabaseSchema = resultsDatabaseSchema,
                         cohortTableName = cohortTableName, 
                         exposure_drug_ids = drug_concept_id,
                         comparator_drug_ids = 1560524,
                         event_ids = condition_concept_id)
suppressMessages(executeSql(conn, sql, progressBar = FALSE))

CohortMethod::getDbCohortMethodData(connectionDetails = connectionDetails,
                                    cdmDatabaseSchema = cdmDatabaseSchema,
                                    targetId = 2,
                                    comparatorId = 4,
                                    outcomeIds = 3,
                                    studyStartDate = "",
                                    studyEndDate = "",
                                    exposureDatabaseSchema = resultsDatabaseSchema,
                                    exposureTable = cohortTableName,
                                    outcomeDatabaseSchema = resultsDatabaseSchema,
                                    outcomeTable = cohortTableName,
                                    covariateSettings = covSettings)

