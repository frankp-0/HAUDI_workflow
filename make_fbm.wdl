# make_fbm.wdl
#
# This WDL workflow converts Admix-kit .lanc local ancestry files
# and their associated PLINK2 files into a Filebacked Big Matrix (FBM)
# compatible with HAUDI and GAUDI.
#
# Required inputs:
#   - Matching arrays of .lanc and PLINK2 files
#   - An output prefix for the FBM
#   - Array of ancestry names (ordered by 0, 1, ... in .lanc files)
#
# Optional inputs:
#   - A subset of samples or variants to include in FBM
#   - Minimum count filter for FBM columns
#
# Output files:
#   - {prefix}.bk: FBM backing file (binary matrix file)
#   - {prefix}_dims.txt: File which reports the FBM's dimensions
#   - {prefix}_info.txt: File with information on FBM columns
#   - {prefix}_samples.txt: File with ordered samples Corresponding to FBM rows
#
# Assumes:
#   - Input .lanc and PLINK2 files are per-chromosome
#   - Input .lanc and PLINK2 files are sorted by position

version 1.0

workflow make_fbm {
  input {
    # List of Admix-kit .lanc files (per-chromosome)
    Array[File] lanc_files

    # Corresponding PLINK2 files (per-chromosome)
    Array[File] pgen_files
    Array[File] pvar_files
    Array[File] psam_files

    # Outut prefix for FBM (file will be appended with ".bk")
    String fbm_prefix

    # Optional: restrict FBM variants (one variant ID per-line)
    File? variants_file

    # Optional: min count to retain a column (anc-specific or total genotype)
    Int? min_ac

    # Optional: restrict FBM samples (one sample ID per-line)
    File? samples_file

    # Array of ancestry names in same order as 0, 1, ..., in .lanc files
    Array[String] anc_names

    # Maximum number of variants to read from pgen at a time
    Int chunk_size = 400

    # Resources
    Int disk_size_gb = 16
    Int memory_gb = 4
  }

  call make_fbm {
    input:
      lanc_files = lanc_files,
      pgen_files = pgen_files,
      pvar_files = pvar_files,
      psam_files = psam_files,
      fbm_prefix = fbm_prefix,
      variants_file = variants_file,
      min_ac = min_ac,
      samples_file = samples_file,
      anc_names = anc_names,
      chunk_size = chunk_size,
      disk_size_gb = disk_size_gb,
      memory_gb = memory_gb
  }

  output {
    File bk_file = make_fbm.bk_file
    File info_file = make_fbm.info_file
    File dims_file = make_fbm.dims_file
    File fbm_samples_file = make_fbm.samples_file
  }

  meta {
    author: "Frank Ockerman"
    email: "frankpo@unc.edu"
  }
}

task make_fbm {
  input {
    Array[File] lanc_files
    Array[File] pgen_files
    Array[File] pvar_files
    Array[File] psam_files
    String fbm_prefix
    File? variants_file
    Int? min_ac
    File? samples_file
    Array[String] anc_names
    Int chunk_size
    Int disk_size_gb
    Int memory_gb
  }


  command <<<
    # Symlink .lanc files and write their names to a file
    for f in ~{sep=' ' lanc_files}; do
      ln -s "$f" .
      echo "$f" >> lanc_files.txt
    done

    # Symlink PLINK2 files and write their base names to a file
    for f in ~{sep=' ' pgen_files}; do
      ln -s "$f" .
      basename "$f" .pgen
    done > plink_prefixes.txt

    for f in ~{sep=' ' psam_files}; do
      ln -s "$f" .
    done

    for f in ~{sep=' ' pvar_files}; do
      ln -s "$f" .
    done

    # Call R script to create FBM
    Rscript /scripts/make_fbm.R \
      --lanc_files_file lanc_files.txt \
      --plink_prefixes_file plink_prefixes.txt \
      --fbm_prefix ~{fbm_prefix} \
      ~{if defined(variants_file) then "--variants_file " + variants_file else ""} \
      ~{if defined(min_ac) then "--min_ac " + min_ac else ""} \
      ~{if defined(samples_file) then "--samples_file " + samples_file else ""} \
      --anc_names ~{sep=',' anc_names} \
      --chunk_size ~{chunk_size}
  >>>

  output {
    File bk_file = "${fbm_prefix}.bk"
    File dims_file = "${fbm_prefix}_dims.txt"
    File info_file = "${fbm_prefix}_info.txt"
    File samples_file = "${fbm_prefix}_samples.txt"
  }

  runtime {
    docker: "frankpo/run_haudi:0.0.5"
    disks: "local-disk ~{disk_size_gb} SSD"
    memory: "~{memory_gb}G"
  }
}
