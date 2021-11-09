#+ echo=FALSE
    knitr::kable(dec_input) %>% kableExtra::kable_styling(bootstrap_options=c('responsive','striped'))
    table1_list[["gender_cohort_plot"]]
    #table1_list[["age_cohort_plot"]]
    knitr::kable(table1_list[["basic_demographics_table"]]) %>% kableExtra::kable_styling(bootstrap_options=c('responsive','striped'))
    knitr::kable(print(table1_list[["table_1_output"]],  row.names = FALSE, right = FALSE)) %>% kableExtra::kable_styling(bootstrap_options=c('responsive','striped'))
    knitr::kable(print(table1_list[["table_2_output"]],  row.names = FALSE, right = FALSE)) %>% kableExtra::kable_styling(bootstrap_options=c('responsive','striped'))
    # knitr::kable(table1_list[["top_drugs_table"]]) %>% kableExtra::kable_styling(bootstrap_options=c('responsive','striped'))
    # knitr::kable(table1_list[["top_conditions_table"]]) %>% kableExtra::kable_styling(bootstrap_options=c('responsive','striped'))
    # plot(table1_list[["km_graph"]])
    # table1_list[["cox_summary"]]
    # table1_list[["time_to_event"]]
    plot(chronograph_plot)
