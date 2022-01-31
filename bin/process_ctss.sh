#!/bin/bash

set -e

while getopts :i:t: opt
do
case ${opt} in
t) TPM=${OPTARG};;
*) echo "Usage is : $0 -t <tpm_threshold> <ctss_file1> <ctss_file2>" >&2
    exit 1;;
esac
done
shift $((OPTIND -1)) #throw out the -t parameter from $@ inputs

FILES=$@

# "Pooling ctss"
cat $FILES > ctss_all


#  "Sorting pooled ctss"
sort -k 1,1 -k 2,2n -k 3,3n -k 6,6 ctss_all > ctss_all.Sorted

#  "Grouping and adding ctss"
bedtools groupby -i ctss_all.Sorted -g 1,2,3,6 -c 5 -o sum > ctss_all.SortedGrouped

#  "Formating file"
awk -F "\t" '{print$1"\t"$2"\t"$3"\t"$1":"$2"-"$3"\t"$5"\t"$4}' < ctss_all.SortedGrouped > ctssAll

# "Filter ctss < $TPM TPM"
counts=$(awk 'FNR==NR{sum+=$5} END {print sum}' ctssAll)
awk -v ctssall="$counts" '{if (($5/ctssall)*1000000>="$TPM") print}' ctssAll > ctssAll_${TPM}_tpm_new.ctss.bed
