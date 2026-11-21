#!/bin/sh
# Build the p8fs kernel and the demo (needs cc65 2.19 or later), then run it in c65
set -e
cl65 -c -g --target none -l p8fs.lst -o p8fs.o p8fs.s
cl65 -g --target none --config demo.cfg -m demo.map -Ln demo.sym -o demo.bin p8fs.o demo.s
c65 -r demo.bin -a 0x400
