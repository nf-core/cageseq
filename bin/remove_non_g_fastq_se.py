#!/usr/bin/env python3

import gzip
import argparse

parser = argparse.ArgumentParser()
parser.add_argument("-f", "--infastqz", type=str, help="Path to the fastq.gz file")
parser.add_argument("-b", "--base_to_keep", type=str, default="G", help="Which nuclotide to keep. Defaults to G")
args = parser.parse_args()


def filter_gz_fastq_by_first_base(input_fastq_gz, output_fastq_gz, base="G"):
    with gzip.open(input_fastq_gz, "rt") as infile, gzip.open(output_fastq_gz, "wt") as outfile:
        while True:
            header = infile.readline()
            if not header:
                break  # End of file
            seq = infile.readline()
            plus = infile.readline()
            qual = infile.readline()

            if seq.startswith(base):
                outfile.write(header)
                outfile.write(seq)
                outfile.write(plus)
                outfile.write(qual)


if __name__ == "__main__":
    filter_gz_fastq_by_first_base(args.infastqz, "filtered_output.fastq.gz", base=args.base_to_keep)
