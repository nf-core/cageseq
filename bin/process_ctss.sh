#!/bin/sh
#
set -e

if [ $# -eq 0 ]
then
 cat <<EOF
Usage is : $0 <ctss.bed> ...
EOF
 exit 1;
fi


CTSS_NEG=$1
CTSS_POS=$2

# split BED into strands
# sed '/+/d' $CTSS_FILE.bed > ${CTSS}_allm
# grep + $CTSS_FILE.bed > ${CTSS}_allp
# put CTSS output to paraclu format
awk -F "\t" '{print$1"\t"$6"\t"$2"\t"$5}' < $CTSS_POS.bed > ${CTSS_POS}_pos_4P
awk -F "\t" '{print$1"\t"$6"\t"$3"\t"$5}' < $CTSS_NEG.bed > ${CTSS_NEG}_neg_4P
# sort the pos and neg strand prior paraclu clustering
sort -k1,1 -k3n ${CTSS_POS}_pos_4P > ${CTSS_POS}_pos_4Ps
sort -k1,1 -k3n ${CTSS_NEG}_neg_4P > ${CTSS_NEG}_neg_4Ps
