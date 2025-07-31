library(HAUDI)
library(optparse)

option_list <- list(
  make_option(c("--file"), type = "character"),
  make_option(c("--file_fmt"), type = "character"),
  make_option(c("--plink_prefix"), type = "character"),
  make_option(c("--output"), type = "character")
)
opt <- parse_args(OptionParser(option_list = option_list))

HAUDI::convert_to_lanc(
  file = opt$file, file_fmt = opt$file_fmt,
  plink_prefix = opt$plink_prefix, output = opt$output
)
