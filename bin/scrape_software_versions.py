#!/usr/bin/env python
from __future__ import print_function
from collections import OrderedDict
import re

regexes = {
    'nf-core/cageseq': ['v_pipeline.txt', r"(\S+)"],
    'Nextflow': ['v_nextflow.txt', r"(\S+)"],
    'FastQC': ['v_fastqc.txt', r"FastQC v(\S+)"],
    'MultiQC': ['v_multiqc.txt', r"multiqc, version (\S+)"],
    'STAR': ['v_star.txt', r"STAR_(\S+)"],
    'bowtie': ['v_bowtie.txt', r"version (\S+)"],
    'bedtools': ['v_bedtools.txt', r"bedtools v(\S+)"],
    'cutadapt': ['v_cutadapt.txt', r"(\S+)"],
    'samtools': ['v_samtools.txt', r"samtools (\S+)"],
    'sortmerna': ['v_sortmerna.txt', r"SortMeRNA version (\S+)"],
    'rseqc': ['v_rseqc.txt', r"read_distribution.py (\S+)"],
}
results = OrderedDict()
results['nf-core/cageseq'] = '<span style="color:#999999;\">N/A</span>'
results['Nextflow'] = '<span style="color:#999999;\">N/A</span>'
results['FastQC'] = '<span style="color:#999999;\">N/A</span>'
results['MultiQC'] = '<span style="color:#999999;\">N/A</span>'
results['bowtie'] = '<span style="color:#999999;\">N/A</span>'
results['STAR'] = '<span style="color:#999999;\">N/A</span>'
results['bedtools'] = '<span style="color:#999999;\">N/A</span>'
results['cutadapt'] = '<span style="color:#999999;\">N/A</span>'
results['samtools'] = '<span style="color:#999999;\">N/A</span>'
results['sortmerna'] = '<span style="color:#999999;\">N/A</span>'
results['rseqc'] = '<span style="color:#999999;\">N/A</span>'

# Search each file using its regex
for k, v in regexes.items():
    try:
        with open(v[0]) as x:
            versions = x.read()
            match = re.search(v[1], versions)
            if match:
                results[k] = "v{}".format(match.group(1))
    except IOError:
        results[k] = False

# Remove software set to false in results
for k in list(results):
    if not results[k]:
        del(results[k])

# Dump to YAML
print ('''
id: 'software_versions'
section_name: 'nf-core/cageseq Software Versions'
section_href: 'https://github.com/nf-core/cageseq'
plot_type: 'html'
description: 'are collected at run time from the software output.'
data: |
    <dl class="dl-horizontal">
''')
for k,v in results.items():
    print("        <dt>{}</dt><dd><samp>{}</samp></dd>".format(k,v))
print ("    </dl>")

# Write out regexes as csv file:
with open('software_versions.csv', 'w') as f:
    for k,v in results.items():
        f.write("{}\t{}\n".format(k,v))
