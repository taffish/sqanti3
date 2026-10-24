# sqanti3

`sqanti3` packages [SQANTI3](https://github.com/ConesaLab/SQANTI3) for TAFFISH.

Package identity:

- command: `taf-sqanti3`; kind: `tool`; version: `6.1-r1`
- image: `ghcr.io/taffish/sqanti3:6.1-r1`
- native platforms: `linux/amd64`, `linux/arm64`; CPU runtime
- packaging license: Apache-2.0; upstream license: GPL-3.0-only

## Installation

After publication, use `taf update` and `taf install sqanti3`.
Before publication, use `taf install --from .` in this app directory.

## What This App Packages

The unmodified official v6.1 source (commit
`589dfd41e84b6e73ef27cf20d7a823131e02465f`) is installed with Conda
dependencies. Bioconda's SQANTI3 package was still 6.0.2 when this update
started, so it is not used as the application payload.
The source archive SHA256 is
`f5a58b4a4ac395c1217c71a2e693157b698b59910d9ae061dcfa1badc433abe2`.

No upstream algorithm is patched. The upstream x86-named gtfToGenePred path
is linked to the architecture-native UCSC binary. The separate
`sqanti3-resources` packaging helper manages optional evidence files, not
scientific analysis or species selection.

## Scope and Container Contents

- `sqanti3`: YAML orchestration (`all`, `qc`, `filter`, `rescue`, `init`).
- `sqanti3_qc.py`: GTF or FASTA/FASTQ correction, classification and QC.
- `sqanti3_filter.py`: rules-based and machine-learning filtering.
- `sqanti3_rescue.py`: automatic/full rescue, evidence checking and requantification.
- `sqanti3_reads.py`: multisample aggregation, upstream PDF and interactive HTML.
- minimap2, GMAP, deSALT and uLTRA: long-read alignment options.
- STAR, kallisto, samtools and seqtk: short-read and sequence helpers.
- gffread, gtftools, bedtools and native gtfToGenePred: annotation/interval helpers.
- TD2 1.1.0, PSAURON 1.1.3 and CPU PyTorch 2.5.1: ORF prediction/scoring.
- Python, R, Plotly and Pandoc: upstream analysis and report dependencies.
- IsoAnnotLite and the small bundled human/mouse TUSCO panels are retained.

No production genome, annotation, GMAP index, CAGE/polyA/phyloP collection or
sequencing study is bundled. GPU execution is not provided.
The companion tappAS is an independent downstream Java GUI consuming
IsoAnnotLite output, not a component of this CLI image; install it separately
from [tappAS](https://app.tappas.org/overview/). SQANTI3's own static reports
are included. No browser server or exposed port is required.
This is a deliberate application boundary: tappAS adds its own Java desktop,
SQLite project lifecycle, R analysis and separately managed annotations. Its
published hardware requirements include 8 GB RAM and 20 GB free workspace;
bundling that GUI requires a separate desktop/session and data-governance review.
The CLI package does not claim to validate the tappAS GUI.

## Usage

```sh
taf-sqanti3 --help
taf-sqanti3 -- --help
taf-sqanti3 sqanti3_qc.py --help
taf-sqanti3 sqanti3_qc.py --isoforms collapsed.gtf --refGTF reference.gtf --refFasta genome.fa --dir qc-out --output sample --cpus 8 --report html
taf-sqanti3 sqanti3_filter.py rules --sqanti_class qc-out/sample_classification.txt --filter_gtf qc-out/sample_corrected.gtf --dir filter-out --output sample
taf-sqanti3 sqanti3_filter.py ml --sqanti_class qc-out/sample_classification.txt --dir ml-out --output sample --cpus 8
taf-sqanti3 sqanti3 init --config sqanti3_config.yaml
taf-sqanti3 sqanti3 all --config sqanti3_config.yaml --dry-run
```

For sequence input, use `--isoforms transcripts.fa --fasta --aligner_choice minimap2`
with matching reference GTF/FASTA. Add `--include_ORF` to request TD2 prediction.
Upstream recommends collapsed GTF input. Do not add an `exec` command or another
entrypoint: ordinary explicit executable names use TAFFISH automatic command mode.
Use `taf-sqanti3 sqanti3 qc ...`, not `taf-sqanti3 qc ...`.
For a value containing spaces, TAFFISH 0.11.0 needs literal quotes preserved
inside the argument, for example `--output "'report with spaces'"` for reads.
Ordinary shell quoting alone is not the tested wrapper syntax.
The YAML wrapper can ask for confirmation for disabled sections; prefer direct
module commands in unattended jobs.

### Version 6.1 changes affecting use

Rescue now runs requantification by default and needs `--counts`.
Its default evidence check can also require counts; `--skip_requant` alone does
not disable that check. To intentionally perform neither operation:

```sh
taf-sqanti3 sqanti3_rescue.py --filter_class filter-out/sample_RulesFilter_classification.txt --refGTF reference.gtf --refFasta genome.fa --corrected_isoforms_fasta qc-out/sample_corrected.fasta --filtered_isoforms_gtf filter-out/sample.filtered.gtf --strategy rules --mode automatic --skip_requant --skip_evidence_check --dir rescue-out --output sample --cpus 8
```

These switches change the analysis and are not automatic packaging defaults.
Read upstream help before choosing them. QC adds count-design/prevalence controls
and minimum-intron information. SQANTI-reads has its own version `1.1.0`.

```sh
taf-sqanti3 sqanti3_reads.py --design design.csv --sqanti_dirs sqanti-output-root --refGTF reference.gtf --output reads-out --prefix sample --report both --cpus 8 --jobs 1
```

Open the resulting HTML in a local browser and the PDF in a PDF reader.
They are upstream-generated reports, not TAFFISH-recalculated results.
The native PDF summary table can have crowded long column headings; use the
HTML and accompanying CSV/JSON for readable labels and exact values.
The upstream rules-filter R report fails when no gene is wholly classified as
an artifact (`all_artifacts_TRUE` is absent). For such input, explicitly add
`--skip_report`; do not alter filtering rules merely to make the report render.
Filtering tables remain the primary results. This upstream boundary is retained,
not silently patched by the package.

## Inputs and Output Notes

Reference FASTA, annotation, BED tracks and aligned evidence must share assembly
and sequence naming. Pre-create FASTA/BAM indexes before making inputs read-only.
Use writable explicit output directories; references and shared resources are
not output directories. Short-read/BAM/count inputs and derived indexes remain
project inputs, not automatically downloaded resources.

QC writes classification/junction tables, corrected GTF/FASTA, parameters,
logs and requested reports. Filter writes its classification, passing IDs and
optional filtered sequence/annotation files. Rescue and reads use their own
output directories. Intermediate aligner, ORF and TUSCO outputs depend on options.

## Backend Usage and Capability Matrix

All ordinary commands have the same interface:

```sh
TAFFISH_CONTAINER_BACKEND=docker taf-sqanti3 sqanti3_qc.py --help
TAFFISH_CONTAINER_BACKEND=podman taf-sqanti3 sqanti3_qc.py --help
TAFFISH_CONTAINER_BACKEND=apptainer taf-sqanti3 sqanti3_qc.py --help
```

Docker uses the invoking UID/GID; Podman uses keep-id; Apptainer uses the caller.
Report generation is headless on all three backends; view completed files on
the host. The native platform/backend validation record is in Testing below.
ARM64 Linux Apptainer is not separately validated; this is not a claim of
six native platform/backend combinations. GPU is unsupported on all backends;
use the packaged CPU path.

## Resources, Databases, and Platform

The smallest reusable unit is an explicitly selected, versioned plain-text
evidence member, not an entire mutable catalog. Supported helper kinds are
`cage-bed`, `polya-bed` (BED6 or more), `polya-motifs` (one ranked DNA motif
per line), `phylop-bed` (BED4), `isoannot-gff3` (tappAS GFF3) and
`junctions-star` (STAR nine-column junction records).
The helper checks identity, size, SHA256 and basic syntax, not biological
compatibility. It never selects a species/assembly or converts scientific data.

Potential sources include [refTSS](https://reftss.riken.jp/),
[PolyASite](https://polyasite.unibas.ch/atlas), and the
[tappAS GFF3 downloads](https://app.tappas.org/resources/downloads/gffs/).
Their versions, assemblies, formats and licenses are independent.
refTSS identifies CC-BY-4.0 on its site; do not infer that license for other
resources. Review each member's actual license before installation or redistribution.
Compressed bundles must be explicitly unpacked/converted outside this helper;
pin the resulting plain file and record the preparation provenance separately.
The original source URL remains provenance; for an archive URL use
`--local-file`, never `--allow-download` against the archive.

Create `member.json` with exactly these fields, replacing every example value:

```json
{
  "schema": "taffish.sqanti3.resource.v1",
  "id": "selected-cage", "version": "selected-version",
  "kind": "cage-bed", "assembly": "selected-assembly",
  "url": "https://resource-provider.example/fixed-member.bed",
  "sha256": "64-lowercase-hex-digits-from-the-selected-file",
  "bytes": 12345, "filename": "peaks.bed",
  "license": "reviewed-resource-license",
  "license_url": "https://resource-provider.example/license"
}
```

The placeholder descriptor is deliberately not installable. Obtain the actual
byte count and checksum independently; a URL alone is not a fixed identity.

```sh
store="$HOME/.local/share/taffish/resources/sqanti3"
mkdir -p "$store"
chmod 0755 "$store"
TAFFISH_SQANTI3_RESOURCE_INSTALL_ROOT="$store" taf-sqanti3 sqanti3-resources install --spec member.json --dry-run
TAFFISH_SQANTI3_RESOURCE_INSTALL_ROOT="$store" taf-sqanti3 sqanti3-resources install --spec member.json --local-file peaks.bed --accept-license
taf-sqanti3 sqanti3-resources list
taf-sqanti3 sqanti3-resources path --id selected-cage --version selected-version
```

A network transfer requires both `--allow-download` and `--accept-license`;
there is no implicit runtime download. Re-running installation verifies and
reuses an identical installed member. It never overwrites an installed version.
Interrupted downloads retain a private partial and can resume; `--restart`
resets only that member's uncommitted payload. SHA/size/format failures never
replace old resources. An atomic per-member directory lock prevents concurrent
installation, including on host shares that do not enforce advisory file locks.
Ctrl-C and TERM release the lock while preserving partial data. After SIGKILL,
a crash or power loss, installation fails closed if a lock remains: first
confirm that **all installers using this store have stopped**, then use `rmdir`
on the exact empty `.locks/<hash>` directory printed in the error, on the host
store (not the container path). Retry the same install to resume. Never remove
a lock while another installer may be active; never remove the whole `.locks`,
`.partial` or `members` tree. A PID from another container is not proof of staleness.
Space is checked before transfer. A successful install atomically promotes
the member and records its descriptor and READY checksum.

Every install (including a new member or dry-run) validates the complete
published store using the same validator as automatic discovery: root identity,
permissions, every member's manifest/READY, size, checksum and basic format.
Validation repeats under the member lock and immediately before promotion.
A bad existing member or unsafe ROOT.json fails before transfer; the helper
does not delete, overwrite or silently repair old resources. Restore the exact
verified bytes/permissions from your backup, or select a separate verified root.
Missing ROOT.json over an existing members tree is not treated as a new store.
Only first-install initialization and uncommitted partials can resume without
a completed member; they are never accepted by discovery as a usable library.

### Administrator-once / read-only user reuse

An administrator can pre-create
`/usr/local/share/taffish/resources/sqanti3` or
`/opt/taffish/resources/sqanti3`, then run the same explicit installer once.
The store must not be group/world-writable. Installed files are 0644 and
directories 0755; ancestors must also be traversable. Ordinary users need only
read access and never rerun installation. No root privilege is requested by
the wrapper itself.

Discovery order is explicit `TAFFISH_SQANTI3_RESOURCE_ROOT`, personal
`${XDG_DATA_HOME:-$HOME/.local/share}/taffish/resources/sqanti3`, then the two
system paths above. Host Python 3 validates the same identity/format contract
as the container helper before binding the store read-only at
`/sqanti3-resources`. A valid root symlink is resolved; broken links and
internal symlinks fail. A selected invalid root fails clearly rather than
silently falling back. Set `TAFFISH_SQANTI3_RESOURCE_AUTO_MOUNT=0` to disable
discovery, or use `TAFFISH_SQANTI3_RESOURCE_INSTALL_ROOT` for an explicit writable
install bind at `/resource-install`.

Upstream options still require explicit member paths, for example
`--CAGE_peak /sqanti3-resources/members/selected-cage/selected-version/peaks.bed`.
An empty root or merely downloaded partial is not a verified usable store.

### Three-backend manual fallback

For an already verified store, disable discovery and bind it explicitly.
Use shell-safe absolute paths without whitespace, colon, comma or glob characters
in these runtime-argument examples; use a safe alias/location otherwise.

```sh
TAFFISH_SQANTI3_RESOURCE_AUTO_MOUNT=0 TAFFISH_CONTAINER_BACKEND=docker TAFFISH_DOCKER_RUN_ARGS="--volume=$store:/sqanti3-resources:ro" taf-sqanti3 sqanti3-resources verify
TAFFISH_SQANTI3_RESOURCE_AUTO_MOUNT=0 TAFFISH_CONTAINER_BACKEND=podman TAFFISH_PODMAN_RUN_ARGS="--volume=$store:/sqanti3-resources:ro" taf-sqanti3 sqanti3-resources verify
TAFFISH_SQANTI3_RESOURCE_AUTO_MOUNT=0 TAFFISH_CONTAINER_BACKEND=apptainer TAFFISH_APPTAINER_RUN_ARGS="--bind=$store:/sqanti3-resources:ro" taf-sqanti3 sqanti3-resources verify
```

For manual installation, bind the pre-created writable store to
`/resource-install` without `:ro`, keep discovery off and call the same
`install` command. Do not write into the image's installation tree.
Use the install-root variable when possible; it handles all three backends.

## Runtime and Reproducibility Boundaries

The image pins official application source and critical dependency identities.
ARM64 uses R 4.4.2 and amd64 uses R 4.4.3, both with Bioconductor 3.20;
the ARM64 build matches upstream's pysam constraint and available ICU/libdeflate
dependencies. No algorithm changes or emulated platform claims are involved.
Conda channels, transitive solves, APT indexes and upstream hosting can drift;
Dockerfile comments describe the repair boundary. This is not a promise that
all historical external URLs remain available forever. Resolved package lists
are retained under `/opt/sqanti3/share/doc/sqanti3/`.
Compiler frontends, headers, sysroots, caches and development/test payloads
not needed at runtime are removed; compiling new packages in this runtime is
outside the contract.

Tiny bundled TUSCO panels are source-versioned; project FASTA/GTF/counts are
explicit inputs. Optional resource families are not downloaded in full.
PSAURON 1.1.3 includes its 792,554-byte model inside the image (SHA256
`a1b0b67303af6db3514ce62a1d07e2c211d81c0659647b53a91db3f430b27f38`);
its loader reads that packaged file, not a user cache or a network download.
It therefore needs no separate system-wide model installer; every user reads
the same image-contained model. External evidence uses the separate store above.
No production study, whole-catalog biological compatibility, GPU performance
or all optional aligner/ML/rescue combinations are certified by packaging smoke.

## Troubleshooting

- Missing evidence: explicitly select/install a member, or omit the corresponding
  optional upstream analysis option. The helper does not choose evidence for you.
- Invalid resource root: run `sqanti3-resources verify`, restore matching bytes
  and read/traverse permissions, or select another verified root. Do not edit READY.
  Installing a different member or using `--restart` does not bypass this check.
- Interrupted/corrupt partial: rerun the same install; use `--restart` only to
  discard that uncommitted payload. Installed members are immutable.
- Rescue asks for counts: supply the proper count matrix, or deliberately choose
  both skip switches if you intend to skip both operations.
- Failures on large datasets: check output space, RAM, CPUs, assembly/name
  compatibility and upstream logs before changing scientific parameters.
- R startup can mention an unavailable `otelsdk`. It is an optional `Suggests`
  dependency of `otel` 0.2.0, not a required SQANTI3 analysis dependency;
  required R imports and the tested offline reports pass without it.

## Testing

Runtime validation below covers the repaired 6.1-r1 candidate on 2026-10-21–22.

- Both native architectures passed canonical app-root builds: amd64 image
  2,931,849,551 bytes; ARM64 image 2,885,091,406 bytes. Package caches,
  development headers, compiler/sysroot files and non-runtime tests are removed;
  required analysis/report/model dependencies remain.
- xjp Docker and Podman: 141 independent exact probes per backend passed
  (normal, read-only and read-only/nonroot), with networking disabled.
- xjp Apptainer: 47 exact probes passed against the real read-only SIF made
  from the same candidate OCI, as an ordinary user.
- Each xjp backend passed 41 wrapper checks, 8 model/ORF/report/rescue checks,
  3 count/prevalence checks and 8 terminal interruption/recovery/idempotence checks.
  The wrapper resource suite includes 100 full-store validation/recovery cases,
  42 existing negative/recovery/idempotence cases including SIGKILL fail-closed
  recovery, plus 5 earliest-signal/lock-ownership cases. Bad existing stores
  reject new members, dry-run and reuse without changing old bytes/permissions;
  corruption during transfer prevents promotion and permits partial reuse after recovery.
- A private representative shared bind passed 20 administrator-once,
  ordinary-user read-only reuse and permission/recovery checks. This does not
  claim that a real site's system-wide store has been deployed.
- The 101 installed official source/configuration files match upstream bytes.
  The packaged PSAURON model is loaded and evaluated offline.
- The maintainer confirmed the native HTML's display and interactions; the
  checked file is byte-identical to the final amd64 wrapper report. All 68 PDF
  pages were rendered and visually reviewed, with the upstream layout limits above.
- Native ARM64 Docker and Podman each passed 141 independent exact probes,
  41 wrapper checks, the 100+42+5 resource/lock cases, 8 model/ORF/report/rescue
  checks and 3 count/prevalence checks. Local Conda DNS timeouts required a
  task-private BuildKit DNS configuration for the unchanged Dockerfile;
  that builder/configuration was removed afterward. No host network settings
  or Docker/Podman engine were restarted or changed.
- Linux ARM64 Apptainer is not separately validated. This is not a claim of
  all six architecture/backend combinations; no backend exception is assumed.
- These are pre-publication packaging checks, not a formal biological study.

## License and Citation

TAFFISH packaging is Apache-2.0; SQANTI3 is GPL-3.0-only. Upstream documentation
and license files are retained in the image. Dependencies, models and external
evidence retain their own licenses; installing a member requires explicit
license acknowledgement and does not grant redistribution rights.

Cite Pardo-Palacios FJ et al., Nature Methods (2024),
[doi:10.1038/s41592-024-02229-2](https://doi.org/10.1038/s41592-024-02229-2).
