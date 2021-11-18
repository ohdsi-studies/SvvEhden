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
  
  # Initiate an R-file and write the code we need for it:  
  fileConn <- file("test_plot.R")
  
  # i = 1
  # dec_input = dec_df[i,]
  
  c(drug_name, event_name, drug_id, event_id) %<-% dec_input[1:4] 
  
  # Initiate a total count variable
  total_count <- -1
  total_count <- table1_list[["basic_demographics_table"]][1,3]
  
  writeLines(c("#+ echo=FALSE
    knitr::kable(dec_input) %>% kableExtra::kable_styling(bootstrap_options=c('responsive','striped'))
    cat(\"Chronograph ##\")
    plot(chronograph_plot)
    cat(\"Basic demographioc table##\")
    knitr::kable(table1_list[[\"basic_demographics_table\"]]) %>% kableExtra::kable_styling(bootstrap_options=c('responsive','striped'))
    cat(\"Gender distribution ##\")
    table1_list[[\"gender_cohort_plot\"]]
    cat(\"DEC vs. drug ##\")
    knitr::kable(table1_list[[\"table_1_output\"]],  row.names = FALSE, right = FALSE) %>% kableExtra::kable_styling(bootstrap_options=c('responsive','striped'))
    cat(\"Event vs. All ##\")
    knitr::kable(table1_list[[\"table_2_output\"]],  row.names = FALSE, right = FALSE) %>% kableExtra::kable_styling(bootstrap_options=c('responsive','striped'))
    cat(\"Drug vs. All ##\")
    knitr::kable(table1_list[[\"table_3_output\"]],  row.names = FALSE, right = FALSE) %>% kableExtra::kable_styling(bootstrap_options=c('responsive','striped'))
    cat(\"Top drugs and conditions for DEC ##\")
    knitr::kable(table1_list[[\"top_drugs_table\"]]) %>% kableExtra::kable_styling(bootstrap_options=c('responsive','striped'))
    knitr::kable(table1_list[[\"top_conditions_table\"]]) %>% kableExtra::kable_styling(bootstrap_options=c('responsive','striped'))
    # plot(table1_list[[\"km_graph\"]])
    # table1_list[[\"cox_summary\"]]
    # table1_list[[\"time_to_event\"]]
    "
               ), fileConn)
  close(fileConn)
  
  # Render the R-file as a markdown-file, to get an html
  short_drug_name = shorten_to_file_path(drug_name)
  short_event_name = shorten_to_file_path(event_name)
  
  rmarkdown::render("test_plot.R", output_file=paste0(output_path,"DEC", i, " ", short_drug_name, "-", 
                                                      short_event_name, "-" , total_count, ".html"), 
                    quiet = !saddle$overall_verbose)  
  
  # toc()
}


