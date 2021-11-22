-- Creates the cohorts to be used in SVVEHDEN-sprint, according to updated study protocol.

/* Input variables (sent from cohort-module) */
-- These local variables are "rendered" by the R-script before execution.
-- the concept id for the target drug of interest - T
-- the concept ids for comparator drugs (any other drug than the target drug in the database) - C
-- concept ids for the event, i.e. outcome of interest - O
-- the schema that will hold all cohorts
-- the table name where the final cohort tables will reside
-- the schema where the OMOP data is located
-- a limitation on the cohort size (NUMBER OF EXPECTED NUMBER OF EVENTS?)
/* 

##################################################################################
Chronograph analyses:
IC = log2 ((N_observed + 0.5)/(N_expected + 0.5))
where N_expected = (Ntarget_drug * N_event) / Ntotal and Ntotal and Nevent are derived from the comparator drug cohort

N_expected: expected number of subjects with the target drug-event combination (i.e. derived from 22, 32 and 42) 
N_observed: actual number of subjects with the target drug-event combination (i.e. intersection of 22 and 32)
N_target_drug: number of subjects with the target drug (i.e. target drug cohort (22))
N_event: total number of subjects with the event in target and comparator drug cohort combined (32)
N_total: total number of subjects in target and comparator drug cohort combined (i.e. total drug cohort, (42))
##################################################################################
For convenience, the cohorts are enumerated as follows (cohort IDs):  
11(0):  Target drug cohort with event in 30-day post-index risk window (descriptive analyses)
21(0):  Target drug cohort (descriptive analyses)
22(0):  Target drug cohort (chronograph analyses)
31(0):  Comparator drug cohort with event in 30-day post-index risk window (descriptive analyses)
32(0):  Total drug (target and comparator) cohort with event(s) in 3-yrs pre and/or post-index risk window (chronograph analyses) (i.e. derived from 42 and 3)
40(0)*: Comparator drug cohort (chronograph analyses)
41(0):  Comparator drug cohort (descriptive analyses)
42(0):  Total drug (target and comparator) cohort (chronograph analyses) (i.e. derived from 22 and 40)
2*:     Study pool of eligible target drug eras used for defining first and randomly sampled target drug era cohorts  
3*:     Study pool of eligible condition eras
4*:     Study pool of eligible comparator drug eras used for defining first and randomly sampled comparator drug era cohorts 
############################################
-- Cohorts 11, 21, 31 and 41 serve as input for descriptive tables (risk window: max. 30-day post index date)
-- Cohorts 22, 32 and 42 serve as input for chronograph analyses (risk window: max. 3-yrs pre and max 3-yrs post index date)
-- Each subject is observed only once in the target drug (21, 22) and comparator drug (41, 42) cohorts
-- Each subject has at least 13-months pre and 1-day post-index observation time (equals time window of drug persistence gap)
-- Each subject contributes max 1 event to descriptive analyses 
-- Each subject can contribute more than 1 event to chronograph analyses 
-- By default, all cohort IDs refer to drug exposure defined based on first-time use (i.e. first drug era)
-- NOTE: Cohort IDs with "0" extension refer to drug exposure defined based on a randomly sampled drug era - TO BE ADDED IF NEEDED
-- NOTE: Study pool of eligible drug eras (2* and 4*) serve as input for defining first and randomly sampled (target/comparator) drug eras 
-- NOTE: Study pool of eligible condition eras (3*) for extraction of event occurences for descriptive analyses (i.e. first post-index event) and chronograph analyses (any event within pre- and postindex risk window)  
-- NOTE: Cohort 40 is currently not used as input for chronograph analyses, but will serve as input in matched cohort design
-- NOTE: set SEED to make sampling reproducible (RAND(SEED) FUNCTION)
############################################
*/

/*Input variables (sent from cohort-module)*/
-- These local variables are "rendered" by the R-script before execution.
{DEFAULT @exposure_drug_ids = ''} -- the concept id for the drug of interest
{DEFAULT @comparator_drug_ids = ''} -- the concept ids for comparator drugs (typically all drugs in the database)
{DEFAULT @event_ids = ''} -- concept ids for the outcome/event ID
{DEFAULT @resultsDatabaseSchema = ''} -- the schema that will hold all cohorts
{DEFAULT @conditionEraTableName = ''} -- the table name holding the condition_era
{DEFAULT @drugEraTableName = ''} -- the table name holding the drug_era
{DEFAULT @tempTableName = ''} -- the table name where the final cohort tables will reside
{DEFAULT @cdmDatabaseSchema = ''} -- the schema where the OMOP data is located
{DEFAULT @maximum_cohort_size = ''} -- a limitation on the cohort size

---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------

/* CREATE TABLE WITH EMPTY KEY VARIABLES */
-- Initiate one table with suffix original, where all cohort data will be inserted before processing/sampling 
IF OBJECT_ID('@resultsDatabaseSchema.@tempTableName_original', 'U') IS NOT NULL
DROP TABLE @resultsDatabaseSchema.@tempTableName_original;
CREATE TABLE @resultsDatabaseSchema.@tempTableName_original (
  cohort_definition_id INT,                           --unique identifier for each cohort
  cohort_start_date DATE,
  cohort_end_date DATE,
  subject_id BIGINT,
  drug_concept_id INT, -- not needed in final table, used for sampling 
  drug_era_start_date DATE, -- not needed in final table, used for setting risk time 
  drug_era_end_date DATE, -- not needed in final table, used for setting risk time 
  observation_period_start_date DATE, -- not needed in final table, used for setting risk time 
  observation_period_end_date DATE, -- not needed in final table, used for setting risk time 
  death_date DATE, -- not needed in final table, used for checking data 
  order_number INT, -- not needed in final table, identifier for first time use
  row_number INT -- not needed in final table, used for sampling 
  );

---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------

/* COHORT 2*. POPULATE TABLE WITH COHORT OF ELIGIBLE TARGET DRUG ERAS (STUDY POOL)*/
-- Study pool for constructing target drug cohorts based on first era (21, 22) or randomly sampled era (210, 220) 
-- Includes drug eras with at least 13-months pre and 1-day post drug start database observation 
-- NOTE: to be added: code for extracting distinct drug eras based on predefined drug era gap, 13 months (required for randomly sampled drug era cohorts)
INSERT INTO @resultsDatabaseSchema.@tempTableName_original (
  cohort_definition_id,
  subject_id,
  drug_concept_id,
  drug_era_start_date,
  drug_era_end_date,
  observation_period_start_date,
  observation_period_end_date,
  death_date
)
SELECT 2 AS cohort_definition_id, 
       x.person_id AS subject_id,
       x.drug_concept_id,
       x.drug_era_start_date, 
       x.drug_era_end_date,
       y.observation_period_start_date,
       y.observation_period_end_date,
       z.death_date
FROM @cdmDatabaseSchema.@drugEraTableName x
LEFT JOIN @cdmDatabaseSchema.death z						--add death_date to table (used for checking data only)
	  ON x.person_id = z.person_id
INNER JOIN @cdmDatabaseSchema.observation_period y	        --add observation_period_start_date and observation_period_end_date to table (needed for setting risk time)
      ON x.person_id = y.person_id
	   AND y.observation_period_start_date < x.drug_era_start_date
	   AND y.observation_period_end_date > x.drug_era_start_date
WHERE (DATEDIFF(MONTH, y.observation_period_start_date, x.drug_era_start_date) >= 13) AND (x.drug_concept_id IN (@exposure_drug_ids));  --select drug eras with at least 13-months pre and 1-day post-index observation time

 ---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------

/* COHORT 21. POPULATE TABLE WITH TARGET DRUG COHORT BASED ON FIRST TIME USE (FOR DESCRIPTIVE ANALYSES) */
-- Cohort constructed using COHORT 2 (pool of eligible target drug eras) as study base 
-- Risk time starts at drug_era_start_date (i.e. index date)
-- Risk time ends at drug_era_start_date+30 days or last date of observation (includes death) whichever occurs first 
-- NOTE: no need to define censoring based on drug_era_end_date as max time at risk is 30 days
-- NOTE: cohort_start_date and cohort_end_date do not meet OHDSI standards?
INSERT INTO @resultsDatabaseSchema.@tempTableName_original (
  cohort_definition_id,
  cohort_start_date,
  cohort_end_date,
  subject_id,
  drug_concept_id,
  drug_era_start_date,
  observation_period_end_date,
  death_date,
  order_number)
SELECT 21 AS cohort_definition_id, 
       t.drug_era_start_date AS cohort_start_date,							-- set cohort start date (index date) as drug era start date
	   CASE WHEN t.observation_period_end_date <= DATEADD(DAY, +30, t.drug_era_start_date)	-- set cohort end date as last day of obs or drug er start date +30 days whichever occurs first
			THEN t.observation_period_end_date 
			ELSE DATEADD(DAY, +30, t.drug_era_start_date)  
			END AS cohort_end_date,
       t.subject_id,
       t.drug_concept_id,
       t.drug_era_start_date,
       t.observation_period_end_date,
       t.death_date,
       t.order_number
FROM ( SELECT subject_id,											
              drug_concept_id,
              drug_era_start_date,
              observation_period_end_date,
              death_date,
              ROW_NUMBER() OVER ( PARTITION BY subject_id													-- select first-time use of target drug only (i.e. first drug era)
                                  ORDER by drug_era_start_date
                                ) AS order_number 
       FROM @resultsDatabaseSchema.@tempTableName_original
       WHERE cohort_definition_id = 2) t 
WHERE t.order_number = 1;

---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------

/* COHORT 22. POPULATE TABLE WITH TARGET DRUG COHORT BASED ON FIRST TIME USE (FOR CHRONOGRAPH ANALYSES) */
-- Risk time starts at drug_era_start_date-3 yrs or earliest date of observation whichever occurs last
-- Risk time ends at drug_era_start_date+3 yrs, drug era end date or last date of observation (includes death) whichever occurs first 
-- Note: need to set persistence gap for drug eras (default is ?)
INSERT INTO @resultsDatabaseSchema.@tempTableName_original (
  cohort_definition_id,
  cohort_start_date,
  cohort_end_date,
  subject_id,
  drug_concept_id,
  drug_era_start_date,
  observation_period_end_date,
  death_date,
  order_number)
SELECT 22 AS cohort_definition_id, 
       t.drug_era_start_date AS cohort_start_date,							-- set cohort start date (index date) as drug era start date
	   t.drug_era_end_date AS cohort_end_date,
       t.subject_id,
       t.drug_concept_id,
       t.drug_era_start_date,
       t.observation_period_end_date,
       t.death_date,
       t.order_number
FROM ( SELECT subject_id,											
              drug_concept_id,
              drug_era_start_date,
			  drug_era_end_date,
              observation_period_end_date,
              death_date,
              ROW_NUMBER() OVER ( PARTITION BY subject_id													-- select first-time use of target drug only (i.e. first drug era)
                                  ORDER by drug_era_start_date
                                ) AS order_number 
       FROM @resultsDatabaseSchema.@tempTableName_original
       WHERE cohort_definition_id = 2) t 
WHERE t.order_number = 1;

---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------

/* COHORT 4*. POPULATE TABLE WITH COHORT OF ELIGIBLE COMPARATOR DRUG ERAS (STUDY POOL)*/
-- Study pool for constructing comparator drug cohorts based on first era (41, 42) or randomly sampled era (410, 420)
-- Randomly samples 1 comparator drug per subject
-- NOTE: to be added: code for extracting distinct drug eras based on predefined drug era gap, 13 months (required for randomly sampled drug era cohorts)
INSERT INTO @resultsDatabaseSchema.@tempTableName_original (
  cohort_definition_id,
  subject_id,
  drug_concept_id,
  drug_era_start_date,
  drug_era_end_date,
  observation_period_start_date,
  observation_period_end_date,
  death_date
)
SELECT 4 AS cohort_definition_id, 
       person_id,
	   drug_concept_id,
	   drug_era_start_date, 
	   drug_era_end_date,
	   observation_period_start_date,
	   observation_period_end_date,
	   death_date
FROM ( SELECT *, 
              Row_number() OVER(PARTITION BY person_id ORDER BY newid()) AS one_row_per_person_row_number -- Scramble the order
       FROM ( SELECT x.person_id, 
		             x.drug_concept_id, 
					 x.drug_era_start_date, 
                     x.drug_era_end_date,
					 y.observation_period_start_date, 
					 y.observation_period_end_date, 
					 z.death_date,
                     Row_number() OVER(PARTITION BY x.person_id, drug_concept_id ORDER BY newid()) AS one_row_per_person_and_drug_row_number -- Scramble the order
              FROM  @cdmDatabaseSchema.@drugEraTableName x
	          LEFT JOIN @cdmDatabaseSchema.death z						--add death_date to table (used for checking data only)
	                       ON x.person_id = z.person_id
	          INNER JOIN @cdmDatabaseSchema.observation_period y			--add observation_period_start_date and observation_period_end_date to table (needed for setting risk time)
                           ON x.person_id = y.person_id
	                       AND y.observation_period_start_date < x.drug_era_start_date
	                       AND y.observation_period_end_date > x.drug_era_start_date
	          WHERE (DATEDIFF(MONTH, y.observation_period_start_date, x.drug_era_start_date) >= 13)  --select drug eras with at least 13-months pre and 1-day post-index observation time 
				    AND drug_concept_id IN (@comparator_drug_ids) 
				    AND drug_concept_id NOT IN (@exposure_drug_ids) 
	         ) T1
	   WHERE one_row_per_person_and_drug_row_number = 1
	) T2
WHERE one_row_per_person_row_number = 1;

---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------

/* COHORT 41. POPULATE TABLE WITH COMPARATOR DRUG COHORT BASED ON FIRST TIME USE (FOR DESCRIPTIVE ANALYSES) */
-- Cohort constructed using COHORT 4 (pool of eligible comparator drug eras) as study base 
-- Risk time starts at drug_era_start_date (i.e. index date)
-- Risk time ends at drug_era_start_date+30 days or last date of observation (includes death) whichever occurs first 
-- Note: no need to define censoring based on drug_era_end_date as max time at risk is 30 days
INSERT INTO @resultsDatabaseSchema.@tempTableName_original (
  cohort_definition_id,
  cohort_start_date,
  cohort_end_date,
  subject_id,
  drug_concept_id,
  observation_period_end_date,
  death_date,
  order_number)
SELECT 41 AS cohort_definition_id, 
       t.drug_era_start_date AS cohort_start_date,							-- set cohort start date (index date) as drug era start date
       CASE WHEN t.observation_period_end_date <= DATEADD(DAY, +30, t.drug_era_start_date)	-- set cohort end date as last date of obs or drug era start date +30 days whichever occurs first
	        THEN t.observation_period_end_date 
			ELSE DATEADD(DAY, +30, t.drug_era_start_date)  
			END AS cohort_end_date,
       t.subject_id,
       t.drug_concept_id,
       t.observation_period_end_date,
       t.death_date,
       t.order_number
FROM ( SELECT subject_id,											
              drug_concept_id,
              drug_era_start_date,
              observation_period_end_date,
              death_date,
              ROW_NUMBER() OVER ( PARTITION BY subject_id         -- select first-time use of target drug only (i.e. first drug era)
                                  ORDER by drug_era_start_date 
                                ) AS order_number 
       FROM @resultsDatabaseSchema.@tempTableName_original
       WHERE cohort_definition_id = 4 ) t 
WHERE t.order_number = 1;

/* Check no. of obs in table COHORT 41 (96780) */ -- not needed in final script, used for data check only
--SELECT COUNT(*) FROM @resultsDatabaseSchema.@tempTableName_original  WHERE cohort_definition_id = 41;
--SELECT * FROM @resultsDatabaseSchema.@tempTableName_original  WHERE cohort_definition_id = 41;

---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------

/* COHORT 40. POPULATE TABLE WITH COMPAROTOR DRUG COHORT BASED ON FIRST TIME USE (FOR CHRONOGRAPH ANALYSES) */
-- Risk time starts at drug_era_start_date-3 yrs or earliest date of observation whichever occurs last
-- Risk time ends at drug_era_start_date+3 yrs, drug era end date or last date of observation (includes death) whichever occurs first 
-- Note: need to set persistence gap for drug eras (default is ?)
INSERT INTO @resultsDatabaseSchema.@tempTableName_original (
  cohort_definition_id,
  cohort_start_date,
  cohort_end_date,
  subject_id,
  drug_concept_id,
  drug_era_start_date,
  drug_era_end_date,
  observation_period_start_date,
  observation_period_end_date,
  death_date,
  order_number)
SELECT 40 AS cohort_definition_id, 
       t.drug_era_start_date AS cohort_start_date,
	   t.drug_era_end_date AS cohort_end_date,
	   t.subject_id,
	   t.drug_concept_id,
	   t.drug_era_start_date,
	   t.drug_era_end_date,
	   t.observation_period_start_date,
	   t.observation_period_end_date,
	   t.death_date,
	   t.order_number
FROM ( SELECT subject_id,
	   	      drug_concept_id,
	   	      drug_era_start_date,
	   	      drug_era_end_date,
	   	      observation_period_end_date,
	   	      observation_period_start_date,
	   	      death_date,
	   	      ROW_NUMBER() OVER ( PARTITION BY subject_id			-- select first-time use of target drug only (i.e. first drug era)
  	   	      	   	              ORDER by drug_era_start_date
                                ) AS order_number 
       FROM @resultsDatabaseSchema.@tempTableName_original
       WHERE cohort_definition_id = 4) t 
WHERE t.order_number = 1;

---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------

/* COHORT 42. POPULATE TABLE WITH TOTAL DRUG (TARGET AND COMPARATOR) COHORT BASED ON FIRST TIME USE (FOR CHRONOGRAPH ANALYSES) */
/* Defined as all subjects in cohort 22 and cohort 40 */
INSERT INTO @resultsDatabaseSchema.@tempTableName_original (
  cohort_definition_id,
  cohort_start_date,
  cohort_end_date,
  subject_id,
  drug_concept_id,
  drug_era_start_date,
  drug_era_end_date,
  observation_period_start_date,
  observation_period_end_date,
  death_date,
  order_number)
SELECT 42 AS cohort_definition_id,
       cohort_start_date,
       cohort_end_date,
       subject_id,
       drug_concept_id,
       drug_era_start_date,
       drug_era_end_date,
       observation_period_start_date,
       observation_period_end_date,
       death_date,
       order_number
FROM @resultsDatabaseSchema.@tempTableName_original 
WHERE cohort_definition_id IN (22,40);

---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------

/* COHORT 3*. POPULATE TABLE WITH COHORT OF ELIGIBLE CONDITION ERAS (STUDY POOL)*/
-- Study pool for extracing conditions for merging with target, comparator, total (target and comparator) drug cohorts 
INSERT INTO @resultsDatabaseSchema.@tempTableName_original (
  cohort_definition_id,
  cohort_start_date,
  cohort_end_date,
  subject_id
)
SELECT 3 AS cohort_definition_id,												 
       x.cohort_start_date,                                    -- outcome @event_start_date, for use in  chronograph 
       x.cohort_end_date,
       x.subject_id
FROM ( SELECT DISTINCT condition_era_start_date AS cohort_start_date,			-- distinct to select only 1 record per day (multiple diagnoses on the same day most likely refer to the same occurrence than seperate occurrences)
                       condition_era_end_date AS cohort_end_date,                         -- set cohort start date as condition era start date (used in analysis) and cohort end date as condition era start date (not used in analysis)
                       person_id AS subject_id
       FROM @cdmDatabaseSchema.@conditionEraTableName
       WHERE condition_concept_id IN ( SELECT descendant_concept_id
							  		   FROM @cdmDatabaseSchema.concept_ancestor
									   WHERE ancestor_concept_id IN (@event_ids) ) 
	  ) x;

---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------

/* COHORT 11. POPULATE TABLE WITH TARGET DRUG COHORT BASED ON FIRST TIME USE WITH EVENT IN 30-DAY POST INDEX RISK WINDOW (FOR DESCRIPTIVE ANALYSES) */
-- Cohort constructed from COHORT 21 (target drug cohort) and COHORT 3 (pool of eligible condition eras) as study base 
-- Includes first post-index date diagnosis only (only 1 event per subjectid).

INSERT INTO @resultsDatabaseSchema.@tempTableName_original (
  cohort_definition_id, 
  cohort_start_date, 
  cohort_end_date, 
  subject_id)
SELECT 11 AS cohort_definition_id,
       t.t21cohort_start_date AS cohort_start_date,             -- set cohort start date (index date) as drug era start date (cohort start date from target drug cohort (21))
	   CASE WHEN t.t3cohort_start_date <= t.t21cohort_end_date 
	        THEN t.t3cohort_start_date     -- set cohort end date as condition era start date (cohort start date from event cohort (3)), date of last obs or drug era start date +30 days (cohort end date from target drug cohort (21)) whichever occurs first
	        ELSE t.t21cohort_end_date 
			END AS cohort_end_date,
	   t.t21subject_id AS subject_id
FROM ( SELECT t11.*,
              row_number() over(PARTITION BY t11.t3subject_id ORDER BY t11.t3cohort_start_date) AS ROW
       FROM ( SELECT t3.cohort_definition_id AS t3cohort_definition_id,
                     t3.cohort_start_date AS t3cohort_start_date,
                     t3.cohort_end_date AS t3cohort_end_date,
                     t3.subject_id AS t3subject_id,
                     t21.cohort_definition_id AS t21cohort_definition_id,
                     t21.cohort_start_date AS t21cohort_start_date,
                     t21.cohort_end_date AS t21cohort_end_date,
                     t21.subject_id AS t21subject_id
              FROM @resultsDatabaseSchema.@tempTableName_original t3
              INNER JOIN @resultsDatabaseSchema.@tempTableName_original t21 ON t3.subject_id = t21.subject_id
              WHERE t3.cohort_definition_id = 3
                    AND t21.cohort_definition_id = 21
                    AND t3.cohort_start_date BETWEEN t21.cohort_start_date AND t21.cohort_end_date 
            ) t11
     ) t
WHERE t.row=1;
---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------

/* COHORT 31. POPULATE TABLE WITH COMPARATOR DRUG COHORT BASED ON FIRST TIME USE WITH EVENT IN 30-DAY POST INDEX RISK WINDOW (FOR DESCRIPTIVE ANALYSES) */
-- Cohort constructed from COHORT 41 (target drug cohort) and COHORT 3 (pool of eligible condition eras) as study base 
-- Includes first post-index date diagnosis only (only 1 event per subjectid).

INSERT INTO @resultsDatabaseSchema.@tempTableName_original (
  cohort_definition_id, 
  cohort_start_date, 
  cohort_end_date, 
  subject_id)
SELECT 31 AS cohort_definition_id,
       t.t41cohort_start_date AS cohort_start_date,   -- set cohort start date (index date) as drug era start date (cohort start date from comparator drug cohort (41))
	   CASE WHEN t.t3cohort_start_date <= t.t41cohort_end_date 
	        THEN t.t3cohort_start_date     -- set cohort end date as condition era start date (cohort start date from event cohort (3)), date of last obs or drug era start date +30 days (cohort end date from target drug cohort (41)) whichever occurs first
	        ELSE t.t41cohort_end_date 
			END AS cohort_end_date,
	   t.t3subject_id AS subject_id
FROM ( SELECT t31.*,
              row_number() over(PARTITION BY t31.t3subject_id ORDER BY t31.t3cohort_start_date) AS ROW
       FROM ( SELECT t3.cohort_definition_id AS t3cohort_definition_id,
                     t3.cohort_start_date AS t3cohort_start_date,
                     t3.cohort_end_date AS t3cohort_end_date,
                     t3.subject_id AS t3subject_id,
                     t41.cohort_definition_id AS t41cohort_definition_id,
                     t41.cohort_start_date AS t41cohort_start_date,
                     t41.cohort_end_date AS t41cohort_end_date,
                     t41.subject_id AS t41subject_id
              FROM @resultsDatabaseSchema.@tempTableName_original t3
              INNER JOIN @resultsDatabaseSchema.@tempTableName_original t41 ON t3.subject_id = t41.subject_id
              WHERE t3.cohort_definition_id = 3
                    AND t41.cohort_definition_id = 41
                    AND (t3.cohort_start_date BETWEEN t41.cohort_start_date AND t41.cohort_end_date) 
            ) t31
     ) t
WHERE t.row=1;
---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------

/* COHORT 32. POPULATE TABLE WITH TOTAL (TARGET AND COMPARATOR) DRUG COHORT BASED ON FIRST TIME USE WITH EVENT(S) IN 3-YR PRE OR 3-YR POST INDEX RISK WINDOW (FOR TEMPORAL ANALYSES) */
-- Cohort constructed using COHORT 42 (total (target and comparator) drug cohort) and 3 (pool of eligible condition eras) as study base 
-- Includes any event diagnosis in the risk window before or after the index date (allows more than 1 event per subjectid)

INSERT INTO @resultsDatabaseSchema.@tempTableName_original (
  cohort_definition_id, 
  cohort_start_date, 
  cohort_end_date, 
  subject_id)
SELECT 32 AS cohort_definition_id,
       t.t3cohort_start_date AS cohort_start_date,                                         -- set cohort start date (index date) as drug era start date -3 yrs or first date of obs whichever occurs last from total drug cohort (42)
       t.t3cohort_end_date  AS cohort_end_date,
       t.t3subject_id AS subject_id
FROM ( SELECT t3.cohort_definition_id AS t3cohort_definition_id,
              t3.cohort_start_date AS t3cohort_start_date,
              t3.cohort_end_date AS t3cohort_end_date,
              t3.subject_id AS t3subject_id
       FROM @resultsDatabaseSchema.@tempTableName_original t3
       WHERE t3.cohort_definition_id = 3
	  ) t;   


-- Initiate the table that will hold the final sampled cohorts
IF OBJECT_ID('@resultsDatabaseSchema.@tempTableName', 'U') IS NOT NULL 
DROP TABLE @resultsDatabaseSchema.@tempTableName;
CREATE TABLE @resultsDatabaseSchema.@tempTableName (
  cohort_definition_id INT,
  cohort_start_date DATE,
  cohort_end_date DATE,
  subject_id BIGINT);

-- Apply any other sampling on the original-table to create the final one
INSERT INTO @resultsDatabaseSchema.@tempTableName(
    cohort_definition_id,
    cohort_start_date,
    cohort_end_date,
    subject_id
  )
SELECT cohort_definition_id, cohort_start_date, cohort_end_date, subject_id
FROM (SELECT cohort_definition_id, cohort_start_date, cohort_end_date, subject_id, ROW_NUMBER() OVER (PARTITION BY cohort_definition_id ORDER BY subject_id) cohort_row_number
      FROM @resultsDatabaseSchema.@tempTableName_original) T1
      WHERE cohort_definition_id in (22, 32, 42) OR cohort_row_number <= @maximum_cohort_size 
       -- restrict to cohort sample size for descriptive-tables cohorts, as the covariates-collection is expensive.
	  
 
