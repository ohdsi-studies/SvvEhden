{DEFAULT @cdm_database_schema = ''}
{DEFAULT @cohort_database_schema = ''}
{DEFAULT @cohort_table = ''}
{DEFAULT @exposure_cohort_id = ''}
{DEFAULT @comparator_cohort_id = ''}
{DEFAULT @outcome_cohort_id = ''}
{DEFAULT @cohort_start_field = ''}
{DEFAULT @cohort_id_field = ''}
{DEFAULT @cohort_person_id_field = ''}

-- Four tables will be used. Two for exposed ("exp"), two for comparator ("comp"), both with
-- and without the outcome ("out")
-- Ending with ICTPD is to prevent overlap with possible existing tables
DROP TABLE IF EXISTS @cohort_database_schema.exp_ICTPD;
DROP TABLE IF EXISTS @cohort_database_schema.exp_out_ICTPD;
DROP TABLE IF EXISTS @cohort_database_schema.comp_ICTPD;
DROP TABLE IF EXISTS @cohort_database_schema.comp_out_ICTPD;

-- For each period, we count the number of observed patients that at some point have the exposure.
-- This gives you the "how many were at risk"-denominator for the case series, 
-- and has nothing to do with the outcome.
SELECT period_table.period_id,
	     COUNT(*) AS exposed_count -- AS is ok in SQLRender as long as it's not used as a table alias
INTO @cohort_database_schema.exp_ICTPD
FROM @cohort_database_schema.@cohort_table cohort
CROSS JOIN @cohort_database_schema.period_ICTPD period_table
INNER JOIN @cdm_database_schema.observation_period
	ON cohort.@cohort_person_id_field = observation_period.person_id
			-- In the join, we only keep rows when the cohort entry date lies within the observation time of the patient
		AND cohort.@cohort_start_field >= observation_period_start_date
		AND cohort.@cohort_start_field <= observation_period_end_date
		-- Patients just contribute to periods within their observation time
		-- i.e. the observation time is the "time at risk", but note the period parameter as well,
		-- e.g. time at risk endpoint = min(drug start + fixed time at risk from period, observation time)
		-- Also note, cohort entry and exit cannot be used, as we want time before cohort entry as well.
WHERE DATEADD(DAY, period_table.period_start, cohort.@cohort_start_field) <= observation_period_end_date
	AND DATEADD(DAY, period_table.period_end, cohort.@cohort_start_field) >= observation_period_start_date
	AND cohort.@cohort_id_field IN (@exposure_cohort_id)
  GROUP BY period_table.period_id;
  
-- For each period, we count the number of observed comparator patients 
-- This gives you the "how many were at risk"-denominator for the comparator, 
-- and has nothing to do with the outcome.	
SELECT period_table.period_id,
	COUNT(*) AS comparator_count
INTO @cohort_database_schema.comp_ICTPD
FROM @cohort_database_schema.@cohort_table cohort
CROSS JOIN @cohort_database_schema.period_ICTPD period_table
INNER JOIN @cdm_database_schema.observation_period
	ON cohort.@cohort_person_id_field = observation_period.person_id
		AND cohort.@cohort_start_field >= observation_period_start_date
		AND cohort.@cohort_start_field <= observation_period_end_date
WHERE DATEADD(DAY, period_table.period_start, cohort.@cohort_start_field) <= observation_period_end_date 
	AND DATEADD(DAY, period_table.period_end, cohort.@cohort_start_field) >= observation_period_start_date
	AND cohort.@cohort_id_field IN (@comparator_cohort_id) 
GROUP BY period_table.period_id;

-- For each period, we count the number of exposure cohort patients with the outcome
SELECT a.period_id,
        CASE WHEN b.outcome_count IS NULL THEN 0 ELSE b.outcome_count END AS outcome_count -- OK in SQLRender
INTO @cohort_database_schema.exp_out_ICTPD
FROM
(
/*SELECT period_table.period_id
FROM (SELECT DISTINCT @cohort_id_field FROM @cohort_database_schema.@cohort_table) exposure -- short name for exposure cohort
CROSS JOIN (SELECT DISTINCT period_id FROM @cohort_database_schema.period_ICTPD) period_table
CROSS JOIN (SELECT DISTINCT @cohort_id_field FROM @cohort_database_schema.@cohort_table) outcome
WHERE 1=1
	AND exposure.@cohort_id_field IN (@exposure_cohort_id)
	AND outcome.@cohort_id_field IN (@outcome_cohort_id)
GROUP BY period_table.period_id*/

SELECT 
    period_table.period_id
FROM  @cohort_database_schema.period_ICTPD period_table
) a
LEFT JOIN
(
SELECT exposure.@cohort_id_field AS exposure_id,
	outcome.@cohort_id_field AS outcome_id,
    period_table.period_id,
	COUNT(*) AS outcome_count
FROM @cohort_database_schema.@cohort_table exposure
CROSS JOIN @cohort_database_schema.period_ICTPD period_table
INNER JOIN @cohort_database_schema.@cohort_table outcome
	ON exposure.@cohort_person_id_field = outcome.@cohort_person_id_field
	AND outcome.@cohort_id_field = @outcome_cohort_id
INNER JOIN @cdm_database_schema.observation_period
	ON exposure.@cohort_person_id_field = observation_period.person_id
		AND exposure.@cohort_start_field >= observation_period_start_date
		AND exposure.@cohort_start_field <= observation_period_end_date
		AND outcome.@cohort_person_id_field = observation_period.person_id
		AND outcome.@cohort_start_field >= observation_period_start_date
		AND outcome.@cohort_start_field <= observation_period_end_date
WHERE DATEADD(DAY, period_table.period_start, exposure.@cohort_start_field) <= outcome.@cohort_start_field
	AND DATEADD(DAY, period_table.period_end, exposure.@cohort_start_field) >= outcome.@cohort_start_field
	AND exposure.@cohort_id_field = @exposure_cohort_id

GROUP BY exposure.@cohort_id_field,
	outcome.@cohort_id_field,
    period_table.period_id
) b
  ON a.period_id   = b.period_id;
    
-- For each period, we count the number of comparator cohort patients with the outcome
SELECT a.period_id, 
    CASE WHEN b.all_outcome_count IS NULL THEN 0 ELSE b.all_outcome_count END AS comparator_outcome_count
INTO @cohort_database_schema.comp_out_ICTPD
FROM
(
SELECT 
    period_table.period_id
FROM  @cohort_database_schema.period_ICTPD period_table
) a
LEFT JOIN
(
SELECT outcome.@cohort_id_field AS outcome_id,
    period_table.period_id,
	COUNT(*) AS all_outcome_count
FROM @cohort_database_schema.@cohort_table exposure
CROSS JOIN @cohort_database_schema.period_ICTPD period_table
INNER JOIN @cohort_database_schema.@cohort_table outcome
	ON exposure.@cohort_person_id_field = outcome.@cohort_person_id_field
	AND outcome.@cohort_id_field = @outcome_cohort_id
INNER JOIN @cdm_database_schema.observation_period
	ON exposure.@cohort_person_id_field = observation_period.person_id
		AND exposure.@cohort_start_field >= observation_period_start_date
		AND exposure.@cohort_start_field <= observation_period_end_date
		AND outcome.@cohort_person_id_field = observation_period.person_id
		AND outcome.@cohort_start_field >= observation_period_start_date
		AND outcome.@cohort_start_field <= observation_period_end_date	
WHERE DATEADD(DAY, period_table.period_start, exposure.@cohort_start_field) <= outcome.@cohort_start_field
	AND DATEADD(DAY, period_table.period_end, exposure.@cohort_start_field) >= outcome.@cohort_start_field
	AND exposure.@cohort_id_field = @comparator_cohort_id
GROUP BY period_table.period_id,
exposure.@cohort_id_field,
	outcome.@cohort_id_field
) b
  ON  a.period_id   = b.period_id;

