# Spatial Data and Scripts

This directory contains spatial data files and the scripts that produce them. The data files are linked both to their GitHub repository location and a raw version to facilitate easy download. Scripts to produce the datasets can be found in the `./scripts` subdirectory of the repository.  

## Data

| File name | Script | Language | Description|
|:----------|:-----|:-------|:-----------|
|[`neighborcounties.csv`](./data/neighborcounties.csv) [[Raw]](https://raw.githubusercontent.com/btskinner/spatial/master/data/neighborcounties.csv)|`neighborcounties.py`|Python 3.5|Long data file that lists all adjacent counties (2010)|
|[`county_centers.csv`](./data/county_centers.csv) [[Raw]](https://raw.githubusercontent.com/btskinner/spatial/master/data/county_centers.csv)|`popcenters.r`|R 3.2.3|Geocoordinates for geographic and population-weighted centers in all counties (2000 and 2010)|
