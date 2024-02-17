    .setcpu "65C02"
    .feature labels_without_colons
    .feature c_comments

; portability defines to map Merlin assembler to ca65
    .define EQU     =
    .define DS      .res
    .define DB      .byte
    .define DFB     .byte
    .define DA      .word
    .define DW      .word
    .define ASC     .literal

; user should define ClockDriver. Use NoClock which just points at a rts,
; or implement the ProDOS clock interface (see xdosmli.s)
    .import ClockDriver

    .export InitMLI, RegisterMLI, ReserveMLI, GoMLI, NoClock

    .include "api.s"

        .zeropage
        .org $40            ; MLI interface vars defined here
    .include "equates.s"    ; zero page and various constants

        .reloc
        .segment "P8RAM"
    .include "wrkspace.s"   ; work area

        .code
    .include "xdosmli.s"    ; main GoMLI aka GoPro(DOS) entrypoint
    .include "init.s"       ; one time InitMLI setup
    .include "bfmgr.s"      ; block file manager
    .include "create.s"     ; create handler
    .include "fndfil.s"     ; find file entry header
    .include "newfndvol.s"  ; volume handling, including multi-vol support
    .include "alloc.s"      ; block allocation
    .include "posnopen.s"   ; set/get mark, open
    .include "readwrite.s"  ; read/write
    .include "closeeof.s"   ; close/eof
    .include "destroy.s"    ; newline/rename/destroy
    .include "detree.s"     ; destructor for tree files
    .include "memmgr.s"     ; get/set buf mgmt; mirror devices
    .include "datatbls.s"   ; various constants, MLI routine jump table

; original source files were imported with this sed command to
; change local labels :1 => @1 and mark lines starting with @ as comments
;   sed -E -e 's/:([0-9a-zA-Z]+)/@\1/' -e 's/^\*/; @/' ../ProDOS8/MLI.SRC/FNDFIL.S > fndfil.s

/*
    original include order with * indicating p8fs files:

* PUT mli.src/Equates
 PUT mli.src/ProLdr
 PUT mli.src/DevSrch  ; original device setup
 PUT mli.src/Reloc
 PUT mli.src/RAM1
 PUT mli.src/RAM2
 PUT mli.src/ROM
* PUT mli.src/Globals
 PUT mli.src/TClock
 PUT mli.src/CClock
* PUT mli.src/XDosMLI
* PUT mli.src/BFMgr
* PUT mli.src/Create
* PUT mli.src/FndFil
* PUT mli.src/NewFndVol
* PUT mli.src/Alloc
* PUT mli.src/PosnOpen
* PUT mli.src/ReadWrite
* PUT mli.src/CloseEOF
* PUT mli.src/Destroy
* PUT mli.src/DeTree
* PUT mli.src/MemMgr
* PUT mli.src/DataTbls
* PUT mli.src/WrkSpace
 PUT mli.src/RAM0
 PUT mli.src/XRW1
 PUT mli.src/XRW2
 PUT mli.src/SEL0
 PUT mli.src/SEL1
 PUT mli.src/SEL2
*/
