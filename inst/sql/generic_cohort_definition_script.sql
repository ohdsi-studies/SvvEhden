-- Creates the cohorts to be used in SVVEHDEN-sprint, according to the study protocol.

/*Input variables (sent from cohort-module)*/
-- These local variables are "rendered" by the R-script before execution.
{DEFAULT @exposure_drug_ids = ''} -- the concept id for the drug of interest
{DEFAULT @comparator_drug_ids = ''} -- the concept ids for comparator drugs (typically all drugs in the database)
{DEFAULT @event_ids = ''} -- concept ids for the outcome/event ID
{DEFAULT @resultsDatabaseSchema = ''} -- the schema that will hold all cohorts
{DEFAULT @tempTableName = ''} -- the table name where the final cohort tables will reside
{DEFAULT @cdmDatabaseSchema = ''} -- the schema where the OMOP data is located
{DEFAULT @maximum_cohort_size = ''} -- a limitation on the cohort size

/* 
##################################################################################
For convenience, the cohorts are enumerated as follows:
11: Drug users with the event in risk window, entry date at drug initiation. Only one instance per person is sampled.
21: All drug users. Only one instance per person is sampled.
22: All drug users.  Only one instance per person is sampled.
31: All experiencing the event, that also have a drug (any drug) preceiding within the risk window,
    entry date at drug initiation. Only one instance per person is sampled.
32: All experiencing the event. (Not requiring drug within risk window, not sampled.)
41: All drug initiations in the database. Only one instance per person is sampled.
42: All drug initations in thed database. Only one instance per person is sampled.
############################################
-- Cohorts 11, 12, 21, 31 and 41 are made for descriptive tables
-- Cohorts 22, 32 and 42 are made for the chronograph
-- When the same patient is included to the same cohort at multiple timepoints, we select one timepoint per patient randomly.
############################################
*/

---------------------------------------------------------------------------------------------

-- Initiate one table with suffix original, where all cohort data will be inserted before processing/sampling 
IF OBJECT_ID('@resultsDatabaseSchema.@tempTableName_original', 'U') IS NOT NULL
DROP TABLE @resultsDatabaseSchema.@tempTableName_original;
CREATE TABLE @resultsDatabaseSchema.@tempTableName_original (
  cohort_definition_id INT,
  cohort_start_date DATE,
  cohort_end_date DATE,
  subject_id BIGINT,
  drug_concept_id INT-- not needed in final table, but used during sampling
  )
  
---------------------------------------------------------------------------------------------
--- Insert all the rows with the exposure drug as cohort 21 and 22 --- 
-- (need to create the other cohorts before cohort 1, since 1 is build upon the other ones)
INSERT INTO @resultsDatabaseSchema.@tempTableName_original (
  cohort_definition_id,
  cohort_start_date,
  cohort_end_date,
  subject_id,
  drug_concept_id
)
SELECT 21, -- Exposure drug, for use in  descriptive tables
drug_era_start_date,
drug_era_end_date,
person_id,
drug_concept_id
FROM @cdmDatabaseSchema.drug_era
WHERE drug_concept_id IN (@exposure_drug_ids);
  
INSERT INTO @resultsDatabaseSchema.@tempTableName_original (
  cohort_definition_id,
  cohort_start_date,
  cohort_end_date,
  subject_id,
  drug_concept_id
)
SELECT 22, -- Exposure drug, for use in  chronograph
drug_era_start_date,
drug_era_end_date,
person_id,
drug_concept_id
FROM @cdmDatabaseSchema.drug_era
WHERE drug_concept_id IN (@exposure_drug_ids);

---------------------------------------------------------------------------------------------
--- Insert all the drugs in the database as cohort 4 ---
-- (need to create cohort 4 before 3, since 31 is build on cohort 4)
INSERT INTO @resultsDatabaseSchema.@tempTableName_original (
  cohort_definition_id,
  cohort_start_date,
  cohort_end_date,
  subject_id,
  drug_concept_id
)
SELECT 41, -- Comparator drug(s), for use in  descriptive tables
drug_era_start_date,
drug_era_end_date,
person_id,
drug_concept_id
FROM @cdmDatabaseSchema.drug_era
WHERE drug_concept_id IN (@comparator_drug_ids);
  
INSERT INTO @resultsDatabaseSchema.@tempTableName_original (
  cohort_definition_id,
  cohort_start_date,
  cohort_end_date,
  subject_id,
  drug_concept_id
)
SELECT 42, -- Comparator drug(s), for use in  chronograph
drug_era_start_date,
drug_era_end_date,
person_id,
drug_concept_id
FROM @cdmDatabaseSchema.drug_era
WHERE drug_concept_id IN (@comparator_drug_ids);  

---------------------------------------------------------------------------------------------
--- Insert all the rows with the outcome as cohort 31 and 32 --- 
INSERT INTO @resultsDatabaseSchema.@tempTableName_original (
  cohort_definition_id,
  cohort_start_date,
  cohort_end_date,
  subject_id,
  drug_concept_id
)
SELECT 31, -- Any drug + outcome @drug_start_date, for use in  descriptive tables
cohort_start_date,
condition_era_end_date,
person_id,
drug_concept_id
FROM ( SELECT D.cohort_start_date, -- cohort 31: use drug start date
              CE.condition_era_end_date,
              CE.person_id,
			  D.drug_concept_id
	          --Row_number() OVER(PARTITION BY CE.person_id, CE.condition_era_end_date, CE.condition_era_id ORDER BY newid()) AS row_number
              FROM @cdmDatabaseSchema.condition_era CE
			   -- cohort 31: require a drug (any drug) to match risk window: this inner join makes sure the condition_era do have a preceding
			   --            drug withing the 30 day risk window
              INNER JOIN @resultsDatabaseSchema.@tempTableName_original D ON D.subject_id = CE.person_id AND
                                                                             D.cohort_definition_id = 41 AND
 	             														     DATEDIFF(DAY, D.cohort_start_date, CE.condition_era_start_date) <= 30 AND 
 	             														     DATEDIFF(DAY, D.cohort_start_date, CE.condition_era_start_date) > 0 
              WHERE condition_concept_id IN ( SELECT descendant_concept_id
                                              FROM @cdmDatabaseSchema.concept_ancestor
                                              WHERE ancestor_concept_id IN (@event_ids) )  
     ) T1
--WHERE row_number = 1 -- select every reaction one time only (randomly select drug_start if more than one)

INSERT INTO @resultsDatabaseSchema.@tempTableName_original (
  cohort_definition_id,
  cohort_start_date,
  cohort_end_date,
  subject_id,
  drug_concept_id
)
SELECT 32, -- outcome @event_start_date, for use in  chronograph
condition_era_start_date,
condition_era_end_date,
person_id,
NULL
FROM ( SELECT condition_era_start_date, -- cohort 32: use condition start date
              condition_era_end_date,
              person_id
       FROM @cdmDatabaseSchema.condition_era
       WHERE condition_concept_id IN ( SELECT descendant_concept_id
                                       FROM @cdmDatabaseSchema.concept_ancestor
                                       WHERE ancestor_concept_id IN (@event_ids) )  
     ) T1

---------------------------------------------------------------------------------------------
--  Now create cohort 11 

INSERT INTO @resultsDatabaseSchema.@tempTableName_original(
    cohort_definition_id,
    cohort_start_date,
    cohort_end_date,
    subject_id,
    drug_concept_id
  )
SELECT 11, -- Exposure drug + outcome @drug_start_date, for use in  descriptive tables
D.cohort_start_date,
R.cohort_end_date,
D.subject_id,
D.drug_concept_id
FROM @resultsDatabaseSchema.@tempTableName_original D
INNER JOIN @resultsDatabaseSchema.@tempTableName_original R ON D.subject_id = R.subject_id AND 
                                                               D.cohort_definition_id = 21 AND 
                                                               R.cohort_definition_id = 31 AND 
                                                               DATEDIFF(DAY, D.cohort_start_date, R.cohort_start_date) <= 30 AND 
                                                               DATEDIFF(DAY, D.cohort_start_date, R.cohort_start_date) > 0 
															   
---------------------------------------------------------------------------------------------
-- Initiate the table that will hold the final sampled cohorts
IF OBJECT_ID('@resultsDatabaseSchema.@tempTableName', 'U') IS NOT NULL 
DROP TABLE @resultsDatabaseSchema.@tempTableName;
CREATE TABLE @resultsDatabaseSchema.@tempTableName (
  cohort_definition_id INT,
  cohort_start_date DATE,
  cohort_end_date DATE,
  subject_id BIGINT,
  row_number INT)

---------------------------------------------------------------------------------------------
-- Apply the sampling on the original-table to create the final one
INSERT INTO @resultsDatabaseSchema.@tempTableName(
    cohort_definition_id,
    cohort_start_date,
    cohort_end_date,
    subject_id,
    row_number -- this row number should always be 1, it guarantees that only the first (of the scrambled) drug initiation is used
  )
SELECT cohort_definition_id, cohort_start_date, cohort_end_date, subject_id, one_row_per_person_row_number 
FROM ( SELECT *, Row_number() OVER(PARTITION BY cohort_definition_id ORDER BY newid()) AS maximum_cohort_size_row_number
       FROM ( SELECT *, 
                     Row_number() OVER(PARTITION BY subject_id, cohort_definition_id ORDER BY newid()) AS one_row_per_person_row_number -- Scramble the order
              FROM ( SELECT *
                     FROM ( SELECT *, 
                                   Row_number() OVER(PARTITION BY subject_id, cohort_definition_id, drug_concept_id ORDER BY newid()) AS one_row_per_person_and_drug_row_number -- Scramble the order
                            FROM @resultsDatabaseSchema.@tempTableName_original
                          ) T1
                     WHERE one_row_per_person_and_drug_row_number = 1 -- take the first row of each subject_id-drug_concept_id-cohort_definition_id-combination = random row.
		       	) T2
            ) T3
       WHERE one_row_per_person_row_number = 1 -- and take the first row of each subject_id-cohort_definition_id-combination = random row.
             OR cohort_definition_id IN (32)   -- do not sample the reaction cohort for chronographs
     ) T4
WHERE cohort_definition_id in (22, 32, 42) OR maximum_cohort_size_row_number <= @maximum_cohort_size -- restrict to cohort sample size for descriptive-tables cohorts
