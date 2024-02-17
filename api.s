; MLI commands

MLI_CREATE          = $C0   ; [ path, access, file_type, aux_type, storage_type,
                            ;   create_date, create_time ]
MLI_DESTROY         = $C1   ; [ path ]
MLI_RENAME          = $C2   ; [ oldpath, newpath ]
MLI_SET_FILE_INFO   = $C3   ; [ path, access, file_type, aux_type, null,
                            ;   create_date, create_time ]
MLI_GET_FILE_INFO   = $C4   ; [ path, access, file_type, aux_type, storage_type,
                            ;   mod_date, mod_time, create_date, create_time ]
MLI_ONLINE          = $C5   ; [ unit_num, data_buffer ]
MLI_SET_PREFIX      = $C6   ; [ path ]
MLI_GET_PREFIX      = $C7   ; [ buffer ]
MLI_OPEN            = $C8   ; [ path, io_buffer, ref_num ]
MLI_NEWLINE         = $C9   ; [ ref_num, enable_mask, newline_char ]
MLI_READ            = $CA   ; [ ref_num, data_buffer, request_count, transfer_count ]
MLI_WRITE           = $CB   ; [ ref_num, data_buffer, request_count, transfer_count ]
MLI_CLOSE           = $CC   ; [ ref_num ]
MLI_FLUSH           = $CD   ; [ ref_num ]
MLI_SET_MARK        = $CE   ; [ ref_num, position ]
MLI_GET_MARK        = $CF   ; [ ref_num, position ]
MLI_SET_EOF         = $D0   ; [ ref_num, eof ]
MLI_GET_EOF         = $D1   ; [ ref_num, eof ]
MLI_SET_BUF         = $D2   ; [ ref_num, io_buffer ]
MLI_GET_BUF         = $D3   ; [ ref_num, io_buffer ]
; MLI_ALLOC_INTERRUPT   = $40       ; not supported
; MLI_DEALLOC_INTERRUPT = $41       ; not supported
MLI_READ_BLOCK      = $80   ; [ unit_num, data_buffer, block_num ]
MLI_WRITE_BLOCK     = $81   ; [ unit_num, data_buffer, block_num ]
MLI_GET_TIME        = $82   ; [ ]

; device driver API

DEVICE_CMD := $42   ; aka dhpCmd
DEVICE_UNT := $43   ; aka unitNum
DEVICE_BUF := $44   ; aka bufPtr
DEVICE_DRV := DEVICE_BUF    ; used for RegisterMLI
DEVICE_BLK := $46   ; aka blockNum

DEVICE_CMD_STATUS   = 0     ; ready for r/w?; return device block size as [Y, X]
DEVICE_CMD_READ     = 1     ; read block => buf
DEVICE_CMD_WRITE    = 2     ; write block => buf
DEVICE_CMD_FORMAT   = 3     ; physical device format (usually no-op)

; storage types
; also (but not referenced) unused = 0, sudir header = $e, vol header = $f

seedling        = 1
sapling         = 2
tree            = 3
directoryFile   = $d

; file access bits

destroyEnable   = $80
renameEnable    = $40
backupNeeded    = $20
fileInvisible   = $04     ; see https://prodos8.com/docs/technote/23/
writeEnable     = $02
readEnable      = $01


; * Error Codes specific to ProDOS 8
; * Other error codes are in the GS/OS equate file

vcbUnusable     = $0A
fcbUnusable     = $0B
badBlockErr     = $0C             ;Block allocated illegally
fcbFullErr      = $42
vcbFullErr      = $55
badBufErr       = $56

; others I inferred from missing refs and https://prodos8.com/docs/techref/calls-to-the-mli/
badSystemCall   = $1
invalidPcount   = $4
irqTableFull    = $25
drvrIOError     = $27
drvrNoDevice    = $28
drvrWrtProt     = $2b
drvrOffLine     = $2e  ;TODO duplicate?
drvrDiskSwitch  = $2e
badPathSyntax   = $40
; fcbFullErr      = $42 ; defined above
invalidRefNum   = $43
pathNotFound    = $44
volNotFound     = $45
unknownVol      = $45 ;TODO duplicate?
fileNotFound    = $46
dupPathname     = $47
volumeFull      = $48
volDirFull      = $49
badFileFormat   = $4a
badStoreType    = $4b
eofEncountered  = $4c
outOfRange      = $4d
invalidAccess   = $4e
fileBusy        = $50
dirError        = $51
; not a prodos disk $52 ; never referenced
paramRangeErr   = $53
; vcbFullErr      = $55    ; defined above
; badBufErr       = $56    ; defined above
dupVolume       = $57
damagedBitMap   = $5a
