#' STEP 4. Number of genes vs UMIs filter
#'
#' Eliminates cells based on a p value and a linear regression generated from numGenes vs numUmis
#'
#' This filter focuses on filter cells that are far from the behaviour of the relationship between the number of genes (it measures the number of
#' genes in a cell that has at least one count) and the number of UMIs/molecules (the total number of counts in a cell).
#'
#' @param config list containing the following information
#'          - enable: true/false. Refering to apply or not the filter.
#'          - auto: true/false. 'True' indicates that the filter setting need to be changed depending on some sensible value (it requires
#'          to call generate_default_values_numGenesVsNumUmis)
#'          - filterSettings: slot with thresholds
#'              - regressionType: String. Regression to be used: {linear or spline}
#'              - regressionTypeSettings: list with the config settings for all the regression type options
#'                          - linear and spline: for each there is only one element:
#'                             - p.level: which refers to  confidence level for deviation from the main trend
#'
#' @param scdata \code{SeuratObject}
#' @param sample_id value in \code{scdata$samples} to apply filter for
#' @param task_name name of task: \code{'numGenesVsNumUmis'}
#' @param num_cells_to_downsample maximum number of cells for returned plots
#' @export
#'
#' @return a list with the filtered seurat object by numGenesVsNumUmis, the config and the plot values
#'
#'
filter_gene_umi_outlier <- function(scdata, config, sample_id, cells_id, task_name = "numGenesVsNumUmis", num_cells_to_downsample = 6000) {
  cells_id.sample <- cells_id[[sample_id]]

  if (length(cells_id.sample) == 0) {
    return(list(data = scdata, new_ids = cells_id, config = config, plotData = list()))
  }

  scdata.sample <- subset_ids(scdata, cells_id.sample)

  type <- config$filterSettings$regressionType

  # get p.level and update in config
  # defaults from "gene.vs.molecule.cell.filter" in pagoda2
  if (safeTRUE(config$auto))
    p.level <- min(0.001, 1 / ncol(scdata.sample))
  else
    p.level <- config$filterSettings$regressionTypeSettings[[type]]$p.level

  p.level <- suppressWarnings(as.numeric(p.level))
  if(is.na(p.level)) stop("p.level couldnt be interpreted as a number.")

  config$filterSettings$regressionTypeSettings[[type]]$p.level <- p.level

  # regress log10 molecules vs genes
  fit.data <- data.frame(
    log_molecules = log10(scdata.sample$nCount_RNA),
    log_genes = log10(scdata.sample$nFeature_RNA),
    row.names = scdata.sample$cells_id
  )

  fit.data <- fit.data[order(fit.data$log_molecules), ]

  if (type == 'spline') fit <- lm(log_genes ~ splines::bs(log_molecules), data = fit.data)
  else fit <- MASS::rlm(log_genes ~ log_molecules, data = fit.data)

  if (safeTRUE(config$enabled)) {
    # get the interval based on p.level parameter
    preds <- suppressWarnings(predict(fit, interval = "prediction", level = 1 - p.level))

    # filter outliers above/below cutoff bands
    is.outlier <- fit.data$log_genes > preds[, 'upr'] | fit.data$log_genes < preds[, 'lwr']
    remaining_ids <- as.numeric(rownames(fit.data)[!is.outlier])
    remaining_ids <- remaining_ids[order(remaining_ids)]
  } else {
    remaining_ids <- cells_id.sample
  }

  # downsample for plot data
  nkeep <- downsample_plotdata(ncol(scdata.sample), num_cells_to_downsample)

  set.seed(gem2s$random.seed)
  keep_rows <- sample(nrow(fit.data), nkeep)
  keep_rows <- sort(keep_rows)
  downsampled_data <- fit.data[keep_rows, ]

  # get evenly spaced predictions on downsampled data for plotting lines
  xrange <- range(downsampled_data$log_molecules)
  newdata <- data.frame(log_molecules = seq(xrange[1], xrange[2], length.out = 10))
  line_preds <- suppressWarnings(predict(fit, newdata, interval = "prediction", level = 1 - p.level))

  line_preds <- cbind(newdata, line_preds) %>%
    dplyr::select(-fit) %>%
    dplyr::rename(lower_cutoff = lwr, upper_cutoff = upr)

  plot_data <- list(
    pointsData = purrr::transpose(downsampled_data),
    linesData = purrr::transpose(line_preds)
  )

  # Populate with filter statistics and plot data
  filter_stats <- list(
    before = calc_filter_stats(scdata.sample),
    after = calc_filter_stats(subset_ids(scdata.sample, remaining_ids))
  )

  guidata <- list()
  guidata[[generate_gui_uuid(sample_id, task_name, 0)]] <- plot_data
  guidata[[generate_gui_uuid(sample_id, task_name, 1)]] <- filter_stats

  cells_id[[sample_id]] <- remaining_ids

  result <- list(
    data = scdata,
    new_ids = cells_id,
    config = config,
    plotData = guidata
  )

  return(result)
}
