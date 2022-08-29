-- return all the drug cohorts to be used to construct the json file

select distinct * from
(
  SELECT distinct C.concept_id, C.concept_code, C.concept_name
  FROM @cdm_database_schema.drug_exposure DE
  INNER JOIN @cdm_database_schema.concept C ON C.concept_id = DE.drug_concept_id 
  where C.concept_id != 0 and
        C.vocabulary_id = 'RxNorm' and C.concept_class_id = 'Ingredient' and C.standard_concept  ='S' and C.invalid_reason is null

union

  SELECT distinct C.concept_id, C.concept_code, C.concept_name
  FROM @cdm_database_schema.drug_exposure DE
  INNER JOIN @cdm_database_schema.CONCEPT_ANCESTOR CA ON CA.descendant_concept_id = DE.drug_concept_id 
  INNER JOIN @cdm_database_schema.concept C ON C.concept_id = CA.ancestor_concept_id
  where C.concept_id != 0 and
        C.vocabulary_id = 'RxNorm' and C.concept_class_id = 'Ingredient' and C.standard_concept  ='S' and C.invalid_reason is null
) U
