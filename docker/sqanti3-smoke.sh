#!/bin/sh
set -eu

export PATH=/opt/conda/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export LD_LIBRARY_PATH=/opt/conda/lib
export PYTHONNOUSERSITE=1
export PYTHONDONTWRITEBYTECODE=1
export MPLBACKEND=Agg
export MPLCONFIGDIR=/tmp/matplotlib
export NUMBA_CACHE_DIR=/tmp/numba-cache
export XDG_CACHE_HOME=/tmp/xdg-cache
export XDG_CONFIG_HOME=/tmp/xdg-config
export XDG_DATA_HOME=/tmp/xdg-data
export OPENBLAS_NUM_THREADS=1
export OMP_NUM_THREADS=1

mode="${1:-all}"

buildtime() {
  sqanti3_qc.py --version 2>&1 | grep -Fx 'SQANTI3 6.0.2' >/dev/null
  sqanti3 --help 2>&1 | grep -F 'Python wrapper for SQANTI3 pipeline' >/dev/null
  sqanti3_qc.py --help 2>&1 | grep -F -- '--refFasta' >/dev/null
  sqanti3_filter.py rules --help 2>&1 | grep -F -- '--sqanti_class' >/dev/null
  sqanti3_rescue.py --help 2>&1 | grep -F -- '--filter_class' >/dev/null
  sqanti3_reads.py --help 2>&1 | grep -F -- '--design' >/dev/null
  Rscript --version 2>&1 | grep -F 'Rscript (R) version' >/dev/null
  test -L /opt/conda/share/sqanti3-6.0.2-1/src/utilities/gtfToGenePred-linux-x86_64
  test "$(readlink /opt/conda/share/sqanti3-6.0.2-1/src/utilities/gtfToGenePred-linux-x86_64)" = '/opt/conda/bin/gtfToGenePred'
  printf 'sqanti3_buildtime_ok\n'
}

identity() {
  sqanti3_qc.py --version 2>&1 | grep -Fx 'SQANTI3 6.0.2' >/dev/null
  sqanti3_filter.py rules --version 2>&1 | grep -Fx 'SQANTI3 6.0.2' >/dev/null
  sqanti3_rescue.py --version 2>&1 | grep -Fx 'SQANTI3 v6.0.2' >/dev/null
  sqanti3_reads.py --version 2>&1 | grep -Fx 'sqanti-reads 1.0.0' >/dev/null
  python - <<'PY'
import importlib.metadata as md
import runpy
import Bio
import bx
import gffutils
import gtfparse
import numpy
import pandas
import polars
import pyarrow
import pybedtools
import pysam
import scipy
import sklearn
import torch
import torchaudio
import torchvision

config = runpy.run_path("/opt/conda/share/sqanti3-6.0.2-1/src/config.py")
assert config["__version__"] == "6.0.2"
assert md.version("torch").startswith("2.5.1")
assert md.version("torchaudio") == "2.5.1"
assert md.version("torchvision") == "0.20.1"
assert torch.version.cuda is None
PY
  Rscript -e 'pkgs <- c("caret", "dplyr", "DT", "e1071", "forcats", "ggplot2", "ggplotify", "gridExtra", "Gviz", "htmltools", "jsonlite", "NOISeq", "optparse", "plotly", "plyr", "purrr", "randomForest", "RColorConesa", "readr", "reshape2", "rmarkdown", "scales", "stringr", "tibble", "tidyr"); stopifnot(all(vapply(pkgs, requireNamespace, logical(1), quietly=TRUE)))'
  printf 'sqanti3_identity_ok\n'
}

modules() {
  tmp="$(mktemp -d /tmp/taf-sqanti3-modules.XXXXXX)"
  trap 'rm -rf "$tmp"' EXIT HUP INT TERM
  sqanti3 --help >"$tmp/sqanti3.help" 2>&1
  sqanti3 qc --help >"$tmp/qc-wrapper.help" 2>&1
  printf 'rules\n' | sqanti3 filter --help >"$tmp/filter-wrapper.help" 2>&1
  sqanti3 rescue --help >"$tmp/rescue-wrapper.help" 2>&1
  sqanti3 init --help >"$tmp/init-wrapper.help" 2>&1
  sqanti3_qc.py --help >"$tmp/qc.help" 2>&1
  sqanti3_filter.py rules --help >"$tmp/rules.help" 2>&1
  sqanti3_filter.py ml --help >"$tmp/ml.help" 2>&1
  sqanti3_rescue.py --help >"$tmp/rescue.help" 2>&1
  sqanti3_reads.py --help >"$tmp/reads.help" 2>&1
  grep -F '{all,qc,filter,rescue,init}' "$tmp/sqanti3.help" >/dev/null
  grep -F -- '--include_ORF' "$tmp/qc.help" >/dev/null
  grep -F -- '--aligner_choice' "$tmp/qc.help" >/dev/null
  grep -F -- '--json_filter' "$tmp/rules.help" >/dev/null
  grep -F -- '--percent_training' "$tmp/ml.help" >/dev/null
  grep -F -- '--mode' "$tmp/rescue.help" >/dev/null
  grep -F -- '--sqanti_dirs' "$tmp/reads.help" >/dev/null
  gffread --version >"$tmp/gffread.version" 2>&1
  gmap --version >"$tmp/gmap.version" 2>&1
  minimap2 --version >"$tmp/minimap2.version" 2>&1
  STAR --version >"$tmp/star.version" 2>&1
  kallisto version >"$tmp/kallisto.version" 2>&1
  samtools --version >"$tmp/samtools.version" 2>&1
  uLTRA --version >"$tmp/ultra.version" 2>&1
  TD2.LongOrfs --help >"$tmp/td2-longorfs.help" 2>&1
  TD2.Predict --help >"$tmp/td2-predict.help" 2>&1
  grep -Eq '^[0-9]+\.[0-9]+(-r[0-9]+)?$' "$tmp/minimap2.version"
  grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+[a-z]?$' "$tmp/star.version"
  grep -F 'kallisto, version' "$tmp/kallisto.version" >/dev/null
  grep -E '^samtools [0-9]+' "$tmp/samtools.version" >/dev/null
  printf 'sqanti3_modules_ok\n'
}

pipeline() {
  tmp="$(mktemp -d /tmp/taf-sqanti3-pipeline.XXXXXX)"
  trap 'rm -rf "$tmp"' EXIT HUP INT TERM
  cd "$tmp"

  awk 'BEGIN { print ">chr1"; for (i = 0; i < 800; i++) printf "ACGTACGT"; print "" }' > reference.fa
  cat > reference.gtf <<'GTF'
chr1	taf	transcript	101	700	.	+	.	gene_id "GENE1"; transcript_id "REF1"; gene_name "Gene1";
chr1	taf	exon	101	300	.	+	.	gene_id "GENE1"; transcript_id "REF1";
chr1	taf	exon	501	700	.	+	.	gene_id "GENE1"; transcript_id "REF1";
chr1	taf	transcript	1001	1400	.	+	.	gene_id "GENE2"; transcript_id "REF2"; gene_name "Gene2";
chr1	taf	exon	1001	1400	.	+	.	gene_id "GENE2"; transcript_id "REF2";
GTF
  cat > isoforms.gtf <<'GTF'
chr1	taf	transcript	101	700	.	+	.	gene_id "PB.1"; transcript_id "PB.1.1";
chr1	taf	exon	101	300	.	+	.	gene_id "PB.1"; transcript_id "PB.1.1";
chr1	taf	exon	501	700	.	+	.	gene_id "PB.1"; transcript_id "PB.1.1";
chr1	taf	transcript	1001	1400	.	+	.	gene_id "PB.2"; transcript_id "PB.2.1";
chr1	taf	exon	1001	1400	.	+	.	gene_id "PB.2"; transcript_id "PB.2.1";
GTF

  samtools faidx reference.fa
  gtfToGenePred isoforms.gtf isoforms.genePred -genePredExt -allErrors -ignoreGroupsWithoutExons
  test -s isoforms.genePred
  gffread isoforms.gtf -g reference.fa -w direct.fasta
  test -s direct.fasta

  sqanti3_qc.py \
    --isoforms isoforms.gtf \
    --refGTF reference.gtf \
    --refFasta reference.fa \
    --dir qc-out \
    --output tiny \
    --cpus 1 \
    --report skip

  test -s qc-out/tiny_classification.txt
  test -s qc-out/tiny_junctions.txt
  test -s qc-out/tiny_corrected.gtf
  test -s qc-out/tiny_corrected.fasta
  grep -F 'structural_category' qc-out/tiny_classification.txt >/dev/null
  grep -F 'PB.1.1' qc-out/tiny_classification.txt >/dev/null

  sqanti3_filter.py rules \
    --sqanti_class qc-out/tiny_classification.txt \
    --filter_gtf qc-out/tiny_corrected.gtf \
    --dir filter-out \
    --output tiny \
    --cpus 1 \
    --skip_report

  test -s filter-out/tiny_RulesFilter_classification.txt
  test -f filter-out/tiny_pass_isoforms.txt
  test -f filter-out/tiny.filtered.gtf
  minimap2 -ax splice --secondary=no reference.fa qc-out/tiny_corrected.fasta > remap.sam
  grep -F '@SQ' remap.sam >/dev/null
  printf 'sqanti3_pipeline_ok\n'
}

case "$mode" in
  buildtime)
    buildtime
    ;;
  identity)
    identity
    ;;
  modules)
    modules
    ;;
  pipeline)
    pipeline
    ;;
  all)
    buildtime
    identity
    modules
    pipeline
    ;;
  *)
    printf 'unknown smoke mode: %s\n' "$mode" >&2
    exit 2
    ;;
esac
