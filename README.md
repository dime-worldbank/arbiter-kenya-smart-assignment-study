#### \## Description of the files

#### 

#### The following are all the scripts and folders in `Code` and a brief description of what they do.

#### 

#### \### Main scripts

#### 

#### \* `00\_accred2ct.do`: Creates a Stata-friendly mapping from accreditations to case types using the raw files.

#### \* `01\_cleaning.do`: Creates variables used throughout the rest of the code. It does \*\*not\*\* drop any observations. If observations need to be dropped, this should be done in the scripts for specific tasks (e.g. clustering or estimating case durations), not in this file; otherwise, replicating the results could fail.

#### \* `02\_Hazard.do`: Estimates case durations for agreements/non-agreements and for each case type using a hazard model.

#### \* `02\_VA.do`: Value added estimation in Stata.

#### 

#### \### `Clusters` folder

#### 

#### Cluster-related files.

#### 

#### \#### `Baseline` subfolder

#### 

#### \* `02\_cluster\_data\_prep.do`: Prepares the data for `03\_clustering.py`. It calculates the connection between every pair of cells (cs, ct). Connections between cells are measured by the number of "shared" mediators, i.e. mediators who have worked in both cells in the past.

#### \* `03\_cellconnections2arms\_baseline.do`: Calculates each cell's connection to the other arm, using the number of "shared" mediators between the cell and the opposite arm, i.e. mediators who have worked in both the cell and the opposite arm in the past.

#### 

#### \#### `Strength` subfolder

#### 

#### \* `02\_cluster\_data\_prep\_strength.do`: Prepares the data for `03\_clustering.py`. It calculates the connection between every pair of cells (cs, ct), using the "strength" connection method.

#### \* `03\_cellconnections2arms\_strength.do`: Calculates each cell's connection to the other arm, using the strength of the connection between the cell and the opposite arm.

#### 

#### \#### Scripts in the main `Clusters` folder

#### 

#### \* `03\_clustering.py`: Creates clusters using the Louvain communities method and outputs them as a .csv. Must be run after `02\_cluster\_data\_prep.do` or `02\_cluster\_data\_prep\_strength.do`.

#### \* `04\_clustermap.py`: Creates a map of the clusters produced by `03\_clustering.py`.

#### \* `04\_cellbias.do`: Analyses the bias. Runs several regressions (e.g. excluding the most connected cells) and produces graphs.

#### 

#### \### `PAP1` folder

#### 

#### First pre-analysis plan, with all the scripts used for it.

#### 

#### \### `Smart\_Assignment1\_analysis` folder

#### 

#### Results from the first Smart Assignment.

#### 

#### \## Order of execution

#### 

#### \* `00\_accred2ct.do` and `01\_cleaning.do` should be run before anything else.

#### \* `02\_Hazard.do` and `02\_VA.do` are independent, stand-alone files.

#### \* The cluster scripts depend on each other. Scripts that depend on each other are in the same folder, and the number at the start of each script's name indicates the order in which to run them.

#### 

#### \## How to download data from Cadaster

#### 

#### Download the data this way so that new downloads have the same structure as previous ones, just with newer data. Steps:

#### 

#### 1\. Get the connection details for the Cadaster database: host, database name, port, username and password. Ask Wei.

#### 2\. Download the latest version of PostgreSQL.

#### 3\. Open the PostgreSQL shell (SQL Shell / psql).

#### 4\. Enter the information the shell asks for (host, database, port, username and password). Once done, you will be connected to the database.

#### 5\. In the SQL shell, run (on a single line), replacing `<path>` and `<date>` and vw\_deidentified\_case\_w\_appointer with the desired table with:

#### 

#### \\copy (SELECT \* FROM vw\_deidentified\_case\_w\_appointer) TO 'C:\\Users\\<path>\\cases\_raw\_<date>.csv' WITH CSV DELIMITER ',' HEADER

#### 

#### 6\. A new data file will appear in the path you chose.

