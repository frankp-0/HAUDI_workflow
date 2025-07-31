library(HAUDI)
library(data.table)
library(optparse)

option_list <- list(
  make_option(c("--lanc_files_file"), type = "character"),
  make_option(c("--plink_prefixes_file"), type = "character"),
  make_option(c("--fbm_prefix"), type = "character"),
  make_option(c("--variants_file"), type = "character", default = NULL),
  make_option(c("--min_ac"), type = "integer", default = 0),
  make_option(c("--samples_file"), type = "character", default = NULL),
  make_option(c("--anc_names"), type = "character", default = NULL),
  make_option(c("--chunk_size"), type = "integer", default = 400)
)
opt <- parse_args(OptionParser(option_list = option_list))

opt$lanc_files <- readLines(opt$lanc_files_file)
opt$plink_prefixes <- readLines(opt$plink_prefixes_file)

opt$variants <- NULL
if (!is.null(opt$variants_file)) {
  opt$variants <- readLines(opt$variants_file)
}

opt$samples <- NULL
if (!is.null(opt$samples_file)) {
  opt$samples <- readLines(opt$samples_file)
}

if (!is.null(opt$anc_names)) {
  opt$anc_names <- unlist(strsplit(opt$anc_names, ","))
}

print(opt)

result <- HAUDI::make_fbm(
  lanc_files = opt$lanc_files,
  plink_prefixes = opt$plink_prefixes,
  fbm_prefix = opt$fbm_prefix,
  variants = opt$variants,
  min_ac = opt$min_ac,
  samples = opt$samples,
  anc_names = opt$anc_names,
  chunk_size = opt$chunk_size
)


dt_bk_dims <- data.table(
  ncol = ncol(result$fbm),
  nrow = nrow(result$fbm)
)

fwrite(dt_bk_dims, file = paste0(opt$fbm_prefix, "_dims.txt"))
fwrite(result$info, file = paste0(opt$fbm_prefix, "_info.txt"))
writeLines(
  text = attr(x = result$fbm, which = "samples"),
  con = paste0(opt$fbm_prefix, "_samples.txt")
)
