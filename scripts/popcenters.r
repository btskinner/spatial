################################################################################
##
## PROJ: Population Centers
## FILE: popcenters.r
## AUTH: Benjamin Skinner
## INIT: 26 October 2014
##
################################################################################

## PURPOSE #####################################################################
##
## This file is used to create a matrix that gives the population centers for
## each county in 2000 and 2010. The data are already collected by the U.S.
## Census Bureau; this script just puts the files together.
##
## Raw data files come from U.S. Census files for 2000 and 2010:
##
## 2000: ftp://ftp.census.gov/geo/docs/reference/cenpop2000/county
## 2010: ftp://ftp.census.gov/geo/docs/reference/cenpop2010/county
##
################################################################################

## clear memory
rm(list=ls())

## libraries
libs <- c('dplyr','RCurl','readr')
lapply(libs, require, character.only=TRUE)

## directories
ddir <- '../data/'

################################################################################
## CENTERS: 2000 AND 2010
################################################################################

## raw file directory; files
urldir <- 'ftp://ftp.census.gov/geo/docs/maps-data/data/gazetteer/'
url1 <- paste0(urldir, 'county2k.zip');
url2 <- paste0(urldir, 'Gaz_counties_national.zip')

## set up temp folders and download
temp1 <- tempfile(); download.file(url1, temp1)
temp2 <- tempfile(); download.file(url2, temp2)

## read; fixed width for 2000; tab delimited for 2010
cen00 <- read_fwf(unz(temp1, 'county2k.txt', open='rb'),
                  fwf_widths(c(72,8,9,14,14,12,12,10,11)))
cen10 <- read_delim(unz(temp2, 'Gaz_counties_national.txt', open='rb'),
                    delim='\t')

## clean
cen00 <- cen00 %>%
    mutate(fips = substr(cen00$X1,3,7)) %>%
    select(fips, X9, X8) %>%
    rename(clon00 = X9,
           clat00 = X8)

cen10 <- cen10 %>%
    select(GEOID, INTPTLONG, INTPTLAT) %>%
    rename(fips = GEOID,
           clon10 = INTPTLONG,
           clat10 = INTPTLAT)

## join
cen <- cen00 %>% full_join(cen10, by='fips')

################################################################################
## POPCENTERS: 2000 and 2010
################################################################################

## need to get list of separated state files (2000)
url <- paste0('ftp://ftp.census.gov/geo/docs/reference/cenpop2000/county/')
fn <- unlist(strsplit(getURL(url, dirlistonly = TRUE), '\n'))

## download each in turn and store in list (will take a sec...ignore warnings)
stlist <- lapply(fn, FUN = function(x){read_csv(paste0(url,x),col_names=FALSE)})

## collapse list of dataframes into single dataframe
cp00 <- do.call(rbind, stlist)

## download raw file (2010)
url <- paste0('ftp://ftp.census.gov/geo/docs/reference/cenpop2010/county/',
              'CenPop2010_Mean_CO.txt')

## download/read file; lower names
cp10 <- read_csv(url)
names(cp10) <- tolower(names(cp10))

## ## merge state and country fips
## cp00$fips <- paste0(cp00$V1, cp00$V2)

## clean
cp00 <- cp00 %>%
    mutate(fips = paste0(cp00$X1, cp00$X2)) %>%
    select(fips, X6, X5) %>%
    rename(pclon00 = X6,
           pclat00 = X5)

## subset table based on what is needed; rename; make numeric
## cp00 <- cbind(cp00$fips, cp00$V6, cp00$V5)
## colnames(cp00) <- c('fips','pclon00','pclat00')
## cp00 <- apply(cp00, 2, FUN = function(x){as.numeric(x)})

## clean
cp10 <- cp10 %>%
    mutate(fips = paste0(cp10$statefp, cp10$countyfp)) %>%
    select(fips, longitude, latitude) %>%
    rename(pclon10 = longitude,
           pclat10 = latitude)

## ## merge state and country fips
## cp10$fips <- paste0(cp10$statefp, cp10$countyfp)

## ## subset table based on what is needed; rename; make numeric
## cp10 <- cbind(cp10$fips, cp10$longitude, cp10$latitude)
## colnames(cp10) <- c('fips','pclon10','pclat10')
## cp10 <- apply(cp10, 2, FUN = function(x){as.numeric(x)})

## merge
popcen <- cp00 %>% full_join(cp10, by='fips')

################################################################################
## MERGE ALL
################################################################################

## merge
centroids <- cen %>% full_join(popcen, by='fips')

## clean and sort
centroids <- centroids %>%
    filter(fips != 'NANA',
           fips != '6985',
           as.numeric(fips) <= 57000) %>%
    arrange(fips)

################################################################################
## OUTPUT
################################################################################

write_csv(centroids, paste0(ddir, 'county_centers.csv'))

## -----------------------------------------------------------------------------
## END FILE
################################################################################
