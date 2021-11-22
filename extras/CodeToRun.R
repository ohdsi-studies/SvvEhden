
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

############## OPTIONS ##############################

### Optional: specify where the temporary files (used by the Andromeda package) will be created:
andromedaTempFolder = NULL
options(andromedaTempFolder = andromedaTempFolder)

### For some database platforms (e.g. Oracle): define a schema that can be used to emulate temp tables:
sqlRenderTempEmulationSchema = NULL
options(sqlRenderTempEmulationSchema = sqlRenderTempEmulationSchema)

############## PARAMETERS ##############################

### The cdm schema 
cdmDatabaseSchema = "OmopCdm.synpuf5pct"    # if dbms = "sql server", please provide "databasename [.] schemaname"

### The name of the database schema and table where the study-specific cohorts will be instantiated:
cohortDatabaseSchema = cdmDatabaseSchema    # if dbms = "sql server", please provide "databasename [.] schemaname"
cohortTable <- "cohorts_SVVEHDEN"

### The folder where the study intermediate and result files will be written:
outputFolderPath <- "C:/SVVEHDEN_ouput"

### Provide details for connecting to the server:
connectionDetails <-
 DatabaseConnector::createConnectionDetails(
   dbms = "pdw",
   server = Sys.getenv("PDW_SERVER"),
   user = NULL,
   password = NULL,
   port = Sys.getenv("PDW_PORT")
 )

### Specify if you want to limit the number of combinations (normally used during debug or if you want to try out the full script without running all combinations)
maxNumberOfCombinations = 5
verbose = FALSE

### Execute
source("execute.R")
execute(
  connectionDetails = connectionDetails,
  cdmDatabaseSchema = cdmDatabaseSchema,
  cohortDatabaseSchema = cohortDatabaseSchema,
  cohortTable = cohortTable,
  outputFolderPath = outputFolderPath,
  maxNumberOfCombinations = maxNumberOfCombinations,
  verbose = verbose)

### Upload the results to the OHDSI SFTP server:
source("SubmitResults.R")
privateKeyFileName <- "" # type in path and filename of privacy keys (provided in email)
userName <- ""           # type in user name of study (provided in email)
uploadResults(outputFolder, privateKeyFileName, userName)
