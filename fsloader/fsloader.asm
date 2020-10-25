* = $7D00
#include "../../tmon3.h"

jsr NEWLINE
ldx #<BLS
ldy #>BLS
jsr PRINTS
jsr NEWLINE
; seek to bootloader
stz SD_BLK0
stz SD_BLK2
stz SD_BLK3
lda #$10
sta SD_BLK1

; Set destination
stz SD_DATABUFFERL
lda #$10
sta SD_DATABUFFERH

jsr SD_READ_BLOCK_TO
jsr SD_BUFFER_INC
jsr SD_READ_BLOCK_TO
jsr SD_BUFFER_INC
jsr SD_READ_BLOCK_TO
jsr SD_BUFFER_INC

; prepare for jump
stz SD_BLK0
stz SD_BLK1

jmp $1000


BLS:    .byte   "SD BOOTLOADER",0
