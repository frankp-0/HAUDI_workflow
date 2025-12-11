# fit_haudi.wdl
#
# This WDL workflow fits a HAUDI or GAUDI polygenic score
# using a specially-formatted Filebacked Big Matrix (FBM)
# and a phenotype file.
#
# Required inputs:
#   - Method definition ("HAUDI" or "GAUDI")
#   - Files associated with FBM (backing file, dimensions file, column
#   info file, samples file)
#   - A phenotype file and phenotype name
#   - An output prefix
#
# Optional inputs:
#   - The family of the phenotype: "gaussian" (default) or "binomial"
#   - A subset of samples or variants to train the PGS on
#   - The min, max, and total number of gamma values (used to construct array of
#   tuning parameters)
#   - The number of CV folds (default = 5)
#
# Output files:
#   - {output_prefix}_model.rds: Serialized R object containing the model
#   - {output_prefix}_effects.txt: Table of ancestry-specific effect estimates
#   - {output_prefix}_pgs.txt: Calculated PGS for each sample in FBM
#

version 1.0

workflow fit_haudi {
  input {
    # Either "HAUDI" or "GAUDI"
    String method

    # Optional: Either "gaussian" (default) or "binomial" (not supported by GAUDI)
    String? family

    # Files associated with FBM
    File bk_file
    File info_file
    File dims_file
    File fbm_samples_file

    # Optional: restrict training samples (one sample ID per line)
    File? training_samples_file

    # PLINK2-style text file. Must have an "#IID" column for samples
    # and at least one additional column for the phenotype
    File phenotype_file

    # The name of the phenotype column in the phenotype_file
    String phenotype

    # Output prefix for model, effects, and PGS results
    String output_prefix

    # Characterize the sequence of gamma tuning parameter values to use
    Float gamma_min = 0.01
    Float gamma_max = 5
    Float n_gamma = 5

    # Subset the variants used in model fitting (one ID per line)
    File? variants_file

    # Optional: specify phenotype sample ID column
    String phenotype_id_col = "#IID"

    # Specify number of cross-validation folds
    Int n_folds = 5

    # Resources
    Int memory_gb = 4
  }

  call fit_haudi {
    input:
      method = method,
      family = family,
      bk_file = bk_file,
      info_file = info_file,
      dims_file = dims_file,
      fbm_samples_file = fbm_samples_file,
      training_samples_file = training_samples_file,
      phenotype_file = phenotype_file,
      phenotype = phenotype,
      output_prefix = output_prefix,
      gamma_min = gamma_min,
      gamma_max = gamma_max,
      n_gamma = n_gamma,
      variants_file = variants_file,
      phenotype_id_col = phenotype_id_col,
      n_folds = n_folds,
      memory_gb = memory_gb
  }

  output {
    File model_file = fit_haudi.model_file
    File pgs_file = fit_haudi.pgs_file
    File effects_file = fit_haudi.effects_file
  }
}


task fit_haudi {
  input {
    String method
    String? family
    File bk_file
    File info_file
    File dims_file
    File fbm_samples_file
    File? training_samples_file
    File phenotype_file
    String phenotype
    String output_prefix
    Float gamma_min = 0.01
    Float gamma_max = 5
    Float n_gamma = 5
    File? variants_file
    String phenotype_id_col
    Int n_folds
    Int memory_gb = 4
  }

  Int disk_size = ceil(size(bk_file, "GB") + size(info_file, "GB") + size(phenotype_file, "GB") + 4)

  command <<<
    Rscript /scripts/fit_pgs.R \
      --method ~{method} \
      ~{if defined(family) then "--family " + family else ""} \
      --bk_file ~{bk_file} \
      --info_file ~{info_file} \
      --dims_file ~{dims_file} \
      --fbm_samples_file ~{fbm_samples_file} \
      ~{if defined(training_samples_file) then "--training_samples_file " + training_samples_file else ""} \
      --phenotype_file ~{phenotype_file} \
      --phenotype ~{phenotype} \
      --output_prefix ~{output_prefix} \
      --gamma_min ~{gamma_min} \
      --gamma_max ~{gamma_max} \
      --n_gamma ~{n_gamma} \
      ~{if defined(variants_file) then "--variants_file " + variants_file else ""} \
      --phenotype_id_col "~{phenotype_id_col}" \
      --n_folds ~{n_folds}
    >>>

  output {
    File model_file = "${output_prefix}_model.rds"
    File effects_file = "${output_prefix}_effects.txt"
    File pgs_file = "${output_prefix}_pgs.txt"
  }

  runtime {
    docker: "frankpo/run_haudi:0.0.12"
    disks: "local-disk ~{disk_size} SSD"
    memory: "~{memory_gb}G"
  }
}
