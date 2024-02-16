; **************************************************
; from globals

GoPro       JMP    EntryMLI        ;MLI call entry point
DateTime    JMP    ClockDriver     ; configurable clock entry, use NoClock (or any rts) for none
SysErr      JMP    SysErr1         ;Error reporting hook
SysDeath    JMP    SysDeath1       ;System failure hook

; @ * * * * * * * * * * * * * * * *
; @    The xdos machine language  *
; @         interface (MLI)       *
; @      system call processor    *
; @ * * * * * * * * * * * * * * * *

EntryMLI    CLD                    ;Cannot deal with decimal mode!!!
            STY    SaveY           ;Preserve the y and x registers
            STX    SaveX
            tsx                     ;Get processor status
            stx    Spare1           ;Save it on the global page temporarily
            PLA                    ;Find out the address of the caller
            STA    parm
            CLC                    ; & preserve the address of the call spec
            ADC    #$04
            STA    CmdAdr
            PLA
            STA    parm+1
            ADC    #$00
            STA    CmdAdr+1        ;CmdAdr is in the globals

; @  Check cmd code

            LDA    Spare1
            PHA
            PLP                    ;Pull processor to re-enable interrupts
            CLD                    ;No decimal! (** #46 **)
            LDY    #$00
            STY    SErr            ;Clear any previous errors...

; @ Hashing algorithm used here adds high nibble
; @ (div by 16 first) to the whole cmd code
; @ and then masks it to 5 lower bits
; @ This compresses range of codes without any overlapping

            INY                    ;Find out if we've got a valid command
            LDA    (parm),Y        ;Get command #
            LSR                    ;Hash it to a range of $00-$1F
            LSR
            LSR
            LSR
            CLC
            ADC    (parm),Y
            AND    #$1F
            TAX
            LDA    (parm),Y        ;Now see if result is a valid command number
            CMP    scNums,X        ;Should match if it is
            BNE    scnErr          ;Branch if not

; @  Get IOB address

            INY                    ;Index to call spec parm list addr
            LDA    (parm),Y        ;Make parm point to parameter count byte
            PHA                    ; in parameter block
            INY
            LDA    (parm),Y
            STA    parm+1
            PLA
            STA    parm

; @  Check parm count

            LDY    #c_pCnt         ;Now make sure parameter list has the
            LDA    pCntTbl,X       ;  proper number of parameters
            BEQ    GoClock         ;Clock has 0 parameters
            CMP    (parm),Y
            BNE    scpErr          ;Report error if wrong count

; @ Check class of function

            LDA    scNums,X        ;Get call number again
            CMP    #$65
            beq    ExitMLI          ; special not supported
            ASL                    ;Carry set if bfm or dev mgr
            BPL    GoDevMgr
            BCS    GoBFMgr
                ; interrupt mgmt not supported
            BRA    ExitMLI         ;Command processed, all done

; @*************************************************
; @ Command $82 - Get the date and time

GoClock     JSR    DateTime        ;go read clock
            BRA    ExitMLI         ;No errors posible!

; @*************************************************
; @ READBLOCK and WRITEBLOCK commands ($80 and $81)

GoDevMgr    LSR                    ;Save command #
            ADC    #$01            ;Valid commands are 1 & 2
            STA    dhpCmd          ;(READ & WRITE)
            JSR    DevMgr          ;Execute read or write request
            BRA    ExitMLI

; @-------------------------------------------------
; @ Commands $C0 thru $D3

GoBFMgr     LSR
            AND    #$1F            ;Valid commands in range of $00-$13
            TAX
            JSR    BFMgr           ;Go do it...

ExitMLI     STZ    BUBit           ;First clear bubit
            LDY    SErr            ;Y holds error code thru most of exit
            CPY    #$01            ;If >0 then set carry
            TYA                    ; & set z flag
            PHP                    ;Disable interupts
            SEI                    ; until exit complete
            LSR    mliActv         ;Indicate MLI done.(** #46 **) (** #85 **)
            PLX                    ;Save status register in X
            LDA    CmdAdr+1        ; until return address is placed
            PHA                    ; on the stack returning is done via 'RTI'
            LDA    CmdAdr          ; so that the status register is
            PHA                    ; restored at the same time
            PHX                    ;Place status back on the stack
            TYA                    ;Return error, if any
            LDX    SaveX           ;Restore x & y registers
            LDY    SaveY
    ; from globals.s
            RTI                    ;Re-enable interrupts and return


; @-------------------------------------------------
; Device handler for disconnect devices, see DevAdrTbl

gNoDev      LDA    #drvrNoDevice   ;Report no device connected
            JSR    SysErr          ; returns error and pops back

scnErr      LDA    #badSystemCall  ;Report no such command
            BNE    scErr1          ;Branch always
scpErr      LDA    #invalidPcount  ;report parameter count is invalid
scErr1      JSR    GoSysErr
            BCS    ExitMLI         ;Branch always taken

;            TTL    'ProDOS Device Manager'

; @-------------------------------------------------
; @ ProDOS device manager
; @ Block I/O setup

DevMgr      LDY    #$05            ;The call spec for devices must
            PHP                    ;(do not allow interupts)
            SEI
@loop       LDA    (parm),Y        ; be passed to drivers in zero page
;TODO was STA |dhpCmd, Y   ; maybe some banking notation??
            STA    dhpCmd,Y       ;dhpCmd,unitNum,bufPtr,blockNum
            DEY
            BNE    @loop
            LDX    bufPtr+1
            STX    userBuf+1
            INX
            INX                    ;Add 2 for 512 byte range
            LDA    bufPtr          ;Is buffer page alligned?
            BEQ    @1              ;Branch if it is
            INX                    ;Else account for 3-page straddle...
@1          JSR    ValDBufZ        ;Make sure user is not conflicting
            BCS    DevMgrErr       ; with protected RAM
            JSR    DMgr            ;Call internal entry for device dispatch
            BCS    DevMgrErr       ;Branch if error occured
            PLP
            CLC                    ;Make sure carry is clear (no error)
            RTS

DevMgrErr   PLP
GoSysErr    JSR    SysErr

; @-------------------------------------------------
; @ NOTE: interrupts must always be off when entering here
; @ Do block I/O rtn

DMgr        LDA    unitNum         ;Get device number
            AND    #$F0            ;Strip misc lower nibble
            STA    unitNum         ;  & save it back
            LSR                    ;Use as index to device table
            LSR
            LSR
            TAX
            LDA    DevAdrTbl,X      ;Fetch driver address
            STA    goAdr
            LDA    DevAdrTbl+1,X
            STA    goAdr+1
GoCmd       JMP    (goAdr)         ;Goto driver (or error if no driver)


; @-------------------------------------------------
; @ System error handler

SysErr1     STA    SErr
            PLX
            PLX                    ;Pop 1 level of return
            SEC
NoClock     RTS

; @-------------------------------------------------
; @ System death handler

SysDeath1   TAX                    ;System death!!!

Halt        BRA    Halt            ;Hold forever
