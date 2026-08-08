sqanti3 6.0.2-r1

Purpose:
  SQANTI3 corrects, classifies, quality-controls, filters, and rescues long-read
  transcript models. The image also includes SQANTI-reads, all supported
  aligners, TD2 ORF prediction, short-read helpers, and report runtimes.

Usage:
  taf-sqanti3 -- --help
  taf-sqanti3 sqanti3_qc.py --help
  taf-sqanti3 sqanti3_qc.py --isoforms collapsed.gtf --refGTF reference.gtf --refFasta genome.fa --dir qc-out --output sample --cpus 8
  taf-sqanti3 sqanti3_filter.py rules --sqanti_class qc-out/sample_classification.txt --filter_gtf qc-out/sample_corrected.gtf --dir filter-out --output sample

Packaged commands:
  sqanti3              YAML wrapper: all, qc, filter, rescue, and init.
  sqanti3_qc.py        Correction, classification, QC, and reports.
  sqanti3_filter.py    Rules or machine-learning isoform filtering.
  sqanti3_rescue.py    Automatic or full rescue of filtered isoforms.
  sqanti3_reads.py     Multisample SQANTI-reads aggregation and reports.
  gffread, gtftools, bedtools, gtfToGenePred
                       Annotation, SQANTI-reads UJC, and interval helpers.
  minimap2, gmap, deSALT, uLTRA
                       Supported long-read alignment paths.
  STAR, kallisto, samtools, seqtk
                       Short-read and sequence helpers.
  TD2.LongOrfs, TD2.Predict
                       ORF prediction and PSAURON scoring.
  R, Rscript, pandoc   QC, filter, rescue, TUSCO, and reads reports.

Common workflows:
  taf-sqanti3 sqanti3_qc.py --isoforms transcripts.fa --fasta --refGTF reference.gtf --refFasta genome.fa --aligner_choice minimap2 --dir qc-out --output sample --cpus 8
  taf-sqanti3 sqanti3_qc.py --isoforms collapsed.gtf --refGTF reference.gtf --refFasta genome.fa --include_ORF --dir qc-out --output sample --cpus 8
  taf-sqanti3 sqanti3_filter.py ml --sqanti_class qc-out/sample_classification.txt --dir ml-filter --output sample --cpus 8
  taf-sqanti3 sqanti3_rescue.py --filter_class filter-out/sample_RulesFilter_classification.txt --refGTF reference.gtf --refFasta genome.fa --strategy rules --mode automatic --dir rescue-out --output sample
  taf-sqanti3 sqanti3 init --config sqanti3_config.yaml
  taf-sqanti3 sqanti3 all --config sqanti3_config.yaml

Required QC inputs:
  --isoforms    Collapsed transcript GTF, or FASTA/FASTQ with --fasta.
  --refGTF      Reference transcript annotation GTF.
  --refFasta    Matching reference genome FASTA.

Optional evidence:
  --short_reads / --SR_bam / --coverage / --expression / --fl_count
  --CAGE_peak / --polyA_motif_list / --polyA_peak / --phyloP_bed
  --isoAnnotLite with an optional tappAS-compatible --gff3 annotation

Key outputs:
  QC: *_classification.txt, *_junctions.txt, *_corrected.gtf,
      *_corrected.fasta, logs, parameters, and requested HTML/PDF reports.
  Filter: *_RulesFilter_classification.txt or ML equivalent,
      *_pass_isoforms.txt, optional filtered sequence/annotation files,
      and a report unless --skip_report is selected.
  Rescue and SQANTI-reads write their own selected output directories.

Platform and resources:
  Native platforms are linux/amd64 and linux/arm64. Both contain the complete
  CPU runtime and an architecture-native gtfToGenePred. No production genome,
  annotation, CAGE/polyA/phyloP resource, GMAP index, or sequencing dataset is
  bundled. TD2 works on CPU and may be slow on large transcriptomes.

Boundaries:
  Reference FASTA, GTF, BED tracks, and aligned evidence must use the same
  assembly and compatible sequence names. Upstream recommends collapsed GTF
  input over FASTA/FASTQ input. The sqanti3 YAML wrapper may ask for
  confirmation when a disabled section is requested; direct module commands
  are preferable in unattended flows. Smoke covers a real small GTF QC and
  rules-filter path, not every optional protocol or scientific conclusion.

Detailed documentation:
  https://conesalab.github.io/SQANTI3/latest/
  https://github.com/ConesaLab/SQANTI3
  https://github.com/taffish/sqanti3

Wrapper options:
  taf-sqanti3 --help       Show this TAFFISH help.
  taf-sqanti3 --version    Show TAFFISH wrapper version.
  taf-sqanti3 --compile    Print generated wrapper code.
  taf-sqanti3 -- --help    Pass --help to the default sqanti3 command.

Version note:
  The app and main SQANTI3 runtime are 6.0.2. sqanti3_reads.py separately
  reports the upstream SQANTI-reads component version 1.0.0.
