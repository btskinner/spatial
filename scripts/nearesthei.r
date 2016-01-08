################################################################################
##
## PROJ: Nearest higher education institution to county population center
## FILE: nearesthei.r
## AUTH: Benjamin Skinner
## INIT: 29 December 2015
##
################################################################################

## PURPOSE #####################################################################
##
## This file is used to find the nearest higher education institution to
## every county population center in the United States.
##
## Latitude and longitude data on colleges come from the IPEDS database.
## Population center data comes from the United States Census Bureau as put
## together by the <popcenters.r> script.
##
################################################################################

## clear memory
rm(list=ls())

## required library
libs <- c('dplyr','geosphere','readr')
lapply(libs, require, character.only=TRUE)

## directory paths
ddir <- '../data/'

## formula (meters to miles)
m2miles <- 0.0006214

## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## Functions
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

getIpeds <- function(year) {

    ## --------------------------------------
    ## This function downloads and subsets HD
    ## IPEDS files
    ## --------------------------------------

    ## file to retrieve
    f <- paste0('HD',year)

    ## download file
    url <- paste0('http://nces.ed.gov/ipeds/datacenter/data/',f,'.zip')
    temp <- tempfile()
    download.file(url,temp,method='internal')

    ## read file; lower names
    df <- read_csv(unz(temp,paste0(tolower(f),'.csv')))
    names(df) <- tolower(names(df))

    ## subset
    df <- df %>%
        select(unitid,countycd,longitud,latitude,sector) %>%
        mutate(fouryr = as.integer(sector %in% c(1,2,3)),
               twoyr = as.integer(sector %in% c(4,5,6)),
               pub = as.integer(sector %in% c(1,4,7)),
               pnp = as.integer(sector %in% c(2,5,8)),
               pfp = as.integer(sector %in% c(3,6,9)),
               fips = countycd,
               stfips = floor(fips/1000)) %>%
        filter(!is.na(longitud),
               !is.na(latitude)) %>%
        filter(fouryr == 1 | twoyr == 1) %>%
        select(-c(countycd,sector))

    ## return df dataframe
    return(df)
}

nearestHei <- function(hei_df,county_df) {

    ## --------------------------------------
    ## This function computes the distances
    ## between each county population
    ## centroid and HEI and returns a data
    ## frame with the nearest HEI to each
    ## county centroid.
    ## --------------------------------------

    ## sort dataframes
    hei_df <- hei_df %>% arrange(unitid)
    county_df <- county_df %>% arrange(fips)

    ## grab vectors of unitid and county fips
    fips <- county_df$fips
    unitid <- hei_df$unitid

    ## matrix of county lon/lat
    cmat <- data.matrix(county_df %>% select(pclon10,pclat10))

    ## matrix of hei lon/lat
    hmat <- data.matrix(hei_df %>% select(longitud,latitude))

    ## calculate distances (may take a minute)
    dist <- distm(cmat,hmat)

    ## add row and column names
    rownames(dist) <- fips
    colnames(dist) <- unitid

    ## --------------------------------------
    ## Across states
    ## --------------------------------------

    ## get nearest unitid and distance for each county
    nearest <- apply(dist, 1, FUN=function(x){
        index <- which.min(x)
        return(cbind(names(x[index]),x[index]*m2miles))
    })

    ## transpose and save as dataframe
    nearest <- data.frame(t(nearest),stringsAsFactors=FALSE)

    ## clean up
    all <- nearest %>%
        mutate(fips = rownames(nearest),
               unitid = as.integer(X1),
               miles = round(as.numeric(X2),2),
               limit_instate = 0) %>%
        select(fips,unitid,miles,limit_instate)

    ## --------------------------------------
    ## Instate only
    ## --------------------------------------

    ## number of observations for each dataframe
    ncols <- nrow(hei_df)
    nrows <- nrow(county_df)

    ## build matrices of state fips; transpose 2nd for overlay
    countyst <- matrix(rep(county_df$stfips,ncols),ncol=ncols)
    heist <- t(matrix(rep(hei_df$stfips,nrows),ncol=nrows))

    ## mask: 1==same state, 0==different
    mask <- ifelse(countyst == heist, TRUE, FALSE)

    ## where FALSE, make Inf (we want smallest number later)
    dist[!mask] <- Inf

     ## get nearest unitid and distance for each county
    nearest <- apply(dist, 1, FUN=function(x){
        index <- which.min(x)
        return(cbind(names(x[index]),x[index]*m2miles))
    })

    ## transpose and save as dataframe
    nearest <- data.frame(t(nearest),stringsAsFactors=FALSE)

    ## clean up
    ins <- nearest %>%
        mutate(fips = rownames(nearest),
               unitid = as.integer(X1),
               miles = round(as.numeric(X2),2),
               limit_instate = 1) %>%
        select(fips,unitid,miles,limit_instate)

    ## combine and arrange
    nearest <- data.frame(rbind(all,ins)) %>%
        mutate(fips = as.integer(fips)) %>%
        arrange(fips)

    ## return
    return(nearest)
}

## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## Read in population center data
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

## read data
popcen <- read_csv(paste0(ddir,'county_centers.csv'))

## subset to 2010 population centers
popcen <- popcen %>%
    mutate(fips = as.integer(fips),
           stfips = floor(fips/1000)) %>%
    filter(!is.na(pclon10),
           !is.na(pclat10)) %>%
    select(fips,stfips,pclon10,pclat10)

## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## Run
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

## IPEDS years to use
years <- c(2010:2014)

## init list
yearlist <- list()

## loop through years
for(y in years) {

    ## get appropriate IPEDS file
    hei <- getIpeds(y)

    ## Combinations
    ##
    ## (1) Public four-year
    ## (2) Public two-year
    ## (3) Private four-year, non-profit
    ## (4) Private two-year, non-profit
    ## (5) Private four-year, for-profit
    ## (6) Private two-year, for-profit
    ## (7) Any institution

    ## set up combination vectors
    combo <- list(c(0,1,0,1,0,0),       # (1)
                  c(0,0,1,1,0,0),       # (2)
                  c(0,1,0,0,1,0),       # (3)
                  c(0,0,1,0,1,0),       # (4)
                  c(0,1,0,0,0,1),       # (5)
                  c(0,0,1,0,0,1),       # (6)
                  c(1,0,0,0,0,0))       # (7)

    ## init list
    dflist <- list()

    for(c in 1:length(combo)) {

        message(paste0('\nCombination ',c))

        if(c != length(combo)) {
            ## subset hei data
            hei_sub <- hei %>%
                filter(fouryr == combo[[c]][2],
                       twoyr == combo[[c]][3],
                       pub == combo[[c]][4],
                       pnp == combo[[c]][5],
                       pfp == combo[[c]][6])
        }

        ## get nearest
        message('\nComputing nearest HEIs')
        df <- nearestHei(hei_sub, popcen)

        ## add indicator variables
        df <- df %>%
            mutate(year = y,
                   any = combo[[c]][1],
                   limit_fouryr = combo[[c]][2],
                   limit_twoyr = combo[[c]][3],
                   limit_pub = combo[[c]][4],
                   limit_pnp = combo[[c]][5],
                   limit_pfp = combo[[c]][6])

        ## add df to dflist
        dflist[[c]] <- df
    }

    ## collapse list
    message('\nCollapsing list into single dataframe')
    out <- do.call('rbind', dflist)

    ## arrange
    yearlist[[as.character(y)]] <- out %>% arrange(fips,year)
}

## collapse year list into single dataframe
df <- do.call('rbind', yearlist)

## some states don't have all types of institutions; drop if mile is Inf
df <- df %>% filter(!is.infinite(miles))

## arrange
df <- df %>% arrange(fips,year)

## write to disk
write_csv(df,paste0(ddir,'nearest_hei.csv'))

## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## END FILE
## =============================================================================
