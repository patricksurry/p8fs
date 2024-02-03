
TODO

- get rid of more unused symbols / defs

- optionally reserve pages in memTabl below $C000 (default $0,1,$BF)
    (CalcMemBit, WhichBit)

- check TODO

- globals.s DateTime is self-modifying code for clock card (currently unused), could wire up to clock if exists, or make easier to configure (config.s with ReadClock = NoClock pointing at default routine)

- make it ROM-able (separate writable buffer and workspace)
    globals data tables => should be in data e.g.
    SErr        DB     $00             ;Error code, 0=no error


kVersion    DB     $23             ;Represents release 2.03


- memory layout intermixed with buffers, see equates.s

d000-d6ff  was core disk IO routines
d700-ddff  is buffer space


    ;TODO

    orig        EQU    $D700

    pathBuf     EQU    orig            ; 1 page
    fcb         EQU    orig+$100       ;File Control Blocks (1 page)
    vcb         EQU    orig+$200       ;Volume Control Blocks (1 page)
    bmBuf       EQU    orig+$300       ;Bitmap buffer (2 page / 1 block)
    genBuf      EQU    pathBuf+$500    ;General purpose buffer (2 page / 1 block)


../cc65/bin/cl65 -g --verbose --target none --config p8fs.cfg -m p8fs.map -Ln p8fs.sym -l p8fs.lst -o p8fs.bin p8fs.s 2>&1

    . load demovol.po $400  ; puts block 2 at $800
    . g test_start

sed 's/\.//' p8fs.sym > /tmp/labels ; py65mon -m 65c02 -l p8fs.bin -a c000 -b /tmp/labels