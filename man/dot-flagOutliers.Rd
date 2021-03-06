% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/utils-outliers.R
\name{.flagOutliers}
\alias{.flagOutliers}
\title{Flag outliers in vectorized data}
\usage{
.flagOutliers(df = NULL, parameter = NULL, windowSize = 23, thresholdMin = 8)
}
\arguments{
\item{df}{A data frame.}

\item{parameter}{The data frame parameter to use for outlier detection.}

\item{windowSize}{The size of the rolling window.}

\item{thresholdMin}{The minimum threshold value used to detect outliers.}
}
\value{
A dataframe with an additional column identifying outliers.
}
\description{
This function uses Hampel filter outlier detection to flag
outliers in \code{parameter} column of the incoming dataframe. The 
\code{windowSize} and \code{thresholdMin} parameters as passed on to the
\code{seismicRoll::findOutliers} function.

An additional boolean column named \code{<parameter>_outlierFlag} is added
to the dataframe. This column will have \code{TRUE} whenever an outlier is
detected for the chosen \code{parameter}.

See \code{seismicRoll::findOutliers} for further details.
}
\keyword{internal}
