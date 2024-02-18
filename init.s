InitMLI:    ; () -> nil
        ; zero the entire workspace
    .assert (<wrkspace_start) = 0, error, "wrkspace must be page-aligned"
        lda #0
        sta dataPtr
        lda #>(wrkspace_end-1)
        sta dataPtr+1
        sec
        sbc #>wrkspace_start
        tax
        lda #0
        ldy #<wrkspace_end
@loop:  dey
        sta (dataPtr),y
        bne @loop
        dec dataPtr+1
        dex
        bne @loop

        ; set up the device driver table
        ldx #31
@nodev: lda #>gNoDev
        sta DevAdrTbl, x
        dex
        lda #<gNoDev
        sta DevAdrTbl, x
        dex
        bpl @nodev

        ; DevCnt is one less than the active device count, the index of the last
        ; active device in DevLst with #$ff meaning none
        ; DevLst (initially nil) is a list of unit numbers %dsss iiii - see RegisterMLI
        lda #$ff    ; 0 active devices
        sta DevCnt

        ; set up the map of allocated memory in the lower 48K
        ; there are $C0 (= 12 x 16) 256 byte pages in 48K
        ; represented by 24 bytes where each bit marks used=1, free=0
        ; (nb. opposite to the prodos free bitmap blocks where free=1)
        ; we count up by msb first so $c0 reserves the zeropage and stack

        ; normally we put the MLI code in the (unmapped) top 16K
        ; which doesn't appear here, but our workspace data area does
        ; (the original prodos o/s used the last page, $BF, for globals)

        ; you should also reserve any space for your own code and data
        ; so that prodos doesn't allocate buffers over it.  you can do
        ; that manually by updating memTabl before calling the MLI
        ; see CalcMemBit in memmgr.c to convert page number of index + mask

        lda #$c0
        sta memTabl     ; reserve zp and stack

        ; reserve the workspace pages
;TODO 8pg align is lazy
    .assert wrkspace_end - wrkspace_start <= $800, error, "workspace exceeds 8 pages"
    .assert wrkspace_start & $03ff = 0, error, "workspace not aligned to 8-page boundary"
        lda #$ff
        sta memTabl + (wrkspace_start >> 11)

        rts


RegisterMLI:
    ; register device driver with address in DEVICE_DRV as DEVICE_UNT (dsss iiii)
    ; and add to the active device list.
    ; The unit byte %dsssiiii indicates the device number (originally drive 0-1 plus slot 0-7)
    ; where 2 * dsss (high nibble) indexes the driver addresses in DevAdrTbl
    ; and iiii=fwrs indicates driver support for format/write/read/status operations
    ; NB. the same driver can be registered multiple times as different unit numbers
    ; (duplicate entries in DevLst) with DEVICE_UNT available to the driver
    ; e.g. indicating different partitions on the same device

        inc DevCnt      ; append new unit to active list
        ldx DevCnt
        lda DEVICE_UNT
        sta DevLst,x

        and #$f0        ; unit num -> driver table offset
        lsr
        lsr
        lsr
        tax
        lda DEVICE_DRV
        sta DevAdrTbl,x
        lda DEVICE_DRV+1
        sta DevAdrTbl+1,x

        rts

ReserveMLI:     ; (X) --> nil,  X unchanged
    ; use memmgr CalcMemBit to reserve a memory page 0<=X<$c0
        jsr CalcMemBit      ; returns A as bit mask, Y as offset in memTabl
        ora memTabl,y       ; reserve the page
        sta memTabl,y
        rts
