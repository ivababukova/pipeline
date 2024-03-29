# STEP 1. Classifier filter

#' @description Filters seurat object based on mitochondrialContent
#' @param config list containing the following information
#'          - enable: true/false. Refering to apply or not the filter.
#'          - auto: true/false. 'True' indicates that the filter setting need to be changed depending on some sensible value (it requires
#'          to call generate_default_values_mitochondrialContent)
#'          - filterSettings: slot with thresholds
#'                  - method: String. Method to be used {absoluteThreshold}
#'                  - methodSettings: List with the method as key and contain all the filterSettings for this specific method.
#'                          * absoluteThreshold: based on a cut-off threshold
#'                                  - maxFraction: Float. maximun pct MT-content that we considere for a alive cell
#'                                  - binStep: Float. Bin size for the histogram
#'                          * we are supposed to add more methods ....
#' @import data.table
#' @export
#' @return a list with the filtered seurat object by mitochondrial content, the config and the plot values
#'
filter_emptydrops <- function(scdata, config, sample_id, cells_id, task_name = "classifier", num_cells_to_downsample = 6000) {
  cells_id.sample <- cells_id[[sample_id]]

  if (length(cells_id.sample) == 0) {
    return(list(data = scdata, new_ids = cells_id, config = config, plotData = list()))
  }

  scdata.sample <- subset_ids(scdata, cells_id.sample)

  FDR <- config$filterSettings$FDR
  if (isTRUE(config$auto)) {
    FDR <- generate_default_values_classifier(scdata.sample, config)
  }

  # for plots and filter stats to be populated
  guidata <- list()

  # check if filter data is actually available
  if (is.null(scdata@meta.data$emptyDrops_FDR)) {
    message("Classify is enabled but has no classify data available: will dissable it: no filtering!")
    config$enabled <- FALSE
  }

  if (config$enabled) {
    message("Classify is enabled: filtering with FDR=", FDR)
    meta <- scdata.sample@meta.data

    message("Info: empty-drops table of FDR threshold categories (# UMIs for a given threshold interval)")
    print(table(meta$samples, cut(meta$emptyDrops_FDR, breaks = c(-Inf, 0, 0.0001, 0.01, 0.1, 0.5, 1, Inf)), useNA = "ifany"))

    # prevents filtering of NA FDRs if FDR=1
    ed_fdr <- scdata.sample$emptyDrops_FDR
    ed_fdr[is.na(ed_fdr)] <- 1

    message(
      "Number of barcodes to filter for this sample: ",
      sum(ed_fdr > FDR, na.rm = TRUE), "/", length(ed_fdr)
    )

    numis <- log10(scdata.sample@meta.data$nCount_RNA)

    fdr_data <- unname(purrr::map2(ed_fdr, numis, function(x, y) {
      c("FDR" = x, "log_u" = y)
    }))
    fdr_data <- fdr_data[get_positions_to_keep(scdata.sample, num_cells_to_downsample)]

    remaining_ids <- scdata.sample@meta.data$cells_id[ed_fdr <= FDR]

    # update config
    config$filterSettings$FDR <- FDR

    # Downsample plotData
    knee_data <- get_bcranks_plot_data(scdata.sample, is.cellsize = FALSE)[["knee"]]

    # Populate guidata list
    guidata[[generate_gui_uuid(sample_id, task_name, 0)]] <- fdr_data
    guidata[[generate_gui_uuid(sample_id, task_name, 1)]] <- knee_data
  } else {
    message("filter disabled: data not filtered!")
    # guidata is an empty list
    guidata[[generate_gui_uuid(sample_id, task_name, 0)]] <- list()
    guidata[[generate_gui_uuid(sample_id, task_name, 1)]] <- list()
    guidata[[generate_gui_uuid(sample_id, task_name, 2)]] <- list()
    remaining_ids <- cells_id.sample
  }

  # get filter stats after filtering
  filter_stats <- list(
    before = calc_filter_stats(scdata.sample),
    after = calc_filter_stats(subset_ids(scdata.sample, remaining_ids))
  )

  guidata[[generate_gui_uuid(sample_id, task_name, 2)]] <- filter_stats

  cells_id[[sample_id]] <- remaining_ids

  result <- list(
    data = scdata,
    new_ids = cells_id,
    config = config,
    plotData = guidata
  )

  return(result)
}



#' @description Filters seurat object based on classifier filter using emptyDrops
#               https://rdrr.io/github/MarioniLab/DropletUtils/man/emptyDrops.html
#' @param config list containing the following information
#'          - enable: true/false. Refering to apply or not the filter.
#'          - auto: true/false. 'True' indicates that the filter setting need to be changed depending on some sensible value (it requires
#'          to call generate_default_values_classifier)
#'          - filterSettings: slot with thresholds
#'                  - minProbabiliy:
#'                  - filterThreshold:
#' @export
#' @return a list with the filtered seurat object by probabilities classifier, the config and the plot values
#'
generate_default_values_classifier <- function(scdata, config) {

  # HARDCODE
  threshold <- 0.01

  return(threshold)
}
