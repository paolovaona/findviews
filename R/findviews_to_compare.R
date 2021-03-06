########################################
#### Distance between Distributions ####
########################################
# Implementation of the Eclidean distance between histograms
distribution_distance <- function(s1, s2){
   if (length(s1) == 0 | length(s2) == 0) return(NA_real_)
   if (all(is.na(s1)) | all(is.na(s2))) return(NA_real_)
   stopifnot(is.factor(s1) & is.factor(s2))

   s1 <- stats::na.omit(s1)
   s2 <- stats::na.omit(s2)

   table1 <- safe_table(s1)[]/length(s1)
   table2 <- safe_table(s2)[]/length(s2)

   table1 <- merge_table_names(table1, table2)
   table2 <- merge_table_names(table2, table1)

   table1 <- table1[sort(names(table1))]
   table2 <- table2[sort(names(table2))]
   stopifnot(names(table1) == names(table2))

   d <- sqrt(sum((table2 - table1)^2))
   return(d)
}

# Multivariate distance between histograms
multi_distribution_distance <- function(df1, df2){
   stopifnot(is.data.frame(df1) & all(sapply(df1, is.factor)))
   stopifnot(is.data.frame(df2) & all(sapply(df2, is.factor)))
   stopifnot(names(df1) == names(df2))

   if (nrow(df1) == 0 | nrow(df1) == 0) return(0)

   s1 <- merge_factors(df1)
   s2 <- merge_factors(df2)

   distribution_distance(s1, s2)
}

##########################
#### Scoring function ####
##########################
score_comparison_cat <- function(views, group1, group2, data){
   stopifnot(is.list(views))
   stopifnot(is.data.frame(data), nrow(data) >= 2)
   stopifnot(all(unlist(views) %in% names(data)))
   stopifnot(all(sapply(data, is.factor)))
   stopifnot(is.logical(group1), length(group1) == nrow(data), sum(group1) > 0)
   stopifnot(is.logical(group2), length(group2) == nrow(data), sum(group2) > 0)

   if (length(views) == 0) return(numeric(0))

   scores <- sapply(views, function(cols){
      multi_distribution_distance(
         data[group1,cols,drop=F],
         data[group2,cols,drop=F]
      )
   })

   scores
}

score_comparison_num <- function(views, group1, group2, data){
   stopifnot(is.list(views))
   stopifnot(is.data.frame(data), nrow(data) >= 2)
   stopifnot(all(unlist(views) %in% names(data)))
   stopifnot(is.logical(group1), length(group1) == nrow(data), sum(group1) > 0)
   stopifnot(is.logical(group2), length(group2) == nrow(data), sum(group2) > 0)

   if (length(views) == 0) return(numeric(0))

   # Discretizes the columns of data frame
   view_cols <- unique(unlist(views))
   discretized_data <- lapply(view_cols, function(colname){
      bin_equiwidth(data[[colname]], NBINS_CONT_VARIABLES)
   })
   discretized_data <- as.data.frame(discretized_data, col.names = view_cols)

   # Computes the scores
   scores <- sapply(views, function(cols){
      multi_distribution_distance(
         discretized_data[group1,cols,drop=F],
         discretized_data[group2,cols,drop=F]
      )
   })

   scores
}

#######################
#### Main Function ####
#######################
#' Views of a multidimensional dataset, ranked by their differentiation power,
#' non-Shiny version
#'
#'\code{findviews_to_compare_core} detects views on which two arbitrary sets of
#' tuples are well separated. It produces the same
#' results as \code{\link{findviews_to_compare}}, but does \emph{not}
#' present them with a Shiny app.
#'
#'The function \code{findviews_to_compare_core} takes two groups of tuples as
#'input, and detects views on which the statistical distribution of those two
#'groups is different. See the documentation of
#'\code{\link{findviews_to_compare}} for more details.
#'
#' The  difference between \code{\link{findviews_to_compare}} and
#' \code{\link{findviews_to_compare_core}} is that the former presents
#' its results with a Shiny app, while the latter simply outputs them as R
#' stuctures.
#'
#' @inheritParams findviews
#' @inheritParams findviews_to_compare
#'
#'
#' @examples
#' \dontrun{
#' findviews_to_compare_core(mtcars$mpg >= 20 , mtcars$mpg < 20 , mtcars)
#' }
#'
#' @export
findviews_to_compare_core <- function(group1, group2, data, view_size_max=NULL,
                                      clust_method="complete"){

   if (!(is.logical(group1) & is.logical(group2)))
      stop('The input variables group1 and group2 must be vectors of booleans')
   if (nrow(data) != length(group1) | nrow(data) != length(group2))
      stop("The size of the group description does not match the size of the data")
   if (all(group1 == group2))
      stop("The groups to be compared are strictly identical.")

   NAs <- is.na(group1) | is.na(group2)
   group1 <- group1[!NAs]
   group2 <- group2[!NAs]
   data <- data[!NAs,,drop=F]
   if (nrow(data) < 2 | length(group1) < 1 | length(group1) < 2)
      stop("Not enough rows to compare")
   if (sum(group1) == 0 | sum(group2) == 0)
      stop("The groups should contain at least 1 row")

   # Checks all the other parameters and creates the views
   data_and_views <- findviews_trunk(data, view_size_max, clust_method)
   data_num  <- data_and_views$data_num
   views_num <- data_and_views$views_num
   data_cat  <- data_and_views$data_cat
   views_cat <- data_and_views$views_cat
   excluded  <- data_and_views$excluded
   sampled_rows <- data_and_views$sampled_rows

   # Subsamples the groups if necessary
   if (!is.na(sampled_rows)){
      sampled_group1 <- group1[sampled_rows]
      sampled_group2 <- group2[sampled_rows]
      if (sum(sampled_group1) < 1 | sum(sampled_group2) < 1)
         stop("Sampling failed - please try with smaller data set.")
   } else {
      sampled_group1 <- group1
      sampled_group2 <- group2
   }

   # Dissimilarity analysis of each view
   #cat('Scoring the views.... ')
   diff_scores_num <- score_comparison_num(views_num,
                                           sampled_group1,
                                           sampled_group2,
                                           data_num)

   diff_scores_cat <- score_comparison_cat(views_cat,
                                           sampled_group1,
                                           sampled_group2,
                                           data_cat)

   # Ranks the views accordingly
   order_num <- order(diff_scores_num, decreasing = T, na.last = T)
   order_cat <- order(diff_scores_cat, decreasing = T, na.last = T)

   return(list(
      views_cat   = views_cat[order_cat],
      scores_cat  = diff_scores_cat[order_cat],
      views_num   = views_num[order_num],
      scores_num  = diff_scores_num[order_num],
      excluded    = excluded
   ))
}

#' Views of a multidimensional dataset, ranked by their differentiation power.
#'
#' \code{findviews_to_compare} detects views on which two arbitrary sets
#' of rows differ. It plots the results with ggplot and Shiny.
#'
#'
#' The function \code{findviews_to_compare} takes two groups of rows as input
#' and detects views on which the statistical distribution of those two groups
#' differ.
#'
#' To detect the set of views, \code{findviews_to_compare} eliminates
#' the rows which are present in neither group and applies \code{\link{findviews}}.
#'
#' To evaluate the differentiation power of the views, findviews computes the
#' histograms of the two groups to be compared, and computes their dissimilarity
#' them with the Euclidean distance.
#'
#' This method is loosely based on the following paper: \preformatted{
#' Fast, Explainable View Detection to Characterize Exploration Queries
#' Thibault Sellam, Martin Kersten
#' SSDBM, 2016}
#'
#' @inheritParams findviews
#' @param group1 Logical vector of size \code{nrow(data)}, which describes the
#'   first group to compare. The value \code{TRUE} at position i indicates the
#'   the i-th row of \code{data} belongs to the group.
#' @param group2 Logical vector, which describes the second group to compare.
#'   The value \code{TRUE} at position i indicates the the i-th row of
#'   \code{data} belongs to the group.
#'
#' @examples
#' \dontrun{
#' findviews_to_compare(mtcars$mpg >= 20 , mtcars$mpg < 20 , mtcars)
#' }
#'
#' @export
findviews_to_compare <- function(group1, group2, data,
                                 view_size_max=NULL, clust_method="complete", ...){
   fdviews_out <- findviews_to_compare_core(group1, group2, data,
                                            view_size_max, clust_method)

   # Creates and launches the Shiny server
   data_name <- deparse(substitute(data))
   group1_name <- deparse(substitute(group1))
   group2_name <- deparse(substitute(group2))

   fdviews_app <- create_fdviews_app(fdviews_out, "findviews_to_compare",
                                     data, data_name = data_name,
                                     fdviews_group1 = group1,
                                     fdviews_group2 = group2,
                                     fdviews_group1_name = group1_name,
                                     fdviews_group2_name = group2_name
   )
   shiny::runApp(fdviews_app, display.mode = "normal", ...)
}
