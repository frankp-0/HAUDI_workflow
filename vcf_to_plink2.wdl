# vcf_to_plink2.wdl
#
# This WDL workflow converts vcf files to plink2 pgen files
#
# Required inputs:
#   - vcf files
#
# Optional inputs:
#   - Chromosome code (passed to "--output-chr")
#
# Output files:
#   - {vcf_prefix}.pgen
#   - {vcf_prefix}.pvar
#   - {vcf_prefix}.psam
version 1.0

workflow vcf_to_plink2 {
  input {
    Array[File] vcf_files
    String output_chr_code = "chrM"
  }


  scatter (i in range(length(vcf_files))) {
    call vcf_to_plink2 as vcf_to_plink2_chrom {
      input:
        vcf_file = vcf_files[i],
        output_chr_code = output_chr_code
    }
  }

  output {
    Array[File] pgen = vcf_to_plink2_chrom.pgen
    Array[File] pvar = vcf_to_plink2_chrom.pvar
    Array[File] psam = vcf_to_plink2_chrom.psam
  }

  meta {
    author: "Frank Ockerman"
    email: "frankpo@unc.edu"
  }
}

task vcf_to_plink2 {
  input {
    File vcf_file
    String output_chr_code
  }

  Int disk_size = ceil(3*size(vcf_file, "GB")) + 10
  String out_prefix = basename(vcf_file, ".vcf.gz")

  command <<<
    plink2 \
      --vcf ~{vcf_file} \
      --make-pgen \
      --output-chr ~{output_chr_code} \
      --out ~{out_prefix}
  >>>

  output {
    File pgen = "${out_prefix}.pgen"
    File pvar = "${out_prefix}.pvar"
    File psam = "${out_prefix}.psam"
  }

  runtime {
    docker: "quay.io/biocontainers/plink2:2.00a5.10--h4ac6f70_0"
    disks: "local-disk ~{disk_size} SSD"
    memory: "16G"
  }
}
