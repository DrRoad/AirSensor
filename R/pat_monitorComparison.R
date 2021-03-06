#' @export
#' @importFrom rlang .data
#' 
#' @title Comparison of Purple Air and federal monitoring data
#' 
#' @param pat PurpleAir Timeseries \emph{pat} object.
#' @param FUN Algorithm applied to \emph{pat} object for hourly aggregation and 
#' quality control. See \code{pat_createAirSensor()} for more details.
#' @param distanceCutoff Numeric distance (km) cutoff for nearest PWFSL monitor.
#' @param ylim Vector of (lo,hi) y-axis limits. 
#' @param replaceOutliers Logical specifying whether replace outliers in the
#'   \emph{pat} object.
#' @param timezone Olson timezone used for the time axis. (Defaults to 
#' \code{pat} local time.)
#' 
#' @description Creates and returns a ggplot object that plots raw \emph{pat}
#' data, hourly aggregated \emph{pat} data and hourly data from the nearest
#' federal monitor from the PWFSL database.
#' 
#' @return A ggplot object.
#' 
#' @examples
#' \donttest{
#' library(AirSensor)
#' 
#' pat_monitorComparison(example_pat)
#' }
#' 

pat_monitorComparison <- function(
  pat = NULL,
  FUN = AirSensor::PurpleAirQC_hourly_AB_01,
  distanceCutoff = 20, 
  ylim = NULL, 
  replaceOutliers = TRUE,
  timezone = NULL
) {
  
  # ----- Configurable plot options --------------------------------------------
  
  raw_size <- 1
  raw_shape <- 15
  raw_stroke <- 1.0
  raw_alpha <- 0.5
  raw_color <- "gray80"
  hourly_size <- 2
  hourly_shape <- 1
  hourly_stroke <- 0.6
  hourly_alpha <- 1
  pa_color <- "purple2"
  pwfsl_color <- "grey10"
  
  # ----- Validate parameters --------------------------------------------------
  
  MazamaCoreUtils::stopIfNull(pat)
  
  if ( !pat_isPat(pat) )
    stop("Parameter 'pat' is not a valid 'pa_timeseries' object.")
  
  if ( pat_isEmpty(pat) )
    stop("Parameter 'pat' has no data.")
  
  # Remove any duplicate data records
  pat <- pat_distinct(pat)
  
  # Use sensor timezone as default
  if ( is.null(timezone) )
    timezone <- pat$meta$timezone
  
  # ----- Assemble data --------------------------------------------------------
  
  if ( replaceOutliers ) {
    pat <- pat_outliers(pat, showPlot = FALSE, replace = TRUE) 
  }
  
  # Add "source" column to pat$data so it can be used by ggplot2
  pat$data$source <- "PA raw"
  
  # Get the hourly aggregated data
  paHourly_data <-
    pat %>% 
    pat_createAirSensor(
      parameter = 'pm25', 
      FUN = FUN, 
      min_count = 20
    ) %>%
    PWFSLSmoke::monitor_extractData()
  
  names(paHourly_data) <- c("datetime", "PA hourly")
  
  tlim <- range(paHourly_data$datetime)
  
  # If no monitors within cutoff distance
  if ( pat$meta$pwfsl_closestDistance > distanceCutoff * 1000 ) {
    
    tidy_data <-
      paHourly_data %>%
      tidyr::gather("source", "pm25", -.data$datetime)
    
    title <- paste0(
      "Sensor / Reference Monitor comparison -- PurpleAir: \"",
      pat$meta$label,
      "\" No reference monitors found within ", 
      distanceCutoff, 
      " km"
    )
    
    # If monitor within the cutoff distance
  } else {
    
    # Get the PWFSL monitor data
    monitorID <- pat$meta$pwfsl_closestMonitorID
    pwfsl_monitor <-
      PWFSLSmoke::monitor_load(tlim[1], tlim[2], monitorIDs = monitorID) %>%
      PWFSLSmoke::monitor_subset(tlim = tlim)
    pwfsl_data <-
      pwfsl_monitor %>%
      PWFSLSmoke::monitor_extractData()
    
    names(pwfsl_data) <- c("datetime", "Monitor")
    
    # Get monitor names for labeling
    pwfsl_siteName <- pwfsl_monitor$meta$siteName
    pwfsl_agencyName <- pwfsl_monitor$meta$agencyName
    
    # Create a tidy dataframe appropriate for ggplot
    tidy_data <-
      dplyr::full_join(paHourly_data, pwfsl_data, by = "datetime") %>%
      tidyr::gather("source", "pm25", -.data$datetime)
    
    title <- paste0(
      "Sensor / Reference Monitor comparison -- PurpleAir: \"",
      pat$meta$label,
      "\" is ",
      round((pat$meta$pwfsl_closestDistance/1000),1),
      " km from Monitor: \"",
      pwfsl_siteName,
      "\""
    )
    
  }
  
  # ----- General Plot styling -------------------------------------------------
  
  # NOTE:  Convert time axes to the selected timezone for proper formatting
  # NOTE:  by ggplot2.
  tidy_data$datetime <- lubridate::with_tz(tidy_data$datetime, tzone = timezone)
  pat$data$datetime <- lubridate::with_tz(pat$data$datetime, tzone = timezone)
  
  if ( is.null(ylim) ) {
    dataMin <- min(c(0, pat$data$pm25_A, pat$data$pm25_B, tidy_data$pm25), 
                   na.rm = TRUE)
    dataMax <- max(c(pat$data$pm25_A, pat$data$pm25_B, tidy_data$pm25), 
                   na.rm = TRUE)
    ylim <- c(dataMin, dataMax)
  }
  
  # Labels
  yearLabel <- strftime(pat$data$datetime[1], "%Y (%Z)", tz = timezone)
  
  cols <- c(
    "PA raw" = raw_color, 
    "PA hourly" = pa_color, 
    "Monitor" = pwfsl_color
  )
  
  shapes = c(
    "PA raw" = raw_shape, 
    "PA hourly" = hourly_shape, 
    "Monitor" = hourly_shape
  )
  
  sizes = c(
    "PA raw" = raw_size, 
    "PA hourly" = hourly_size, 
    "Monitor" = hourly_size
  )
  
  # ----- ggplot ---------------------------------------------------------------
  
  pm25_plot <-
    pat$data %>%
    ggplot2::ggplot() +
    ggplot2::geom_point(
      ggplot2::aes(
        x = .data$datetime, 
        y = .data$pm25_A,
        color = .data$source, 
        shape = .data$source,
        size = .data$source
      ),
      alpha = raw_alpha
    ) +
    ggplot2::geom_point(
      ggplot2::aes(
        x = .data$datetime, 
        y = .data$pm25_B, 
        color = .data$source, 
        shape = .data$source,
        size = .data$source
      ),
      alpha = raw_alpha
    ) +
    ggplot2::geom_point(
      data = tidy_data,
      ggplot2::aes(
        x = .data$datetime, 
        y = .data$pm25, 
        color = .data$source, 
        shape = .data$source,
        size = .data$source
      ),
      stroke = hourly_stroke,
      alpha = hourly_alpha
    ) +
    ggplot2::scale_color_manual(
      values = cols, 
      breaks = c("PA raw", "PA hourly", "Monitor")
    ) +
    ggplot2::scale_shape_manual(
      values = shapes,
      breaks = c("PA raw", "PA hourly", "Monitor")
    ) +
    ggplot2::scale_size_manual(
      values = sizes,
      breaks = c("PA raw", "PA hourly", "Monitor")
    ) +
    ggplot2::ylim(ylim) +
    ggplot2::scale_x_datetime(breaks = '1 day', date_labels = '%b %d') +
    ggplot2::xlab(yearLabel) + 
    ggplot2::ylab("PM2.5 (\u03bcg / m\u00b3)") +
    ggplot2::theme_light() + 
    ggplot2::ggtitle(title)
  
  # ----- Return ---------------------------------------------------------------
  
  return(pm25_plot)
  
}

