/*
    call MLI by JSR with cmd and param pointer following

SYSCALL  JSR MLI         ;Call Command Dispatcher
         DB  CMDNUM      ;This determines which call is being made
         DW  CMDLIST     ;A two-byte pointer to the parameter list
         BNE ERROR       ;Error if nonzero (A=err)
*/


test_get_dt:
    jsr EntryMLI
    .byte $82   ; GET_DATE_TIME (a no-op without a clock @ DateTime)
    .word 0     ; no params
    brk

test_online:
    ; let's register a device

    ; first set up a driver in the device table (mimics drive d, slot sss as index dsss0000)
    lda #<my_driver
    sta DevAdrTbl
    lda #>my_driver
    sta DevAdrTbl+1

    ; then add to the device table
    lda #1-1
    sta DevCnt      ; # devices - 1
    lda #0
    sta DevLst+0    ; we set of the driver as d0s0

    ; now see if it's online
    jsr EntryMLI
    .byte $C5   ; ON_LINE
    .word test_online_params
    brk
test_online_params:
    .byte 2
    .byte 0     ; all devices, else dsss.... indicates slot s, drive d (but just 0-15 for us)
    .word $400  ; output buffer, 16 or 256 bytes

DEVICE_COMMAND = $42
DEVICE_UNITNUM = $43
DEVICE_BUFFER  = $44
DEVICE_BLOCK   = $46

my_driver:
    ; fake a read
    ldy #$10
@loop:
    lda block2,y
    sta (DEVICE_BUFFER),Y
    dey
    bne @loop
    rts

block2:
    .word 0, 3      ; prev/next pointers
    .byte $F0 | 7
    .byte "FAKEVOL", 0
    .byte 0,0,0,0,0,0,0,0

/*
$42 Command:
0 = STATUS request 1 = READ request 2 = WRITE request 3 = FORMAT request

status => device blocks in (Y,X)

$43 Unit Number:
    7  6  5  4  3  2  1  0
  +--+--+--+--+--+--+--+--+
  |DR|  SLOT  | NOT USED  |
  +--+--+--+--+--+--+--+--+
Note: The UNIT_NUMBER that appears in the device list (DEVLST) in the system globals will include the high nibble of the status byte ($CnFE) as an ID in its low nibble.

$44-$45 Buffer Pointer:
Indicates the start of a 512-byte memory buffer for data transfer.
$46-$47 Block Number:
Indicates the block on the disk for data transfer.
The device driver should report errors by setting the carry flag and loading the error code into the accumulator. The error codes that should be implemented are:

    $27 - I/O error
    $28 - No device connected
    $2B - Write protected
*/