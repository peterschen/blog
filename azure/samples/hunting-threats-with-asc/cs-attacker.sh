#!/usr/bin/env sh
cd /usr/share/wordlists
cp rockyou.txt.gz dce.txt.gz
gunzip dce.txt.gz
echo "$(head -n 15 dce.txt)" > dce.txt
echo "admin >> dce.txt"
echo "office >> dce.txt"
echo "John >> dce.txt"
echo "Jane >> dce.txt"
echo "Susan >> dce.txt"