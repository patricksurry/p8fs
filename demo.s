/*
Before calling the MLI the first time we need to call InitMLI (no params)
and then set up at least one block device driver pointing at a prodos disk.
See below for a simple RAM disk demo.

Then we call the ProDOS MLI by JSR EntryMLI follwed by a 3 byte cmd/param block:

    JSR EntryMLI    ; Call Command Dispatcher
    DB  CMDNUM      ; This determines which call is being made
    DW  CMDLIST     ; A two-byte pointer to the parameter list
    BNE ERROR       ; Error if nonzero (A=err) also carry set

On return A=C=0 on success or A=error code, C=1 on failure.
In either case X, Y are unchanged.  See https://prodos8.com/docs/techref/calls-to-the-mli/
*/

/*
this demo will set up and test a simple ram disk driver for a
simple prodos volume containing blocks 0-1 for loader (ignored),
2-5 for volume dir, 6 for bitmap, and 7-9 for a small sapling file
our volume doesn't boot so we'll only map eight blocks 2-9 using 4K

% prodos demovol.po create --size 10 --name DEMOVOL
% prodos demovol.po import hhg.txt README
% prodos demovol.po ls
README                  893 2/00 ------ 24-02-03T08:59 24-02-03T08:59 3 @ 7
    1 files in DEMOVOL F RW-BN- 24-02-03T08:59
*/

PUTC = $f001

ramPtr = $50
sPtr = $52

DemoBuffer = $400
RamDiskStart = $800
RamDiskBlocks = 8
RamDiskEnd = $800 + RamDiskBlocks * $200
ReadmeLen = 893     ; expected length of file we're reading

    .macro PUTS label
        lda #<label
        sta sPtr
        lda #>label
        sta sPtr+1
        jsr puts
    .endmacro

test_start:
        jsr InitMLI     ; init MLI including our driver via p8fs.s::DeviceDriver

        ; flag memory we're using (24 pages = 12 blocks = 6K)
        lda #$ff
        ldx #2
@mark:  sta memTabl,x
        dex
        bne @mark

test_getdatetime:   ; test a no-op (or configure ClockBegin in p8fs.s)
        PUTS test_getdatetime_label

        jsr EntryMLI
        .byte $82   ; GET_DATE_TIME
        .word 0     ; no params

        bne @fail
        bcs @fail
        bra @ok
@fail:  jmp test_fail
@ok:    PUTS OK

test_online:        ; test whether our device shows as online
        PUTS test_online_label

        jsr EntryMLI
        .byte $C5   ; ON_LINE
        .word test_online_params

        bne @fail
        bcs @fail
        lda DemoBuffer      ; should contain (dvc << 4) | len, "DEMOVOL"
        cmp #7
        bne @fail
        lda DemoBuffer+1
        cmp #'D'
        bne @fail
        bra @ok
@fail:  jmp test_fail
@ok:    PUTS OK

test_set_prefix:    ; test setting default prefix
    ; the startup prefix is null
    ; seems to need an abs prefix (starting with /) for open to work
        PUTS test_set_prefix_label

        ; prepend the volume name with a / to make an absolute prefix
        ldx DemoBuffer
@copy:  lda DemoBuffer,x
        sta DemoBuffer+1,x
        dex
        bne @copy
        lda #'/'
        sta DemoBuffer+1
        inc DemoBuffer      ; inc length to include /

        jsr EntryMLI
        .byte $C6   ; SET_PREFIX
        .word test_set_prefix_params

        bne @fail
        bcs @fail
        bra @ok
@fail:  jmp test_fail
@ok:    PUTS OK

test_open:          ; try reading the file
        PUTS test_open_label

        jsr EntryMLI
        .byte $C8   ; OPEN
        .word test_open_params

        bne @fail
        bcs @fail
        bra @ok
@fail:  jmp test_fail
@ok:    PUTS OK

test_read:
        PUTS test_read_label

        ;TODO these param blocks need to be in RAM, e.g. @ $100
        lda test_open_params+5  ; get filehandle
        sta test_read_params+1

        jsr EntryMLI
        .byte $CA
        .word test_read_params

        bne @fail
        bcs @fail

        lda test_read_params+6
        sta sPtr
        cmp #<ReadmeLen
        bne @fail
        lda test_read_params+7
        sta sPtr+1
        cmp #>ReadmeLen
        bne @fail
        bra @ok
@fail:  jmp test_fail
@ok     PUTS OK

        lda #0
        sta (sPtr)
        PUTS DemoBuffer

        PUTS OK
        brk             ; end of demo

puts:   ; put a string from sPtr until zero byte
        lda (sPtr)
        beq @done
        sta PUTC
        inc sPtr
        bne puts
        inc sPtr+1
        bra puts
 @done: rts

test_fail:
        PUTS FAIL
        brk

LF = $0a

OK:     .byte " OK",LF,0
FAIL:   .byte " FAIL",LF,0

test_getdatetime_label: .byte "GET_DATE_TIME",0

test_online_label: .byte "ONLINE",0
test_online_params:
        .byte 2
        .byte 0     ; request all devices, else dsss.... requests slot s, drive d
        .word DemoBuffer  ; output buffer, 16 or 256 bytes

test_set_prefix_label: .byte "SET_PREFIX",0
test_set_prefix_params:
        .byte 1
        .word DemoBuffer ; use the volume we just found, high nibble is clear since dvc=0

test_open_label: .byte "OPEN",0
test_open_params:
        .byte 3
        .word PathName
        .word RamDiskEnd    ; 1024-byte input/output buffer not already used
        .res 1      ; filehandle result
PathName:
        .byte 6, "README"

test_read_label: .byte "READ",0
test_read_params:
        .byte 4
        .res 1
        .word DemoBuffer
        .word $400      ; request bytes
        .res 2          ; actual bytes

/*
The ProDOS MLI does all reading and writing via a simple interace to
external block device drivers.  The original ProDOS code had Apple-specific
drivers for Disk ][ drives, SmartPort devices and so on.  This kernel
has no drivers built in so we need to supply at least one.

The driver entry point should be assigned to one of the 16 slots in the
DevAdrTable which initally all point to gNoDev (see init.s).
(On the Apple implementation index 0 <= %dsss < 16 corresonded to slot sss, drive d
but we don't care about that here.)

Then we add the slot index to the active device list by incrementing DevCnt
(the number of active devices less 1) and setting DevAdrTbl+DevCnt to the slot number.
There can be up to 14 active devices (why not 16?).

The device interface itself is very simple.  ProDOS calls the entry point
with four params in page zero: $42 = cmd, $43 = unitnum, $44-45 = buf, $46-47 = blockidx.
The driver should return A=C=0 on success, and A=error, C=1 on failure.
See also section 6.3 at https://prodos8.com/docs/techref/adding-routines-to-prodos/

Four commands ($42) are supported:
    0 = STATUS  - return success if ready, plus device capacity as Y*256+X
    1 = READ    - read requested block (512 bytes) to buffer
    2 = WRITE   - write requested block from buffer
    3 = FORMAT  - format device, typically a no-op since caller manages logical format

The error codes that should be implemented are:

    $27 - I/O error
    $28 - No device connected
    $2B - Write protected

The high nibble of the unitnum ($43) contains the device index from
the DevAdrTable that appears in DevLst.
This lets you use the same driver code to manage multiple volumes.
For eample an SD-card driver could map 14 separate volumes each with
the maximum 65535 blocks which is nearly half a gigabyte of storage.

Unit Number:
    7  6  5  4  3  2  1  0
  +--+--+--+--+--+--+--+--+
  |DR|  SLOT  | NOT USED  |
  +--+--+--+--+--+--+--+--+

Buffer Pointer ($44-45): Contains the address of a 512-byte memory buffer.

Block Number ($46-$47): The 0-based index of a 512-block on the disk.
*/

DEVICE_CMD = $42   ; aka dhpCmd
DEVICE_UNT = $43   ; aka unitNum
DEVICE_BUF = $44   ; aka bufPtr
DEVICE_BLK = $46   ; aka blockNum



RamDiskDriver:
        ldx DEVICE_CMD
        bne @next
        ldy #0       ; status, return device size
        ldx #RamDiskBlocks
        bra @ok

@next:  cpx #3      ; format is a no-op
        beq @ok

        ; r/w set up pointer to the block in memory
        lda DEVICE_BLK  ; (blk - 2) * 2 is page offset into our memory
        sec
        sbc #2          ; only 2 <= blk < 10 is valid
        bmi @err
        cmp #8
        bpl @err
        asl
    .assert RamDiskStart & $1ff = 0, error, "RamDisk should be block aligned"
        adc #>RamDiskStart
        sta ramPtr+1
        stz ramPtr
        ldy #0
        cpx #1      ; read
        bne @write

@read:  lda (ramPtr),y
        sta (DEVICE_BUF),y
        iny
        bne @read
        inc DEVICE_BUF+1
        inc ramPtr+1
        lda ramPtr+1
        lsr
        bcs @read     ; odd page?
        bra @ok

@write: lda (DEVICE_BUF),y
        sta (ramPtr),y
        iny
        bne @write
        inc DEVICE_BUF+1
        inc ramPtr+1
        lda ramPtr+1
        lsr
        bcs @write

@ok:    lda #0
        clc
        rts

@err:   lda #$27    ; IO error
        sec
        rts
