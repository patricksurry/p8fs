    .setcpu "65C02"
    .feature labels_without_colons
    .feature c_comments

    .define EQU     =
    .define DUM     .org
    .define ORG     .org
    .define DS      .res
    .define DB      .byte
    .define DFB     .byte
    .define DA      .word
    .define DW      .word
    .define DEND
    .define ASC     .literal

    ; storage types
    .define seedling    1
    .define sapling     2
    .define tree        3

    .define directoryFile   $d

    ; file access bits
    .define destroyEnable   $80
    .define renameEnable    $40
    .define backupNeeded    $20
    .define fileInvisible   $04     ; see https://prodos8.com/docs/technote/23/
    .define writeEnable     $02
    .define readEnable      $01

    ; error codes from https://prodos8.com/docs/techref/calls-to-the-mli/
    .define badSystemCall   $1
    .define invalidPcount   $4
    .define irqTableFull    $25
    .define drvrIOError     $27
    .define drvrNoDevice    $28
    .define drvrWrtProt     $2b
    .define drvrOffLine     $2e  ;TODO duplicate?
    .define drvrDiskSwitch  $2e
    .define badPathSyntax   $40
    ; fcb table full $42
    .define invalidRefNum   $43
    .define pathNotFound    $44
    .define volNotFound     $45
    .define unknownVol      $45 ;TODO duplicate?
    .define fileNotFound    $46
    .define dupPathname     $47
    .define volumeFull      $48
    .define volDirFull      $49
    .define badFileFormat   $4a
    .define badStoreType    $4b
    .define eofEncountered  $4c
    .define outOfRange      $4d
    .define invalidAccess   $4e
    .define fileBusy        $50
    .define dirError        $51
    ; not a prodos disk $52
    .define paramRangeErr   $53
    ; vcb table full $55
    ; bad buffer addr $56
    .define dupVolume       $57
    .define damagedBitMap   $5a

        .zeropage
    .include "equates.s"    ; zero page and various constants
        .segment "DATA"
    .include "wrkspace.s"   ; work area (should be DATA segment?)
        .code
    .include "globals.s"    ; $bf00
    .include "xdosmli.s"    ; MLI entrypoint
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
    .include "datatbls.s"   ; various tables, MLI routine jump table

    .include "test.s"

; import source like
;  sed -E -e 's/:([0-9a-zA-Z]+)/@\1/' -e 's/^\*/; @/' ../ProDOS8/MLI.SRC/FNDFIL.S > fndfil.s

/*
* PUT mli.src/Equates
 PUT mli.src/ProLdr
 PUT mli.src/DevSrch  ; add some device setup
 PUT mli.src/Reloc
 PUT mli.src/RAM1
 PUT mli.src/RAM2
* PUT mli.src/ROM
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
; */