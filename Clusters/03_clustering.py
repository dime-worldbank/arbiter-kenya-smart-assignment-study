import pandas as pd
import networkx as nx
import pickle
import os

# Review: are there

# %% Prepare dataset

## NORMAL (DIDAC)
# Set your working directory 
os.chdir("C:\\Users\didac\Dropbox\Arbiter Research\Data analysis")

# Data 1: Everything
dfc1 = pd.read_csv('Data_Clean\clusterdata_b_20260513.csv') 

# Data 2: Remove observations in which cs_ct = cs1_ct1 (self-links)
dfc2 = dfc1[dfc1["cs_ct"] != dfc1["cs_ct1"]] 

# Data 3: Remove edges with 0 capacity
df = dfc2[dfc2["w_max"] != 0]

df = df.rename(columns={'cs_ct1':'cs1_ct1', 'w_max':'edge'})
df = df.sort_values(by=['cs_ct'])

df = df.drop_duplicates(subset='pair_id', keep='first')

'''
## SHARED (FARABI)
# Set your working directory 
os.chdir("C:\\Users\didac\Dropbox\Arbiter Research\Data analysis")

# Data 1: Everything
dfc1_sh = pd.read_csv('Data_Clean\clusterdata_shared_20260513.csv') 
#dfc1_sh = dfc1_sh.rename(columns={'total_link': 'w_max'})

# Data 2: Remove observations in which cs_ct = cs1_ct1 (self-links)
dfc2_sh = dfc1_sh[dfc1_sh["cs_ct"] != dfc1_sh["cs_ct1"]] 

# Data 3: Remove edges with 0 capacity
df_sh = dfc2_sh[dfc2_sh["w_max"] != 0]
df_sh = df_sh.dropna(subset=['w_max'])

df_sh = df_sh.rename(columns={'cs_ct1':'cs1_ct1', 'w_max':'edge'})
df_sh = df_sh.sort_values(by=['cs_ct'])

df = df_sh


## HYBRID/THRESHOLD
# Set your working directory 
os.chdir("C:\\Users\didac\Dropbox\Arbiter Research\Data analysis")

# Data 1: Everything
dfc1_hyb = pd.read_csv('Data_Clean\clusterdata_hybrid_20260513.csv') 

# Data 2: Remove observations in which cs_ct = cs1_ct1 (self-links)
dfc2_hyb = dfc1_hyb[dfc1_hyb["cs_ct"] != dfc1_hyb["cs_ct1"]] 

# Data 3: Remove edges with 0 capacity
df_hyb = dfc2_hyb[dfc2_hyb["w_max"] != 0]

df_hyb = df_hyb.rename(columns={'cs_ct1':'cs1_ct1', 'w_max':'edge'})
df_hyb = df_hyb.sort_values(by=['cs_ct'])

df_hyb = df_hyb.dropna(subset=['edge'])

df=df_hyb
'''

## STRENGTH
# Set your working directory 
os.chdir("C:\\Users\didac\Dropbox\Arbiter Research\Data analysis")

# Data 1: Everything
dfc1_str = pd.read_csv('Data_Clean\clusterdata_strength_20260513.csv') 
dfc1_str = dfc1_str.rename(columns={'total_link': 'w_max'})

# Data 2: Remove observations in which cs_ct = cs1_ct1 (self-links)
dfc2_str = dfc1_str[dfc1_str["cs_ct"] != dfc1_str["cs_ct1"]] 

# Data 3: Remove edges with 0 capacity
df_str = dfc2_str[dfc2_str["w_max"] != 0]
df_str = df_str.dropna(subset=['w_max'])

df_str = df_str.rename(columns={'cs_ct1':'cs1_ct1', 'w_max':'edge'})
df_str = df_str.sort_values(by=['cs_ct'])

df=df_str


#%% Louvain communities

# Create an undirected graph
G = nx.Graph()

for _, row in df.iterrows():
    G.add_edge(row["cs_ct"], row["cs1_ct1"], weight=float(row["edge"])) 
    
# BASELINE
#louvain_partition = nx.community.louvain_communities(G, weight='weight', resolution = 5.8, seed=1718)
#louvain_partition = nx.community.louvain_communities(G, weight='weight', resolution = 3.35, seed=1718)
#louvain_partition = nx.community.louvain_communities(G, weight='weight', resolution = 1.1, seed=1718)

#louvain_partition = nx.community.louvain_communities(G, weight='weight', resolution = 5.9, seed=1718)
#louvain_partition = nx.community.louvain_communities(G, weight='weight', resolution = 4.6, seed=1718)
#louvain_partition = nx.community.louvain_communities(G, weight='weight', resolution = 3.5, seed=1718)
louvain_partition = nx.community.louvain_communities(G, weight='weight', resolution = 1.1, seed=1718)

# SHARED
#louvain_partition = nx.community.louvain_communities(G, weight='weight', resolution = 4.4, seed=1714)

# HYBRID
#louvain_partition = nx.community.louvain_communities(G, weight='weight', resolution = 1.000483, seed=1714)


# STRENGTH
louvain_partition = nx.community.louvain_communities(G, weight='weight', resolution = 3.82, seed=1716)
#louvain_partition = nx.community.louvain_communities(G, weight='weight', resolution = 3.48, seed=1716)
#louvain_partition = nx.community.louvain_communities(G, weight='weight', resolution = 2.7, seed=1716)
#louvain_partition = nx.community.louvain_communities(G, weight='weight', resolution = 1.6, seed=1716)

#with open("Output/Clusters/2clusters_louv_res1p1_20260513.pkl", "wb") as f:
#    pickle.dump(louvain_partition, f) 

with open("Output/Clusters/2clusters_louv_res3p82_str_20260513.pkl", "wb") as f:
    pickle.dump(louvain_partition, f) 
    
# List to df
# Flatten into rows
rows = []
for cluster_id, items in enumerate(louvain_partition):
    for place in items:
        rows.append((place, cluster_id))
df_louvain_partition = pd.DataFrame(rows, columns=['cs_ct', 'cluster'])    
df_louvain_partition.to_csv("Output/Clusters/2clusters_louv_res3p82_str_20260513.csv")