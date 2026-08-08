# sqanti3

`sqanti3` packages [SQANTI3](https://github.com/ConesaLab/SQANTI3) for TAFFISH.

Package identity:

- name: `sqanti3`
- command: `taf-sqanti3`
- kind: `tool`
- TAFFISH version: `6.0.2-r1`
- TAFFISH app license: Apache-2.0
- upstream release: `ConesaLab/SQANTI3` `v6.0.2`
- upstream license: GPL-3.0-only
- container image: `ghcr.io/taffish/sqanti3:6.0.2-r1`
- native platforms: `linux/amd64`, `linux/arm64`
- default upstream command: `sqanti3`

## Installation

```sh
taf update
taf install sqanti3
```

For local validation before publication, use `taf install --from .` in this
app directory.

## What This App Packages

SQANTI3 curates long-read transcriptomes by correcting transcript models,
classifying isoforms against a reference annotation, annotating splice and
end-site quality, filtering likely artifacts, and rescuing eligible discarded
isoforms. It also includes SQANTI-reads for multisample long-read transcriptome
aggregation and under-annotation analysis.

The image installs the exact Bioconda `sqanti3=6.0.2=hdfd78af_1` package and
retains the official release documentation and licenses. Its complete Python,
R, aligner, short-read, ORF-prediction, filtering, rescue, and reporting
dependency closure is contained in the image; no unrelated host bioinformatics
command is required.

## Scope

This app supports:

- the `sqanti3` YAML configuration wrapper for `all`, `qc`, `filter`, `rescue`, and `init`
- `sqanti3_qc.py` with GTF input or FASTA/FASTQ mapping
- minimap2, GMAP, deSALT, and uLTRA long-read alignment paths
- optional STAR/kallisto short-read evidence and existing junction, BAM, expression, or abundance inputs
- optional TD2/PSAURON ORF prediction with `--include_ORF`
- rules-based and machine-learning isoform filtering
- automatic and full transcript rescue, including optional requantification
- SQANTI-reads aggregation from raw inputs or existing SQANTI3 directories
- HTML and PDF reports through the packaged R and Pandoc runtime
- optional CAGE, polyA motif/site, phyloP, IsoAnnotLite, TUSCO, and expression evidence

The image does not bundle a species reference genome, reference annotation,
CAGE peaks, polyA resources, phyloP tracks, short-read datasets, GMAP indexes,
or production transcriptomes. These inputs are project- and assembly-specific.

## Container Contents

- `sqanti3`: upstream YAML pipeline wrapper and default command
- `sqanti3_qc.py`: transcript correction, classification, QC, and reporting
- `sqanti3_filter.py`: rules and machine-learning filtering
- `sqanti3_rescue.py`: automatic or full rescue of filtered isoforms
- `sqanti3_reads.py`: multisample SQANTI-reads analysis
- `gffread`, `gtfToGenePred`, `gtftools`, and `bedtools`: annotation conversion, SQANTI-reads UJC generation, and interval operations
- `minimap2`, `gmap`, `deSALT`, and `uLTRA`: supported long-read aligners
- `STAR`, `kallisto`, `samtools`, and `seqtk`: short-read and sequence helper paths
- `TD2.LongOrfs` and `TD2.Predict`: ORF discovery and PSAURON scoring
- `R`, `Rscript`, and `pandoc`: QC, filter, rescue, TUSCO, and SQANTI-reads reports

## Usage

Show wrapper and upstream help:

```sh
taf-sqanti3 --help
taf-sqanti3 -- --help
taf-sqanti3 sqanti3_qc.py --help
taf-sqanti3 sqanti3_filter.py rules --help
```

Run the recommended GTF-based QC path:

```sh
taf-sqanti3 sqanti3_qc.py \
  --isoforms collapsed.gtf \
  --refGTF reference.gtf \
  --refFasta genome.fa \
  --dir sqanti3-qc \
  --output sample \
  --cpus 8 \
  --report html
```

Map transcript sequences before QC:

```sh
taf-sqanti3 sqanti3_qc.py \
  --isoforms transcripts.fasta \
  --fasta \
  --refGTF reference.gtf \
  --refFasta genome.fa \
  --aligner_choice minimap2 \
  --dir sqanti3-qc \
  --output sample \
  --cpus 8
```

Add ORF prediction:

```sh
taf-sqanti3 sqanti3_qc.py \
  --isoforms collapsed.gtf \
  --refGTF reference.gtf \
  --refFasta genome.fa \
  --include_ORF \
  --dir sqanti3-qc \
  --output sample \
  --cpus 8
```

Filter a QC classification with the upstream default rules:

```sh
taf-sqanti3 sqanti3_filter.py rules \
  --sqanti_class sqanti3-qc/sample_classification.txt \
  --filter_gtf sqanti3-qc/sample_corrected.gtf \
  --dir sqanti3-filter \
  --output sample \
  --cpus 8
```

Run automatic rescue after rules filtering:

```sh
taf-sqanti3 sqanti3_rescue.py \
  --filter_class sqanti3-filter/sample_RulesFilter_classification.txt \
  --refGTF reference.gtf \
  --refFasta genome.fa \
  --corrected_isoforms_fasta sqanti3-qc/sample_corrected.fasta \
  --filtered_isoforms_gtf sqanti3-filter/sample.filtered.gtf \
  --strategy rules \
  --mode automatic \
  --dir sqanti3-rescue \
  --output sample \
  --cpus 8
```

Create and use an upstream YAML configuration:

```sh
taf-sqanti3 sqanti3 init --config sqanti3_config.yaml
taf-sqanti3 sqanti3 all --config sqanti3_config.yaml --dry-run
taf-sqanti3 sqanti3 all --config sqanti3_config.yaml
```

Run SQANTI-reads from existing per-sample SQANTI3 directories:

```sh
taf-sqanti3 sqanti3_reads.py \
  --refFasta genome.fa \
  --refGTF reference.gtf \
  --design design.tsv \
  --sqanti_dirs sqanti-output-root \
  --output sqanti-reads \
  --report html \
  --cpus 8
```

## Command Mode

This is a normal TAFFISH tool app with automatic command mode. The default
command is the upstream `sqanti3` YAML wrapper. Use explicit packaged command
names for direct, non-interactive pipeline use:

```sh
taf-sqanti3 sqanti3_qc.py ...
taf-sqanti3 sqanti3_filter.py rules ...
taf-sqanti3 sqanti3_rescue.py ...
taf-sqanti3 sqanti3_reads.py ...
```

Use `taf-sqanti3 -- --help` to pass an option-leading argument to the default
command. The YAML wrapper can ask for confirmation when a requested section is
disabled. Direct module commands are preferable in unattended flows.

## Inputs

| Input | Meaning | Notes |
| --- | --- | --- |
| `--isoforms` | collapsed long-read transcriptome | GTF is recommended; FASTA/FASTQ also requires `--fasta` |
| `--refGTF` | reference transcript annotation | chromosome names and assembly must match the genome |
| `--refFasta` | reference genome FASTA | required by QC, rescue, and SQANTI-reads |
| `--short_reads` | short-read FASTA/FASTQ FOFN | optional; may invoke STAR and kallisto |
| `--SR_bam` | mapped short-read BAM directory or FOFN | optional TSS-ratio evidence |
| `--coverage` | splice-junction coverage files | optional existing STAR-style evidence |
| `--expression` | transcript expression matrix | optional existing kallisto-style evidence |
| `--fl_count` | full-length PacBio abundance | optional isoform abundance evidence |
| `--CAGE_peak` | CAGE peak BED | optional, assembly-specific |
| `--polyA_motif_list` | ranked polyA motifs | optional, species-specific |
| `--polyA_peak` | polyA site BED | optional, assembly-specific |
| `--phyloP_bed` | phyloP BED | optional conservation evidence |
| `--gff3` | tappAS-compatible annotation | optional IsoAnnotLite transfer source |

Collapse redundant long-read transcript models before SQANTI3 QC, as upstream
recommends. Reference FASTA, reference GTF, BED tracks, and aligned evidence
must describe the same assembly and use compatible sequence names.

## Output Notes

QC writes the selected `--dir` with logs and parameter records. Key files
include `*_classification.txt`, `*_junctions.txt`, `*_corrected.gtf`,
`*_corrected.fasta`, optional corrected ORF/FAA and IsoAnnotLite files, plus the
requested HTML/PDF report. Extra STAR, kallisto, aligner, TD2, chunk, and TUSCO
directories appear only when those paths are enabled.

Rules or ML filtering writes a filter classification, `*_pass_isoforms.txt`,
optional filtered GTF/FASTA/SAM/FAA/GFF3 files, and a report unless
`--skip_report` is used. Rescue and SQANTI-reads create their own requested
output directories and reports.

## Resources, Databases, and Platform

Native image platforms are `linux/amd64` and `linux/arm64`. The upstream source
hard-codes an x86_64 `gtfToGenePred` filename; this image preserves that code
path while linking it to Bioconda's architecture-native UCSC binary on each
platform. Both architectures use upstream's CPU PyTorch 2.5.1 family for TD2.
SQANTI3, Python, PyTorch, TD2, and PSAURON are pinned consistently across the
two images. Platform-specific R and Bioconductor dependency builds may differ;
each image records its exact resolved packages in
`/opt/sqanti3/share/doc/sqanti3/conda-packages.txt` and `conda-explicit.txt`.

No fixed database mount or download step is required. Users provide the
reference genome, matching annotation, and optional orthogonal evidence as
normal command-line paths. A GMAP run additionally requires a user-built GMAP
index supplied with `--gmap_index`.

Whole-transcriptome QC, FASTA alignment, short-read processing, ORF prediction,
ML filtering, rescue, and report generation can be CPU-, memory-, and
storage-intensive. Set `--cpus` and output locations for the allocated system.
TD2 works without a GPU but can be slow on large transcript sets.

This image is a production runtime. Compiler frontends, development headers,
Conda caches, and dependency-owned test fixtures are removed after installation
and smoke validation. Compiling additional R or Python extensions inside the
container is outside this app's contract; build a derived development image when
that is required.

## Boundaries

- The image includes all commands called by supported upstream paths, but the quick smoke cannot reproduce every aligner, short-read protocol, optional evidence combination, ML model, rescue strategy, or SQANTI-reads study design.
- The offline integration smoke runs real GTF correction/classification, rules filtering, annotation conversion, sequence extraction, and minimap2 remapping on synthetic data.
- Report dependencies and R packages are loaded by smoke; production HTML/PDF appearance remains data-dependent and should be reviewed on the target dataset.
- SQANTI3 is not a database distribution. Reference and evidence resources remain visible, versioned inputs controlled by the user or flow.
- `sqanti3_reads.py --version` reports the SQANTI-reads component version `1.0.0`; the app and main SQANTI3 runtime version are `6.0.2`.

## Troubleshooting

- If records disappear or classification fails, verify that reference and query chromosome names, coordinates, and assembly versions match.
- If the YAML wrapper waits for input, enable the section in its config or call `sqanti3_qc.py`, `sqanti3_filter.py`, or `sqanti3_rescue.py` directly.
- If FASTA input mapping fails, confirm `--fasta`, the selected `--aligner_choice`, and any required GMAP index path.
- If report generation fails, rerun with `--report skip` to separate analysis from rendering, then inspect the module log and validate inputs before retrying the report.
- If a run exhausts memory or storage, reduce `--cpus`/`--chunks` concurrency and place temporary/output data on a larger mounted filesystem.

## Testing

The smoke suite checks:

- exact SQANTI3, SQANTI-reads, PyTorch, torchvision, and torchaudio identities
- all five public SQANTI3 command surfaces and important subcommands
- Python and R runtime imports used by QC, reports, ML filtering, and rescue
- presence and basic identity of all packaged aligners and helper executables,
  including the `gtftools` and coreutils calls used by SQANTI-reads
- architecture-native `gtfToGenePred` wiring
- real GTF correction/classification, rules filtering, sequence extraction, and minimap2 remapping
- selected dynamic-library resolution in the final runtime image

Every index smoke command is independent, offline, and self-contained. This is
integration coverage for the packaged runtime, not scientific validation of a
production transcriptome or all optional SQANTI3 modes.

## License and Citation

TAFFISH app packaging is Apache-2.0. SQANTI3 remains GPL-3.0-only; its license,
third-party notices, and Cupcake notice are retained in the image.

Primary citation: Pardo-Palacios FJ, et al. SQANTI3: curation of long-read
transcriptomes for accurate identification of known and novel isoforms. Nature
Methods. 2024. doi:10.1038/s41592-024-02229-2.

For SQANTI-reads and TUSCO analyses, also cite the component-specific papers
listed in the [official SQANTI3 documentation](https://conesalab.github.io/SQANTI3/latest/).
