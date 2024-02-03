; *-------------------------------------------------
; * Disassembler: The Flaming Bird Disassembler
; * Assembler : Merlin16+
; * Merlin16+ is chosen because it can assemble
; * 65816 opcodes unlike EdAsm (ProDOS) which is
; * an 8-bit assembler. Furthermore, local labels
; * may be used; that should ease the need to
; * create trivial labels.
; * NB. Merlin16+ defaults to case-sensitive labels
; * & using blank lines should improve readibility.
; * Most of the comments and labels are from the
; * source code of ProDOS v1.7
; * Whenever possible a more descriptive label is
; * used in place of the original.
; *-------------------------------------------------
; * Global Equates


; * ProDOS 8 equates

; *
; * Constants
; *
preTime     EQU    $20             ;command needs current date/time stamp
preRef      EQU    $40             ;command requires fcb address and verification
prePath     EQU    $80             ;command has pathname to preprocess
; *
; * volume status constants (bits)
; *
; * file status constants
; *
dataAloc    EQU    $1              ;data block not allocated.
idxAloc     EQU    $2              ;index not allocated
topAloc     EQU    $4              ;top index not allocated
storTypMod  EQU    $8              ;storage type modified
useMod      EQU    $10             ;file usage modified
eofMod      EQU    $20             ;end of file modified
dataMod     EQU    $40             ;data block modified
idxMod      EQU    $80             ;index block modified
fcbMod      EQU    $80             ;has fcb/directory been modified? (flush)
; *
; * header index constants
; *
hNamLen     EQU    $0              ;header name length (offset into header)
hName       EQU    $1              ;header name
hPassEnable EQU    $10             ;password enable byte
hPassWord   EQU    $11             ;encoded password
hCreDate    EQU    $18             ;header creation date
; * hCreTime EQU $1A ;header creation time
hVer        EQU    $1C             ;sos version that created directory
hComp       EQU    $1D             ;backward compatible with sos version
hAttr       EQU    $1E             ;header attributes- protect etc.
hEntLen     EQU    $1F             ;length of each entry
hMaxEnt     EQU    $20             ;maximum number of entries/block
hFileCnt    EQU    $21             ;current number of files in directory
hOwnerBlk   EQU    $23             ;owner's directory disk address
hOwnerEnt   EQU    $25             ;owner's directory entry number
hOwnerLen   EQU    $26             ;owner's directory entry length
vBitMap     EQU    hOwnerBlk
vTotBlk     EQU    hOwnerEnt       ;(used for root directory only)
; *
; * Volume Control Block index constants
; *
vcbSize     EQU    $20             ;Current VCB is 32 bytes per entry (ver 0)
vcbNamLen   EQU    0               ;Volume name length byte
vcbName     EQU    1               ;Volume name
vcbDevice   EQU    $10             ;Volume's device #
vcbStatus   EQU    $11             ;Volume status. (80=files open. 40=disk switched.)
vcbTotBlks  EQU    $12             ;Total blocks on this volume
vcbFreeBlks EQU    $14             ;Number of unused blocks
vcbRoot     EQU    $16             ;Root directory (disk) address
; *vcbBitMapOrg EQU $18 ;map organization (not supported by v 0)
; *vcbBitMapBuf EQU $19 ;bit map buf num
vcbBitMap   EQU    $1A             ;First (disk) address of bitmap(s)
vcbCurrBitMap      EQU             $1C ;Rel addr of bitmap w/space  (add to vcbBitMap)
; *vcbmnum EQU $1D ; relative bit map currently in memory
vcbOpenCnt  EQU    $1E             ;Current number of open files.
; *vcbaddr EQU $1F reserved
; *
; * File Control Block index constants
; *
fcbSize     EQU    $20             ;Current FCB is 32 bytes per entry (ver 0)
fcbRefNum   EQU    0               ;file reference number (position sensitive)
fcbDevNum   EQU    1               ;device (number) on which file resides
; *fcbHead EQU 2 ;block address of file's directory header
; *fcbDirBlk EQU 4 ;block address of file's directory
fcbEntNum   EQU    6               ;file entry number within dir block
fcbStorTyp  EQU    7               ;storage type - seed, sapling, tree, etc.
fcbStatus   EQU    8               ;status - index/data/eof/usage/type modified.
fcbAttr     EQU    9               ;attributes - read/write enable, newline enable.
fcbNewLin   EQU    $A              ;new line terminator (all 8 bits significant).
fcbFileBuf  EQU    $B              ;buffer number
fcbFirst    EQU    $C              ;first block of file (Master index/key blk)
fcbIdxBlk   EQU    $E              ;curr block address of index (0 if no index)
fcbDataBlk  EQU    $10             ;curr block address of data
fcbMark     EQU    $12             ;current file marker.
fcbEOF      EQU    $15             ;logical end of file.
fcbBlksUsed EQU    $18             ;actual number of blocks allocated to this file.
; *fcbAddr EQU $1a reserved
fcbLevel    EQU    $1B             ;level at which this file was opened
fcbDirty    EQU    $1C             ;fcb marked as modified
fcbNLMask   EQU    $1F             ;NewLine enabled mask

; * ProDOS block I/O equates
statCmd     EQU    $00             ;request status, no error=ready
rdCmd       EQU    $1
wrtCmd      EQU    $2

; actual ZP storage from $40 - $4F
parm        DS     2,0
device      DS     1,0             ;parm+2
dhpCmd      EQU    device          ;Command from ProDOS8
unitNum     DS     1,0             ;Unit # from ProDOS 8 (DSSS 0000)
bufPtr      DS     2,0             ;512-byte user's I/O buffer
blockNum    DS     2,0             ;block # requested

zTemps      DS     2,0
tPath       EQU    zTemps
dirBufPtr   EQU    zTemps
tIndex      EQU    zTemps          ;Ptr to index blk buffer
dataPtr     DS     2,0             ;Ptr to data blk buffer
posPtr      DS     2,0             ;Position marker
userBuf     DS     2,0             ;Ptr to user's buffer
; *
; * xdos parameters:
; *
c_pCnt      EQU    $0              ; (count)
c_devNum    EQU    $1              ; (value)
c_refNum    EQU    $1              ; (value)
c_intNum    EQU    $1              ; (value)
c_path      EQU    $1              ;&2 (pointer)
c_isNewln   EQU    $2              ; (mask)
c_dataBuf   EQU    $2              ;&3 (value)
c_bufAdr    EQU    $2              ;&3 (address)
c_intAdr    EQU    $2              ;&3 (address)
c_mark      EQU    $2              ;->4 (value)
c_eof       EQU    $2              ;->4 (value)
c_attr      EQU    $3              ; (flags)
c_newl      EQU    $3              ; (character)
c_bufPtr    EQU    $3              ;&4 (pointer)
c_newPath   EQU    $3              ;&4 (pointer)
c_fileID    EQU    $4              ; (value)
c_reqCnt    EQU    $4              ;&5 (value)
c_blkNum    EQU    $4              ;&5 (address)
c_outRef    EQU    $5
c_auxID     EQU    $5              ;&6 (value)
c_xferCnt   EQU    $6              ;&7 (value)
c_fileKind  EQU    $7              ; (value)
c_date      EQU    $8              ;&9 (value)
c_outBlk    EQU    $8              ;&9 (count)
c_time      EQU    $a              ;&b (value)
c_modDate   EQU    $a              ;&b (value)
c_modTime   EQU    $c              ;&d (value)
c_creDate   EQU    $e              ;&f (value)
c_creTime   EQU    $10             ;&11 (value)
