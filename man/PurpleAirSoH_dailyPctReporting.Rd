% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/PurpleAirSoH_dailyPctReporting.R
\name{PurpleAirSoH_dailyPctReporting}
\alias{PurpleAirSoH_dailyPctReporting}
\title{Daily reporting percentage}
\usage{
PurpleAirSoH_dailyPctReporting(pat = NULL, samplingInterval = 120)
}
\arguments{
\item{pat}{PurpleAir Timeseries \emph{pat} object.}

\item{samplingInterval}{The number of seconds between samples when the sensor 
is operating optimally.}
}
\description{
The number of sensor readings recorded per hour are summed over 
the course of a calendar day. This is then divided by the 
number of samples the sensor would record in an ideal day 
(\code{24 * 3600 / samplingInterval}) to return a percentage of each 
day that the sensor is reporting data.
}
\note{
Purple Air II sensors reporting after the June, 2019 firmware
upgrade report data every 120 seconds. Prior to the upgrade, data were 
reported every 80 seconds.
}
\examples{
library(AirSensor)

tbl <- 
  example_pat \%>\%
  PurpleAirSoH_dailyPctReporting(80) 

timeseriesTbl_multiPlot(tbl, ylim = c(0,101))
}
