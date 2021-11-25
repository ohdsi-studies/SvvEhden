# Build the package using CONTROL + SHIFT + B or see the tab "Build" up on the right panel.
library(SVVEHDEN)

# Make sure the working directory is the root of the SVVEHDEN OHDSI study package
tryCatch({
  setwd("./R")
}, error = function(e) {
  setwd("../R")
})

# Error documentation
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
cdmDatabaseSchema = "OmopCdm.synpuf5pct"    # if dbms = "sql server", please provide "databasename [.] schemaname", otherwise just the schemaname. 

### The name of the database schema and table where the study-specific cohorts will be instantiated:
cohortDatabaseSchema = cdmDatabaseSchema    # if dbms = "sql server", please provide "databasename [.] schemaname", otherwise just the schemaname. 
cohortTable <- "cohorts_SVVEHDEN"

### A folder with write access, where intermediate and result files can be written:
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


### As a start, just run on the first DEC
maxNumberOfCombinations = 1
verbose = FALSE

### Execute
SVVEHDEN::execute(
  connectionDetails = connectionDetails,
  cdmDatabaseSchema = cdmDatabaseSchema,
  cohortDatabaseSchema = cohortDatabaseSchema,
  cohortTable = cohortTable,
  outputFolderPath = outputFolderPath,
  maxNumberOfCombinations = maxNumberOfCombinations,
  verbose = verbose)

### Upload the results to the OHDSI SFTP server:
privateKeyFileName <- "" # type in path and filename of privacy keys (provided in email)
userName <- ""           # type in user name of study (provided in email)
SVVEHDEN::uploadResults(outputFolder, privateKeyFileName, userName)