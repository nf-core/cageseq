#!/usr/bin/env python3

import gzip
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('-f', '--infastqzf', type=str, help='Path to the forward fastq.gz file')
parser.add_argument('-r', '--infastqzr', type=str, help='Path to the reverse fastq.gz file')
parser.add_argument(
    '-b','--base_to_keep', type=str, default='G',
    help='Which nuclotide to keep. Defaults to G')
args = parser.parse_args()

def filter_gz_fastq_by_first_base(input_fastq_gz_f, input_fastq_gz_r,
                                  output_fastq_gz_f, output_fastq_gz_r,
                                  base='G'):
    with gzip.open(input_fastq_gz_f, 'rt') as infile_f, \
         gzip.open(input_fastq_gz_r, 'rt') as infile_r, \
         gzip.open(output_fastq_gz_f, 'wt') as outfile_f, \
         gzip.open(output_fastq_gz_r, 'wt') as outfile_r:
        while True:
            header_f = infile_f.readline()
            header_r = infile_r.readline()
            if not header_f:
                break  # End of file
            seq_f = infile_f.readline()
            plus_f = infile_f.readline()
            qual_f = infile_f.readline()
            seq_r = infile_r.readline()
            plus_r = infile_r.readline()
            qual_r = infile_r.readline()

            if seq_f.startswith(base):
                outfile_f.write(header_f)
                outfile_f.write(seq_f)
                outfile_f.write(plus_f)
                outfile_f.write(qual_f)
                outfile_r.write(header_r)
                outfile_r.write(seq_r)
                outfile_r.write(plus_r)
                outfile_r.write(qual_r)

if __name__ == "__main__":
    filter_gz_fastq_by_first_base(
        args.infastqzf,
        args.infastqzr,
        'filtered_output.fastq_f.gz',
        'filtered_output.fastq_r.gz',
        base=args.base_to_keep)
