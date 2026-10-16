#!/usr/bin/env python3
# Given an input file listing all uniquely (or multi-) mapped bigwig outputs
# creates a sample list csv file in the following format
# input:
# path/to/S10.Signal.UniqueMultiple.str1.out.wig.bw
# path/to/S10.Signal.UniqueMultiple.str2.out.wig.bw
# path/to/S14.Signal.UniqueMultiple.str1.out.wig.bw
# path/to/S14.Signal.UniqueMultiple.str2.out.wig.bw
# output:
# id,single_end,path
# S10,false,[path/to/S10.Signal.UniqueMultiple.str1.out.wig.bw path/to/S10.Signal.UniqueMultiple.str2.out.wig.bw]
# S14,false,[path/to/S14.Signal.UniqueMultiple.str1.out.wig.bw path/to/S14.Signal.UniqueMultiple.str2.out.wig.bw]
import argparse

parser = argparse.ArgumentParser()
parser.add_argument("-f", "--filepath", type=str, help="Path to the file with bigwigs")
parser.add_argument("-s", "--singleend", type=str, help="Whether the samples are single ended or not")
parser.add_argument(
    "-d",
    "--delimiter",
    type=str,
    default=None,
    help="Additional delimiter to remove parts of the input name, eg pool from sequencing facility",
)
parser.add_argument(
    "-l",
    "--field",
    type=int,
    default=None,
    help="Up till which field to remove after splitting with additional delimiter (0 indexed)",
)
args = parser.parse_args()

outdict = {}
with open(args.filepath, "r", encoding="utf-8") as filein:
    for line in filein:
        samplepath = line.strip()
        sample_name = samplepath.split("/")[-1].split(".Signal.")[0]
        if args.delimiter is not None:
            sample_name = args.delimiter.join(sample_name.split(args.delimiter)[args.field + 1 :])
        if sample_name not in outdict:
            outdict[sample_name] = [samplepath]
        else:
            outdict[sample_name].append(samplepath)

with open("sample_list.csv", "w+", encoding="utf-8") as outfile:
    header = "id,single_end,path,new_name\n"
    outfile.write(header)
    for sample, paths in outdict.items():
        if len(paths) > 1:
            path_str = " ".join(paths)
        else:
            path_str = paths[0]
        line_to_write = f"{sample},{args.singleend},[{path_str}],{sample}\n"
        outfile.write(line_to_write)
