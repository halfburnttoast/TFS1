#include "../tmon3.h"

//#define RAM_LOAD

#ifdef RAM_LOAD
    * = $1000
#else
    * = $F000
#endif

#define _SHORT_DELAY \
    phx                 :   \
    ldx #$FF            :   \
    _SDL: dex           :   \
    cpx #$0             :   \
    bne _SDL            :   \
    plx         


ROOT_SECTORS            = $0
SECTORS_PER_CLUSTER     = $1
CLUSTERS_PER_FILE       = $2
FILESYSTEM_VERS         = $3
BYTES_PER_SECTOR_L      = $4
BYTES_PER_SECTOR_H      = $5
ROOT_SECTOR_OFFSET_L    = $6
ROOT_SECTOR_OFFSET_H    = $7
DATA_SECTOR_OFFSET_L    = $8
DATA_SECTOR_OFFSET_H    = $9
VOLUME_START_BLOCK_L    = $A
VOLUME_START_BLOCK_H    = $B
SEEK_PTR_L              = $C
SEEK_PTR_H              = $D
MX16_L                  = $E
MX16_H                  = $F
MY16_L                  = $10
MY16_H                  = $11

MAIN:
    jsr MOUNT_FILESYSTEM
#if 0
    jsr FETCH_ROOT_NODE
    jsr LIST_FILES

    ; DEBUG BELOW --------------
    lda #2
    jsr GET_FILE_SECTOR_OFFSET
    lda MX16_H
    jsr BTOA
    sta CHAROUT
    sty CHAROUT
    lda MX16_L
    jsr BTOA
    sta CHAROUT
    sty CHAROUT

    ; load file
    lda #$20
    sta SD_DATABUFFERH
    lda #$0
    sta SD_DATABUFFERL
    lda #0
    ldx #8
    jsr LOAD_FILE_TO
#endif
    jsr FILE_MANAGER
    ; DEBUG END ---------------------



FILE_MANAGER: .(
    jsr FETCH_ROOT_NODE
    ldx #<ACTS
    ldy #>ACTS
    jsr PRINTS
    jsr GETLINE
    jsr NEWLINE

    ; fetch command char
    ldx #$0
NC: lda LINE_IN, x
    inx
    cmp #' '
    beq NC
    cmp #'R'
    beq READ
    cmp #'Q'
    beq QUIT
    cmp #'L'
    beq LIST
    cmp #'W'
    beq WRITE
    cmp #'D'
    beq DELETE
    cmp #'C'
    beq COPY
    lda #'?'
    sta CHAROUT
    jmp FILE_MANAGER
LIST:
    jsr LIST_FILES
    jmp FILE_MANAGER
QUIT:
    jmp ($FFFA)
READ:
    jsr READ_FILE
    jmp FILE_MANAGER
WRITE:
    jsr WRITE_FILE_FROM
    jmp FILE_MANAGER
DELETE:
    jsr DELETE_FILE
    jmp FILE_MANAGER
COPY:
    jsr COPY_FILE
    jmp FILE_MANAGER
ACTS:   .byte "(L)IST, (R)EAD, (W)RITE, (D)ELETE, (C)OPY, (Q)UIT",0
.)    

; copy a file to the next availiable cluster
COPY_FILE: .(
    
    rts
.)

; Creates a file at the next available root node:
;   checks status byte:
;       0x00 - No file entry (end of list)
;       0x81 - File flagged for deletion
; INPUT:
;   W <start addr> <end addr> <filename> 
WRITE_FILE_FROM: .(
    START_V_L   = $12
    START_V_H   = $13
    END_V_L     = $14
    END_V_H     = $15
    INDEX       = $16
    SECTORS_USED= $17
    jsr GET_OPEN_NODE
    sta INDEX
    lda #$1
    ldy #$0
    sta (SEEK_PTR_L), y

    ; fetch start vector
    jsr BCLR
    jsr GETTOKEN
    bne NC
    jmp ERR
NC: lda LINE_IN, x
    bne NERR
    jmp ERR
NERR:
    cmp #' '
    beq E1
    jsr CTON
    jsr BADD
    inx
    bra NC
E1: lda B16L
    sta START_V_L
    lda B16H
    sta START_V_H

    ; fetch end vector
    jsr BCLR
    jsr GETTOKEN
    bne NC2
    jmp ERR
NC2:lda LINE_IN, x 
    bne NERR3
    jmp ERR
NERR3:
    cmp #' '
    beq E2
    jsr CTON
    jsr BADD
    inx
    bra NC2
E2: lda B16L
    sta END_V_L
    lda B16H
    sta END_V_H

    ; copy filename
    jsr GETTOKEN
    ldy #1
FCL:lda LINE_IN, x
    sta (SEEK_PTR_L), y
    inx
    iny
    cmp #0
    beq FCE
    cpy #12
    beq ERRF
    bra FCL
FCE:
    ; calculate sectors used 
    ; sectors used = ((end_addr - start_addr) / 0x200) + 1
    lda END_V_H
    sta MX16_H
    lda END_V_L
    sta MX16_L
    lda START_V_H
    sta MY16_H
    lda START_V_L
    sta MY16_L
    jsr SUB16       ; (end_addr - start_addr)

    lda #$02
    sta MY16_H
    stz MY16_L
    phx
    ldx #$0
DL: lda MX16_H      ; / 0x200
    beq DE
    bmi DE
    jsr SUB16
    inx
    bra DL
DE: inx             ; + 1
    stx SECTORS_USED
    plx

    ; copy file attributes to node
    lda INDEX
    ldy #13
    sta (SEEK_PTR_L), y
    iny 
    lda SECTORS_USED
    sta (SEEK_PTR_L), y

    ; update SD card with new root node
    jsr SD_WRITE_BLOCK

    ; setup copy operation
    lda START_V_L
    sta SD_DATABUFFERL
    lda START_V_H
    sta SD_DATABUFFERH
    lda INDEX
    jsr GET_FILE_SECTOR_OFFSET
    lda MX16_H
    sta SD_BLK1
    lda MX16_L
    sta SD_BLK0
    lda SECTORS_USED
    jsr WRITE_DATA
    rts

ERR:
    ldx #<ERRS
    ldy #>ERRS
    jsr PRINTS
    rts
ERRS:   .byte   "MISSING ARG",0
ERRF:
    ldx #<FTL
    ldy #>FTL
    jsr PRINTS
    rts
FTL:    .byte   "FILENAME TOO LONG",0
.)


; Writes REGA number of sectors to SD card
; beginning at offset SD_DATABUFFER_H/L
; preset SD_BLK0/1 before calling
WRITE_DATA: .(
    phx
    tax             ; iterator
CL: dex
    phx
    jsr SD_WRITE_BLOCK_FROM
    plx
    cpx #$0
    beq E
    jsr SD_BUFFER_INC
    ;clc
    ;lda SD_DATABUFFERH
    ;adc #$2
    ;sta SD_DATABUFFERH
    _SHORT_DELAY
    bra CL
E:
    plx
    rts
.)


READ_FILE: .(
    FILE_INDEX = $12
    SIZE       = $13
    jsr BCLR
    jsr GETTOKEN
    beq ERR
NC: lda LINE_IN, x
    cmp #' '
    beq E1
    cmp #$0
    beq E1
    jsr CTON
    jsr BADD
    inx
    bra NC
E1: lda B16L
    sta FILE_INDEX
    jsr GET_FILE_SECTORS_USED
    sta SIZE
    jsr BCLR
    jsr GETTOKEN
    beq ERR
NC2:lda LINE_IN, x
    cmp #' '
    beq E2
    cmp #$0
    beq E2
    jsr CTON
    jsr BADD
    inx
    bra NC2
E2: lda B16L
    sta SD_DATABUFFERL
    lda B16H
    sta SD_DATABUFFERH
    ldx SIZE
    lda FILE_INDEX
    jsr LOAD_FILE_TO
    rts
ERR:
    ldx #<ERRS
    ldy #>ERRS
    jsr PRINTS
    rts
ERRS: .byte "MISSING ARG",0
.)

; INPUT:
;   A - file cluster index
; RETURNS:
;   A - file sectors used
GET_FILE_SECTORS_USED: .(
    jsr B16_CLEAR
    sta MY16_L
    lda #$10
    sta MX16_L
    jsr MULT16_8
    lda #<SD_DATA_BUFFER
    sta MY16_L
    lda #>SD_DATA_BUFFER
    sta MY16_H
    jsr ADD16
    lda MX16_L
    sta SEEK_PTR_L
    lda MX16_H
    sta SEEK_PTR_H
    ldy #14
    lda (SEEK_PTR_L), y
    rts
.)

MOUNT_FILESYSTEM: .(
    jsr NEWLINE
    jsr NEWLINE 

    ; save volume start offset
    lda SD_BLK0
    sta VOLUME_START_BLOCK_L
    lda SD_BLK1
    sta VOLUME_START_BLOCK_H

    ; load PROPERTIES node to default buffer
    jsr SD_READ_BLOCK

    ; load properties from node
    lda SD_DATA_BUFFER + ROOT_SECTORS
    sta ROOT_SECTORS
    lda SD_DATA_BUFFER + SECTORS_PER_CLUSTER
    sta SECTORS_PER_CLUSTER
    lda SD_DATA_BUFFER + CLUSTERS_PER_FILE
    sta CLUSTERS_PER_FILE
    lda SD_DATA_BUFFER + FILESYSTEM_VERS
    sta FILESYSTEM_VERS
    lda SD_DATA_BUFFER + BYTES_PER_SECTOR_L
    sta BYTES_PER_SECTOR_L
    lda SD_DATA_BUFFER + BYTES_PER_SECTOR_H
    sta BYTES_PER_SECTOR_H
    lda SD_DATA_BUFFER + ROOT_SECTOR_OFFSET_L
    sta ROOT_SECTOR_OFFSET_L
    lda SD_DATA_BUFFER + ROOT_SECTOR_OFFSET_H
    sta ROOT_SECTOR_OFFSET_H
    lda SD_DATA_BUFFER + DATA_SECTOR_OFFSET_L
    sta DATA_SECTOR_OFFSET_L
    lda SD_DATA_BUFFER + DATA_SECTOR_OFFSET_H
    sta DATA_SECTOR_OFFSET_H
    ldx #<FSL
    ldy #>FSL
    jsr PRINTS
    jsr NEWLINE
    rts
FSL:    .byte   "FILESYSTEM LOADED",0
.)

 
FETCH_ROOT_NODE: .(
    lda ROOT_SECTOR_OFFSET_L
    sta SD_BLK0
    lda ROOT_SECTOR_OFFSET_H
    sta SD_BLK1
    jsr SD_READ_BLOCK
    rts
.)

DELETE_FILE: .(
    phx
    jsr FETCH_ROOT_NODE
    jsr BCLR
    plx
    jsr GETTOKEN
    beq ERR
NC: lda LINE_IN, x
    cmp #' '
    beq E1
    cmp #$0
    beq E1
    jsr CTON
    jsr BADD
    inx
    bra NC
E1: lda B16L
    sta MX16_L
    lda B16H
    sta MX16_H
    lda #$10
    sta MY16_L
    jsr MULT16_8
    lda #<SD_DATA_BUFFER
    sta MY16_L
    lda #>SD_DATA_BUFFER
    sta MY16_H
    jsr ADD16
    lda MX16_L
    sta SEEK_PTR_L
    lda MX16_H
    sta SEEK_PTR_H
    ldy #$0
    lda (SEEK_PTR_L), y
    ora #$80
    sta (SEEK_PTR_L), y
    jsr SD_WRITE_BLOCK
    rts
ERR:
    ldx #<ERRS
    ldy #>ERRS
    jsr PRINTS
    rts
ERRS: .byte "MISSING ARG",0
.)

; Moves SEEK_PTR_H/L to the next available root node
; Returns A - cluster index
GET_OPEN_NODE: .(
    phx
    phy
    jsr FETCH_ROOT_NODE
    lda #<SD_DATA_BUFFER
    sta SEEK_PTR_L
    lda #>SD_DATA_BUFFER
    sta SEEK_PTR_H
    ldx #$0
    ldy #$0
SEEK:
    lda (SEEK_PTR_L), y
    cmp #$0
    beq FOUND
    and #$80
    cmp #$80
    beq FOUND
    inx
    lda #$10
    clc
    adc SEEK_PTR_L
    sta SEEK_PTR_L
    bcc SEEK
    inc SEEK_PTR_H
    clc
    bra SEEK
FOUND:
    txa
    ply
    plx
    rts
.)


LIST_FILES: .(
    phx
    phy
    jsr NEWLINE
    ldx #<FILES
    ldy #>FILES
    jsr PRINTS
    ply
    plx
    lda #<SD_DATA_BUFFER
    sta SEEK_PTR_L
    lda #>SD_DATA_BUFFER
    sta SEEK_PTR_H
N:  jsr NEWLINE
    ldy #$0
    lda (SEEK_PTR_L), y
    beq END                 ; if status byte == 0, end of file list
    and #$80                 ; mark if file is deleted
    cmp #$0
    beq ND
    lda #'*'
    sta CHAROUT
ND: phx
    phy
    ldy #13                 ; print cluster index`
    lda (SEEK_PTR_L), y        
    jsr BTOA
    sta CHAROUT
    sty CHAROUT
    lda #':'
    sta CHAROUT
    lda #' '
    sta CHAROUT
    ldx SEEK_PTR_L          ; print filename
    inx
    ldy SEEK_PTR_H
    jsr PRINTS
    lda #$09
    sta CHAROUT
    sta CHAROUT
    ldy #14                 ; print size in sectors used
    lda (SEEK_PTR_L), y
    jsr BTOA
    sta CHAROUT
    sty CHAROUT
    ply
    plx
    lda SEEK_PTR_L
    clc
    adc #$10
    sta SEEK_PTR_L
    bcc N
    inc SEEK_PTR_H
    clc
    bra N
END:rts
FILES:  .byte   "FILES:",0
.)


; Pass in A - cluster index of file
; S = (sectors_per_cluster * file_cluster_index) + data_sector_offset
; RETURNS:
;   MX16L/H - Sector offset
GET_FILE_SECTOR_OFFSET: .(
    jsr B16_CLEAR
    sta MY16_L
    lda SECTORS_PER_CLUSTER
    sta MX16_L
    jsr MULT16_8
    lda DATA_SECTOR_OFFSET_L
    sta MY16_L
    lda DATA_SECTOR_OFFSET_H
    sta MY16_H
    jsr ADD16
    rts
.)

; X + Y 
; returns X
ADD16: .(
    pha
    clc
    lda MX16_L
    adc MY16_L
    sta MX16_L
    lda MX16_H
    adc MY16_H
    sta MX16_H
    clc
    pla
    rts
.)

; X - Y
; returns X
SUB16:
    sec
    lda MX16_L
    sbc MY16_L
    sta MX16_L
    lda MX16_H
    sbc MY16_H
    sta MX16_H
    rts


#if 0
; X * Y
; returns X
MULT16: .(
    phx
    phy
    pha
    ldy MY16_H   ; load second operand as counter
    ldx MY16_L   ;   "
    lda MX16_H   ; transfer X operand to Y operand
    sta MY16_H   ;   "
    lda MX16_L   ;   "
    sta MY16_L   ;   "
    stz MX16_L   ; clear out result 
    stz MX16_H   ;   "
L:  cpx #$0
    bne NZ 
    cpy #$0
    beq END
NZ: dex
    cpx #$FF
    bne M 
    dey
M:  jsr ADD16
    jmp L
END:
    pla
    ply
    plx
.)
#endif

; Multiply a 16-bit number by a 8-bit number
; Used for calculating file-cluster sector offset
; INPUT:
;   MX16_L/H - Multiplicand
;   MY16_L   - Multiplier
; RETURNS:
;   MX16_L/H
MULT16_8: .(
    phx
    ldx MY16_L
    lda MX16_L
    sta MY16_L
    lda MX16_H
    sta MY16_H
    stz MX16_L
    stz MX16_H
L:  cpx #$0
    beq END
    dex
    jsr ADD16
    bra L
END:plx
    rts
.)

B16_CLEAR:
    stz MX16_L
    stz MX16_H
    stz MY16_L
    stz MY16_H
    rts


; INPUT:
;   A               - CLUSTER INDEX
;   X               - Sectors to load
;   DATABUFFER_H    - DEST pointer
;   DATABUFFER_L    -   "
; RETURNS: NONE
LOAD_FILE_TO: .(
    jsr GET_FILE_SECTOR_OFFSET
    lda MX16_H
    sta SD_BLK1
    lda MX16_L
    sta SD_BLK0
L:  phx
    jsr SD_READ_BLOCK_TO
    plx
    dex
    cpx #$0
    beq END
    jsr SD_BUFFER_INC
    ;lda SD_DATABUFFERH
    ;clc
    ;adc #$2
    ;sta SD_DATABUFFERH
    bra L
END:ldx #<FLS
    ldy #>FLS
    jsr PRINTS
    jsr NEWLINE
    rts
FLS: .byte "FILE LOADED",0
.)
