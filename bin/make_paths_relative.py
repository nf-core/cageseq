#!/usr/bin/env python3
import argparse
import os

parser = argparse.ArgumentParser()
parser.add_argument("-f", "--filepath", type=str, help="Path to the samplefile with absolute path bigwigs")
args = parser.parse_args()

with open(args.filepath, "r", encoding="utf-8") as filein:
    with open("sample_list_relativepath.csv", "w+", encoding="utf-8") as outfile:
        for line in filein:
            if line == "id,single_end,path,new_name\n":
                outfile.write(line)
            else:
                line_parts = line.strip().split(",")
                line_id = line_parts[0]
                line_se = line_parts[1]
                paths = line_parts[2].strip("]").strip("[").split(" ")
                if len(paths) > 1:
                    path_str = " ".join([os.path.basename(path) for path in paths])
                else:
                    path_str = os.path.basename(paths[0])
                new_name = line_parts[3]
                line_to_write = f"{line_id},{line_se},[{path_str}],{new_name}\n"
                outfile.write(line_to_write)
