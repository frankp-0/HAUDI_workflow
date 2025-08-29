# HAUDI_workflow

WDL Workflow to run [HAUDI](https://github.com/frankp-0/HAUDI)
(and the related method GAUDI) on AnVIL.

This repository contains WDL code, corresponding JSON input examples, test data,
and a Dockerfile. The docker image corresponding the Dockerfile is available on
Docker Hub: [frankpo/run_haudi](https://hub.docker.com/r/frankpo/run_haudi).

This repository contains four workflows:

- [vcf_to_plink2](#vcf_to_plink2): Convert a set of vcf files to plink2 pgen files
- [convert_lanc](#convert_lanc): Convert a set of RFMix or FLARE local ancestry
files to the ".lanc" format used in [admix-kit](https://kangchenghou.github.io/admix-kit/)
- [make_fbm](#make_fbm): Convert ".lanc" local ancestry and PLINK2 files
into the input Filebacked Big Matrix (FBM) used by HAUDI/GAUDI
- [fit_gaudi](#fit_gaudi): Fit a HAUDI or GAUDI polygenic score

## vcf_to_plink2

This workflow takes an array of VCF files and converts them to PLINK2 pgen format.
Optionally, you can specify an argument for "--output-chr" (e.g. "chrM" format).

The following inputs must be provided:

input | description
--- | ---
vcf_files | An array of VCF files

The following inputs are optional:

input | description
--- | ---
output_chr_code | Default: "chrM"

The following outputs are returned:

output | description
--- | ---
pgen | An array of pgen files
pvar | An array of pvar files
psam | An array of psam files

## convert_lanc

This workflow takes arrays of (per-chromosome) RFMix or FLARE local ancestry
files and corresponding PLINK2 files as input. RFMix files are the .msp.tsv
output from [RFMix2](https://github.com/slowkoni/rfmix). FLARE files
are the .anc.vcf.gz output from [FLARE](https://github.com/browning-lab/flare).
This workflow converts these inputs into
the ".lanc" format used in [admix-kit](https://kangchenghou.github.io/admix-kit/),
which is a necessary input to later create the FBM used by HAUDI/GAUDI.

It is assumed that all inputs are sorted by position and that
the ordering of files (per-chromosome) is the same in each
input array. It is not assumed that the RFMix/FLARE input and
PLINK2 files have identical samples or variants, however it is assumed that
for each file type, the same set and order of samples exists across chromosomes.

The following inputs must be provided:

input | description
--- | ---
ancestry_files | An array of ancestry files (per-chromosome)
ancestry_file_fmt | A string with the ancestry file format (either "FLARE" or "RFMix")
pgen_files | An array of PLINK2 .pgen files
pvar_files | An array PLINK2 .pvar files
psam_files | An array PLINK2 .psam files

The following inputs are optional:

input | description
--- | ---
disk_size_gb | Disk size in GB to use (default 16)
memory_gb | Memory in GB to use (default 4)

The following outputs are returned:

output | description
--- | ---
lanc_files | An array of .lanc output files with the same prefix as the PLINK2 input

## make_fbm

This workflow converts Admix-kit .lanc local ancestry files
and their associated PLINK2 files into a Filebacked Big Matrix (FBM)
compatible with HAUDI and GAUDI.

It is assumed that PLINK2 files are sorted by position and that the ".lanc"
local ancestry files have the same set of samples and ordering as the .psam files.
It is also assumed that the ordering of files (per-chromosome) is the same in each
input array.

The following inputs must be provided:

input | description
--- | ---
lanc_files | An array of of .lanc files (per-chromosome)
pgen_files | An array of PLINK2 .pgen files
pvar_files | An array of PLINK2 .pvar files
psam_files | An array of PLINK2 .psam files
fbm_prefix | A string with the output prefix for the FBM
anc_names | An array of ancestry names corresponding to 0, 1, ..., in .lanc files

The following inputs are optional:

input | description
--- | ---
variants_file | A file with one variant ID per line used to subset the FBM
min_ac | The minimum count to retain an FBM column (anc-specific or total genotype)
samples_file | A file with one sample ID per line used to subset the FBM
chunk_size | Max number of variants to read  from .pgen file at a time (default 400)
disk_size_gb | Disk size in GB to use (default 16)
memory_gb | Memory in GB to use (default 4)

The following outputs are returned:

output | description
bk_file | Backing file for FBM
info_file | Text file with info on FBM columns
dims_file | File which reports FBM dimensions
fbm_samples_file | File with ordered FBM sample IDs

## fit_gaudi

This workflow fits a HAUDI or GAUDI polygenic score using a specially-formatted
Filebacked Big Matrix (FBM) and a phenotype file.

It is assumed that the phenotype file is tab, space, or comma-separated
and contains a column "#IID" and at least one additional phenotype column.

The following inputs must be provided:

input | description
--- | ---
method | A string (either "HAUDI" or "GAUDI") for the PGS method
family | A string (either "gaussian" or "binomial") with the model family
bk_file | Backing file for FBM
info_file | Text file with info on FBM columns
dims_file | File which reports FBM dimensions
fbm_samples_file | File with ordered FBM sample IDs
phenotype_file | Text file with phenotypes and sample IDs
phenotype | A string with the name of the column in phenotype_file to use
output_prefix | A string with the prefix where output files will be written

The following inputs are optional:

input | description
--- | ---
training_samples_file | A file with training samples, one ID per line
gamma_min | The minimum value for the gamma tuning parameter
gamma_max | The max value for the gamma tuning parameter
n_gamma | The number of values to test for the gamma tuning parameter
variants_file | One variant ID per line, used to subset variants for PGS
n_folds | The number of cross-validation folds to use (default 5)
memory_gb | Memory in gb to use (default 4)

The following outputs are returned:

output | description
--- | ---
model_file | Serialized R object containing the model
pgs_file | Table of ancestry-specific effect estimates
effects_file | Calculated PGS for each sample in FBM
