SVVEHDEN Study-a-Thon
==============================

- Analytics use case(s): **-**
- Study type: **-**
- Tags: **-**
- Study lead: **-**
- Study lead forums tag: **[[Lead tag]](https://forums.ohdsi.org/u/[Lead tag])**
- Study start date: **-**
- Study end date: **-**
- Protocol: **-**
- Publications: **-**
- Results explorer: **-**

Aggregation of data for the SVVEHDEN Study-A-Thon.

Requirements
============

- A database in [Common Data Model version 5](https://github.com/OHDSI/CommonDataModel) in one of these platforms: SQL Server, Oracle, PostgreSQL, IBM Netezza, Apache Impala, Amazon RedShift, Google BigQuery, or Microsoft APS.
- R version 4.0.0 or newer
- On Windows: [RTools](http://cran.r-project.org/bin/windows/Rtools/)
- [Java](http://java.com)

How to run
==========
1. Follow [these instructions](https://ohdsi.github.io/Hades/rSetup.html) for setting up your R environment, including RTools and Java. 

2. Open your study package in RStudio. Use the following code to install all the dependencies:

	```r
	renv::restore()
	```

3. In RStudio, select 'Build' then 'Install and Restart' to build the package.

4. Once installed, you can execute the study by modifying and using the code provided under `extras/CodeToRun.R`.

5. Upload the file ```<outputFolderPath>/Results_<DatabaseId>_<Date>.zip``` in the output folder to the study coordinator:

	```r
	uploadResults(outputFolder, privateKeyFileName = "<file>", userName = "<name>")
	```
	Where ```<file>``` and ```<name>``` are the credentials provided to you personally by the study coordinator.

License
=======
The SVVEHDEN package is licensed under Apache License 2.0

Development
===========
SVVEHDEN was developed in ATLAS and R Studio.

### Development status

Unknown
