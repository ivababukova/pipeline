# constants used in GEM2S
gem2s <- list(
  max.edrops.fdr = 0.001,
  max.empty.counts = 100,
  max.empty.drops = 50,
  random.seed = 42
)

# path where dump/log files are saved
# mounted as a volume outside container to local-runner/debug
DEBUG_PATH <- "/debug"

# File management, it needs to match the sample_file_type enum in sql
# (they are originally defined in 20220304184711_schema.js in the api)
file_types_by_technology <- list(
  "10x" = list("barcodes10x", "features10x", "matrix10x")
)

file_names_v1 <- list(
  barcodes10x = "barcodes.tsv.gz",
  features10x = "features.tsv.gz",
  matrix10x = "matrix.mtx.gz"
)

source("data-raw/cell_cycle_genes.R")

cc_genes <- list("human" = human_cc_genes,
                 "mouse" = mouse_cc_genes)

usethis::use_data(
  gem2s,
  DEBUG_PATH,
  file_names_v1,
  file_types_by_technology,
  cc_genes,
  internal = TRUE,
  overwrite = TRUE
)
