#### Description of the files:

* 00\_accred2ct.do: Creates a Stata-friendly mapping from accreditations to casetypes using raw files.
* 01\_cleaning.do: Creates some useful variables used throughout the code.
* 02\_cluster\_data\_prep.do: Prepares the data to be used in the 03\_clustering.py code.
* 02\_cluster\_data\_prep\_strength.do: Same as above, but using a "strength" connection.
* 02\_Hazard.do: Case durations hazard estimations
* 02\_VA.do: Value Added Estimation in STATA.
* 03\_cellconnections2arms\_baseline.do: Calculates each cell connection to the other arm.
* 03\_cellconnections2arms\_strength.do: Same as above, but using the "strength" measure of connection.
* 03\_clustering.py: Creates clusters
* 04\_clustermap: Creates a map from the clusters
* 04\_cellbias: Bias analysis.



#### Other folders:

* PAP: Fist pre-analysis plan with all scripts used there
* Smart\_Assignment1\_analysis: Results from the first Smart Assignment



#### How to download data from Cadaster:

It is important to download data this way to ensure new downloads are like the previous ones but with new data. Steps:

* Get the necessary information to connect to the Cadaster database: host, database name, port, username and password. Ask Wei.
* Download the last version of PostgresSQL.
* Open the PostgresSQL Shell.
* Write on the Shell the information you are asked: host, database, username and password. Once it is done you will be connected to the database.
* In the SQL shell write:
\\copy (Select \* From vw\_deidentified\_case\_w\_appointer) To 'C:\\Users"path"\\cases\_raw\_"date".csv' With CSV DELIMITER ',' HEADER
* A new data file will appear in the path you chose.

