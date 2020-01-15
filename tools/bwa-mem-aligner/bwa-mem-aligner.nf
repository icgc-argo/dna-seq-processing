#!/usr/bin/env nextflow

/*
 * Copyright (c) 2019, Ontario Institute for Cancer Research (OICR).
 *                                                                                                               
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as published
 * by the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program. If not, see <https://www.gnu.org/licenses/>.
 */

/*
 * author Junjun Zhang <junjun.zhang@oicr.on.ca>
 */

nextflow.preview.dsl=2

params.input_bam = "tests/input/?????_?.lane.bam"
params.aligned_lane_prefix = 'grch38-aligned'
params.ref_genome_gz = "tests/reference/tiny-grch38-chr11-530001-537000.fa.gz"
params.container_version = '0.1.3.0'

def getBwaSecondaryFiles(main_file){  //this is kind of like CWL's secondary files
  def all_files = []
  for (ext in ['.fai', '.sa', '.bwt', '.ann', '.amb', '.pac', '.alt']) {
    all_files.add(main_file + ext)
  }
  return all_files
}

process bwaMemAligner {
  container "quay.io/icgc-argo/bwa-mem-aligner:bwa-mem-aligner.${params.container_version}"

  input:
    path input_bam
    val aligned_lane_prefix
    path ref_genome_gz
    path ref_genome_gz_secondary_files

  output:
    path "${aligned_lane_prefix}.${input_bam.baseName}.bam", emit: aligned_bam

  script:
    """
    bwa-mem-aligner.py \
      -i ${input_bam} \
      -r ${ref_genome_gz} \
      -o ${aligned_lane_prefix} \
      -n ${task.cpus}
    """
}

Channel
  .fromPath(getBwaSecondaryFiles(params.ref_genome_gz), checkIfExists: true)
  .set { ref_genome_gz_ch }

Channel
  .fromPath(params.input_bam, checkIfExists: true)
  .set { input_bam_ch }

// will not run when import as module
workflow {
  main:
    bwaMemAligner(
      input_bam_ch,
      params.aligned_lane_prefix,
      file(params.ref_genome_gz),
      ref_genome_gz_ch.collect()
    )
    bwaMemAligner.out.aligned_bam.view()
  publish:
    bwaMemAligner.out to: "outdir", overwrite: true
}
