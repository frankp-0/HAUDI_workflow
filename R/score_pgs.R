library(HAUDI)
library(bigstatsr)
library(data.table)
library(optparse)

option_list <- list(
  make_option(c("--bk_file"), type = "character"),
  make_option(c("--info_file"), type = "character"),
  make_option(c("--dims_file"), type = "character"),
  make_option(c("--fbm_samples_file"), type = "character"),
  make_option(c("--effects_file"), type = "character"),
  make_option(c("--model_populations"), type = "character"),
  make_option(c("--target_populations"), type = "character"),
  make_option(c("--out_file"), type = "character")
)
opt <- parse_args(OptionParser(option_list = option_list))

## Specify coding scheme for FBM
code_dosage <- rep(NA_real_, 256)
code_dosage[1:201] <- seq(0, 2, length.out = 201)

## Read in data
fbm_info <- fread(opt$info_file)
dt_bk_dims <- fread(opt$dims_file)

## Create FBM
bk_file <- strsplit(opt$bk_file, ".bk")[[1]]
fbm <- FBM.code256(
  nrow = dt_bk_dims$nrow,
  ncol = dt_bk_dims$ncol,
  code = code_dosage,
  backingfile = bk_file,
  create_bk = FALSE,
)
fbm_samples <- readLines(opt$fbm_samples_file)


## Read effects file
dt_effects <- fread(opt$effects_file)

## Define populations
model_pops <- unlist(strsplit(opt$model_populations, ","))
target_pops <- unlist(strsplit(opt$target_populations, ","))

## Scoring
fbm_info[, idx := .I]
idx_list <- lapply(model_pops, function(pop_m) {
  idx_subset <- match(dt_effects$snp, fbm_info[anc == pop_m, id])
  idx_full <- fbm_info[anc == pop_m, ][idx_subset, ]$idx
  list(
    fbm_idx = idx_full[!is.na(idx_full)],
    effects_idx = which(!is.na(idx_full))
  )
})

pgs_list <- lapply(seq_along(model_pops), function(k) {
  dt_effects_col <- which(names(dt_effects) == paste0("beta_", model_pops[k]))
  effect_vec <- rep(0, ncol(fbm))
  effect_vec[idx_list[[k]]$fbm_idx] <- dt_effects[idx_list[[k]]$effects_idx][[dt_effects_col]]
  bigstatsr::big_prodVec(fbm, effect_vec)
})

dt_pgs <- data.table(
  sample = fbm_samples,
  pgs = pgs_list |> do.call("+", args = _)
)

fwrite(dt_pgs, opt$out_file)
