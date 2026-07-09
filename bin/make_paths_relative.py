#!/usr/bin/env python3
import argparse
import os

parser = argparse.ArgumentParser()
parser.add_argument("-f", "--filepath", type=str, help="Path to the samplefile with absolute path bigwigs")
args = parser.parse_args()


def parse_paths(field):
    """Return the list of paths held in the legacy single "path" column.

    Accepts both the new plain form and the legacy "[str1 str2]" bracketed,
    space-separated form.
    """
    cleaned = field.strip().strip("[").strip("]")
    return [p for p in cleaned.replace(",", " ").split(" ") if p]


with open(args.filepath, "r", encoding="utf-8") as filein:
    lines = [line.rstrip("\n") for line in filein if line.strip()]

header = lines[0].split(",")

records = []
has_two_paths = False
for line in lines[1:]:
    fields = line.split(",")
    row = dict(zip(header, fields))
    if "path1" in row and "path2" in row:
        paths = [row["path1"], row["path2"]]
    else:
        paths = parse_paths(row["path"])
    basenames = [os.path.basename(p) for p in paths]
    if len(basenames) == 2:
        has_two_paths = True
    records.append((row["id"], row["single_end"], basenames, row["new_name"]))

with open("sample_list_relativepath.csv", "w+", encoding="utf-8") as outfile:
    if has_two_paths:
        outfile.write("id,single_end,path1,path2,new_name\n")
    else:
        outfile.write("id,single_end,path,new_name\n")
    for line_id, line_se, basenames, new_name in records:
        path_str = ",".join(basenames)
        outfile.write(f"{line_id},{line_se},{path_str},{new_name}\n")
