ARG MAMBA_BASE_IMAGE=mambaorg/micromamba:1.5.10-bookworm-slim@sha256:e3797091302382ea841498bc93a7b0a50f7c1448333d5e946d2d1608d0c5f43d
ARG RUNTIME_BASE_IMAGE=debian:12-slim@sha256:7b140f374b289a7c2befc338f42ebe6441b7ea838a042bbd5acbfca6ec875818

FROM ${MAMBA_BASE_IMAGE} AS builder

ARG SQANTI3_VERSION=6.0.2
ARG SQANTI3_BUILD=hdfd78af_1
ARG SQANTI3_PACKAGE_URL=https://api.anaconda.org/download/bioconda/sqanti3/6.0.2/noarch/sqanti3-6.0.2-hdfd78af_1.conda
ARG SQANTI3_PACKAGE_SHA256=4cad63d2338d59c9dd90bdd3c0b3a41bcba87bac7e3e93866a5bb14f9cd97ca6
ARG SQANTI3_SOURCE_URL=https://github.com/ConesaLab/SQANTI3/archive/refs/tags/v6.0.2.tar.gz
ARG SQANTI3_SOURCE_SHA256=e8711e6bd9455415fdd0380f19c283fa6e4c12c13ca53274ba1b106fda006013
ARG GENOMEINFODBDATA_URL=https://mirror4.twds.com.tw/kali/pool/main/r/r-bioc-genomeinfodbdata/r-bioc-genomeinfodbdata_1.2.13.orig.tar.gz
ARG GENOMEINFODBDATA_SHA256=51a33c432e65261ef81a7c2039b17cbdf7a0b417376fdb7ada4d618566f7074e

USER root

ENV DEBIAN_FRONTEND=noninteractive
ENV MAMBA_DOWNLOAD_THREADS=1
ENV MAMBA_EXTRACT_THREADS=1

ADD --checksum=sha256:4cad63d2338d59c9dd90bdd3c0b3a41bcba87bac7e3e93866a5bb14f9cd97ca6 \
    https://api.anaconda.org/download/bioconda/sqanti3/6.0.2/noarch/sqanti3-6.0.2-hdfd78af_1.conda \
    /tmp/sqanti3-6.0.2-hdfd78af_1.conda
ADD --checksum=sha256:e8711e6bd9455415fdd0380f19c283fa6e4c12c13ca53274ba1b106fda006013 \
    https://github.com/ConesaLab/SQANTI3/archive/refs/tags/v6.0.2.tar.gz \
    /tmp/sqanti3-source.tar.gz
ADD --checksum=sha256:51a33c432e65261ef81a7c2039b17cbdf7a0b417376fdb7ada4d618566f7074e \
    https://mirror4.twds.com.tw/kali/pool/main/r/r-bioc-genomeinfodbdata/r-bioc-genomeinfodbdata_1.2.13.orig.tar.gz \
    /tmp/GenomeInfoDbData_1.2.13.tar.gz

RUN set -eux; \
    echo "${SQANTI3_PACKAGE_SHA256}  /tmp/sqanti3-6.0.2-hdfd78af_1.conda" | sha256sum -c -; \
    echo "${SQANTI3_SOURCE_SHA256}  /tmp/sqanti3-source.tar.gz" | sha256sum -c -; \
    echo "${GENOMEINFODBDATA_SHA256}  /tmp/GenomeInfoDbData_1.2.13.tar.gz" | sha256sum -c -; \
    echo '8798e58b89d84d9fa6a85f2191704668  /tmp/GenomeInfoDbData_1.2.13.tar.gz' | md5sum -c -; \
    chmod 0644 /tmp/GenomeInfoDbData_1.2.13.tar.gz; \
    mkdir -p /tmp/sqanti3-release; \
    tar -xzf /tmp/sqanti3-source.tar.gz \
      -C /tmp/sqanti3-release --strip-components=1; \
    grep -Eq "^__version__ = '${SQANTI3_VERSION}'([[:space:]]|$)" \
      /tmp/sqanti3-release/src/config.py

USER mambauser

RUN set -eux; \
    micromamba install -y -n base \
      -c conda-forge \
      --strict-channel-priority \
      "python=3.11.15" \
      "yq=4.1.2"; \
    micromamba install -y -n base \
      -c conda-forge \
      -c bioconda \
      --strict-channel-priority \
      --no-deps \
      "bioconductor-data-packages=20260207=hdfd78af_1"; \
    data_urls=/opt/conda/share/bioconductor-data-packages/dataURLs.json; \
    test -f "${data_urls}"; \
    cp /tmp/GenomeInfoDbData_1.2.13.tar.gz \
      /opt/conda/share/bioconductor-data-packages/GenomeInfoDbData_1.2.13.tar.gz; \
    sed -i \
      's#https://bioconductor.org/packages/3.20/data/annotation/src/contrib/GenomeInfoDbData_1.2.13.tar.gz#file:///opt/conda/share/bioconductor-data-packages/GenomeInfoDbData_1.2.13.tar.gz#g' \
      "${data_urls}"; \
    grep -F 'file:///opt/conda/share/bioconductor-data-packages/GenomeInfoDbData_1.2.13.tar.gz' "${data_urls}" >/dev/null

RUN set -eux; \
    for attempt in 1 2 3; do \
      micromamba clean -a -y || true; \
      rm -rf /opt/conda/pkgs/*; \
      if micromamba install -y -n base \
          -c conda-forge \
          -c bioconda \
          --strict-channel-priority \
          "sqanti3=${SQANTI3_VERSION}=${SQANTI3_BUILD}" \
          "ucsc-gtftogenepred=482" \
          "pytorch=2.5.1=cpu_generic_*" \
          "torchvision=0.20.1=cpu_*" \
          "torchaudio=2.5.1=cpu_*" \
          "td2=1.1.0" \
          "psauron=1.1.3" \
          nomkl; then \
        break; \
      fi; \
      if [ "${attempt}" = "3" ]; then exit 1; fi; \
      sleep 10; \
    done; \
    if ls /opt/conda/conda-meta/cudatoolkit-*.json >/dev/null 2>&1; then \
      micromamba remove -y -n base --force --no-prune cudatoolkit; \
    fi; \
    /opt/conda/bin/python -c 'import torch, torchaudio; x = torch.randn(1, 160); y = torchaudio.functional.resample(x, 16000, 8000); assert y.shape == (1, 80); assert torch.version.cuda is None'; \
    : > /tmp/torchaudio-ldd.txt; \
    find /opt/conda/lib/python3.11/site-packages/torchaudio \
      -type f -name '*.so' -print0 \
      | xargs -0 -r ldd >> /tmp/torchaudio-ldd.txt 2>&1; \
    if grep -F 'not found' /tmp/torchaudio-ldd.txt; then exit 1; fi; \
    micromamba list -n base > /tmp/conda-packages.txt; \
    micromamba env export --explicit -n base > /tmp/conda-explicit.txt; \
    micromamba clean -a -y

USER root

ENV PATH=/opt/conda/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ENV LD_LIBRARY_PATH=/opt/conda/lib

RUN set -eux; \
    source_dir="/opt/conda/share/sqanti3-${SQANTI3_VERSION}-1"; \
    test -d "${source_dir}"; \
    test -x /opt/conda/bin/gtfToGenePred; \
    rm -f "${source_dir}/src/utilities/gtfToGenePred-linux-x86_64"; \
    ln -s /opt/conda/bin/gtfToGenePred \
      "${source_dir}/src/utilities/gtfToGenePred-linux-x86_64"; \
    rm -f "${source_dir}/src/utilities/gtfToGenePred-darwin-x86_64"; \
    mkdir -p \
      /opt/sqanti3/share/doc/sqanti3/manual \
      /opt/sqanti3/share/licenses/sqanti3 \
      /opt/sqanti3/share/testdata; \
    cp -a /tmp/sqanti3-release/docs/. /opt/sqanti3/share/doc/sqanti3/manual/; \
    cp /tmp/sqanti3-release/README.md \
      /tmp/sqanti3-release/sqanti3_config.yaml \
      /opt/sqanti3/share/doc/sqanti3/; \
    cp /tmp/sqanti3-release/LICENSE \
      /tmp/sqanti3-release/LICENSE.md \
      /opt/sqanti3/share/licenses/sqanti3/; \
    cp /tmp/conda-packages.txt /opt/sqanti3/share/doc/sqanti3/conda-packages.txt; \
    cp /tmp/conda-explicit.txt /opt/sqanti3/share/doc/sqanti3/conda-explicit.txt; \
    { \
      printf 'name=SQANTI3\n'; \
      printf 'version=%s\n' "${SQANTI3_VERSION}"; \
      printf 'upstream_tag=v%s\n' "${SQANTI3_VERSION}"; \
      printf 'upstream_commit=7c202b5dc846fa4bcd99c20d1dbfc3d721edc80c\n'; \
      printf 'source_archive=%s\n' "${SQANTI3_SOURCE_URL}"; \
      printf 'source_archive_sha256=%s\n' "${SQANTI3_SOURCE_SHA256}"; \
      printf 'runtime_package=bioconda::sqanti3=%s=%s\n' "${SQANTI3_VERSION}" "${SQANTI3_BUILD}"; \
      printf 'runtime_package_sha256=%s\n' "${SQANTI3_PACKAGE_SHA256}"; \
      printf 'GenomeInfoDbData_source=%s\n' "${GENOMEINFODBDATA_URL}"; \
      printf 'GenomeInfoDbData_sha256=%s\n' "${GENOMEINFODBDATA_SHA256}"; \
      printf 'pytorch=2.5.1 CPU generic\n'; \
      printf 'torchaudio=2.5.1 CPU; unused amd64 cudatoolkit package removed after functional and linkage checks\n'; \
      printf 'native_gtfToGenePred=bioconda::ucsc-gtftogenepred=482\n'; \
      printf 'runtime_profile=compiler frontends, development headers, and dependency test fixtures removed after smoke validation\n'; \
      printf 'platforms=linux/amd64,linux/arm64\n'; \
      printf 'database_note=No production reference genome, annotation, or optional orthogonal evidence is bundled.\n'; \
    } > /opt/sqanti3/share/doc/sqanti3/source.txt; \
    sqanti3_qc.py --version 2>&1 | grep -Fx "SQANTI3 ${SQANTI3_VERSION}" >/dev/null; \
    python -c 'import torch; assert torch.__version__.startswith("2.5.1"); assert torch.version.cuda is None'; \
    Rscript -e 'stopifnot(requireNamespace("RColorConesa", quietly=TRUE), requireNamespace("rmarkdown", quietly=TRUE), requireNamespace("Gviz", quietly=TRUE), requireNamespace("NOISeq", quietly=TRUE))'

RUN set -eux; \
    find /opt/conda -type d -name '__pycache__' -prune -exec rm -rf '{}' +; \
    find /opt/conda -type f \( -name '*.pyc' -o -name '*.pyo' -o -name '*.a' -o -name '*.o' \) -delete; \
    find /opt/conda/bin -maxdepth 1 -name '*-conda-linux-gnu-*' -delete; \
    find /opt/conda/lib/python3.11/site-packages -type d -name include -prune -exec rm -rf '{}' +; \
    find /opt/conda/lib/R/library -type d -name include -prune -exec rm -rf '{}' +; \
    rm -f \
      /opt/conda/bin/cc \
      /opt/conda/bin/c++ \
      /opt/conda/bin/cpp \
      /opt/conda/bin/gcc \
      /opt/conda/bin/g++ \
      /opt/conda/bin/gfortran \
      /opt/conda/bin/gcov \
      /opt/conda/bin/ld; \
    rm -rf \
      /opt/conda/pkgs \
      /opt/conda/include \
      /opt/conda/man \
      /opt/conda/share/man \
      /opt/conda/share/doc \
      /opt/conda/lib/pkgconfig \
      /opt/conda/lib/cmake \
      /opt/conda/libexec/gcc \
      /opt/conda/lib/python3.11/site-packages/gffutils/test \
      /opt/conda/lib/python3.11/site-packages/gtftools/test_data \
      /opt/conda/lib/python3.11/site-packages/pandas/tests \
      /opt/conda/lib/python3.11/site-packages/pybedtools/test \
      /opt/conda/*-conda-linux-gnu \
      /opt/conda/share/bioconductor-data-packages/GenomeInfoDbData_1.2.13.tar.gz \
      /tmp/conda-explicit.txt \
      /tmp/conda-packages.txt \
      /tmp/GenomeInfoDbData_1.2.13.tar.gz \
      /tmp/sqanti3-6.0.2-hdfd78af_1.conda \
      /tmp/sqanti3-release \
      /tmp/sqanti3-source.tar.gz \
      /root/.cache

FROM ${RUNTIME_BASE_IMAGE} AS runtime

ARG SQANTI3_VERSION=6.0.2

LABEL org.opencontainers.image.title="TAFFISH sqanti3"
LABEL org.opencontainers.image.description="SQANTI3 6.0.2 long-read transcriptome QC, filtering, rescue, and SQANTI-reads runtime"
LABEL org.opencontainers.image.source="https://github.com/taffish/sqanti3"
LABEL org.opencontainers.image.url="https://github.com/ConesaLab/SQANTI3"
LABEL org.opencontainers.image.version="6.0.2-r1"
LABEL org.opencontainers.image.licenses="Apache-2.0 AND GPL-3.0-only"

ENV DEBIAN_FRONTEND=noninteractive
ENV CONDA_PREFIX=/opt/conda
ENV PATH=/opt/conda/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ENV LD_LIBRARY_PATH=/opt/conda/lib
ENV PYTHONNOUSERSITE=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV MPLBACKEND=Agg
ENV MPLCONFIGDIR=/tmp/matplotlib
ENV NUMBA_CACHE_DIR=/tmp/numba-cache
ENV XDG_CACHE_HOME=/tmp/xdg-cache
ENV XDG_CONFIG_HOME=/tmp/xdg-config
ENV XDG_DATA_HOME=/tmp/xdg-data
ENV OPENBLAS_NUM_THREADS=1
ENV OMP_NUM_THREADS=1

RUN set -eux; \
    for attempt in 1 2 3 4 5; do \
      if apt-get -o Acquire::Retries=3 update \
       && apt-get -o Acquire::Retries=3 install -y --no-install-recommends \
            bash \
            bzip2 \
            ca-certificates \
            coreutils \
            findutils \
            fonts-dejavu-core \
            grep \
            gzip \
            less \
            procps \
            sed \
            tar \
            xz-utils; then \
        break; \
      fi; \
      if [ "${attempt}" = "5" ]; then exit 1; fi; \
      apt-get clean; \
      rm -rf /var/lib/apt/lists/*; \
      sleep 5; \
    done; \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

COPY --from=builder /opt/conda /opt/conda
COPY --from=builder /opt/sqanti3 /opt/sqanti3
COPY docker/sqanti3-smoke.sh /opt/sqanti3/share/testdata/sqanti3-smoke.sh

RUN set -eux; \
    chmod 0755 /opt/sqanti3/share/testdata/sqanti3-smoke.sh; \
    dpkg-query -W -f='${Package}==${Version}\n' | sort \
      > /opt/sqanti3/share/doc/sqanti3/debian-packages.txt

FROM runtime AS final

RUN set -eux; \
    /opt/sqanti3/share/testdata/sqanti3-smoke.sh buildtime; \
    : > /tmp/sqanti3-ldd.txt; \
    for exe in python R gffread gtfToGenePred minimap2 STAR samtools; do \
      ldd "$(command -v "${exe}")" >> /tmp/sqanti3-ldd.txt 2>&1 || true; \
    done; \
    if grep -F 'not found' /tmp/sqanti3-ldd.txt; then exit 1; fi; \
    rm -rf \
      /tmp/sqanti3-ldd.txt \
      /tmp/matplotlib \
      /tmp/numba-cache \
      /tmp/xdg-cache \
      /tmp/xdg-config \
      /tmp/xdg-data \
      /root/.cache

WORKDIR /root

ENV TAFFISH_ENV=TAFFISH
ENV TAFFISH_NAME=sqanti3

ENTRYPOINT []
CMD []
