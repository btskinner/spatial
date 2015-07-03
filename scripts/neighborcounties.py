
# FILE: neighborcounties.py
# AUTH: Benjamin Skinner
# INIT: 3 July 2015

# libraries
import pysal as ps
import pandas as pd

# data dirs
shp = '<dir>/tl_2013_us_county.shp'
dbf = '<dir>/tl_2013_us_county.dbf'

# read neighbors
print '\nfinding adjacent counties\n'
counties = ps.rook_from_shapefile(shp)

# get accompanying db information
db = ps.open(dbf)

# get origin fips in order
dbfipslist = [l for l in db[:,3]]

# init list
nbrs = []

# loop through each county
print '\nstoring adjacent counties\n'
for c in range(0, counties.n):

    # get origin county fips
    originfips = int(dbfipslist[c])

    # get fips for neighboring counties
    for n in counties.neighbors[c]:
        adj = int(db[n,3][0])
        nbrs.append((originfips, adj))

# place in data frame, sort, and write
print '\nplacing in dataframe and writing to disk\n'
df = pd.DataFrame(nbrs, columns = ['originfips', 'adjacentfips'])
df = df.sort(['originfips','adjacentfips'])
df.to_csv('../data/neighborcounties.csv', index = False)

