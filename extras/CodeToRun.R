library(SVVEHDEN)

### Optional: specify where the temporary files (used by the Andromeda package) will be created:
andromedaTempFolder = NULL
options(andromedaTempFolder = andromedaTempFolder)

### The folder where the study intermediate and result files will be written:
outputFolderPath <- "C:/SVVEHDEN_ouput"

### Details for connecting to the server:
connectionDetails <-
  DatabaseConnector::createConnectionDetails(
    dbms = "pdw",
    server = Sys.getenv("PDW_SERVER"),
    user = NULL,
    password = NULL,
    port = Sys.getenv("PDW_PORT")
  )

### The name of the database schema where the CDM data can be found:
cdmDatabaseSchema <- "CDM_IBM_MDCD_V1153.dbo"

### The name of the database schema and table where the study-specific cohorts will be instantiated:
cohortDatabaseSchema <- cdmDatabaseSchema
cohortTable <- "cohorts_SVVEHDEN"

### For some database platforms (e.g. Oracle): define a schema that can be used to emulate temp tables:
sqlRenderTempEmulationSchema = NULL
options(sqlRenderTempEmulationSchema = sqlRenderTempEmulationSchema)

######### INTERNAL DEBUG #######################
# Test if this works: yes
connectionDetails <- NULL
cdmDatabaseSchema = NULL
cohortDatabaseSchema = NULL
cohortTable = NULL
outputFolderPath = NULL
################################################

######### INTERNAL DEBUG #######################
# Test if this works: yes
connectionDetails <- createConnectionDetails(dbms = "sql server",
                                             server = "UMCDB06")
cdmDatabaseSchema = "OmopCdm.synpuf5pct_20180710"
cohortDatabaseSchema = cdmDatabaseSchema
cohortTable = paste0("cohorts_",Sys.getenv("USERNAME"),"")
outputFolderPath = paste0("C:\\Users\\",Sys.getenv("USERNAME"),"\\WHO Collaborating Centre for International Drug Monitoring\\EHDEN - SWEDHEN-SPRINT\\output_",Sys.getenv("USERNAME"),"\\")
################################################

### Execute
SVVEHDEN::execute(
  connectionDetails = connectionDetails,
  cdmDatabaseSchema = cdmDatabaseSchema,
  cohortDatabaseSchema = cohortDatabaseSchema,
  cohortTable = cohortTable,
  tempEmulationSchema = tempEmulationSchema,
  outputFolderPath = outputFolderPath,
  verbose = FALSE
)

### Upload the results to the OHDSI SFTP server:
privateKeyFileName <- ""
userName <- ""
#SVVEHDEN::uploadResults(outputFolder, privateKeyFileName, userName) #TODO


