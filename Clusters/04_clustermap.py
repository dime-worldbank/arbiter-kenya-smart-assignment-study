import numpy as np
import pandas as pd
import geopandas as gpd
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D
from shapely.geometry import Point
import pickle
import re
 
# %% LOAD DATA
 
# DATA 1: Load Kenya shapefile
kenya_shp = gpd.read_file(r"Data_Clean\gadm_KEN_shp\gadm41_KEN_0.shp")
 
# DATA 2: Load locations of court stations
cs = pd.read_csv(r"Data_Raw\Court_Station_County_loc_20260513.csv", sep=";")
cs = cs[['courtstation', 'lat', 'lon']]
cs['cstation'] = cs['courtstation'].replace({
    'PORT VICTORIA': 'PORTVICTORIA',
    "MUKURWE-INI": "MUKURWEINI",
    "MURANG'A": "MURANGA",
    "WANG'URU": "WANGURU",
    "OL KALOU": "OLKALOU",
    "ELDAMA RAVINE": "ELDAMARAVINE",
    "MTITO ANDEI": "MTITOANDEI"})
 
# DATA 3: Load clusters
with open("Output/Clusters/2clusters_louv_res3p82_str_20260513.pkl", "rb") as f:
    cl = pickle.load(f)
del f
 
# Clusters to dataframe
cl_dic = {}  # Create a dictionary mapping each courtstation to its cluster
for i, group in enumerate(cl, 1):  # Clusters numbered from 1
    for station in group:
        cl_dic[station] = i
cl = pd.DataFrame(list(  # Convert dictionary into DataFrame
    cl_dic.items()), columns=["court_key", "cluster"])
cl["courtstation"] = cl[  # Extract court station names
    "court_key"].apply(lambda x: re.sub(r'_\d+', '', x))
del cl_dic, i, group, station
 
# DATA 4: List of CS_CT with num cases
cs_ct_num = pd.read_csv(r"Data_Clean\cs_ct_withcases_20260513.csv")

# DATA 5: Six largest cities (source: Wikipedia)
cities = pd.DataFrame({
    "city":  ["Nairobi", "Mombasa", "Nakuru",
              "Ruiru", "Eldoret", "Kisumu"],
    "lat":   [-1.291491817494124, -4.041347919115863, -0.302010436454897,
              -1.148834398186859,  0.513467432351212, -0.089428881721865],
    "lon":   [36.818295266921695, 39.663892429975746, 36.073054858832370,
              36.964774832712230, 35.271044418103350, 34.760606400639475],
    "color": ["#1f77b4", "#2ca02c", "#9467bd",
              "#8c564b", "#bcbd22", "#17becf"],  # blue, green, purple,
                                                 # brown, olive, cyan
})
 
# %% MERGE DATA
 
# Merge clusters with locations
df = cs.merge(cl, on="courtstation", how="outer")
df = df.dropna(subset=['court_key'])  # Drop if no cluster in that court
 
# Merge clusters with number of cases (to check all cs_ct have cases)
df = df.rename(columns={"court_key": "cs_ct"})
df = df.merge(cs_ct_num, on="cs_ct", how="outer")
 
# %% DOT SIZE FROM NUMBER OF CASES
 
# Size range in points^2 (matplotlib markersize is an AREA).
# Tune these two numbers to make all dots bigger/smaller.
S_MIN, S_MAX = 6, 120
 
# Global case range, computed once so every map shares the same size scale
N_MIN = df["n_cases"].min()
N_MAX = df["n_cases"].max()
 
 
def cases_to_size(n, n_min=N_MIN, n_max=N_MAX, s_min=S_MIN, s_max=S_MAX):
    """Map case counts onto marker areas on a log scale.
 
    n_min maps to s_min, n_max maps to s_max. Using the ratio of logs
    (rather than the raw log) keeps the smallest dot visible even when
    n_min == 1, where log(1) == 0 would otherwise give it zero size.
    """
    n = np.asarray(n, dtype=float)
    if n_max <= n_min:  # all courts have the same number of cases
        return np.full(n.shape, s_max)
    frac = (np.log(n) - np.log(n_min)) / (np.log(n_max) - np.log(n_min))
    return s_min + (s_max - s_min) * frac
 
 
df["dot_size"] = cases_to_size(df["n_cases"])
 
# Plot the biggest dots first so smaller ones land on top and stay visible
df = df.sort_values("n_cases", ascending=False)
 
 
def size_legend_handles(values=(1, 10, 100, 500)):
    """Proxy handles showing what each dot size means, in cases."""
    vals = [v for v in values if N_MIN <= v <= N_MAX]
    vals = sorted(set([N_MIN] + vals + [N_MAX]))
    return [
        Line2D([], [], linestyle="none", marker="o", color="red", alpha=0.5,
               markersize=np.sqrt(cases_to_size(v)),
               label=f"{int(v):,} cases")
        for v in vals
    ]
 
 
# %% CITY MARKERS
 
CITY_MARKER = "*"   # star: a different shape, not just a different colour
CITY_S_MAIN = 320   # marker area on the single map
CITY_S_GRID = 220   # marker area on the 45-panel grid
CITY_LW_MAIN = 1.4  # outline thickness on the single map
CITY_LW_GRID = 1.8  # outline thickness on the grid (thin lines vanish there)
 
 
def plot_cities(ax, s=CITY_S_MAIN, linewidth=CITY_LW_MAIN,
                labels=False, fontsize=11):
    """Draw the cities on ax as hollow outlined stars.
 
    facecolor="none" (the string, not None) leaves the marker unfilled so
    court dots underneath stay visible. zorder=5 keeps the stars on top,
    which matters because several cities sit on a court station.
    """
    for _, c in cities.iterrows():
        ax.scatter(c["lon"], c["lat"], marker=CITY_MARKER, s=s,
                   facecolor="none", edgecolor=c["color"],
                   linewidth=linewidth, zorder=5)
        if labels:
            ax.annotate(c["city"], (c["lon"], c["lat"]),
                        xytext=(7, 7), textcoords="offset points",
                        fontsize=fontsize, weight="bold",
                        color=c["color"], zorder=6)
 
 
def city_legend_handles(markersize=15, linewidth=CITY_LW_MAIN):
    """Proxy handles naming each city, for use where labels aren't drawn.
 
    Line2D uses markerfacecolor/markeredgecolor where scatter uses
    facecolor/edgecolor, but the effect is the same hollow star.
    """
    return [
        Line2D([], [], linestyle="none", marker=CITY_MARKER,
               markerfacecolor="none", markeredgecolor=c["color"],
               markeredgewidth=linewidth, markersize=markersize,
               label=c["city"])
        for _, c in cities.iterrows()
    ]
 
 
# %% MAP KENYA & COURTSTATIONS
 
# Build the GeoDataFrame from df, not cs: df has one row per
# courtstation & casetype and excludes courts with no cases.
gdf = gpd.GeoDataFrame(
    df,
    geometry=[Point(lon, lat) for lon, lat in zip(df["lon"], df["lat"])],
    crs="EPSG:4326"  # Set CRS (WGS 84)
)
 
# Plot the map
fig, ax = plt.subplots(figsize=(12, 12))
kenya_shp.boundary.plot(ax=ax, color="black", linewidth=1)  # Kenya outline
gdf.plot(ax=ax, color="red", markersize=gdf["dot_size"], alpha=0.5)
plot_cities(ax, s=CITY_S_MAIN, linewidth=CITY_LW_MAIN,
            labels=True)  # cities named on the map itself
''' # Add names of courtstations
for x, y, label in zip(courts["lon1"], courts["lat1"], courts["courtstation"]):
    ax.text(x, y, label, fontsize=10, ha='right', color='blue', weight='bold')
'''
ax.set_title("Court stations and Clusters")
ax.legend(handles=size_legend_handles(), title="Court station & case type",
          loc="lower right", labelspacing=1.2, frameon=True)
fig.savefig("Output/Clusters/kenya_cs_map.png", dpi=300)
plt.show()
 
 
# %% MAP KENYA AND OVERLAPPING CS
 
cl_tot = int(df['cluster'].max())  # Extract number of clusters
 
# Define number of columns and rows for subplots
nc = 5  # Number of columns
nr = 9  # Number of rows
# nc = 4  # Number of columns
# nr = 5  # Number of rows
 
# Create figure and subplots
fig, axes = plt.subplots(ncols=nc, nrows=nr, figsize=(51, 34))
 
# Subplots loop
for i in range(1, cl_tot + 1):
 
    # Create df with only cluster "i" (already sorted biggest-dot-first)
    df_i = df[df['cluster'] == i]
 
    # Convert DataFrame with cluster "i" to GeoDataFrame
    gdf_i = gpd.GeoDataFrame(
        df_i,
        geometry=[Point(lon, lat) for lon, lat in zip(df_i["lon"], df_i["lat"])],
        crs="EPSG:4326"
    )
 
    # Get subplot position
    row = (i - 1) // nc
    col = (i - 1) % nc
    ax = axes[row, col]
 
    # Plot Kenya boundary and court dots
    kenya_shp.boundary.plot(ax=ax, color="black", linewidth=1)
    gdf_i.plot(ax=ax, color="red", markersize=gdf_i["dot_size"], alpha=0.5)
 
    # Cities on every panel, but unlabelled: names go in one figure legend
    plot_cities(ax, s=CITY_S_GRID, linewidth=CITY_LW_GRID, labels=False)
 
    # Add title
    ax.set_title(f"Cluster {i}")
 
# Hide empty subplots
for i in range(cl_tot, nr * nc):
    row = i // nc
    col = i % nc
    axes[row, col].axis("off")
 
# Adjust spacing to minimize empty gaps
# bottom leaves room for the city legend, which now wraps to two rows
fig.subplots_adjust(left=0, right=0.5, top=1, bottom=0.05,
                    wspace=-0.65, hspace=0.12)
 
# One legend for the whole figure, centred under the panels.
# The panels occupy x = 0 to 0.5 of the figure (see right=0.5 above),
# so the legend is anchored at x = 0.25 rather than 0.5.
fig.legend(handles=city_legend_handles(markersize=22,
                                       linewidth=CITY_LW_GRID),
           title="Largest cities", loc="lower center",
           bbox_to_anchor=(0.25, 0.0), ncol=6, fontsize=20,
           title_fontsize=24, frameon=False)
 
# Apply tight layout
# plt.tight_layout()
 
# fig.set_title('Clusters')
fig.savefig("Output/Clusters/clusters_map.png", dpi=300)
 
# Show the plot
plt.show()
 
