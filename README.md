#### Description of the files:
- VA_Antoine.do: Calculate VA in STATA (Antoine's method)
- VA_Antoine.py: Calculate VA in Python (Antoine's method)
- Hazard_AS.do: Hazard calculations. 
- posterior_script.py: Calculate posterior mu and sigma (Farabi's method)
- compare_Far_Ant.py: Compare results from Farabi's and Antoine's methods

#### Other folders: 
- Descriptive: Data descriptive tables and graphs
- PAP: Pre-analysis plan all scripts
- Smart_Assignment1_analysis: Results from the first Smart Assignment

#### How to download data from Cadaster:
It is important to download data this way to ensure new downloads are like the previous ones but with new data. Steps:
- Get the necessary information to connect to the Cadaster database: host, database name, port, username and password. Ask Wei.
- Download the last version of PostgresSQL.
- Open the PostgresSQL Shell.
- Write on the Shell the information you are asked: host, database, username and password. Once it is done you will be connected to the database. 
- In the SQL shell write: 
\copy (Select * From vw_deidentified_case_w_appointer) To 'C:\Users\"path"\cases_raw_"date".csv' With CSV DELIMITER ',' HEADER
- A new data file will appear in the path you chose. 