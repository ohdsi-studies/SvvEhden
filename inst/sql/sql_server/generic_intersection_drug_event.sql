/* CREATE DRUG WITH EVENT COHORT (MAX AT RISK PERIOD = 1 YR) 
 THIS FILE WILL CREATE INTERSECTION BETWEEN TWO COHORTS. THE @drug_cohort_id CAN BE BOTH AN 
 COMPARATOR DRUG COHOR OR AND TARGET DRUG COHORT
*/

CREATE TABLE #Codesets (
  codeset_id int NOT NULL,
  concept_id bigint NOT NULL
)
;


INSERT INTO #Codesets (codeset_id, concept_id)
SELECT 0 as codeset_id, c.concept_id FROM (select distinct I.concept_id FROM
( 
  select concept_id from @vocabulary_database_schema.CONCEPT where concept_id in (@generic_intersection_event_concept_ids)
UNION  select c.concept_id
  from @vocabulary_database_schema.CONCEPT c
  join @vocabulary_database_schema.CONCEPT_ANCESTOR ca on c.concept_id = ca.descendant_concept_id
  and ca.ancestor_concept_id in (@generic_intersection_event_concept_ids)
  and c.invalid_reason is null

) I
) C UNION ALL 
SELECT 1 as codeset_id, c.concept_id FROM (select distinct I.concept_id FROM
( 
  select concept_id from @vocabulary_database_schema.CONCEPT where concept_id in (@generic_intersection_drug_concept_ids)
UNION  select c.concept_id
  from @vocabulary_database_schema.CONCEPT c
  join @vocabulary_database_schema.CONCEPT_ANCESTOR ca on c.concept_id = ca.descendant_concept_id
  and ca.ancestor_concept_id in (@generic_intersection_drug_concept_ids)
  and c.invalid_reason is null

) I
) C
;

DROP TABLE IF EXISTS #intersection_cohort;
SELECT t.d_subject_id AS subject_id,
	   t.d_cohort_start_date AS cohort_start_date,             -- set cohort start date to drug exposure start date (from drug_cohort)
	   DATEADD(day,1,t.ev_cohort_start_date) AS cohort_end_date               -- set cohort end date to condition start date (from event_cohort)
INTO #intersection_cohort
FROM ( SELECT t1.*,
              row_number() over(PARTITION BY t1.ev_subject_id ORDER BY t1.ev_cohort_start_date) AS row
       FROM ( SELECT event_cohort.subject_id AS ev_subject_id,
					 event_cohort.cohort_start_date AS ev_cohort_start_date,
                     event_cohort.cohort_end_date AS ev_cohort_end_date,
					 drug_cohort.subject_id AS d_subject_id,                   
                     drug_cohort.cohort_start_date AS d_cohort_start_date,
                     drug_cohort.cohort_end_date AS d_cohort_end_date
              FROM @target_database_schema.@target_cohort_table event_cohort  -- join event records from event table (event_cohort) to drug cohort table (drug_cohort)
              INNER JOIN @target_database_schema.@target_cohort_table drug_cohort ON event_cohort.subject_id = drug_cohort.subject_id 
              WHERE event_cohort.cohort_definition_id = @intersection_event_cohort_id
			  AND drug_cohort.cohort_definition_id = @intersection_drug_cohort_id
			  AND (event_cohort.cohort_start_date BETWEEN drug_cohort.cohort_start_date AND drug_cohort.cohort_end_date) 
			  --AND event_cohort.cohort_start_date <= dateadd(day,365,drug_cohort.cohort_start_date) -- only select patients with condition start date between drug_cohort start and exit AND within 1 yr fixed interval after ta cohort start
            ) t1
     ) t
WHERE t.row=1;



DELETE FROM @target_database_schema.@target_cohort_table where cohort_definition_id = @target_cohort_id;
INSERT INTO @target_database_schema.@target_cohort_table (cohort_definition_id, subject_id, cohort_start_date, cohort_end_date)
select @target_cohort_id as cohort_definition_id, subject_id, cohort_start_date, cohort_end_date 
FROM #intersection_cohort CO;
-- @target_cohort_id = cohort id of the intersection (target of this query)



TRUNCATE TABLE #intersection_cohort;
DROP TABLE #intersection_cohort;

TRUNCATE TABLE #Codesets;
DROP TABLE #Codesets;



