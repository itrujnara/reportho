#!/usr/bin/env python3

# Written by Igor Trujnara, released under the MIT license
# See https://opensource.org/license/mit for details

from collections import defaultdict as dd
import csv
import requests
import sys

from utils import safe_post, split_ids

def fetch_slice(ids: list[str], idmap: dict[str,str]) -> dict[str,str]:
    results = dd(str)
    # fetch taxon information
    payload = {"ids": ids}
    headers = {"Content-Type": "application/json", "Accept": "application/json"}
    res1 = safe_post("https://rest.ensembl.org/lookup/id",
                    json = payload,
                    headers = headers)
    json1 = res1.json()
    if json1:
        for entry in json1:
            results[entry]["taxid"] = idmap[json1[entry]["species"]]

    # fetch sequence information
    params = {"type": "protein"}
    res2 = safe_post("https://rest.ensembl.org/sequence/id",
                    json = payload,
                    headers = headers,
                    params = params)
    json2 = res2.json()
    if json2:
        for entry in json2:
            results[entry["query"]]["sequence"] = entry["sequence"]

    check_entry = lambda v: v.get("taxid", None) is not None and v.get("sequence", None) is not None

    return {k: v for k,v in results.items() if check_entry(v)}


def fetch_ensembl(ids: list[str], idmap_path: str) -> dict[str, str]:
    taxon_map = {}
    with open(idmap_path) as f:
        for it in csv.reader(f):
            taxon_map[it[0]] = it[1]
    
    seqs = {}
    for i, s in enumerate(split_ids(ids, 100)):
        seqs.update(fetch_slice(s, taxon_map))
    return seqs


def main():
    if len(sys.argv) < 3:
        raise ValueError("Too few arguments. Usage: fetch_ensembl_sequences.py <ids_path> <idmap_path>")
    f = open(sys.argv[1])
    ids = f.read().splitlines()
    seqs = fetch_ensembl(ids, sys.argv[2])
    for k,v in seqs.items():
        print(f">{k}|{v["taxid"]}\n{v["sequence"]}")


if __name__ == "__main__":
    main()
