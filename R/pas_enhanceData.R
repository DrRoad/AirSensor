#' @export
#' @importFrom MazamaCoreUtils logger.isInitialized logger.trace logger.warn logger.error logger.fatal
#' @importFrom rlang .data
#' 
#' @title Enhance synoptic data from PurpleAir
#' 
#' @description Enhance raw synoptic data from PurpleAir to create a generally 
#' useful dataframe.
#'
#' Steps include:
#'
#' 1) Replace variable with more consistent, more human readable names.
#'
#' 2) Add spatial metadata for each sensor including:
#' \itemize{
#'   \item{timezone -- olson timezone}
#'   \item{countryCode -- ISO 3166-1 alpha-2}
#'   \item{stateCode -- ISO 3166-2 alpha-2}
#'   \item{airDistrict -- CARB air districts}
#' }
#'
#' 3) Convert data types from character to \code{POSIXct} and \code{numeric}.
#'
#' 4) Add distance and monitorID for the two closest PWFSL monitors
#' 
#' 5) Add additional metadata items:
#' \itemize{
#' \item{sensorManufacturer = "Purple Air"}
#' \item{targetPollutant = "PM"}
#' \item{technologyType = "consumer-grade"}
#' \item{communityRegion -- (where known)}
#' }
#'
#' Filtering by country can speed up the process of enhancement and may be
#' performed by providing a vector ISO country codes to the \code{countryCodes} 
#' argument. By default, no subsetting is performed.
#'
#' Setting \code{outsideOnly = TRUE} will return only those records marked as 
#' 'outside'.
#' 
#' @note For data obtained on July 28, 2018 this will result in removal of all 
#' 'B' channels, even those whose parent 'A' channel is marked as 'outside'. 
#' This is useful if you want a quick, synoptic view of the network, e.g. for a 
#' map.
#' 
#' @param pas_raw Dataframe returned by \code{pas_downloadParseRawData()}.
#' @param countryCodes ISO country codes used to subset the data.
#' @param includePWFSL Logical specifying whether to calculate distances from 
#' PWFSL monitors.
#' 
#' @return Enhanced Dataframe of synoptic PurpleAir data.
#' 
#' @seealso \link{pas_downloadParseRawData}
#' 
#' @examples
#' \donttest{
#' library(AirSensor)
#' 
#' initializeMazamaSpatialUtils()
#' 
#' pas <- pas_enhanceData(example_pas_raw, 'US')
#' 
#' setdiff(names(pas), names(example_pas_raw))
#' setdiff(names(example_pas_raw), names(pas))
#' 
#' if ( interactive() ) {
#'   View(pas[1:100,])
#' }
#' }

pas_enhanceData <- function(
  pas_raw = NULL,
  countryCodes = NULL,
  includePWFSL = TRUE
) {
  
  # ----- Validate Parameters --------------------------------------------------
  
  MazamaCoreUtils::stopIfNull(pas_raw)
  MazamaCoreUtils::stopIfNull(countryCodes)
  
  if ( !("data.frame" %in% class(pas_raw)) )
    stop("parameter 'pas_raw' parameter is not a dataframe")
  
  # Guarantee uppercase codes
  countryCodes <- toupper(countryCodes)
  
  # Validate countryCodes
  if ( any(!(countryCodes %in% countrycode::codelist$iso2c)) ) 
    stop("parameter 'countryCodes' has values that are not recognized as ISO-2 country codes")
  
  if ( !is.logical(includePWFSL) )
    stop("parameter 'includePWFSL' is not a logical value")
  
  # ----- Discard unwanted columns ---------------------------------------------
  
  # Prior to 2019-09-05, a "State" column existed
  
  # On 2019-09-05, the data columns looked like this:
  #
  # > sort(names(pas_raw))
  # [1] "A_H"                              "AGE"                              "DEVICE_LOCATIONTYPE"             
  # [4] "Flag"                             "Hidden"                           "humidity"                        
  # [7] "ID"                               "isOwner"                          "Label"                           
  # [10] "lastModified"                     "LastSeen"                         "Lat"                             
  # [13] "Lon"                              "ParentID"                         "pm"                              
  # [16] "PM2_5Value"                       "pressure"                         "temp_f"                          
  # [19] "THINGSPEAK_PRIMARY_ID"            "THINGSPEAK_PRIMARY_ID_READ_KEY"   "THINGSPEAK_SECONDARY_ID"         
  # [22] "THINGSPEAK_SECONDARY_ID_READ_KEY" "timeSinceModified"                "Type"                            
  # [25] "v"                                "v1"                               "v2"                              
  # [28] "v3"                               "v4"                               "v5"                              
  # [31] "v6"                              
  
  # On 2020-04-14, the data columns look like this:
  #
  # [1] "A_H"                              "AGE"                              "DEVICE_LOCATIONTYPE"             
  # [4] "Flag"                             "Hidden"                           "humidity"                        
  # [7] "ID"                               "isOwner"                          "Label"                           
  # [10] "lastModified"                     "LastSeen"                         "Lat"                             
  # [13] "Lon"                              "Ozone1"                           "ParentID"                        
  # [16] "pm"                               "PM2_5Value"                       "pressure"                        
  # [19] "temp_f"                           "THINGSPEAK_PRIMARY_ID"            "THINGSPEAK_PRIMARY_ID_READ_KEY"  
  # [22] "THINGSPEAK_SECONDARY_ID"          "THINGSPEAK_SECONDARY_ID_READ_KEY" "timeSinceModified"               
  # [25] "Type"                             "v"                                "v1"                              
  # [28] "v2"                               "v3"                               "v4"                              
  # [31] "v5"                               "v6"                               "Voc"                             
  
  # On 2020-09-15, the data columns look like this: ("Voc" has been dropped)
  #
  # > sort(names(pas_raw))
  # [1] "A_H"                              "AGE"                              "DEVICE_LOCATIONTYPE"             
  # [4] "Flag"                             "Hidden"                           "humidity"                        
  # [7] "ID"                               "isOwner"                          "Label"                           
  # [10] "lastModified"                     "LastSeen"                         "Lat"                             
  # [13] "Lon"                              "Ozone1"                           "ParentID"                        
  # [16] "pm"                               "PM2_5Value"                       "pressure"                        
  # [19] "temp_f"                           "THINGSPEAK_PRIMARY_ID"            "THINGSPEAK_PRIMARY_ID_READ_KEY"  
  # [22] "THINGSPEAK_SECONDARY_ID"          "THINGSPEAK_SECONDARY_ID_READ_KEY" "timeSinceModified"               
  # [25] "Type"                             "v"                                "v1"                              
  # [28] "v2"                               "v3"                               "v4"                              
  # [31] "v5"                               "v6"    
  
  
  # NOTE:  This should no longer be necessary as "State" is no longer included
  if ( "State" %in% names(pas_raw) ) {
    pas_raw$State <- NULL
  }
  
  # Removing "pm" because it is redundant with the value in "v"
  if ( "pm" %in% names(pas_raw) ) {
    pas_raw$pm <- NULL
  }
  
  # ----- Rename columns -------------------------------------------------------
  
  # Rename some things to have consistent lowerCamelCase and better human names
  # based on the information in the document "Using PurpleAir Data".
  pas <-
    pas_raw %>%
    dplyr::rename(
      parentID = .data$ParentID,
      label = .data$Label,
      latitude = .data$Lat,
      longitude = .data$Lon,
      pm25 = .data$PM2_5Value,
      lastSeenDate = .data$LastSeen,
      sensorType = .data$Type,
      flag_hidden = .data$Hidden,
      flag_highValue = .data$Flag,
      flag_attenuation_hardware = .data$A_H,
      temperature = .data$temp_f,
      age = .data$AGE,
      pm25_current = .data$v,
      pm25_10min = .data$v1,
      pm25_30min = .data$v2,
      pm25_1hr = .data$v3,
      pm25_6hr = .data$v4,
      pm25_1day = .data$v5,
      pm25_1week = .data$v6,
      statsLastModifiedDate = .data$lastModified,
      statsLastModifiedInterval = .data$timeSinceModified
    )
  
  # ----- Add spatial metadata -------------------------------------------------
  
  pas <- pas_addSpatialMetadata(pas, countryCodes)
  
  # ----- Add unique identifiers -----------------------------------------------
  
  pas <- pas_addUniqueIDs(pas)
  
  # ----- Add an Air district --------------------------------------------------
  
  pas <- pas_addAirDistrict(pas)
  
  # ----- Convert times to POSIXct ---------------------------------------------
  
  pas$lastSeenDate <- as.POSIXct(pas$lastSeenDate,
                                 tz = "UTC",
                                 origin = lubridate::origin)
  
  pas$statsLastModifiedDate <- as.POSIXct(pas$statsLastModifiedDate / 1000,
                                          tz = "UTC",
                                          origin = lubridate::origin)
  
  # ----- Convert to proper type -----------------------------------------------
  
  pas$ID <- as.character(pas$ID)
  pas$parentID <- as.character(pas$parentID)
  pas$pm25 <- as.numeric(pas$pm25)
  pas$pm25_current <- as.numeric(pas$pm25_current)
  pas$flag_hidden <- ifelse(pas$flag_hidden == 'true', TRUE, FALSE)
  pas$flag_highValue <- ifelse(pas$flag_highValue == 1, TRUE, FALSE)
  pas$flag_attenuation_hardware <- ifelse(pas$flag_attenuation_hardware == 'true', TRUE, FALSE)
  pas$temperature <- as.numeric(pas$temperature)
  pas$humidity <- as.numeric(pas$humidity)
  pas$pressure <- as.numeric(pas$pressure)
  
  # ----- Convert to internally standard units ---------------------------------
  
  pas$statsLastModifiedInterval <- pas$statsLastModifiedInterval / 1000   # seconds
  
  # Round values to reflect resolution as specified in:
  #   https://www.purpleair.com/sensors
  
  # TODO:  Figure out why rounding breaks outlier detection
  
  # pas$pm25 <- round(pas$pm25)
  # pas$pm25_current <- round(pas$pm25_current)
  # pas$temperature <- round(pas$temperature)
  # pas$humidity <- round(pas$humidity)
  # pas$pressure <- round(pas$pressure)
  
  # ----- Find nearby PWFSL monitors -------------------------------------------
  
  # NOTE:  These columns need to exist even if they are all missing
  pas$pwfsl_closestDistance <- as.numeric(NA)
  pas$pwfsl_closestMonitorID <- as.character(NA)
  
  if ( includePWFSL ) {
    
    if ( logger.isInitialized() ) {
      logger.trace("Adding PWFSL monitor metadata")
    }
    if ( !exists('pwfsl') ) {
      pwfsl <- PWFSLSmoke::loadLatest()
    }
    for ( i in seq_len(nrow(pas)) ) {
      distances <- PWFSLSmoke::monitor_distance(pwfsl,
                                                pas$longitude[i],
                                                pas$latitude[i])
      minDistIndex <- which.min(distances)
      pas$pwfsl_closestDistance[i] <- distances[minDistIndex] * 1000 # To meters
      pas$pwfsl_closestMonitorID[i] <- names(distances[minDistIndex])
    }
    
  }
  
  # ----- Addditional metadata per SCAQMD request ------------------------------
  
  pas$sensorManufacturer <- "Purple Air"
  pas$targetPollutant <- "PM"
  pas$technologyType <- "consumer-grade"
  
  # ----- Add communityRegion --------------------------------------------------
  
  pas <- pas_addCommunityRegion(pas)
  
  # ----- Return ---------------------------------------------------------------
  
  # Guarantee the class name still exists
  class(pas) <- union('pa_synoptic', class(pas))
  
  return(pas)
  
}
