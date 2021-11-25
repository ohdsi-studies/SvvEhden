########################################################################
# print_to_html_module:
# This function is called from the workhorse script, creates html-files for each DEC in the designated output folder, and returns nothing.

# Input parameters:
#   i: The index variable in the for-loop.
# table1_list : List of table1-tables produced by table1_module.
# chronograph_plot: The plot returned from the chronograph_module.
# The following inputs are used from the saddle_list:
#   dec_input:  defaults to saddle$dec_df[i,]
#   overall_verbose: Should informative output be printed?
########################################################################

# This module takes care of printing all results into an Rmarkdown html-file.

print_to_html_module <- function(i, table1_list, chronograph_plot, saddle){
  
  # tic("Printing to html")
  
  # Unpack the saddle
  output_path <- saddle$output_path
  dec_input <- saddle$dec_df[i,]
  verbose <- saddle$overall_verbose
  

  # Add consistent output cohort names, using "name_vector" from the table1-module
  zeallot::`%<-%`(c(drug_event_cohort_name, drug_cohort_name, comp_drugs_with_event_cohort_name,  comp_drugs_cohort_name), 
                  table1_list$name_vector)
  
  # Second version with the cohort N at the end
  zeallot::`%<-%`(c(drug_event_cohort_name_w_N, drug_cohort_name_w_N, comp_drugs_with_event_cohort_name_w_N,  comp_drugs_cohort_name_w_N),
                  paste0(c(drug_event_cohort_name, drug_cohort_name, comp_drugs_with_event_cohort_name,  comp_drugs_cohort_name)," (N=",
                         as.character(table1_list$basic_demographics_table[1,])[c(3,7,11,15)], ")"))
  
  # TODO Oskar: move the renaming of column names into table1_module, so that all plots and graphs can use the same name?
  # I copied this two into table1_module replace the old name_list with these names, so that both the gender plot 
  # and to co-meds and co-conditions-tables can make use of them
  
  # Initiate an R-file and write the code we need for it: 
  unlink("DEC.R")
  fileConn <- file("DEC.R")
  
  # i = 1
  # dec_input = dec_df[i,]
  
  zeallot::`%<-%`(c(drug_name, event_name, drug_id, event_id), dec_input[1:4])
  
  # Initiate a total count variable
  total_count <- -1
  total_count <- table1_list[["basic_demographics_table"]][1,3]
  
  # Prepare for merging the three tables into one
  table1_1 <- clean_output_tables(table1_list$table_1_output)
  table1_2 <- clean_output_tables(table1_list$table_2_output)
  table1_3 <- clean_output_tables(table1_list$table_3_output)
  
  # Merge the three comparisons-tables, and keep the order
  big_table <- merge(merge(table1_1, table1_2, by="Characteristic", all = T), table1_3, by="Characteristic", all=T)
  big_table <- big_table[order(match(big_table$Characteristic, table1_1$Characteristic)),]
  
  # Set the column names
  colnames(big_table) = c("Characteristic", c(drug_event_cohort_name_w_N, drug_cohort_name_w_N), "Std. Diff", 
                          comp_drugs_with_event_cohort_name_w_N,  comp_drugs_cohort_name_w_N, " Std. Diff",
                          drug_cohort_name_w_N, comp_drugs_cohort_name_w_N, "Std. Diff ")
  
  # Reverse the sign on the Std Diff:
  big_table[,c(4)] <- round(as.numeric(big_table[,c(4)])*-1,1)
  big_table[,c(7)] <- round(as.numeric(big_table[,c(7)])*-1,1)
  big_table[,c(10)] <- round(as.numeric(big_table[,c(10)])*-1,1)
  
  big_table[is.na(big_table)] = "0"
  
  writeLines(c("#+ echo=FALSE
    knitr::kable(dec_input[-5]) %>% kableExtra::kable_styling(bootstrap_options=c('responsive','striped'))
    cat(\"Chronograph ##\")
    plot(chronograph_plot)
    cat(\"Table of sex and age ##\")
    knitr::kable(table1_list[[\"basic_demographics_table\"]]) %>% kableExtra::kable_styling(bootstrap_options=c('responsive','striped'))
    cat(\"Gender plot ##\")
    table1_list[[\"gender_cohort_plot\"]]
    cat(\"Below: Percentages and Standardized differences for preexisting conditions and comedications, using a 180 day lookback window from drug start. ('OHDSI Table1'). Standardized difference ('Std Diff') is difference in means divided by standard deviation. ##\")    
    DT::datatable(big_table,  rownames = FALSE)
    cat(\"Below: Top preexisting comedications, using a 180 day lookback window from drug start, counts and percentages. Covariates are 'raw', i.e. not grouped as in 'OHDSI table1' above. ##\")    
    table1_list[[\"top_drugs_table\"]]
    cat(\"Below: Top preexisting conditions, using a 180 day lookback window from drug start, counts and percentages. Covariates are 'raw', i.e. not grouped as in 'OHDSI table1' above. ##\")    
    table1_list[[\"top_conditions_table\"]]
    #knitr::kable(table1_list[[\"top_drugs_table\"]]) %>% kableExtra::kable_styling(bootstrap_options=c('responsive','striped'))
    #knitr::kable(table1_list[[\"top_conditions_table\"]]) %>% kableExtra::kable_styling(bootstrap_options=c('responsive','striped'))
    # plot(table1_list[[\"km_graph\"]])
    # table1_list[[\"cox_summary\"]]
    # table1_list[[\"time_to_event\"]]
    "
  ), fileConn)
  close(fileConn)
  
  # Render the R-file as a markdown-file, to get an html
  short_drug_name = shorten_to_file_path(drug_name)
  short_event_name = shorten_to_file_path(event_name)
  
  rmarkdown::render("DEC.R", output_file=paste0(output_path,"DEC", i, " ", short_drug_name, "-", 
                                                      short_event_name, "-" , total_count, ".html"), 
                    quiet = !saddle$overall_verbose)  
  
  # Delete test plot when done, otherwise the package will fail to build. 
  unlink("DEC.R")
  #tictoc::toc()
}


