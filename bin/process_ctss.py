#!/usr/bin/env python

import argparse
import numpy as np
import csv

parser = argparse.ArgumentParser()
parser.add_argument("ctss", help="The ctss.bed file")
args = parser.parse_args()
ctssfile = args.ctss

content = []
with open(ctssfile)as f:
    for line in f:
        content.append(line.strip().split())

for row in content:
    del row[2:4]  # 0 for column 1, 1 for column 2, etc.

for row in content:
    row[1], row[3] = row[3], row[1]
    row[2], row[3] = row[3], row[2]

with open('processed_ctss.bed', 'w') as f:
    w = csv.writer(f, dialect = 'excel-tab')
    w.writerows(content_exp)
