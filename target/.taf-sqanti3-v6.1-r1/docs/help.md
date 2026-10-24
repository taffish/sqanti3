sqanti3 6.1-r1

Purpose:
  QC, classify, filter and rescue long-read transcripts; generate SQANTI-reads
  PDF and interactive HTML reports. CPU execution on amd64 and arm64.

Usage:
  taf-sqanti3 -- --help
  taf-sqanti3 sqanti3_qc.py --help
  taf-sqanti3 sqanti3_qc.py --isoforms collapsed.gtf --refGTF reference.gtf --refFasta genome.fa --dir qc-out --output sample --cpus 8 --report html
  taf-sqanti3 sqanti3_filter.py rules --sqanti_class qc-out/sample_classification.txt --filter_gtf qc-out/sample_corrected.gtf --dir filter-out --output sample

More tasks:
  taf-sqanti3 sqanti3_filter.py ml --help
  taf-sqanti3 sqanti3_rescue.py --help
  taf-sqanti3 sqanti3_reads.py --design design.csv --sqanti_dirs sqanti-output-root --refGTF reference.gtf --output reads-out --prefix sample --report both --cpus 8 --jobs 1
  taf-sqanti3 sqanti3 init --config sqanti3_config.yaml
  taf-sqanti3 sqanti3 all --config sqanti3_config.yaml --dry-run

Input and output:
  Use matching reference FASTA, GTF and assembly/sequence names.
  GTF input is recommended. Sequence input also needs --fasta; choose an
  --aligner_choice explicitly when needed. --include_ORF requests CPU TD2.
  Write to your selected output directory, not the reference/resource store.
  QC emits classification/junction tables, corrected GTF/FASTA and reports.
  Open completed HTML/PDF files on the host; no browser service is needed.
  If rules-filter report fails with all_artifacts_TRUE, use --skip_report;
  this upstream empty-category limitation does not require changing the filter.
  Pre-create reference/BAM indexes before mounting inputs read-only.

Version 6.1:
  Rescue now requires --counts for default requantification/evidence checks.
  To intentionally omit BOTH, use --skip_requant --skip_evidence_check.
  These change the analysis; see upstream rescue help before selecting them.
  SQANTI-reads separately reports component version 1.1.0.

Choose a backend:
  TAFFISH_CONTAINER_BACKEND=docker taf-sqanti3 sqanti3_qc.py --help
  TAFFISH_CONTAINER_BACKEND=podman taf-sqanti3 sqanti3_qc.py --help
  TAFFISH_CONTAINER_BACKEND=apptainer taf-sqanti3 sqanti3_qc.py --help
  Apptainer requires Linux. ARM64 Apptainer is not separately validated;
  use native Docker/Podman on ARM64 or a Linux amd64 Apptainer host.
  GPU mode is not provided; use CPU execution.

Optional shared evidence:
  Select compatible CAGE/polyA/phyloP, STAR junction or tappAS GFF3 members.
  Create member.json with the exact identity, size, SHA256, format and license
  fields documented in the repository README. No species is selected for you.
  store="$HOME/.local/share/taffish/resources/sqanti3"
  mkdir -p "$store"
  chmod 0755 "$store"
  TAFFISH_SQANTI3_RESOURCE_INSTALL_ROOT="$store" taf-sqanti3 sqanti3-resources install --spec member.json --dry-run
  TAFFISH_SQANTI3_RESOURCE_INSTALL_ROOT="$store" taf-sqanti3 sqanti3-resources install --spec member.json --local-file peaks.bed --accept-license
  taf-sqanti3 sqanti3-resources list
  taf-sqanti3 sqanti3-resources path --id selected-cage --version selected-version
  A network transfer requires --allow-download and --accept-license.
  Repeat the same command to resume/reuse; --restart resets only the partial.
  After a crash, a stale lock fails closed; see README for safe lock recovery.
  Installs reject any bad existing member; restore its verified bytes/permissions.
  Never edit an installed member. Use a new version for different content.
  Pass the returned path explicitly to the appropriate upstream option.

Discovery and sharing:
  Host Python 3 verifies the store before mounting it read-only.
  Order: TAFFISH_SQANTI3_RESOURCE_ROOT, personal XDG/HOME data path, then
  /usr/local/share/taffish/resources/sqanti3 and
  /opt/taffish/resources/sqanti3. Invalid selected roots fail clearly.
  An administrator can install once in a system path; ordinary users reuse it.
  Store directories/files must be readable, traversable where applicable, and
  not writable by other users. Ancestor directories must permit traversal.
  TAFFISH_SQANTI3_RESOURCE_AUTO_MOUNT=0 disables discovery.

Manual read-only fallback for a verified store (safe absolute path):
  TAFFISH_SQANTI3_RESOURCE_AUTO_MOUNT=0 TAFFISH_CONTAINER_BACKEND=docker TAFFISH_DOCKER_RUN_ARGS="--volume=$store:/sqanti3-resources:ro" taf-sqanti3 sqanti3-resources verify
  TAFFISH_SQANTI3_RESOURCE_AUTO_MOUNT=0 TAFFISH_CONTAINER_BACKEND=podman TAFFISH_PODMAN_RUN_ARGS="--volume=$store:/sqanti3-resources:ro" taf-sqanti3 sqanti3-resources verify
  TAFFISH_SQANTI3_RESOURCE_AUTO_MOUNT=0 TAFFISH_CONTAINER_BACKEND=apptainer TAFFISH_APPTAINER_RUN_ARGS="--bind=$store:/sqanti3-resources:ro" taf-sqanti3 sqanti3-resources verify
  Install with RESOURCE_INSTALL_ROOT above on any backend; it binds writable
  /resource-install. Do not use the image root as persistent storage.

Help and troubleshooting:
  taf-sqanti3 --help       Wrapper usage
  taf-sqanti3 --version    Wrapper identity
  taf-sqanti3 --compile    Generated command
  taf-sqanti3 sqanti3_qc.py --version
  Use explicit executables (sqanti3_qc.py, sqanti3_filter.py, sqanti3_rescue.py,
  sqanti3_reads.py), not bare module names. Check output space and input names
  on failure; resource verify reports identity/permissions problems.
  https://github.com/taffish/sqanti3
  https://conesalab.github.io/SQANTI3/latest/
