# ==============================================================================
#
# FILE: neighborcounties.py
# AUTH: Benjamin Skinner (updated by Olivia Morales)
# INIT: 3 July 2015 (up. 17 March 2022)
#
# ==============================================================================

## updated libraries/function in scripts to reflect recent PySAL 2.0 release; all details 
## on PySAL 2.0 are at https://github.com/pysal/pysal/blob/master/MIGRATING.md

# libraries
import pandas as pd
import numpy as np
import pysal as ps
import libpysal as lps
from libpysal.weights import Rook
import os


# data dirs
shp = '../data/tl_2010_us_county10.shp'
dbf = '../data/tl_2010_us_county10.dbf'

# --------------------------------------------------------------------
# Store neighboring counties
# --------------------------------------------------------------------

# message
print('\nFinding adjacent counties.\n')

# read in data, finding counties that share borders
## change in function syntax (PySAL 2.0)

counties = lps.weights.Rook.from_shapefile(shp)

# store neighbors dictionary
neighbors = counties.neighbors

# convert dict to dataframe
neighbors = pd.DataFrame.from_dict(neighbors, orient='index')

# id value is the index value
neighbors['id'] = neighbors.index

# convert from wide to long
neighbors = pd.melt(neighbors, id_vars='id', value_name='adjid')

# drop number of neighboring counties
neighbors = neighbors.drop('variable', axis=1)

# drop values with NaN (flotsam from melt)
neighbors = neighbors[np.isfinite(neighbors['adjid'])]

# sort by ids
neighbors = neighbors.sort_values(['id','adjid'])

# --------------------------------------------------------------------
# Create concordance dataframe
# --------------------------------------------------------------------

# message
print('\nCreating concordance dataframe.\n')

# get accompanying database information
## change in function syntax (PySAL 2.0)

db = lps.io.open(dbf)

# select fips column
concordance = pd.DataFrame(db.by_col_array(['GEOID10']), columns=['fips'])

# create id for merge
concordance['id'] = concordance.index

# --------------------------------------------------------------------
# Merge to convert ids to fips codes
# --------------------------------------------------------------------

# message
print('\nConverting IDs to FIPS codes.\n')

# merge to get origin fips values
df = pd.merge(neighbors, concordance, how='left', left_on='id', right_on='id')
df = df.rename(columns = {'fips': 'orgfips'})

# merge to get adjacent fips values
df = pd.merge(df, concordance, how='left', left_on='adjid', right_on='id')
df = df.rename(columns = {'fips': 'adjfips'})

# subset to just origin and adjacent fips values; sort
df = df[['orgfips','adjfips']]
df = df.sort_values(['orgfips', 'adjfips'])

# --------------------------------------------------------------------
# Create indicator for same state counties
# --------------------------------------------------------------------

# message
print('\nCreating indicator variable for same state counties.\n')

# convert to floats
df = df[['orgfips', 'adjfips']].astype(float)

# add indicator for county in same state
df['instate'] = (np.floor(df['orgfips']/1000)==np.floor((df['adjfips']/1000)))
df['instate'] = df['instate'].astype(int)

# convert back to string, adding leading zeros
df['orgfips'] = df['orgfips'].astype(int).astype(str).str.zfill(5)
df['adjfips'] = df['adjfips'].astype(int).astype(str).str.zfill(5)

# --------------------------------------------------------------------
# Write to disk
# --------------------------------------------------------------------

# message
print('\nWriting to disk.\n')

# final sort
df = df.sort_values(['orgfips', 'adjfips'])

# write to csv
df.to_csv('../data/neighborcounties.csv', index=False)

# --------------------------------------------------------------------
# End file
# ====================================================================

