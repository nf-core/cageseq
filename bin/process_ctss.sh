#!/bin/sh
#
if [ $# -eq 0 ]
then
 cat <<EOF
Usage is : $0 <ctss.bed> ...
EOF
 exit 1;
fi

CTSS_FILE=$1

# get filename without extension
CTSS=${CTSS_FILE%.*}
# split BED into strands
sed '/+/d' $CTSS_FILE > ${CTSS}_allm
grep + $CTSS_FILE > ${CTSS}_allp
# put CTSS output to paraclu format
awk -F "\t" '{print$1"\t"$6"\t"$2"\t"$5}' < ${CTSS}_allm > ${CTSS}_pos_4P
awk -F "\t" '{print$1"\t"$6"\t"$3"\t"$5}' < ${CTSS}_allp > ${CTSS}_neg_4P
# sort the pos and neg strand prior paraclu clustering
sort -k1,1 -k3n ${CTSS}_pos_4P > ${CTSS}_pos_4Ps
sort -k1,1 -k3n ${CTSS}_neg_4P > ${CTSS}_neg_4Ps
