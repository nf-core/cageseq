#!/usr/bin/env python

"""
Extract CTSS from bed formatted alignment
"""

import numpy as np
import pandas as pd
import argparse

parser = argparse.ArgumentParser()
parser.add_argument("bed", help="The bed file")
parser.add_argument("ctss_file", help="The CTSS file")
args = parser.parse_args()
bedfile = args.bed
ctss_file = args.ctss_file

ctss_dict = {}
# Count tags
with open(bedfile, "r") as bf:
    for line in bf:
        sp = line.split()
        line_key = "_".join([sp[0], sp[1], sp[5]])
        if line_key in ctss_dict:
            ctss_dict[line_key] += 1
        else:
            ctss_dict[line_key] = 1
bf.close()

no_tags = len(ctss_dict)
chr = np.empty([no_tags, 1], dtype=object)
strand = np.empty([no_tags, 1], dtype=object)
pos = np.empty([no_tags, 1], dtype=int)
count = np.empty([no_tags, 1], dtype=int)

def extract_ctss(elem):
    ekey = elem[1]
    idx = elem[0]
    sp = ekey.split("_")
    ct = ctss_dict[ekey]
    chr[idx] = sp[0]
    strand[idx] = sp[2]
    pos[idx] = sp[1]
    count[idx] = ct


[extract_ctss(elem) for elem in enumerate(ctss_dict)]

df = pd.DataFrame(chr)
df['strand'] = strand
df['position'] = pos
df['count'] = count
df.columns = ['chr', 'strand', 'position', 'count']

def sort_chrom_df(chrom_df):
    sens_df = chrom_df.loc[chrom_df['strand'] == '+']
    as_df = chrom_df.loc[chrom_df['strand'] == '-']
    sens_df = sens_df.sort_values(by=['position'])
    as_df = as_df.sort_values(by=['position'])
    frames = [sens_df, as_df]
    res = pd.concat(frames)
    return res


uchroms = np.unique(chr)
res_frames = []
for uc in uchroms:
    chrom_df = df.loc[df['chr'] == uc]
    cdf = sort_chrom_df(chrom_df)
    res_frames.append(cdf)

merged_frame = pd.concat(res_frames)
merged_frame.to_csv(ctss_file, sep="\t", index=False, header=False)