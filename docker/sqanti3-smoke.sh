#!/bin/bash
set -Eeuo pipefail

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
tmp=
lastlog=
cleanup() { if test -n "$tmp"; then rm -rf "$tmp"; fi; }
failure() {
  status=$?
  printf >&2 'SQANTI3_SMOKE_FAIL stage=%s exit=%s\n' "$mode" "$status"
  if test -n "$lastlog" && test -f "$lastlog"; then tail -60 "$lastlog" >&2; fi
  exit "$status"
}
trap failure ERR
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
capture() { lastlog="$tmp/$1.log"; shift; "$@" >"$lastlog" 2>&1; }

buildtime() {
  sqanti3_qc.py --version 2>&1 | grep -Fx 'SQANTI3 6.1' >/dev/null
  sqanti3 --help 2>&1 | grep -F 'Python wrapper for SQANTI3 pipeline' >/dev/null
  sqanti3_qc.py --help 2>&1 | grep -F -- '--refFasta' >/dev/null
  sqanti3_filter.py rules --help 2>&1 | grep -F -- '--sqanti_class' >/dev/null
  sqanti3_rescue.py --help 2>&1 | grep -F -- '--filter_class' >/dev/null
  sqanti3_reads.py --help 2>&1 | grep -F -- '--design' >/dev/null
  sqanti3-resources --help >/dev/null
  Rscript --version 2>&1 | grep -F 'Rscript (R) version' >/dev/null
  test -L /opt/conda/share/sqanti3-6.1-1/src/utilities/gtfToGenePred-linux-x86_64
  test "$(readlink /opt/conda/share/sqanti3-6.1-1/src/utilities/gtfToGenePred-linux-x86_64)" = '/opt/conda/bin/gtfToGenePred'
  printf 'sqanti3_buildtime_ok\n'
}

identity() {
  sqanti3_qc.py --version 2>&1 | grep -Fx 'SQANTI3 6.1' >/dev/null
  sqanti3_filter.py rules --version 2>&1 | grep -Fx 'SQANTI3 6.1' >/dev/null
  sqanti3_rescue.py --version 2>&1 | grep -Fx 'SQANTI3 v6.1' >/dev/null
  sqanti3_reads.py --version 2>&1 | grep -Fx 'sqanti-reads 1.1.0' >/dev/null
  python - <<'PY'
import importlib.metadata as md
import runpy
import Bio
import bx
import gffutils
import gtfparse
import numpy
import pandas
import plotly
import polars
import pyarrow
import pybedtools
import pysam
import scipy
import sklearn
import torch
import torchaudio
import torchvision

config = runpy.run_path("/opt/conda/share/sqanti3-6.1-1/src/config.py")
assert config["__version__"] == "6.1"
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
  capture sqanti3 sqanti3 --help
  capture qc-wrapper sqanti3 qc --help
  printf 'rules\n' | capture filter-wrapper sqanti3 filter --help
  capture rescue-wrapper sqanti3 rescue --help
  capture init-wrapper sqanti3 init --help
  capture qc sqanti3_qc.py --help
  capture rules sqanti3_filter.py rules --help
  capture ml sqanti3_filter.py ml --help
  capture rescue sqanti3_rescue.py --help
  capture reads sqanti3_reads.py --help
  grep -F '{all,qc,filter,rescue,init}' "$tmp/sqanti3.log" >/dev/null
  grep -F -- '--include_ORF' "$tmp/qc.log" >/dev/null
  grep -F -- '--aligner_choice' "$tmp/qc.log" >/dev/null
  grep -F -- '--counts_design' "$tmp/qc.log" >/dev/null
  grep -F -- '--json_filter' "$tmp/rules.log" >/dev/null
  grep -F -- '--percent_training' "$tmp/ml.log" >/dev/null
  grep -F -- '--skip_requant' "$tmp/rescue.log" >/dev/null
  grep -F -- '--sqanti_dirs' "$tmp/reads.log" >/dev/null
  capture gffread-version gffread --version
  capture gmap-version gmap --version
  capture minimap2-version minimap2 --version
  capture star-version STAR --version
  capture kallisto-version kallisto version
  capture samtools-version samtools --version
  capture ultra-version uLTRA --version
  capture td2-longorfs TD2.LongOrfs --help
  capture td2-predict TD2.Predict --help
  grep -Eq '^[0-9]+\.[0-9]+(-r[0-9]+)?$' "$tmp/minimap2-version.log"
  grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+[a-z]?$' "$tmp/star-version.log"
  grep -F 'kallisto, version' "$tmp/kallisto-version.log" >/dev/null
  grep -E '^samtools [0-9]+' "$tmp/samtools-version.log" >/dev/null
  printf 'sqanti3_modules_ok\n'
}

pipeline() {
  tmp="$(mktemp -d /tmp/taf-sqanti3-pipeline.XXXXXX)"
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
  grep -F 'min_intron_length' qc-out/tiny_classification.txt >/dev/null
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

reports() {
  tmp="$(mktemp -d /tmp/taf-sqanti3-reports.XXXXXX)"
  cd "$tmp"
  fixture=/opt/sqanti3/share/testdata/reads
  capture reads-report sqanti3_reads.py --design "$fixture/design.csv" \
    --sqanti_dirs "$fixture/sqanti_dirs" --refGTF "$fixture/reference/gencode.v38.basic_chr22.gtf" \
    --output "$tmp/report" --prefix sqantiReads -ge 10 --report both --jobs 1 --cpus 1
  test -s report/sqantiReads_report.html
  test -s report/sqantiReads_report.pdf
  python - <<'PY'
from pathlib import Path
import json
import pandas as pd
from pandas.testing import assert_frame_equal
base = Path('/opt/sqanti3/share/testdata/reads/baseline')
out = Path('report')
for expected in sorted(base.glob('*.csv')):
    assert_frame_equal(pd.read_csv(out/expected.name), pd.read_csv(expected), check_dtype=False, rtol=1e-6)
assert (out/'sqantiReads_report.pdf').read_bytes().startswith(b'%PDF-')
html = (out/'sqantiReads_report.html').read_text()
assert html.count('Plotly.newPlot') > 10
assert 'plotly.js' in html.lower() and '<html' in html.lower()
summary = list(out.glob('*qc_summary.json'))
assert len(summary) == 1 and json.loads(summary[0].read_text())
PY
  printf 'sqanti3_reports_ok\n'
}

resources() {
  tmp="$(mktemp -d /tmp/taf-sqanti3-resources.XXXXXX)"
  cd "$tmp"
  mkdir root
  chmod 0755 root
  python - <<'PY'
import hashlib, json
from pathlib import Path
payload=b'chrSynthetic\t10\t20\tpeak\t1\t+\n'
Path('evidence.bed').write_bytes(payload)
spec=dict(schema='taffish.sqanti3.resource.v1', id='synthetic', version='1', kind='cage-bed',
          assembly='synthetic', url='https://example.invalid/evidence.bed', bytes=len(payload),
          sha256=hashlib.sha256(payload).hexdigest(), filename='evidence.bed',
          license='CC0-1.0 synthetic test fixture', license_url='https://creativecommons.org/publicdomain/zero/1.0/')
Path('spec.json').write_text(json.dumps(spec))
spec['version'] = '2'
Path('next.json').write_text(json.dumps(spec))
PY
  capture dry-run sqanti3-resources install --root "$tmp/root" --spec spec.json --dry-run
  grep -F 'license_acceptance_required' "$lastlog" >/dev/null
  capture install sqanti3-resources install --root "$tmp/root" --spec spec.json --local-file evidence.bed --accept-license
  capture idempotent sqanti3-resources install --root "$tmp/root" --spec spec.json --local-file evidence.bed --accept-license
  grep -F 'already verified' "$lastlog" >/dev/null
  capture verify sqanti3-resources verify --root "$tmp/root"
  chmod 0666 root/ROOT.json
  if sqanti3-resources install --root "$tmp/root" --spec next.json --local-file evidence.bed --accept-license >"$tmp/unsafe-root.log" 2>&1; then
    printf >&2 'new member accepted an unsafe resource root\n'; return 1
  fi
  grep -F 'not writable' "$tmp/unsafe-root.log" >/dev/null
  test ! -e root/members/synthetic/2
  chmod 0644 root/ROOT.json
  printf 'corrupt\n' >> root/members/synthetic/1/evidence.bed
  if sqanti3-resources verify --root "$tmp/root" >"$tmp/corrupt.log" 2>&1; then
    printf >&2 'corrupt resource was accepted\n'; return 1
  fi
  grep -F 'mismatch' "$tmp/corrupt.log" >/dev/null
  sha256sum root/members/synthetic/1/* > before.sha256
  if sqanti3-resources install --root "$tmp/root" --spec next.json --local-file evidence.bed --accept-license >"$tmp/new-member.log" 2>&1; then
    printf >&2 'new member accepted a corrupt resource store\n'; return 1
  fi
  grep -F 'mismatch' "$tmp/new-member.log" >/dev/null
  test ! -e root/members/synthetic/2
  sha256sum -c before.sha256 >/dev/null
  cp evidence.bed root/members/synthetic/1/evidence.bed
  capture recovered sqanti3-resources install --root "$tmp/root" --spec next.json --local-file evidence.bed --accept-license
  capture recovered-idempotent sqanti3-resources install --root "$tmp/root" --spec next.json
  grep -F 'already verified' "$lastlog" >/dev/null
  capture final-verify sqanti3-resources verify --root "$tmp/root"
  printf 'sqanti3_resources_ok\n'
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
  reports) reports ;;
  resources) resources ;;
  all)
    buildtime
    identity
    modules
    pipeline
    reports
    resources
    ;;
  *)
    printf 'unknown smoke mode: %s\n' "$mode" >&2
    exit 2
    ;;
esac
