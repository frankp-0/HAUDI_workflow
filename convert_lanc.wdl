# convert_lanc.wdl
#
# This WDL workflow converts local ancestry files to the .lanc format
# used by Admix-kit. Supported ancestry input formats are RFMix
# and FLARE. For FLARE input, ancestry is imputed to the midpoint
# between variant positions in the FLARE file.
#
# Required inputs:
#   - Matching arrays of local ancestry files and PLINK2 files
#   - The ancestry file format (either "RFMix" or "FLARE")
#
# Output files:
#   - lanc_files
#
# Assumes:
#   - Input ancestry_files and PLINK2 files are per-chromosome
#   - Input ancestry_files and PLINK2 files are sorted by position
#   - ancestry_file_fmt is either "RFMix" or "FLARE"

version 1.0

workflow convert_lanc {
  input {
    # List of ancestry files (per-chromosome)
    Array[File] ancestry_files

    # Ancestry files format
    String ancestry_file_fmt

    # Corresponding PLINK2 files (per-chromosome)
    Array[File] pgen_files
    Array[File] pvar_files
    Array[File] psam_files

    # Resources
    Int disk_size_gb = 16
    Int memory_gb = 4
  }

  scatter (i in range(length(ancestry_files))) {
    call convert_lanc as convert_lanc_chrom {
      input:
        ancestry_file = ancestry_files[i],
        ancestry_file_fmt = ancestry_file_fmt,
        pgen_file = pgen_files[i],
        pvar_file = pvar_files[i],
        psam_file = psam_files[i],
        disk_size_gb = disk_size_gb,
        memory_gb = memory_gb,
    }
  }

  output {
    Array[File] lanc_files = convert_lanc_chrom.lanc
  }
}

task convert_lanc {
  input {
    File ancestry_file
    String ancestry_file_fmt
    File pgen_file
    File pvar_file
    File psam_file
    Int disk_size_gb
    Int memory_gb
  }

  String plink_prefix = basename(pgen_file, ".pgen")

  command <<<
    # Symlink PLINK2 files and write their base names to a file
    ln -s ~{pgen_file} .
    ln -s ~{pvar_file} .
    ln -s ~{psam_file} .

    # Call R script to convert to .lanc
    Rscript /scripts/convert_lanc.R \
      --file ~{ancestry_file} \
      --file_fmt ~{ancestry_file_fmt} \
      --plink_prefix ~{plink_prefix} \
      --output ~{plink_prefix}.lanc
  >>>

  output {
    File lanc = "~{plink_prefix}.lanc"
  }


  runtime {
    docker: "frankpo/run_haudi:0.0.6"
    disks: "local-disk ~{disk_size_gb} SSD"
    memory: "~{memory_gb}G"
  }
}

