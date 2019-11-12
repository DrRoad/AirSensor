#' @export
#' @importFrom rlang .data
#' @importFrom dplyr contains
#' 
#' @title Daily state of health
#' 
#' @param pat PurpleAir Timeseries \emph{pat} object.
#' @param SoH_functions Vector of function names. All the passed in functions 
#' must output tibbles with a daily `datetime` variable and must cover the same
#' period of time.
#' 
#' @description This function combines the output of the State of Health (SoH) 
#' function arguments into a single tibble. 
#' 
#' 
#' @examples  
#' SoH <- 
#'   example_pat_failure_B %>%
#'   pat_dailySoH() 
#' head(SoH)
#' #timeseriesTbl_multiplot(tbl, ylim = c(0,100))

pat_dailySoH <- function(
  pat = NULL,
  SoH_functions = c("PurpleAirSoH_dailyPctDC", 
                    "PurpleAirSoH_dailyPctReporting", 
                    "PurpleAirSoH_dailyPctValid", 
                    "PurpleAirSoH_dailyOtherFit", 
                    "PurpleAirSoH_dailyABFit")
) {
  
  # ----- Validate parameters --------------------------------------------------
  
  MazamaCoreUtils::stopIfNull(pat)
  
  if ( !pat_isPat(pat) )
    stop("Parameter 'pat' is not a valid 'pa_timeseries' object.")
  
  if ( pat_isEmpty(pat) )
    stop("Parameter 'pat' has no data.") 
  
  
  # ----- pat_dailySoH() ---------------------------------------------------
  
  # Initialize a list to store the output of each function
  SoH_list <- list()
  
  for (SoH_function in SoH_functions) {
    
    result <- try({
      # Isolate each passed in function
      FUN <- get(SoH_function)
    }, silent = TRUE)
    
    if ( ! "try-error" %in% class(result) ) {
      result <- try({
        # Run the pat through each function and store it in the list
        SoH_list[[SoH_function]] <- FUN(pat)
      }, silent = TRUE)
    }
    
    if ( "try-error" %in% class(result) ) {
      localTime <- lubridate::with_tz(pat$data$datetime, tzone = pat$meta$timezone)
      hour <- lubridate::hour(localTime)
      start <- lubridate::floor_date(localTime[ min(which(hour == 0)) ], unit = "hour")
      end <- lubridate::floor_date(localTime[ max(which(hour == 23)) ], unit = "hour")
      days <- dplyr::tibble(datetime = MazamaCoreUtils::dateSequence(start, end, timezone = pat$meta$timezone))
      SoH_list[[SoH_function]] <- rep_len(as.numeric(NA), length.out = length(days$datetime))
    }
    
  }
  
  # bind the all columns from the list into one dataframe with one datetime column
  SoH_tbl <- dplyr::bind_cols(SoH_list) %>%
    dplyr::select(unique("datetime"), 
                  contains("pm25"), 
                  contains("temperature"), 
                  contains("humidity"))
  
  return(SoH_tbl)
}











