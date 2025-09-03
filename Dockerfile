FROM rocker/r-ver:4.4.0

RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev zlib1g-dev \
    libssl-dev libglpk-dev

RUN Rscript -e "install.packages(c('remotes', 'optparse'))"

RUN Rscript -e "remotes::install_github('https://github.com/frankp-0/HAUDI@v1.0.5')"

COPY R/* /scripts/
COPY test_data /test_data
