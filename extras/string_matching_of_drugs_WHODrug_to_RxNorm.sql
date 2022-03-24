-- !preview conn=DBI::dbConnect(RSQLite::SQLite())

SELECT DrugText, TermText, Rx.*
FROM (
        SELECT top 1000 CT.*, DLX.DrugText, ALX.TermText, PD.Patent, UD.Unspecific       
        FROM [dbo].[CombinationtableFinal_r4_vigiRankMaxRandom] CT
        LEFT JOIN [SignalData_EhdenStudyathonMiniSprint_2022Spring_r4].[VmDrug_lx] DLX on DLX.VmDrug_Id = CT.VmDrug_Id
        LEFT JOIN [SignalData_EhdenStudyathonMiniSprint_2022Spring_r4].[VmAdrTerm_lx] ALX on ALX.VmAdrTerm_Id = CT.VmAdrTerm_Id
        LEFT JOIN [ResearchProjects].[SVVEHDEN].[PatentedDrugs] PD on PD.DrugText like DLX.DrugText
        LEFT JOIN [ResearchProjects].[SVVEHDEN].[UnspecificDrugs] UD on UD.DrugText like DLX.DrugText
        ORDER BY randomSortOrder
     ) T
LEFT JOIN [OmopCdm].[synpuf5pct_20180710].[concept] RX ON RX.vocabulary_id like 'RxNorm' and RX.concept_class_id = 'Ingredient' and RX.standard_concept = 'S' and RX.concept_name = DrugText
WHERE Patent = 0 and Unspecific = 0 and RX.concept_id is not null
ORDER BY T.randomSortOrder
