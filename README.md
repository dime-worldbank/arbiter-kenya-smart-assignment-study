# arbiter-kenya-smart-assignment-study
Data analysis code for Arbiter Kenya (aka Cadaster)'s smart assignment study

#### Description of the files:
- cleaning.do: Uses the raw data and creates a cleaned dataset used by the other files. It also creates the file issues.xlsx reporting issues in the data. 
- descriptive_exhibits.do: Creates tables and graphs that describe several aspects of the data: Number of cases per mediator under different restricions, number of cases referred monthly, case types by year and courtstation.
- Antoine_va_TC.do: First calculates the value added of eligible mediators and then creates two groups, treatment and control, finally it exports a list with mediator id's, VA and their groups in va_groups.csv. 
- impact_eval_details.do: Creates tables and graphs relevant to the impact evaluation: number of cases eligible to be in the impact evaluation referred to court monthly, names of the courtstations to be in the impact evaluation, previous caseload of eligible mediators, and number of mediators in treatment and control groups under different conditions.
- power_calcs.do: Reports the power calculations. It does not export any result, the results appear in the screen. 
- caseload_TC.do: Compares the previous caseload of mediators in groups T and C and non-experimental mediators. 
- Judges_appoitnment.do: Compares the mediators chosen by Judges during the impact evaluation to those recommended by Smart Assignment
- va_shrunk_unshrunk.do: Some comparisions between the shrunk VA and unshrunk VA estimators
- va_TC_diff_unshrunk.do: Compare T and C groups using the shrunk and unshrunk estimators. 
- PAP_descriptive.do: Creates descriptive statistics for the PAP
- PAP_powercalcs.do: Power calculations for the PAP
- PAP_simul.do: Power calculations and other results e.g. Brier scores for the PAP.
 

#### Folder structure: 
In the same folder there should be at least these three folders:
- Data_Raw: Where raw data is saved.
- Data_Clean: Where clean data is saved.
- Ouptut: Where outputs (tables and graphs) are saved. 

#### Some Relevant ouptuts:
- va_groups.csv: VA and VA groups for the impact evaluation.
- courts_totalcasenum_only10plus.csv: Courtstations for the impact evaluation. 
- power_calcs.xlsx: Power calculations. This is summary file created "manually" by copying different outputs of Antoine_va_TC.do and impact_eval_details.do.

#### How to run the code:
- cleaning.do should be ran first to create the cleaned dataset that other .do files use. The other .do files can be run after cleaning.do in any order, since they don't depend on each other. 
- Dates: Files can be ran using datasets downloaded on different dates, select the one you want to use. June 15, 2023 was the date used for the impact evaluation input technical test. 
- Some .do files have instructions at the beginning, follow them. 

#### How to download data from Cadaster:
It is important to download data this way to ensure new downloads are like the previous ones but with new data. Steps:
- Get the necessary information to connect to the Cadaster database: host, database name, port, username and password. Ask Wei.
- Download the last version of PostgresSQL.
- Open the PostgresSQL Shell.
- Write on the Shell the information you are asked: host, database, username and password. Once it is done you will be connected to the database. 
- In the SQL shell write: 
\copy (Select * From vw_deidentified_case_w_appointer) To 'C:\Users\"path"\cases_raw_"date".csv' With CSV DELIMITER ',' HEADER
- A new data file will appear in the path you chose. 