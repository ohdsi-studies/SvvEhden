########################################################################
# table1_module: A function that takes cohorts from cohort_module and produces
# descriptive tables (demographics, comeds, conditions)
#   i: The index variable in the for-loop.
#   cohort_list:  contains studyPopulation, cohortMethodData, cohort1, cohort2, cohort3, cohort4
# 
#   output:  list("basic_demographics_table" = basic_demographics_table
#             "top_drugs_table" = top_drugs_table
#             "top_conditions_table" = top_conditions_table
#             "km_graph" = kaplan_meier_output
#             "cox_summary" = raw_cox_output
#             "time_to_event" = time_to_event_output
#             "table_1_output" = table_1_output
#             "table_2_output" = table_2_output
#             "gender_cohort_plot" = gender_cohort_plot
#             "age_cohort_plot" = age_cohort_plot

########################################################################
table1_module <- function(i, cohort_list, saddle){
  
  # tic("Descriptive tables module")
  
  #  Unpack the input
  verbose <- saddle$overall_verbose
  # descriptive_cohort_counts <- cohort_list[[7]] %>% dplyr::filter(COHORT_DEFINITION_ID %in% c(11, 21,31, 41)) %>% dplyr::pull(N) 
  
  zeallot::`%<-%`(c(studyPopulation, cohortMethodData, cohort1, cohort2, cohort3, cohort4), cohort_list)
  internal_cohort_list = c(cohort1, cohort2, cohort3, cohort4)
  
  # # Add consistent output cohort names
  zeallot::`%<-%`(c(drug_event_cohort_name, drug_cohort_name, comp_drugs_with_event_cohort_name,  comp_drugs_cohort_name),
                  c("Target drug + event", "Target drug", "Comp. drugs with event", "Comp. drugs"))
  name_vector = c(drug_event_cohort_name, drug_cohort_name, comp_drugs_with_event_cohort_name, comp_drugs_cohort_name)
  
  
  covariates_for_cohort1 <- as.data.frame(cohort1$covariates)
  covariateRef_for_cohort1 <- as.data.frame(cohort1$covariateRef)
  covariates_for_cohort1 %<>% 
    dplyr::rename(subject_id = rowId) %>% 
    dplyr::left_join(covariateRef_for_cohort1, by="covariateId") %>% 
    dplyr::select(subject_id, name=covariateName, value=covariateValue, concept_id = conceptId)
  covariates_for_cohort1$cohort = 1
  
  covariates_for_cohort2 <- as.data.frame(cohort2$covariates)
  covariateRef_for_cohort2 <- as.data.frame(cohort2$covariateRef)
  covariates_for_cohort2 %<>% 
    dplyr::rename(subject_id = rowId) %>% 
    dplyr::left_join(covariateRef_for_cohort2, by="covariateId") %>% 
    dplyr::select(subject_id, name=covariateName, value=covariateValue, concept_id = conceptId)
  covariates_for_cohort2$cohort = 2
  
  covariates_for_cohort3 <- as.data.frame(cohort3$covariates)
  covariateRef_for_cohort3 <- as.data.frame(cohort3$covariateRef)
  covariates_for_cohort3 %<>% 
    dplyr::rename(subject_id = rowId) %>% 
    dplyr::left_join(covariateRef_for_cohort3, by="covariateId") %>% 
    dplyr::select(subject_id, name=covariateName, value=covariateValue, concept_id = conceptId)
  covariates_for_cohort3$cohort = 3
  
  covariates_for_cohort4 <- as.data.frame(cohort4$covariates)
  covariateRef_for_cohort4 <- as.data.frame(cohort4$covariateRef)
  covariates_for_cohort4 %<>% 
    dplyr::rename(subject_id = rowId) %>% 
    dplyr::left_join(covariateRef_for_cohort4, by="covariateId") %>% 
    dplyr::select(subject_id, name=covariateName, value=covariateValue, concept_id = conceptId)
  covariates_for_cohort4$cohort = 4
  
  covariates_for_cohort_i = list(covariates_for_cohort1, covariates_for_cohort2, covariates_for_cohort3, covariates_for_cohort4)
  covariate_for_cohorts_allInOne <- dplyr::bind_rows(covariates_for_cohort1, covariates_for_cohort2, covariates_for_cohort3, covariates_for_cohort4)
  
  ########################
  # Demographics
  ########################
  if(verbose) { 
    print("Summarizing demographics table") 
  }
  
  # There doesn't seem to be gender in the Eunomia-database, only a few "gender=Unknown concept" so we set the gender-string to that, just to make it run:  
  if(length(which_database)!= 0){
    if(which_database == "sql server"){
      gender_string = c("gender = FEMALE", "gender = MALE")
    } else if (which_database == "sqlite"){
      gender_string = c("gender = Unknown concept")
    }
  } else {gender_string = c("gender = FEMALE", "gender = MALE")}
  
  gender_cohort_plot = interactive_barplot(internal_cohort_list, name_vector, gender_string)


for(i in 1:4) {
  
  # i=1
  covariates_for_cohort = covariates_for_cohort_i[i][[1]]
  
  gender_table <- covariates_for_cohort %>% dplyr::filter(name %in% c(gender_string)) %>% dplyr::count(name) %>% dplyr::mutate(Percentage=round(100*n/sum(n)))
  colnames(gender_table)=c(name_vector[i],"n","Percentage")
  final_gender_table <- suppressMessages(dplyr::bind_cols(c("Sex", rep("", nrow(gender_table)-1)), gender_table))
  colnames(final_gender_table)=c(" ", "Category","n","Percentage")
  final_gender_table$n <- as.character(final_gender_table$n)
  final_gender_table$Percentage <- as.character(final_gender_table$Percentage)
  
  # Age at cohort_entry
  age_quantiles <- covariates_for_cohort %>% dplyr::filter(name %in% "age in years") %>% dplyr::pull(value) %>%  quantile(c(0.5, 0.25, 0.75)) 
  age_quantiles <- c("Median", age_quantiles[1], paste0( "IQR=(",paste0(round(age_quantiles[2:3]), collapse=", "),")")) 
  names(age_quantiles) = NULL
  age_table <- covariates_for_cohort %>% dplyr::filter(name %in% "age in years") %>% 
    mutate(age = cut(value, breaks=c(0, seq(20, 90, by=10), 110))) %>% pull(age) %>% table() 
  age_perc <- round(age_table %>% prop.table()*100)
  age_groups <- cbind.data.frame(as.data.frame(age_table), as.data.frame(age_perc)[,2])
  colnames(age_groups)=c("Category", "n", "Percentage")
  names(age_quantiles) = names(age_groups)
  age_groups$n <- as.character(age_groups$n) 
  age_groups$Percentage <- as.character(age_groups$Percentage)
  final_age_table <- dplyr::bind_rows(age_groups, age_quantiles) 
  final_age_table <- suppressMessages(dplyr::bind_cols(c("Age", rep("", nrow(final_age_table)-1)), final_age_table))
  colnames(final_age_table)=c(" ", "Category","n","Percentage")
  
  basic_demographics_table_single <- invisible(dplyr::bind_rows(final_gender_table, final_age_table))#, final_state_table)
  basic_demographics_table_single <- rbind.data.frame(c("","Total", length(unique(covariates_for_cohort$subject_id)), "100"),
                                                      basic_demographics_table_single)
  colnames(basic_demographics_table_single) = c(" ", name_vector[i][[1]],"n","Percentage")
  
  if(i == 1) {
    basic_demographics_table = basic_demographics_table_single
  } else {
    basic_demographics_table = cbind(basic_demographics_table, basic_demographics_table_single)
  }
}

##########################################
# Top comedications and conditions
##########################################
if(verbose) { print("Summarizing comed- and conditions- table") }

# alt 1: drop concept id:s  before the destinct below
# alt 2: display concept_ids

covariate_for_tables <- covariate_for_cohorts_allInOne
covariate_for_tables <- subset(covariate_for_tables, select=c("subject_id", "name", "value", "cohort")) %>% dplyr::mutate(name=tolower(name)) #alt 1, remove for alt 2
covariate_for_tables <- dplyr::distinct(covariate_for_tables) # distinct not count any subject twice

covariate_for_tables %<>% tidyr::separate(name, c("time","name"), ":")
covariate_for_tables$name[is.na(covariate_for_tables$name)] <- covariate_for_tables$time[is.na(covariate_for_tables$name)]
covariate_for_tables %<>% tidyr::separate(time, c("type","time"), "_")
covariate_for_tables$time[is.na(covariate_for_tables$time)] <- covariate_for_tables$type[is.na(covariate_for_tables$time)]

for(i in 1:4) {
  no_of_subjects = length(dplyr::distinct(subset(covariate_for_tables %>% dplyr::filter(cohort == i), select=c("subject_id")))$subject_id)
  count_name <- paste0("Count ", name_vector[i])
  perc_name <- paste0("Percentage ", name_vector[i])
  
  top_drugs_table_i <- covariate_for_tables %>% 
    dplyr::filter(type %in% "drug" & time == "era group during day -180 through -1 days relative to index" & cohort == i) %>%
    #dplyr::mutate(name=tolower(paste0(name, " (", concept_id ,")"))) %>% #add back in for alt 2
    dplyr::count(name) %>% 
    dplyr::arrange(desc(n)) %>% 
    dplyr::mutate(Percentage=round(100*n/no_of_subjects)) %>% 
    setNames(c("Co-medications 1-180 days prior", count_name, perc_name)) 
  
  top_conditions_table_i <- covariate_for_tables %>% 
    dplyr::filter(type %in% "condition" & time == "era group during day -180 through -1 days relative to index" & cohort == i) %>%
    #dplyr::mutate(name=tolower(paste0(name, " (", concept_id ,")"))) %>%  #add back in for alt 2
    dplyr::count(name) %>% 
    dplyr::arrange(desc(n)) %>% 
    dplyr::mutate(Percentage=round(100*n/no_of_subjects)) %>% 
    setNames(c("Co-conditions 1-180 days prior", count_name, perc_name))
  
  if(i == 1){
    top_drugs_table = top_drugs_table_i
    top_conditions_table = top_conditions_table_i
  } else {
    top_drugs_table = merge(top_drugs_table, top_drugs_table_i, by = "Co-medications 1-180 days prior")
    top_conditions_table = merge(top_conditions_table, top_conditions_table_i, by = "Co-conditions 1-180 days prior")
  }  
  
}

top_drugs_table = DT::datatable(top_drugs_table, rownames= FALSE, options = list(order = list(1, 'desc')))
top_conditions_table = DT::datatable(top_conditions_table, rownames= FALSE, options = list(order = list(1, 'desc')))

##########################################
# Look at outcomes
##########################################

table_1_output = data.frame()
table_2_output = data.frame()
table_3_output = data.frame()

# Fetch custom aggregations used:
agg1 = custom_aggregateCovariates(cohort1)
agg2 = custom_aggregateCovariates(cohort2)
agg3 = custom_aggregateCovariates(cohort3)
agg4 = custom_aggregateCovariates(cohort4)

## Compare two cohorts drug+event (1) and drug (2)
if(verbose) { print("cohort 1 vs 2 table") }
#standardized_mean_comparison_table  <- computeStandardizedDifference(cohort1a, cohort2)
table_1_output <- FeatureExtraction::createTable1(covariateData1 = custom_aggregateCovariates(cohort2), 
                                                  covariateData2 = custom_aggregateCovariates(cohort1),
                                                  specifications = FeatureExtraction::getDefaultTable1Specifications(),
                                                  output = "two columns",
                                                  showCounts = FALSE,
                                                  showPercent = TRUE,
                                                  percentDigits = 1,
                                                  valueDigits = 1,
                                                  stdDiffDigits = 1)
# table_1_output <-  table1_two_cohorts # print(table1_two_cohorts, row.names = FALSE, right = FALSE)

## Compare two cohorts drug+event (1) and event (3)
#if(verbose) { print("cohort 1 vs 3 table") }
#standardized_mean_comparison_table  <- computeStandardizedDifference(cohort1b, cohort3)
#table_2_output <- FeatureExtraction::createTable1(covariateData1 = custom_aggregateCovariates(cohort1), 
#                               covariateData2 = custom_aggregateCovariates(cohort3),
#                               specifications = FeatureExtraction::getDefaultTable1Specifications(),
#                               output = "two columns",
#                               showCounts = FALSE,
#                               showPercent = TRUE,
#                               percentDigits = 1,
#                               valueDigits = 1,
#                               stdDiffDigits = 2)
# table_2_output <- table2_two_cohorts #print(table2_two_cohorts, row.names = FALSE, right = FALSE))

if(verbose) { print("cohort 3 vs 4 table") }
#standardized_mean_comparison_table  <- computeStandardizedDifference(cohort1a, cohort2)
table_2_output <- FeatureExtraction::createTable1(covariateData1 = agg4, 
                                                  covariateData2 = agg3,
                                                  specifications = FeatureExtraction::getDefaultTable1Specifications(),
                                                  output = "two columns",
                                                  showCounts = FALSE,
                                                  showPercent = TRUE,
                                                  percentDigits = 1,
                                                  valueDigits = 1,
                                                  stdDiffDigits = 1)



if(verbose) { print("cohort 2 vs 4 table") }
#standardized_mean_comparison_table  <- computeStandardizedDifference(cohort1a, cohort2)
table_3_output <- FeatureExtraction::createTable1(covariateData1 = agg4, 
                                                  covariateData2 = agg2,
                                                  specifications = FeatureExtraction::getDefaultTable1Specifications(),
                                                  output = "two columns",
                                                  showCounts = FALSE,
                                                  showPercent = TRUE,
                                                  percentDigits = 1,
                                                  valueDigits = 1,
                                                  stdDiffDigits = 1)

# if(verbose) { print("Summarizing kaplan meier plot") }
# kaplan_meier_output <- plotKaplanMeier(studyPopulation, includeZero = FALSE)
# 
# if(verbose) { print("Summarizing raw cox table") }
# raw_cox_output <- fitOutcomeModel(population = studyPopulation,
#                                   modelType = "cox")
# 
# if(verbose) { print("Summarizing time to event plot") }
# time_to_event_output <- plotTimeToEvent(cohortMethodData = cohortMethodData,
#                                         outcomeId = 31,
#                                         firstExposureOnly = FALSE,
#                                         washoutPeriod = 0,
#                                         removeDuplicateSubjects = FALSE,
#                                         minDaysAtRisk = 0,
#                                         riskWindowStart = 0,
#                                         startAnchor = "cohort start",
#                                         riskWindowEnd = 30,
#                                         endAnchor = "cohort end")

table1_output_list <- list("basic_demographics_table" = basic_demographics_table
                           ,"top_drugs_table" = top_drugs_table 
                           ,"top_conditions_table" = top_conditions_table
                           # ,"km_graph" = kaplan_meier_output 
                           # ,"cox_summary" = raw_cox_output 
                           # ,"time_to_event" = time_to_event_output
                           ,"table_1_output" = table_1_output
                           ,"table_2_output" = table_2_output
                           ,"table_3_output" = table_3_output
                           ,"gender_cohort_plot" = gender_cohort_plot
                           # ,"age_cohort_plot" = age_cohort_plot
                           ,"name_vector"= name_vector) 
# toc()

return(table1_output_list)
}
