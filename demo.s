    .setcpu "65C02"
    .feature c_comments

/*
This demo sets up and tests a simple ram disk driver which exposes
a small ProDOS disk image.  The disk image reserves blocks 0-1 for the boot loader
(normally used by the full ProDOS to boot Apple hardware), blocks 2-5 for the
volume direcory, block 6 (or more) for the bitmap and further blocks for file storage.
Our example will use three blocks to store a "sapling file" called README.
Since we don't care about the boot loader blocks, we'll map the image
so that block 2 starts at RamDiskStart.

Before calling the MLI the first time we need to call InitMLI (no params)
and then set up at least one block device driver pointing at a ProDOS disk volume.
We also need to reserve any memory pages in the lower 48K to avoid
ProDOS allocating them for buffer space.

From then on we can call ProDOS MLI normally by JSR GoMLI
followed by a 3 byte cmd/param block.  Parameters are read and/or written
from the block pointed to by `CMDLIST`.

    JSR GoMLI    ; Call Command Dispatcher
    DB  CMDNUM      ; This determines which call is being made
    DW  CMDLIST     ; A two-byte pointer to the parameter list
    BNE ERROR       ; Error if nonzero (A=err) also carry set

The call returns to the instruction immediately following the parameters
with A=C=0 on success or A=error code, C=1 on failure.
In either case X, Y are unchanged.  See https://prodos8.com/docs/techref/calls-to-the-mli/
for more details.
*/

PUTC = $f001

ramPtr = $50
sPtr = $52

ScratchParams := $200      ; scratch space for r/w params

DemoBuffer := $400
RamDiskStart := $800     ; note we'll load our disk image @ $400, to ignore two boot sector blocks
RamDiskBlocks = 8
RamDiskEnd := RamDiskStart + RamDiskBlocks * $200
ReadmeLen = 893     ; expected length of file we're reading

RamDiskUnitNum = $CF   ; install our device driver as d1s6 with capability format/read/write/status

    .macro PUTS label
        lda #<label
        sta sPtr
        lda #>label
        sta sPtr+1
        jsr puts
    .endmacro

        .include "api.s"

    .import InitMLI, RegisterMLI, ReserveMLI, GoMLI, NoClock

ClockDriver = NoClock
    .export ClockDriver

LF = $0a

        .data
OK:     .byte " OK",LF,0
FAIL:   .byte " FAIL (C=1 or A!=0)",LF,0

        .code
test_start:
        jsr InitMLI     ; init MLI

        lda #<RamDiskDriver
        sta DEVICE_DRV
        lda #>RamDiskDriver
        sta DEVICE_DRV+1
        lda #RamDiskUnitNum
        sta DEVICE_UNT
        jsr RegisterMLI

        ldx #>ScratchParams          ; reserve param space
        jsr ReserveMLI

        ; flag the memory we're using for the RAM drive
        ldx #>RamDiskStart          ; first page index
@mark:  jsr ReserveMLI
        inx
        cpx #>RamDiskEnd            ; first free page
        bne @mark

        .data
test_gettime_label: .byte "GET_TIME",0

        .code
test_gettime:   ; test a no-op (or configure ClockBegin in p8fs.s)
        PUTS test_gettime_label

        jsr GoMLI
        .byte MLI_GET_TIME
        .word 0     ; no params

        bne @fail
        bcs @fail
        bra @ok
@fail:  jmp test_fail
@ok:    PUTS OK

        .data
test_online_label: .byte "ONLINE",0
test_online_params:
        .byte 2
        .byte 0             ; request all devices, else dsss.... requests slot s, drive d
        .word DemoBuffer    ; output buffer, 16 or 256 bytes, not reserved

        .code
test_online:        ; test whether our device shows as online
        PUTS test_online_label

        jsr GoMLI
        .byte MLI_ONLINE
        .word test_online_params

        bne @fail
        bcs @fail
        lda #RamDiskUnitNum
        and #$f0
        ora #7
        ; expect DemoBuffer to contain (unit | len), "DEMOVOL"
        cmp DemoBuffer
        bne @fail2
        lda DemoBuffer+1
        cmp #'D'
        bne @fail2
        bra @ok
@fail2: lda #$ff
@fail:  jmp test_fail
@ok:    PUTS OK

        .data
test_set_prefix_label: .byte "SET_PREFIX",0
test_set_prefix_params:
        .byte 1
        .word DemoBuffer    ; path derived from volume name we just found

        .code
test_set_prefix:    ; test setting default prefix
    ; the startup prefix is null
    ; seems to need an abs prefix (starting with /) for open to work
        PUTS test_set_prefix_label

        ; prepend the volume name with a / to make an absolute prefix
        lda DemoBuffer
        and #$0f                ; clear the unit number
        tax                     ; offset to last char in volume name
        inc
        sta DemoBuffer          ; inc length to include leading '/'
@copy:  lda DemoBuffer,x        ; shift name over one to make space
        sta DemoBuffer+1,x
        dex
        bne @copy
        lda #'/'
        sta DemoBuffer+1

        jsr GoMLI
        .byte MLI_SET_PREFIX
        .word test_set_prefix_params

        bne @fail
        bcs @fail
        bra @ok
@fail:  jmp test_fail
@ok:    PUTS OK

        .data
test_open_label: .byte "OPEN",0
test_open_params:
        .byte 3
        .word PathName
        .word RamDiskEnd    ; 1024-byte input/output buffer not already used
open_fh_offset = * - test_open_params
        .res 1              ; filehandle result
open_params_len = * - test_open_params
PathName:
        .byte 6, "README"

        .code
test_open:          ; try reading the file
        PUTS test_open_label

        ; copy the params to scratch so MLI can write FH
        ldx #0
@cp:    lda test_open_params,x
        sta ScratchParams,x
        inx
        cpx #open_params_len
        bne @cp

        jsr GoMLI
        .byte MLI_OPEN
        .word ScratchParams

        bne @fail
        bcs @fail
        bra @ok
@fail:  jmp test_fail
@ok:    PUTS OK

        .data
test_read_label: .byte "READ",0
test_read_params:
        .byte 4
read_fh_offset = * - test_read_params
        .res 1
        .word DemoBuffer
        .word $400      ; request bytes
read_actual_offset = * - test_read_params
        .res 2          ; actual bytes
read_params_len = * - test_read_params

        .code
test_read:
        PUTS test_read_label

        ; copy param block to scratch so we can include file handle
        lda ScratchParams + open_fh_offset
        tay
        ldx #0
@cp:    lda test_read_params,x
        sta ScratchParams,x
        inx
        cpx #read_params_len
        bne @cp
        ; update the FH
        sty ScratchParams + read_fh_offset

        jsr GoMLI
        .byte MLI_READ
        .word ScratchParams

        bne @fail
        bcs @fail

        lda ScratchParams + read_actual_offset
        sta sPtr
        cmp #<ReadmeLen
        bne @fail2
        lda ScratchParams + read_actual_offset + 1
        sta sPtr+1
        cmp #>ReadmeLen
        bne @fail2
        bra @ok
@fail2: lda #$ff
@fail:  jmp test_fail
@ok:    PUTS OK

        lda #0
; TODO wrong need to add base
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
@done:  rts

test_fail:
        PUTS FAIL
        brk

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

RamDiskDriver:
        ldx DEVICE_CMD
        bne @next
        ldy #0          ; DEVICE_CMD_STATUS, return device size
        ldx #RamDiskBlocks
        bra @ok

@next:  cpx #DEVICE_CMD_FORMAT
        beq @ok         ; no-op

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
        cpx #DEVICE_CMD_READ
        bne @write

@read:  lda (ramPtr),y
        sta (DEVICE_BUF),y
        iny
        bne @read
        inc DEVICE_BUF+1
        inc ramPtr+1
        lda ramPtr+1
        lsr
        bcs @read     ; odd page (block-aligned)?
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
