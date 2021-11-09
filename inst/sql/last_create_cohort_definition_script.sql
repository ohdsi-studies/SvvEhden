-- Creates the cohorts to be used in SVVEHDEN-sprint, according to the study protocol.

/*Input variables (sent from cohort-module)*/
-- These local variables are "rendered" by the R-script before execution.
-- the concept id for the drug of interest
-- the concept ids for comparator drugs (typically all drugs in the database)
-- concept ids for the outcome/event ID
-- the schema that will hold all cohorts
-- the table name where the final cohort tables will reside
-- the schema where the OMOP data is located
-- a limitation on the cohort size

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
IF OBJECT_ID('OmopCdm.mini.cohorts_Sarahe_original', 'U') IS NOT NULL
DROP TABLE OmopCdm.mini.cohorts_Sarahe_original;
CREATE TABLE OmopCdm.mini.cohorts_Sarahe_original (
  cohort_definition_id INT,
  cohort_start_date DATE,
  cohort_end_date DATE,
  subject_id BIGINT,
  drug_concept_id INT-- not needed in final table, but used during sampling
  )
  
---------------------------------------------------------------------------------------------
--- Insert all the rows with the exposure drug as cohort 21 and 22 --- 
-- (need to create the other cohorts before cohort 1, since 1 is build upon the other ones)
INSERT INTO OmopCdm.mini.cohorts_Sarahe_original (
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
FROM OmopCdm.mini.drug_era
WHERE drug_concept_id IN (974166);
  
INSERT INTO OmopCdm.mini.cohorts_Sarahe_original (
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
FROM OmopCdm.mini.drug_era
WHERE drug_concept_id IN (974166);

---------------------------------------------------------------------------------------------
--- Insert all the drugs in the database as cohort 4 ---
-- (need to create cohort 4 before 3, since 31 is build on cohort 4)
INSERT INTO OmopCdm.mini.cohorts_Sarahe_original (
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
FROM OmopCdm.mini.drug_era
WHERE drug_concept_id IN (735951,40161726,19045272,1548195,1518148,1331270,1549686,1237049,40161989,756349,40172423,937439,1702364,1151422,1174888,741530,932745,40161849,966991,40223294,1557272,997276,1308842,1707164,1549254,941258,745466,1759842,1301025,766814,734354,1301125,991382,40162204,40172778,1367571,1342439,40170416,1331235,1322081,40238145,903459,1319880,715997,719174,1594973,1502905,797617,923645,939506,1301065,918172,725131,1192710,1105889,1351115,1789276,1551673,40169509,713192,920293,901656,40170840,19093848,787787,1525278,1504620,915175,1153013,903963,1367500,1112807,924724,1353256,1338005,1525215,722031,963353,1134439,1503297,927478,836715,1710281,969444,1154161,1322184,1558242,740560,19049105,529411,1036228,1318137,1305058,924939,1343916,750982,794852,19077884,1592085,724816,40171301,1501700,1326303,917336,19069022,1353766,40161714,1514412,951511,723013,1195492,1124300,715233,19087090,957797,19044522,40162144,705944,992590,1511856,923081,19092849,950933,1360421,934262,1378509,1580747,1596977,950435,1729720,700299,1304643,904542,1716903,907553,751246,791967,1724869,1368671,932196,1304850,937368,1396131,945286,968426,950696,711452,1305637,738156,40173720,798874,907879,1592180,46221581,1308216,1129625,996541,1105775,1526475,915542,714684,40162070,19035704,722424,40226690,906780,739138,1168079,1114122,1397141,988294,1315942,733301,904453,40162170,1153664,529303,1362225,1334456,989482,911735,19013225,1549080,1318853,40172704,40175309,1703063,1313200,951469,1116031,1510202,917205,1337107,708298,778711,1742253,40161629,990009,950098,1836430,1521369,702865,1597756,40172441,904639,1560524,751412,40161944,1836948,705103,1703687,1717704,718122,40173211,922976,1036094,1554072,40169140,1769535,948787,798834,711584,704943,1518254,716968,1189490,1140640,913782,19011035,1837289,1350489,1636780,19067073,1332418,40162116,1383925,800878,701322,1516766,1749008,1000560,1341927,1377141,19046180,795113,904250,19036797,1550557,1363516,756018,40161781,1786621,1328165,757627,40175931,712615,1738366,996416,720727,1344905,766209,40161793,1308738,942799,1502855,19078092,740910,1502809,1000772,789578,1314002,1395058,742267,922570,931973,1000632,40174405,1724827,938268,1103314,40161467,778474,1551803,1750500,974166,904525,1710612,1728416,1705674,1551099,964339,909440,938205,40161976,743670,766529,1126128,923672,785788,1119510,19025274,902722,1341238,1123995,1152631,740275,907013,734275,1140088,1370109,1703069,989878,1717327,1781406,757352,1345858,713823,1501309,1177480,19021129,19036781,19095309,1342346,1110410,1363053,997881,1386957,932815,704984,1317640,955583,1346823,781039,19010309,940535,1140643,902616,1506270,1539403,1506602,1545958,19090761,1584910,967823,920458,991876,1583722,940426,1797513,915981,710062,1124957,40162251,1350504,1300978,792263,1137460,1102527,954853,1141018,986417,1188114,1551860,755695,1307046,40161593,1344965,1125315,1149196,705178,1138050,778268,1704183,718583,1715472,1762711,40226762,40226742,961047,749910,1118084,727835,919204,1760616,1510813,956874,902427,918906,1754994,40161730,970250,1351557,1143374,1595799,703547,1103640,1738521,1310149,751347,914335,1154343,975125,1746244,1314577,1126658,19084212,1335471,40161914,1305447,1396012,977968,1135766,988095,905273,1398937,1103518,934075,955632,1351541,1130863,745268,1552929,1195334,733523,1307863,1178663,1559684,1115572,953076,1701928,990760,1768849,748010,1713332,917006,994341,1714165,1115008,948078,1167322,966956,19086176,1517998,40170444,1707687,1711523,1547504,905531,40167733,929435,1185922,19117912,1771162,721724,797399,1560171,711714,1154332,1836503,1201620,1777806,939259,1139699,715458,906149,40170553,1560305,1188052,19015230,1154029,1113648,1340128,40161167,1500211,40169482,735979,40161785,985708,1363749,1758536,19020477,836208,1101554,1746940,19020002,1236493,1361711,1383815,1373928,979096,1163944,1136980,1112921,920378,929887,777221,40172250,953391,950637,1505346,735850,733008,1149380,1757803,715939,1314924,1308432,1118045,1351461);
  
INSERT INTO OmopCdm.mini.cohorts_Sarahe_original (
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
FROM OmopCdm.mini.drug_era
WHERE drug_concept_id IN (735951,40161726,19045272,1548195,1518148,1331270,1549686,1237049,40161989,756349,40172423,937439,1702364,1151422,1174888,741530,932745,40161849,966991,40223294,1557272,997276,1308842,1707164,1549254,941258,745466,1759842,1301025,766814,734354,1301125,991382,40162204,40172778,1367571,1342439,40170416,1331235,1322081,40238145,903459,1319880,715997,719174,1594973,1502905,797617,923645,939506,1301065,918172,725131,1192710,1105889,1351115,1789276,1551673,40169509,713192,920293,901656,40170840,19093848,787787,1525278,1504620,915175,1153013,903963,1367500,1112807,924724,1353256,1338005,1525215,722031,963353,1134439,1503297,927478,836715,1710281,969444,1154161,1322184,1558242,740560,19049105,529411,1036228,1318137,1305058,924939,1343916,750982,794852,19077884,1592085,724816,40171301,1501700,1326303,917336,19069022,1353766,40161714,1514412,951511,723013,1195492,1124300,715233,19087090,957797,19044522,40162144,705944,992590,1511856,923081,19092849,950933,1360421,934262,1378509,1580747,1596977,950435,1729720,700299,1304643,904542,1716903,907553,751246,791967,1724869,1368671,932196,1304850,937368,1396131,945286,968426,950696,711452,1305637,738156,40173720,798874,907879,1592180,46221581,1308216,1129625,996541,1105775,1526475,915542,714684,40162070,19035704,722424,40226690,906780,739138,1168079,1114122,1397141,988294,1315942,733301,904453,40162170,1153664,529303,1362225,1334456,989482,911735,19013225,1549080,1318853,40172704,40175309,1703063,1313200,951469,1116031,1510202,917205,1337107,708298,778711,1742253,40161629,990009,950098,1836430,1521369,702865,1597756,40172441,904639,1560524,751412,40161944,1836948,705103,1703687,1717704,718122,40173211,922976,1036094,1554072,40169140,1769535,948787,798834,711584,704943,1518254,716968,1189490,1140640,913782,19011035,1837289,1350489,1636780,19067073,1332418,40162116,1383925,800878,701322,1516766,1749008,1000560,1341927,1377141,19046180,795113,904250,19036797,1550557,1363516,756018,40161781,1786621,1328165,757627,40175931,712615,1738366,996416,720727,1344905,766209,40161793,1308738,942799,1502855,19078092,740910,1502809,1000772,789578,1314002,1395058,742267,922570,931973,1000632,40174405,1724827,938268,1103314,40161467,778474,1551803,1750500,974166,904525,1710612,1728416,1705674,1551099,964339,909440,938205,40161976,743670,766529,1126128,923672,785788,1119510,19025274,902722,1341238,1123995,1152631,740275,907013,734275,1140088,1370109,1703069,989878,1717327,1781406,757352,1345858,713823,1501309,1177480,19021129,19036781,19095309,1342346,1110410,1363053,997881,1386957,932815,704984,1317640,955583,1346823,781039,19010309,940535,1140643,902616,1506270,1539403,1506602,1545958,19090761,1584910,967823,920458,991876,1583722,940426,1797513,915981,710062,1124957,40162251,1350504,1300978,792263,1137460,1102527,954853,1141018,986417,1188114,1551860,755695,1307046,40161593,1344965,1125315,1149196,705178,1138050,778268,1704183,718583,1715472,1762711,40226762,40226742,961047,749910,1118084,727835,919204,1760616,1510813,956874,902427,918906,1754994,40161730,970250,1351557,1143374,1595799,703547,1103640,1738521,1310149,751347,914335,1154343,975125,1746244,1314577,1126658,19084212,1335471,40161914,1305447,1396012,977968,1135766,988095,905273,1398937,1103518,934075,955632,1351541,1130863,745268,1552929,1195334,733523,1307863,1178663,1559684,1115572,953076,1701928,990760,1768849,748010,1713332,917006,994341,1714165,1115008,948078,1167322,966956,19086176,1517998,40170444,1707687,1711523,1547504,905531,40167733,929435,1185922,19117912,1771162,721724,797399,1560171,711714,1154332,1836503,1201620,1777806,939259,1139699,715458,906149,40170553,1560305,1188052,19015230,1154029,1113648,1340128,40161167,1500211,40169482,735979,40161785,985708,1363749,1758536,19020477,836208,1101554,1746940,19020002,1236493,1361711,1383815,1373928,979096,1163944,1136980,1112921,920378,929887,777221,40172250,953391,950637,1505346,735850,733008,1149380,1757803,715939,1314924,1308432,1118045,1351461);  

---------------------------------------------------------------------------------------------
--- Insert all the rows with the outcome as cohort 31 and 32 --- 
INSERT INTO OmopCdm.mini.cohorts_Sarahe_original (
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
              FROM OmopCdm.mini.condition_era CE
			   -- cohort 31: require a drug (any drug) to match risk window: this inner join makes sure the condition_era do have a preceding
			   --            drug withing the 30 day risk window
              INNER JOIN OmopCdm.mini.cohorts_Sarahe_original D ON D.subject_id = CE.person_id AND
                                                                             D.cohort_definition_id = 41 AND
 	             														     DATEDIFF(DAY, D.cohort_start_date, CE.condition_era_start_date) <= 30 AND 
 	             														     DATEDIFF(DAY, D.cohort_start_date, CE.condition_era_start_date) > 0 
              WHERE condition_concept_id IN ( SELECT descendant_concept_id
                                              FROM OmopCdm.mini.concept_ancestor
                                              WHERE ancestor_concept_id IN (201826) )  
     ) T1
--WHERE row_number = 1 -- select every reaction one time only (randomly select drug_start if more than one)

INSERT INTO OmopCdm.mini.cohorts_Sarahe_original (
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
       FROM OmopCdm.mini.condition_era
       WHERE condition_concept_id IN ( SELECT descendant_concept_id
                                       FROM OmopCdm.mini.concept_ancestor
                                       WHERE ancestor_concept_id IN (201826) )  
     ) T1

---------------------------------------------------------------------------------------------
--  Now create cohort 11 

INSERT INTO OmopCdm.mini.cohorts_Sarahe_original(
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
FROM OmopCdm.mini.cohorts_Sarahe_original D
INNER JOIN OmopCdm.mini.cohorts_Sarahe_original R ON D.subject_id = R.subject_id AND 
                                                               D.cohort_definition_id = 21 AND 
                                                               R.cohort_definition_id = 31 AND 
                                                               DATEDIFF(DAY, D.cohort_start_date, R.cohort_start_date) <= 30 AND 
                                                               DATEDIFF(DAY, D.cohort_start_date, R.cohort_start_date) > 0 
															   
---------------------------------------------------------------------------------------------
-- Initiate the table that will hold the final sampled cohorts
IF OBJECT_ID('OmopCdm.mini.cohorts_Sarahe', 'U') IS NOT NULL 
DROP TABLE OmopCdm.mini.cohorts_Sarahe;
CREATE TABLE OmopCdm.mini.cohorts_Sarahe (
  cohort_definition_id INT,
  cohort_start_date DATE,
  cohort_end_date DATE,
  subject_id BIGINT,
  row_number INT)

---------------------------------------------------------------------------------------------
-- Apply the sampling on the original-table to create the final one
INSERT INTO OmopCdm.mini.cohorts_Sarahe(
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
                            FROM OmopCdm.mini.cohorts_Sarahe_original
                          ) T1
                     WHERE one_row_per_person_and_drug_row_number = 1 -- take the first row of each subject_id-drug_concept_id-cohort_definition_id-combination = random row.
		       	) T2
            ) T3
       WHERE one_row_per_person_row_number = 1 -- and take the first row of each subject_id-cohort_definition_id-combination = random row.
             OR cohort_definition_id IN (32)   -- do not sample the reaction cohort for chronographs
     ) T4
WHERE cohort_definition_id in (22, 32, 42) OR maximum_cohort_size_row_number <= 50 -- restrict to cohort sample size for descriptive-tables cohorts

