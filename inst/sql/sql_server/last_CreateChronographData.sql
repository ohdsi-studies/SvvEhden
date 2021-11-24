IF OBJECT_ID('tempdb..#exposure', 'U') IS NOT NULL
	DROP TABLE #exposure;

IF OBJECT_ID('tempdb..#all_table', 'U') IS NOT NULL
	DROP TABLE #all_table;	
	
IF OBJECT_ID('tempdb..#exposure_outcome', 'U') IS NOT NULL
	DROP TABLE #exposure_outcome;

IF OBJECT_ID('tempdb..#outcome', 'U') IS NOT NULL
	DROP TABLE #outcome;		

-- Count number of people observed relative to each exposure	
SELECT exposure.cohort_definition_id AS exposure_id,
    period.period_id,
	COUNT(*) AS observed_count
INTO #exposure
FROM OmopCdm.synpuf5pct_20180710.cohorts_oskarg exposure
CROSS JOIN #period period
INNER JOIN OmopCdm.synpuf5pct_20180710.observation_period
	ON exposure.subject_id = observation_period.person_id
		AND exposure.cohort_start_date >= observation_period_start_date
		AND exposure.cohort_start_date <= observation_period_end_date
WHERE DATEADD(DAY, period.period_start, exposure.cohort_start_date) <= observation_period_end_date
	AND DATEADD(DAY, period.period_end, exposure.cohort_start_date) >= observation_period_start_date

	AND exposure.cohort_definition_id IN (42,22)
	
GROUP BY exposure.cohort_definition_id,
    period.period_id;
	
-- Count number of people observed relative to any exposure	
SELECT period.period_id,
	COUNT(*) AS all_observed_count
INTO #all_table
FROM OmopCdm.synpuf5pct_20180710.cohorts_oskarg exposure
CROSS JOIN #period period
INNER JOIN OmopCdm.synpuf5pct_20180710.observation_period
	ON exposure.subject_id = observation_period.person_id
		AND exposure.cohort_start_date >= observation_period_start_date
		AND exposure.cohort_start_date <= observation_period_end_date
WHERE DATEADD(DAY, period.period_start, exposure.cohort_start_date) <= observation_period_end_date
	AND DATEADD(DAY, period.period_end, exposure.cohort_start_date) >= observation_period_start_date

	AND exposure.cohort_definition_id IN (42,22)
 
GROUP BY period.period_id;

-- Count number of people with the outcome relative to each exposure (within same observation period)	
SELECT a.exposure_id
     , a.outcome_id
	 , a.period_id
	 , CASE WHEN b.outcome_count IS NULL THEN 0 ELSE b.outcome_count END AS outcome_count
INTO #exposure_outcome
FROM
(
SELECT exposure.cohort_definition_id AS exposure_id,
	outcome.cohort_definition_id AS outcome_id,
    period.period_id
FROM       (SELECT DISTINCT cohort_definition_id FROM OmopCdm.synpuf5pct_20180710.cohorts_oskarg) exposure
CROSS JOIN (SELECT DISTINCT period_id          FROM #period) period
CROSS JOIN (SELECT DISTINCT cohort_definition_id  FROM OmopCdm.synpuf5pct_20180710.cohorts_oskarg outcome) outcome

INNER JOIN #exposure_outcome_ids exposure_outcome_ids
	ON exposure.cohort_definition_id = exposure_outcome_ids.exposure_id
		AND outcome.cohort_definition_id = exposure_outcome_ids.outcome_id

WHERE 1=1

GROUP BY exposure.cohort_definition_id,
	outcome.cohort_definition_id,
    period.period_id
) a
LEFT JOIN
(
SELECT exposure.cohort_definition_id AS exposure_id,
	outcome.cohort_definition_id AS outcome_id,
    period.period_id,
	COUNT(*) AS outcome_count
FROM OmopCdm.synpuf5pct_20180710.cohorts_oskarg exposure
CROSS JOIN #period period
INNER JOIN OmopCdm.synpuf5pct_20180710.cohorts_oskarg outcome
	ON exposure.subject_id = outcome.subject_id
INNER JOIN OmopCdm.synpuf5pct_20180710.observation_period
	ON exposure.subject_id = observation_period.person_id
		AND exposure.cohort_start_date >= observation_period_start_date
		AND exposure.cohort_start_date <= observation_period_end_date
		AND outcome.subject_id = observation_period.person_id
		AND outcome.cohort_start_date >= observation_period_start_date
		AND outcome.cohort_start_date <= observation_period_end_date

INNER JOIN #exposure_outcome_ids exposure_outcome_ids
	ON exposure.cohort_definition_id = exposure_outcome_ids.exposure_id
		AND outcome.cohort_definition_id = exposure_outcome_ids.outcome_id

WHERE DATEADD(DAY, period.period_start, exposure.cohort_start_date) <= outcome.cohort_start_date
	AND DATEADD(DAY, period.period_end, exposure.cohort_start_date) >= outcome.cohort_start_date

GROUP BY exposure.cohort_definition_id,
	outcome.cohort_definition_id,
    period.period_id
) b
    ON  a.exposure_id = b.exposure_id
    AND a.outcome_id  = b.outcome_id
    AND a.period_id   = b.period_id;
	
-- Count number of people with the outcome relative to any exposure	(within same observation period)
SELECT a.outcome_id
	 , a.period_id
	 , CASE WHEN b.all_outcome_count IS NULL THEN 0 ELSE b.all_outcome_count END AS all_outcome_count
INTO #outcome
FROM
(
SELECT outcome.cohort_definition_id AS outcome_id,
    period.period_id
FROM       (SELECT DISTINCT cohort_definition_id FROM OmopCdm.synpuf5pct_20180710.cohorts_oskarg outcome) outcome
CROSS JOIN (SELECT DISTINCT period_id         FROM #period) period
WHERE 1=1

	AND outcome.cohort_definition_id IN (32)

) a
LEFT JOIN
(
SELECT outcome.cohort_definition_id AS outcome_id,
    period.period_id,
	COUNT(*) AS all_outcome_count
FROM OmopCdm.synpuf5pct_20180710.cohorts_oskarg exposure
CROSS JOIN #period period
INNER JOIN OmopCdm.synpuf5pct_20180710.cohorts_oskarg outcome
	ON exposure.subject_id = outcome.subject_id
INNER JOIN OmopCdm.synpuf5pct_20180710.observation_period
	ON exposure.subject_id = observation_period.person_id
		AND exposure.cohort_start_date >= observation_period_start_date
		AND exposure.cohort_start_date <= observation_period_end_date
		AND outcome.subject_id = observation_period.person_id
		AND outcome.cohort_start_date >= observation_period_start_date
		AND outcome.cohort_start_date <= observation_period_end_date	
WHERE DATEADD(DAY, period.period_start, exposure.cohort_start_date) <= outcome.cohort_start_date
	AND DATEADD(DAY, period.period_end, exposure.cohort_start_date) >= outcome.cohort_start_date

	AND exposure.cohort_definition_id IN (42,22)
	

	AND outcome.cohort_definition_id IN (32)
	
GROUP BY outcome.cohort_definition_id,
    period.period_id
) b
    ON  a.outcome_id  = b.outcome_id
    AND a.period_id   = b.period_id;

