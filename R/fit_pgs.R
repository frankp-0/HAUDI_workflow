library(HAUDI)
library(bigstatsr)
library(data.table)
library(optparse)

option_list <- list(
  make_option(c("--method"), type = "character"),
  make_option(c("--family"), type = "character", default = "gaussian"),
  make_option(c("--bk_file"), type = "character"),
  make_option(c("--info_file"), type = "character"),
  make_option(c("--dims_file"), type = "character"),
  make_option(c("--fbm_samples_file"), type = "character"),
  make_option(c("--training_samples_file"), type = "character", default = NULL),
  make_option(c("--phenotype_file"), type = "character"),
  make_option(c("--phenotype"), type = "character"),
  make_option(c("--output_prefix"), type = "character"),
  make_option(c("--gamma_min"), type = "numeric"),
  make_option(c("--gamma_max"), type = "numeric"),
  make_option(c("--n_gamma"), type = "numeric"),
  make_option(c("--variants_file"), type = "character", default = NULL),
  make_option(c("--phenotype_id_col"), type = "character", default = "#IID"),
  make_option(c("--n_folds"), type = "integer", default = 5)
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

## Create phenotype
pheno <- fread(opt$phenotype_file, colClasses = "character")
pheno <- pheno[match(fbm_samples, pheno[[opt$phenotype_id_col]]), ]
y <- pheno[[opt$phenotype]] |> as.numeric()
if (!is.null(opt$training_samples_file)) {
  training_samples <- readLines(opt$training_samples_file)
  y[!fbm_samples %in% training_samples] <- NA
}
ind_train <- which(!is.na(y))

if (!is.null(opt$variants_file)) {
  variants <- readLines(opt$variants_file)
} else {
  variants <- NULL
}

if (opt$method == "GAUDI") {
  ## Fit model
  mod <- HAUDI::gaudi(
    fbm = fbm,
    fbm_info = fbm_info,
    y_train = y[ind_train],
    ind_train = ind_train,
    gamma_vec = seq(opt$gamma_min, opt$gamma_max, length.out = opt$n_gamma),
    k = opt$n_folds,
    variants = variants
  )

  # get PGS
  X <- HAUDI::construct_gaudi(fbm, fbm_info, variants = variants)
  pgs <- predict(mod$fit, Xnew = X, lambda = mod$best_lambda)$fit[, 1]
  dt_pgs <- data.table(sample = fbm_samples, score = pgs)

  # get effect sizes and snps (excluding intercept)
  beta <- coef(mod$fit, lambda = mod$best_lambda)$beta[-1, 1]
  snps_anc <- mod$snps[-1]
  dt_effect <- data.table(
    snps = sapply(strsplit(snps_anc, ".anc."), function(x) x[[1]]),
    anc = sapply(strsplit(snps_anc, ".anc."), function(x) x[[2]]),
    beta = beta
  )
  dt_effect <- dcast(dt_effect, snps ~ anc, value.var = "beta")

  # write results
  saveRDS(mod, file = paste0(opt$output_prefix, "_model.rds"))
  fwrite(dt_pgs, file = paste0(opt$output_prefix, "_pgs.txt"))
  fwrite(dt_effect, file = paste0(opt$output_prefix, "_effects.txt"))
} else if (opt$method == "HAUDI") {
  ## Fit model
  result <- HAUDI::haudi(
    fbm = fbm,
    fbm_info = fbm_info,
    y_train = y[ind_train],
    ind.train = ind_train,
    gamma_vec = seq(opt$gamma_min, opt$gamma_max, length.out = opt$n_gamma),
    k = opt$n_folds,
    family = opt$family,
    variants = variants
  )

  # get PGS
  dt_pgs <- data.table(
    sample = fbm_samples,
    score = predict(result$model, fbm)
  )

  # get effect sizes and snps
  dt_effect <- HAUDI::get_beta_haudi(fbm_info, result$model)

  # write results
  saveRDS(result, file = paste0(opt$output_prefix, "_model.rds"))
  fwrite(dt_pgs, file = paste0(opt$output_prefix, "_pgs.txt"))
  fwrite(dt_effect, file = paste0(opt$output_prefix, "_effects.txt"))
}
