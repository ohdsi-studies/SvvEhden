{DEFAULT @cohort_database_schema = ''}

SELECT exposed.period_id, exposed_count, comparator_count, outcome_count, comparator_outcome_count FROM @cohort_database_schema.exp_ICTPD exposed 
LEFT JOIN @cohort_database_schema.comp_ICTPD comparator ON exposed.period_id = comparator.period_id
LEFT JOIN @cohort_database_schema.exp_out_ICTPD exposed_o ON exposed.period_id = exposed_o.period_id
LEFT JOIN @cohort_database_schema.comp_out_ICTPD comparator_o ON exposed.period_id = comparator_o.period_id
ORDER BY exposed.PERIOD_ID DESC