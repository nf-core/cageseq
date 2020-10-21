#!/bin/bash

while getopts :i:q:n: opt
do
case ${opt} in
q) QCUT=${OPTARG};;
i) VAR=${OPTARG};;
n) NAME=${OPTARG};;
*) echo: "Usage is : $0 -q <mapping quality cutoff> -i <map1.bam> -n <sample_name">&2
    exit 1;;
esac
done

if [ "${QCUT}" = "" ]; then QCUT=20; fi

#convert sam to bam and bam to bed
TMPFILE="/tmp/$(basename "$0").$RANDOM.txt"
samtools view  -F 4 -u -q $QCUT -b "$VAR.bam" |  bamToBed -i stdin > "$TMPFILE"

 #generate ctss on the positive strand
awk 'BEGIN{OFS="\t"}{if($6=="+"){print $1,$2,$5}}' "${TMPFILE}" \
| sort -k1,1 -k2,2n \
| groupBy -i stdin -g 1,2 -c 3 -o count \
| awk -v x="$NAME" 'BEGIN{OFS="\t"}{print $1,$2,$2+1,  x  ,$3,"+"}' >> "$NAME".pos_ctss.bed

#generate ctss on the negative strand
awk 'BEGIN{OFS="\t"}{if($6=="-"){print $1,$3,$5}}' "${TMPFILE}" \
| sort -k1,1 -k2,2n \
| groupBy -i stdin -g 1,2 -c 3 -o count \
| awk -v x="$NAME" 'BEGIN{OFS="\t"}{print $1,$2-1,$2, x  ,$3,"-"}' >> "$NAME".neg_ctss.bed

cat "$NAME".pos_ctss.bed "$NAME".neg_ctss.bed | sort -k1,1 -k2,2n > "$NAME".ctss.bed

rm "$TMPFILE"
