
TODO

- optionally reserve pages in memTabl below $C000 (default $0,1,$BF)

- globals.s DateTime is self-modifying code for clock card (currently unused), could wire up to clock if exists, or make easier to configure

- memory layout intermixed with buffers, see equates.s

    ClockBegin  EQU    $D742           ;Entry address of clock

    ;TODO

    LoadIntrp   EQU    $0800           ;Execution addr of load interpreter
    orig        EQU    $D700
    orig1       EQU    $DE00
    Globals     EQU    $BF00           ;ProDOS's global page
    IntHandler  EQU    $FF9B           ;Start of interrupt handler
    pathBuf     EQU    orig
    fcb         EQU    orig+$100       ;File Control Blocks
    vcb         EQU    orig+$200       ;Volume Control Blocks
    bmBuf       EQU    orig+$300       ;Bitmap buffer
    genBuf      EQU    pathBuf+$500    ;General purpose buffer


../cc65/bin/cl65 -g --verbose --target none --config p8fs.cfg -m p8fs.map -Ln p8fs.sym -l p8fs.lst -o p8fs.bin p8fs.s 2>&1


sed 's/\.//' p8fs.sym > /tmp/labels ; py65mon -m 65c02 -l p8fs.bin -a bf00 -b /tmp/labels