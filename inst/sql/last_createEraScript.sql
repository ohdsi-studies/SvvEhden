/****************************************************
OHDSI-SQL File Instructions
-----------------------------
 1. Set parameter name of schema that contains CDMv4 instance
    (@SOURCE_CDMV4, @SOURCE_CDMV4_SCHEMA)
 2. Set parameter name of schema that contains CDMv5 instance
    ([CDM], main)
 3. Run this script through SqlRender to produce a script that will work in your
    source dialect. SqlRender can be found here: https://github.com/OHDSI/SqlRender
 4. Run the script produced by SQL Render on your target RDBDMS.
<RDBMS> File Instructions
-------------------------
 1. This script will hold a number of placeholders for your CDM V4 and CDMV5
    database/schema. In order to make this file work in your environment, you
    should plan to do a global "FIND AND REPLACE" on this file to fill in the
    file with values that pertain to your environment. The following are the
    tokens you should use when doing your "FIND AND REPLACE" operation:
    
     [CDM]
     [CDM].[CDMSCHEMA]
    
*********************************************************************************/
/* SCRIPT PARAMETERS */

    
--    -- The target CDMv5 database name
    -- the target CDMv5 database plus schema
--	Not currently used
	--USE [CDM];

DROP TABLE IF EXISTS main.drug_era_pw390;

/****
DRUG ERA
Note: Eras derived from DRUG_EXPOSURE table, using 390 gap
 ****/
DROP TABLE IF EXISTS temp.cteDrugTarget;

/* / */

-- Normalize DRUG_EXPOSURE_END_DATE to either the existing drug exposure end date, or add days supply, or add 1 day to the start date
CREATE TEMP TABLE cteDrugTarget

AS
SELECT
d.DRUG_EXPOSURE_ID
    ,d.PERSON_ID
    ,c.CONCEPT_ID
    ,d.DRUG_TYPE_CONCEPT_ID
    ,DRUG_EXPOSURE_START_DATE
    ,COALESCE(DRUG_EXPOSURE_END_DATE, CAST(STRFTIME('%s', DATETIME(DRUG_EXPOSURE_START_DATE, 'unixepoch', (DAYS_SUPPLY)||' days')) AS REAL), CAST(STRFTIME('%s', DATETIME(DRUG_EXPOSURE_START_DATE, 'unixepoch', (1)||' days')) AS REAL)) AS DRUG_EXPOSURE_END_DATE
    ,c.CONCEPT_ID AS INGREDIENT_CONCEPT_ID

FROM
main.DRUG_EXPOSURE d
INNER JOIN main.CONCEPT_ANCESTOR ca ON ca.DESCENDANT_CONCEPT_ID = d.DRUG_CONCEPT_ID
INNER JOIN main.CONCEPT c ON ca.ANCESTOR_CONCEPT_ID = c.CONCEPT_ID
WHERE c.DOMAIN_ID = 'Drug'
    AND c.CONCEPT_CLASS_ID = 'Ingredient';
ANALYZE cteDrugTarget
;

/* / */

DROP TABLE IF EXISTS temp.cteEndDates;

/* / */

CREATE TEMP TABLE cteEndDates

AS
SELECT
PERSON_ID
    ,INGREDIENT_CONCEPT_ID
    ,CAST(STRFTIME('%s', DATETIME(EVENT_DATE, 'unixepoch', (- 390)||' days')) AS REAL) AS END_DATE -- unpad the end date

FROM
(
    SELECT E1.PERSON_ID
        ,E1.INGREDIENT_CONCEPT_ID
        ,E1.EVENT_DATE
        ,COALESCE(E1.START_ORDINAL, MAX(E2.START_ORDINAL)) START_ORDINAL
        ,E1.OVERALL_ORD
    FROM (
        SELECT PERSON_ID
            ,INGREDIENT_CONCEPT_ID
            ,EVENT_DATE
            ,EVENT_TYPE
            ,START_ORDINAL
            ,ROW_NUMBER() OVER (
                PARTITION BY PERSON_ID
                ,INGREDIENT_CONCEPT_ID ORDER BY EVENT_DATE
                    ,EVENT_TYPE
                ) AS OVERALL_ORD -- this re-numbers the inner UNION so all rows are numbered ordered by the event date
        FROM (
            -- select the start dates, assigning a row number to each
            SELECT PERSON_ID
                ,INGREDIENT_CONCEPT_ID
                ,DRUG_EXPOSURE_START_DATE AS EVENT_DATE
                ,0 AS EVENT_TYPE
                ,ROW_NUMBER() OVER (
                    PARTITION BY PERSON_ID
                    ,INGREDIENT_CONCEPT_ID ORDER BY DRUG_EXPOSURE_START_DATE
                    ) AS START_ORDINAL
            FROM temp.cteDrugTarget

            UNION ALL

            -- add the end dates with NULL as the row number, padding the end dates by 30 to allow a grace period for overlapping ranges.
            SELECT PERSON_ID
                ,INGREDIENT_CONCEPT_ID
                ,CAST(STRFTIME('%s', DATETIME(DRUG_EXPOSURE_END_DATE, 'unixepoch', (390)||' days')) AS REAL)
                ,1 AS EVENT_TYPE
                ,NULL
            FROM temp.cteDrugTarget
            ) RAWDATA
        ) E1
    INNER JOIN (
        SELECT PERSON_ID
            ,INGREDIENT_CONCEPT_ID
            ,DRUG_EXPOSURE_START_DATE AS EVENT_DATE
            ,ROW_NUMBER() OVER (
                PARTITION BY PERSON_ID
                ,INGREDIENT_CONCEPT_ID ORDER BY DRUG_EXPOSURE_START_DATE
                ) AS START_ORDINAL
        FROM temp.cteDrugTarget
        ) E2 ON E1.PERSON_ID = E2.PERSON_ID
        AND E1.INGREDIENT_CONCEPT_ID = E2.INGREDIENT_CONCEPT_ID
        AND E2.EVENT_DATE <= E1.EVENT_DATE
    GROUP BY E1.PERSON_ID
        ,E1.INGREDIENT_CONCEPT_ID
        ,E1.EVENT_DATE
        ,E1.START_ORDINAL
        ,E1.OVERALL_ORD
    ) E
WHERE 2 * E.START_ORDINAL - E.OVERALL_ORD = 0;
ANALYZE cteEndDates
;

/* / */

DROP TABLE IF EXISTS temp.cteDrugExpEnds;

/* / */

CREATE TEMP TABLE cteDrugExpEnds

AS
SELECT
d.PERSON_ID
    ,d.INGREDIENT_CONCEPT_ID
    ,d.DRUG_TYPE_CONCEPT_ID
    ,d.DRUG_EXPOSURE_START_DATE
    ,MIN(e.END_DATE) AS ERA_END_DATE

FROM
temp.cteDrugTarget d
INNER JOIN temp.cteEndDates e ON d.PERSON_ID = e.PERSON_ID
    AND d.INGREDIENT_CONCEPT_ID = e.INGREDIENT_CONCEPT_ID
    AND e.END_DATE >= d.DRUG_EXPOSURE_START_DATE
GROUP BY d.PERSON_ID
    ,d.INGREDIENT_CONCEPT_ID
    ,d.DRUG_TYPE_CONCEPT_ID
    ,d.DRUG_EXPOSURE_START_DATE;
ANALYZE cteDrugExpEnds
;

/* / */

CREATE TABLE main.drug_era_pw390  AS
SELECT
* 
FROM
(SELECT row_number() OVER (
        ORDER BY person_id
        ) AS drug_era_id
    ,person_id
    ,INGREDIENT_CONCEPT_ID as drug_concept_id
    ,min(DRUG_EXPOSURE_START_DATE) AS drug_era_start_date
    ,ERA_END_DATE as drug_era_end_date
    ,COUNT(*) AS drug_exposure_count
    ,390 AS gap_days
FROM temp.cteDrugExpEnds
GROUP BY person_id
    ,INGREDIENT_CONCEPT_ID
    ,drug_type_concept_id
    ,ERA_END_DATE) A;
    
-------------------------------------------------------------------------

/* CURRENTLY NOT USED /Oskar
CONDITION ERA
Note: Eras derived from CONDITION_OCCURRENCE table, using 30d gap

IF OBJECT_ID('tempdb..#condition_era_phase_1', 'U') IS NOT NULL
    DROP TABLE #condition_era_phase_1;

IF OBJECT_ID('tempdb..#cteConditionTarget', 'U') IS NOT NULL
    DROP TABLE #cteConditionTarget;

-- create base eras from the concepts found in condition_occurrence
SELECT co.PERSON_ID
    ,co.condition_concept_id
    ,co.CONDITION_START_DATE
    ,COALESCE(co.CONDITION_END_DATE, DATEADD(day, 1, CONDITION_START_DATE)) AS CONDITION_END_DATE
INTO #cteConditionTarget
FROM main.CONDITION_OCCURRENCE co;


IF OBJECT_ID('tempdb..#cteCondEndDates', 'U') IS NOT NULL
    DROP TABLE #cteCondEndDates;

SELECT PERSON_ID
    ,CONDITION_CONCEPT_ID
    ,DATEADD(day, - 390, EVENT_DATE) AS END_DATE -- unpad the end date
INTO #cteCondEndDates
FROM (
    SELECT E1.PERSON_ID
        ,E1.CONDITION_CONCEPT_ID
        ,E1.EVENT_DATE
        ,COALESCE(E1.START_ORDINAL, MAX(E2.START_ORDINAL)) START_ORDINAL
        ,E1.OVERALL_ORD
    FROM (
        SELECT PERSON_ID
            ,CONDITION_CONCEPT_ID
            ,EVENT_DATE
            ,EVENT_TYPE
            ,START_ORDINAL
            ,ROW_NUMBER() OVER (
                PARTITION BY PERSON_ID
                ,CONDITION_CONCEPT_ID ORDER BY EVENT_DATE
                    ,EVENT_TYPE
                ) AS OVERALL_ORD -- this re-numbers the inner UNION so all rows are numbered ordered by the event date
        FROM (
            -- select the start dates, assigning a row number to each
            SELECT PERSON_ID
                ,CONDITION_CONCEPT_ID
                ,CONDITION_START_DATE AS EVENT_DATE
                ,- 1 AS EVENT_TYPE
                ,ROW_NUMBER() OVER (
                    PARTITION BY PERSON_ID
                    ,CONDITION_CONCEPT_ID ORDER BY CONDITION_START_DATE
                    ) AS START_ORDINAL
            FROM #cteConditionTarget

            UNION ALL

            -- pad the end dates by 30 to allow a grace period for overlapping ranges.
            SELECT PERSON_ID
                ,CONDITION_CONCEPT_ID
                ,DATEADD(day, 390, CONDITION_END_DATE)
                ,1 AS EVENT_TYPE
                ,NULL
            FROM #cteConditionTarget
            ) RAWDATA
        ) E1
    INNER JOIN (
        SELECT PERSON_ID
            ,CONDITION_CONCEPT_ID
            ,CONDITION_START_DATE AS EVENT_DATE
            ,ROW_NUMBER() OVER (
                PARTITION BY PERSON_ID
                ,CONDITION_CONCEPT_ID ORDER BY CONDITION_START_DATE
                ) AS START_ORDINAL
        FROM #cteConditionTarget
        ) E2 ON E1.PERSON_ID = E2.PERSON_ID
        AND E1.CONDITION_CONCEPT_ID = E2.CONDITION_CONCEPT_ID
        AND E2.EVENT_DATE <= E1.EVENT_DATE
    GROUP BY E1.PERSON_ID
        ,E1.CONDITION_CONCEPT_ID
        ,E1.EVENT_DATE
        ,E1.START_ORDINAL
        ,E1.OVERALL_ORD
    ) E
WHERE (2 * E.START_ORDINAL) - E.OVERALL_ORD = 0;


IF OBJECT_ID('tempdb..#cteConditionEnds', 'U') IS NOT NULL
    DROP TABLE #cteConditionEnds;


SELECT c.PERSON_ID
    ,c.CONDITION_CONCEPT_ID
    ,c.CONDITION_START_DATE
    ,MIN(e.END_DATE) AS ERA_END_DATE
INTO #cteConditionEnds
FROM #cteConditionTarget c
INNER JOIN #cteCondEndDates e ON c.PERSON_ID = e.PERSON_ID
    AND c.CONDITION_CONCEPT_ID = e.CONDITION_CONCEPT_ID
    AND e.END_DATE >= c.CONDITION_START_DATE
GROUP BY c.PERSON_ID
    ,c.CONDITION_CONCEPT_ID
    ,c.CONDITION_START_DATE;

SELECT * INTO main.condition_era FROM
(SELECT row_number() OVER (
        ORDER BY person_id
        ) AS condition_era_id
    ,person_id
    ,CONDITION_CONCEPT_ID as condition_concept_id
    ,min(CONDITION_START_DATE) AS condition_era_start_date
    ,ERA_END_DATE AS condition_era_end_date
    ,COUNT(*) AS condition_occurence_count
FROM #cteConditionEnds
GROUP BY person_id
    ,CONDITION_CONCEPT_ID
    ,ERA_END_DATE) A;


--USE [CDM];

*/



