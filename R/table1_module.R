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
  c(studyPopulation, cohortMethodData, cohort1, cohort2, cohort3, cohort4) %<-% cohort_list
  
  covariates_for_cohort_i <- as.data.frame(cohort2$covariates)
  covariateRef_for_cohort_i <- as.data.frame(cohort2$covariateRef)
  covariates_for_cohort_i %<>% 
    rename(subject_id = rowId) %>% 
    left_join(covariateRef_for_cohort_i, by="covariateId") %>% 
    select(subject_id, name=covariateName, value=covariateValue, concept_id = conceptId)
  
  #######################
  # Demographics
  #######################
  if(verbose) { 
    print("Summarizing demographics table") 
  }
  
  internal_cohort_list = c(cohort4, cohort3, cohort2, cohort1)
  name_list = c("4: All drugs cohort",  "3: Event cohort", "2: Drug cohort", "1: DEC cohort")
  gender_cohort_plot = interactive_barplot(internal_cohort_list, name_list, c("gender = FEMALE", "gender = MALE"))
  #age_cohort_plot = interactive_barplot(internal_cohort_list, name_list, c("(0,20]", "(20,30]"))#, "(30,40]", "(40,50]", "(50,60]", "(60,70]", "(70,80]", "(80,90]", "(90,110]"))
    
  gender_table <- covariates_for_cohort_i %>% filter(name %in% c("gender = FEMALE", "gender = MALE")) %>% count(name) %>% mutate(Percentage=round(100*n/sum(n)))
  colnames(gender_table)=c("Category","n","Percentage")
  final_gender_table <- suppressMessages(bind_cols(c("Sex", rep("", nrow(gender_table)-1)), gender_table))
  colnames(final_gender_table)=c(" ", "Category","n","Percentage")
  final_gender_table$n <- as.character(final_gender_table$n)
  final_gender_table$Percentage <- as.character(final_gender_table$Percentage)
  
  # Age at cohort_entry
  age_quantiles <- covariates_for_cohort_i %>% filter(name %in% "age in years") %>% pull(value) %>%  quantile(c(0.5, 0.25, 0.75)) 
  age_quantiles <- c("Median", age_quantiles[1], paste0( "IQR=(",paste0(round(age_quantiles[2:3]), collapse=", "),")")) 
  names(age_quantiles) = NULL
  age_table <- covariates_for_cohort_i %>% filter(name %in% "age in years") %>% 
    mutate(age = cut(value, breaks=c(0, seq(20, 90, by=10), 110))) %>% pull(age) %>% table() 
  age_perc <- round(age_table %>% prop.table()*100)
  age_groups <- cbind.data.frame(as.data.frame(age_table), as.data.frame(age_perc)[,2])
  colnames(age_groups)=c("Category", "n", "Percentage")
  names(age_quantiles) = names(age_groups)
  age_groups$n <- as.character(age_groups$n) 
  age_groups$Percentage <- as.character(age_groups$Percentage)
  final_age_table <- bind_rows(age_groups, age_quantiles) 
  final_age_table <- suppressMessages(bind_cols(c("Age", rep("", nrow(final_age_table)-1)), final_age_table))
  colnames(final_age_table)=c(" ", "Category","n","Percentage")
  
  # # Get the "state"-names (proxy for countries, no need to do more here until real data arrives)
  # fiftytwo_states <- querySql(conn, "SELECT DISTINCT state from OmopCdm.synpuf5pct_20180710.location")
  # 
  # state_query <- paste0("SELECT n=COUNT(*), state, cohort_definition_id FROM ", resultsDatabaseSchema, 
  #                       ".cohorts_for_deci COH LEFT JOIN ", OmopCdm.synpuf5pct_20180710 ,".person PERS ON COH.subject_id = PERS.person_id 
  #        LEFT JOIN ", cdmDatabaseSchema ,".location LOC ON LOC.location_id = PERS.location_id
  #        GROUP BY state, cohort_definition_id")
  # state_counts <- querySql(conn, state_query) %>% filter(COHORT_DEFINITION_ID==cohort_i) %>% rename(n=N)
  # 
  # states <- fiftytwo_states %>% left_join(state_counts, by="STATE") %>% arrange(desc(n)) %>% select("Category"=STATE, n=n) 
  # states %<>% mutate("Percentage"=round(100*n/sum(n)))
  # final_state_table <- bind_cols(c("State", rep("", nrow(states)-1)), states)
  # final_state_table$n <- as.character(final_state_table$n)
  # final_state_table$Percentage <- as.character(final_state_table$Percentage)
  
  basic_demographics_table <- invisible(bind_rows(final_gender_table, final_age_table))#, final_state_table)
  basic_demographics_table <- rbind.data.frame(c("","Total", length(unique(covariates_for_cohort_i$subject_id)), "100"),
                                               basic_demographics_table)
  ##########################################
  # Top comedications and conditions
  ##########################################
  # if(verbose) { print("Summarizing comed- and conditions- table") }
  # 
  # covariates_for_cohort_i %<>% separate(name, c("time","name"), ":")
  # covariates_for_cohort_i$name[is.na(covariates_for_cohort_i$name)] <- covariates_for_cohort_i$time[is.na(covariates_for_cohort_i$name)]
  # covariates_for_cohort_i %<>% separate(time, c("type","time"), "_")
  # covariates_for_cohort_i$time[is.na(covariates_for_cohort_i$time)] <- covariates_for_cohort_i$type[is.na(covariates_for_cohort_i$time)]
  # 
  # top_drugs_table <- bind_cols(
  #   # 90 days
  #   covariates_for_cohort_i %>% filter(type %in% "drug" & time == "era group during day -90 through 0 days relative to index") %>%
  #     count(name) %>% arrange(desc(n)) %>% slice_head(n=10) %>% mutate(name=tolower(name)) %>% rename(drugs_90_days=name, n_90_days=n),
  #   # 1 year
  #   covariates_for_cohort_i %>% filter(type %in% "drug" & time == "era group during day -365 through 0 days relative to index") %>%
  #     count(name) %>% arrange(desc(n)) %>% slice_head(n=10) %>% mutate(name=tolower(name)) %>% rename(drugs_one_year=name, n_one_year=n),
  #   # 5 year
  #   covariates_for_cohort_i %>% filter(type %in% "drug" & time == "era group during day -1825 through 0 days relative to index") %>%
  #     count(name) %>% arrange(desc(n)) %>% slice_head(n=10) %>% mutate(name=tolower(name)) %>%  rename(drugs_five_years=name, n_five_year=n))
  # 
  # top_conditions_table <- bind_cols(
  #   # 90 days
  #   covariates_for_cohort_i %>% filter(type %in% "condition" & time == "era group during day -90 through 0 days relative to index") %>%
  #     count(name) %>% arrange(desc(n)) %>% slice_head(n=10) %>% mutate(name=tolower(name)) %>% rename(cond_90_days=name, n_90_days=n),
  #   # 1 year
  #   covariates_for_cohort_i %>% filter(type %in% "condition" & time == "era group during day -365 through 0 days relative to index") %>%
  #     count(name) %>% arrange(desc(n)) %>% slice_head(n=10) %>% mutate(name=tolower(name)) %>% rename(cond_one_year=name, n_one_year=n),
  #   # 5 year
  #   covariates_for_cohort_i %>% filter(type %in% "condition" & time == "era group during day -1825 through 0 days relative to index") %>%
  #     count(name) %>% arrange(desc(n)) %>% slice_head(n=10) %>% mutate(name=tolower(name)) %>%  rename(cond_five_years=name, n_five_year=n))
  
  ##########################################
  # Look at outcomes
  ##########################################
  
  ## Compare two cohorts drug+event (1) and drug (2)
  if(verbose) { print("cohort 1 vs 2 table") }
  #standardized_mean_comparison_table  <- computeStandardizedDifference(cohort1a, cohort2)
  table_1_output <- FeatureExtraction::createTable1(covariateData1 = custom_aggregateCovariates(cohort1), 
                                 covariateData2 = custom_aggregateCovariates(cohort2),
                                 specifications = FeatureExtraction::getDefaultTable1Specifications(),
                                 output = "two columns",
                                 showCounts = FALSE,
                                 showPercent = TRUE,
                                 percentDigits = 1,
                                 valueDigits = 1,
                                 stdDiffDigits = 2)
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
  table_2_output <- FeatureExtraction::createTable1(covariateData1 = custom_aggregateCovariates(cohort3), 
                                                    covariateData2 = custom_aggregateCovariates(cohort4),
                                                    specifications = FeatureExtraction::getDefaultTable1Specifications(),
                                                    output = "two columns",
                                                    showCounts = FALSE,
                                                    showPercent = TRUE,
                                                    percentDigits = 1,
                                                    valueDigits = 1,
                                                    stdDiffDigits = 2)
  
  if(verbose) { print("cohort 2 vs 4 table") }
  #standardized_mean_comparison_table  <- computeStandardizedDifference(cohort1a, cohort2)
  table_3_output <- FeatureExtraction::createTable1(covariateData1 = custom_aggregateCovariates(cohort2), 
                                                    covariateData2 = custom_aggregateCovariates(cohort4),
                                                    specifications = FeatureExtraction::getDefaultTable1Specifications(),
                                                    output = "two columns",
                                                    showCounts = FALSE,
                                                    showPercent = TRUE,
                                                    percentDigits = 1,
                                                    valueDigits = 1,
                                                    stdDiffDigits = 2)
  
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
  
  table1_output_list <- list("basic_demographics_table" = basic_demographics_table,
                             #"top_drugs_table" = top_drugs_table, 
                             #"top_conditions_table" = top_conditions_table ,
                             # "km_graph" = kaplan_meier_output, 
                             # "cox_summary" = raw_cox_output, 
                             # "time_to_event" = time_to_event_output,
                             "table_1_output" = table_1_output,
                             "table_2_output" = table_2_output,
                             "table_3_output" = table_2_output,
                             "gender_cohort_plot" = gender_cohort_plot
                             #"age_cohort_plot" = age_cohort_plot
                            ) 
  
  # toc()
  
  return(table1_output_list)
}