-- Creates the comparator drug cohorts to be used in SVVEHDEN-sprint, according to updated study protocol.
-- Identify comparator drug cohort through matching the any drug cohort to the 
-- target drug cohort based on sex, age at and calendar year of cohort entry.
/* 
##################################################################################
*/


----------------------------------------------------------------------
-- The CodeSets part must be in here, for executeDiagnostics() to work:
-- ConseptSets.R function extractConceptSetsSqlFromCohortSql().
----------------------------------------------------------------------
CREATE TABLE #Codesets (
  codeset_id int NOT NULL,
  concept_id bigint NOT NULL
)
;

INSERT INTO #Codesets (codeset_id, concept_id)
SELECT 0 as codeset_id, c.concept_id FROM (select distinct I.concept_id FROM
( 
  select concept_id from @vocabulary_database_schema.CONCEPT where concept_id in (@all_drug_concept_ids)
UNION  select c.concept_id
  from @vocabulary_database_schema.CONCEPT c
  join @vocabulary_database_schema.CONCEPT_ANCESTOR ca on c.concept_id = ca.descendant_concept_id
  and ca.ancestor_concept_id in (@all_drug_concept_ids)
  and c.invalid_reason is null

) I
) C
;
----------------------------------------------------------------------

/* Add sex, age at and calendar year of cohort entry to target drug cohort */
drop table if exists #target_drug_cohort
create table #target_drug_cohort (
    drug bigint,
	person_id bigint,
	cohort_start_date date,
	cohort_end_date date,
	gender_concept_id int,
	age_cohort_entry int,
	cohort_start_yr int
)

insert into #target_drug_cohort
select 
	0 as drug,
    t.subject_id as person_id,
	t.cohort_start_date as cohort_start_date,
	t.cohort_end_date as cohort_end_date,
	p.gender_concept_id as gender_concept_id,
	datediff(year,(datefromparts(p.year_of_birth, p.month_of_birth, p.day_of_birth)),t.cohort_start_date) as age_cohort_entry,
	datepart(year from t.cohort_start_date) as cohort_start_yr
from @target_database_schema.@target_cohort_table t
join @cdm_database_schema.PERSON p
ON t.subject_id = p.person_id
where cohort_definition_id = @matching_drug_cohort_id; -- @matching_drug_cohort_id = cohort id of the drug to compare against

/* Add sex, age at and calendar year of cohort entry to any drug cohort */
drop table if exists #any_drug_cohort
create table #any_drug_cohort (
    drug bigint,
	person_id bigint,
	cohort_start_date date,
	cohort_end_date date,
	gender_concept_id int,
	age_cohort_entry int,
	cohort_start_yr int
)

insert into #any_drug_cohort
select 
    1 as drug,
    t.subject_id as person_id,
	t.cohort_start_date as cohort_start_date,
	t.cohort_end_date as cohort_end_date,
	p.gender_concept_id as gender_concept_id,
	datediff(year,(datefromparts(p.year_of_birth, p.month_of_birth, p.day_of_birth)),t.cohort_start_date) as age_cohort_entry,
	datepart(year from t.cohort_start_date) as cohort_start_yr
from @target_database_schema.@target_cohort_table t
join @cdm_database_schema.PERSON p
ON t.subject_id = p.person_id
where cohort_definition_id = 999999@fixed_TAR;

/* Identify comparator drug cohort by matching the any drug cohort on sex, age at and calendar year of cohort entry to the target drug cohort (10:1 ratio) */
DROP TABLE if exists #comp_drug_cohort
create table #comp_drug_cohort (
	person_id bigint,
	cohort_start_date date,
	cohort_end_date date,
)
;WITH cteDrug AS
  (SELECT person_id,
          age_cohort_entry,
          gender_concept_id,
          cohort_start_yr,
          Row_Number() Over(PARTITION BY age_cohort_entry, gender_concept_id, cohort_start_yr
                            ORDER BY person_id) AS CaseRN
   FROM #target_drug_cohort),
     cteAssignPersonNumber AS
  (SELECT p.person_id,
          p.age_cohort_entry,
          p.gender_concept_id,
          cohort_start_yr,
          Row_Number() OVER (PARTITION BY p.age_cohort_entry,
                                          p.gender_concept_id,
                                          p.cohort_start_yr
                             ORDER BY NewID()) AS AssignedPersonNumber, p.cohort_end_date,p.cohort_start_date
   FROM #any_drug_cohort p)
INSERT into #comp_drug_cohort
SELECT p.person_id,
	   p.cohort_start_date,
	   p.cohort_end_date
FROM cteDrug c
INNER JOIN cteAssignPersonNumber p ON p.gender_concept_id = c.gender_concept_id
AND p.age_cohort_entry = c.age_cohort_entry
AND p.cohort_start_yr = c.cohort_start_yr
AND p.AssignedPersonNumber BETWEEN 10*(CaseRN - 1)+ 1 AND 10*CaseRN
ORDER BY p.person_id


DELETE FROM @target_database_schema.@target_cohort_table where cohort_definition_id = @target_cohort_id;
INSERT INTO @target_database_schema.@target_cohort_table (cohort_definition_id, subject_id, cohort_start_date, cohort_end_date)
select @target_cohort_id as cohort_definition_id, person_id, cohort_start_date, cohort_end_date 
FROM #comp_drug_cohort CO;
-- @target_cohort_id = cohort id of the comparator cohort (target of this query)


TRUNCATE TABLE #Codesets;
DROP TABLE #Codesets;

TRUNCATE TABLE #comp_drug_cohort;
DROP TABLE #comp_drug_cohort;

TRUNCATE TABLE #target_drug_cohort;
DROP TABLE #target_drug_cohort;

TRUNCATE TABLE #any_drug_cohort;
DROP TABLE #any_drug_cohort;

