# TODO: MOVE CHRONOGRAPH CODE OR PACKAGE IN ORDER TO USE!?
# Fix era setup
# Use Eunomia as a debug to spot sql server-dependencies
# Generic SQL Script to be completed (Judith)

# Make sure the working directory is the root of the SVVEHDEN OHDSI study package
tryCatch({
  setwd("./R")
}, error = function(e) {
  setwd("../R")
})
source("general_function_library.R")   

ParallelLogger::clearLoggers()
ParallelLogger::addDefaultErrorReportLogger(fileName = file.path(getwd(), "errorReportR.txt"),
                                            name = "DEFAULT_ERRORREPORT_LOGGER")

### Optional: specify where the temporary files (used by the Andromeda package) will be created:
andromedaTempFolder = NULL
options(andromedaTempFolder = andromedaTempFolder)

### The folder where the study intermediate and result files will be written:
outputFolderPath <- "C:/SVVEHDEN_ouput"

### Details for connecting to the server:
# connectionDetails <-
#   DatabaseConnector::createConnectionDetails(
#     dbms = "pdw",
#     server = Sys.getenv("PDW_SERVER"),
#     user = NULL,
#     password = NULL,
#     port = Sys.getenv("PDW_PORT")
#   )

connectionDetails <- Eunomia::getEunomiaConnectionDetails()
DatabaseConnector::connect(connectionDetails, dbms="sqlite")

### The name of the database schema where the CDM data can be found:
cdmDatabaseSchema <- "main"

### The name of the database schema and table where the study-specific cohorts will be instantiated:
cohortDatabaseSchema <- cdmDatabaseSchema
cohortTable <- "cohorts_SVVEHDEN"

### For some database platforms (e.g. Oracle): define a schema that can be used to emulate temp tables:
sqlRenderTempEmulationSchema = NULL
options(sqlRenderTempEmulationSchema = sqlRenderTempEmulationSchema)

######### INTERNAL DEBUG #######################
#connectionDetails <- createConnectionDetails(dbms = "sql server", server = "UMCDB06")
#cdmDatabaseSchema = "OmopCdm.synpuf5pct_20180710"
#cohortDatabaseSchema = cdmDatabaseSchema
#cohortTable = paste0("cohorts_",Sys.getenv("USERNAME"),"")
#outputFolderPath = paste0("C:\\Users\\",Sys.getenv("USERNAME"),"\\WHO Collaborating Centre for International Drug Monitoring\\EHDEN - SWEDHEN-SPRINT\\output_",Sys.getenv("USERNAME"),"\\")
################################################
### Specify if you want to limit the number of combinations (normally used during debug or if you want to try out the full script without running all combinations)
maxNumberOfCombinations = 5
################################################

### Execute
source("execute.R")   
execute(
  connectionDetails = connectionDetails,
  cdmDatabaseSchema = cdmDatabaseSchema,
  cohortDatabaseSchema = cohortDatabaseSchema,
  cohortTable = cohortTable,
  outputFolderPath = outputFolderPath,
  maxNumberOfCombinations = maxNumberOfCombinations,
  verbose = FALSE)

### Upload the results to the OHDSI SFTP server:
privateKeyFileName <- ""
userName <- ""
#SVVEHDEN::uploadResults(outputFolder, privateKeyFileName, userName) #TODO
