#!/usr/bin/env python3

# Written by Igor Trujnara, released under the MIT license
# See https://opensource.org/license/mit for details

import io
import sys
import requests

from Bio import SeqIO
from utils import safe_get, split_ids


def fetch_slice(ids: list[str]) -> list[SeqIO.SeqRecord]:
    payload: dict[str,str] = {"accession": ','.join(ids)}
    headers: dict[str,str] = {"Accept": "text/x-fasta"}
    res = safe_get("https://www.ebi.ac.uk/proteins/api/proteins",
                       params = payload,
                       headers = headers)
    if not res.ok:
        return []
    
    tmp = io.StringIO(res.content.decode())
    seqs = SeqIO.parse(tmp, "fasta")

    return list(seqs)


def fetch_ebi(ids: list[str]) -> list[str]:
    seqs = []
    for s in split_ids(ids, 100):
        seqs = seqs + fetch_slice(s)
    return [reform_fasta(seq) for seq in seqs]


def reform_fasta(entry: SeqIO.SeqRecord) -> str:
    prot_id = entry.description.split('|')[1]
    tax_id = entry.description.split("OX=")[1].split(' ')[0]
    seq = str(entry.seq)
    return f">{prot_id}|{tax_id}\n{seq}"


def main():
   f = open(sys.argv[1])
   ids = f.read().splitlines()
   seqs = fetch_ebi(ids)
   for i in seqs:
       print(i)


if __name__ == "__main__":
    main()
