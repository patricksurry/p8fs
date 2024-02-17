#!/bin/zsh
sed 's/\.//' demo.sym > /tmp/labels
cat >/tmp/cmd << EOF
batch /tmp/labels     ; import symbols
load demovol.po 400   ; load disk image with block 2 @ $800
EOF
py65mon -m 65c02 -l demo.bin -a c000 -b /tmp/cmd
