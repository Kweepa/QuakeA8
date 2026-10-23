; LoadPrg via the OS SIOV. Page 2 is the HUD once play starts, and the
; relocated load_dest/name live under the OS ROM, so both are snapshotted
; before PORTB maps the OS back in. Measured on this XL: $FF shows the OS,
; $FE is RAM at $A000/$C000/$D800/$F000.
!zone a8sio

A8_DIR_SEC	= 20
; 128-byte SIO sector. SIOV stores each byte then checksums the accumulator,
; so a buffer under the OS ROM still returns DSTATS=$01 and the RAM never
; changes. $C000-$CFFF and $D800-$FFFF are that ROM while PORTB=$FF.
; Not $0800: AI_ENTRY / crusher columns. The leftover sector looked like a
; resident shambler and jsr'd the ogre tail ($8C97) over mesh_project.
; Same page as the directory. sio_find has already taken start and length;
; the next LoadPrg re-reads the directory. Heap stops at HEAP_LIM, below
; this page. WPN_RAM already shares it with the directory.
A8_SECBUF	= $BE00
!if A8_SECBUF < SKEL_BSS_END AND A8_SECBUF + 128 > ENEMY_DATA_BASE {
	!error "A8_SECBUF overlaps play BSS"
}
!if A8_SECBUF >= $C000 AND A8_SECBUF < $D000 {
	!error "A8_SECBUF is under the OS ROM"
}
!if A8_SECBUF >= $D800 {
	!error "A8_SECBUF is under the OS ROM"
}
!if A8_SECBUF < HEAP_LIM {
	!error "A8_SECBUF is inside the heap"
}
A8_DIRBUF	= $BE00
A8_OSPAGE	= $BC00
A8_OS_ON	= $FF
A8_RAM	= $FE

sio_sec_l	!byte 0
sio_sec_h	!byte 0
sio_left_l	!byte 0
sio_left_h	!byte 0
sio_skip	!byte 0
sio_dst_l	!byte 0
sio_dst_h	!byte 0
sio_pay_l	!byte 0
sio_pay_h	!byte 0
sio_name_l	!byte 0
sio_name_h	!byte 0

LoadPrg
	stx load_name_l
	sty load_name_h
	jsr load_irq_off
	lda load_name_l
	sta sio_name_l
	lda load_name_h
	sta sio_name_h
	lda load_dest
	sta sio_pay_l
	lda load_dest+1
	sta sio_pay_h
	jsr a8_ctx_save
	jsr a8_os_capture
	jsr a8_os_install
	lda #A8_OS_ON
	sta $d301
	jsr sio_load_dir
	bcs .fail
	jsr sio_find
	bcs .fail
	jsr sio_body
	php
	jsr a8_ctx_done
	plp
	rts
.fail
	jsr a8_ctx_done
	sec
	rts

a8_ctx_done
	lda #A8_RAM
	sta $d301
	jsr a8_ctx_restore
	jmp a8_pokey_play

; ZP first, with abs,x so the pointer is not in the page being copied.
; Pages 2 and 3 follow. The three pages sit at the top of the draw bitmap
; ($C000 until init_vic sets bmp_hi). Gutters of those rows are put back
; after the copy, because clear_draw never stores them.
a8_ctx_save
	jsr a8_ctx_patch
	ldx #0
-
	lda $00,x
a8_zp_st	sta $c000,x
	inx
	bne -
	lda #$00
	sta src_ptr
	lda #$02
	sta src_ptr+1
	lda #0
	sta dst_ptr
	lda a8_zp_st+2
	clc
	adc #1
	sta dst_ptr+1
	jsr a8_copy_page
	inc src_ptr+1
	inc dst_ptr+1
	jmp a8_copy_page

a8_ctx_restore
	lda #0
	sta src_ptr
	lda a8_zp_ld+2
	clc
	adc #1
	sta src_ptr+1
	lda #0
	sta dst_ptr
	lda #$02
	sta dst_ptr+1
	jsr a8_copy_page
	inc src_ptr+1
	inc dst_ptr+1
	jsr a8_copy_page
	ldx #0
-
a8_zp_ld	lda $c000,x
	sta $00,x
	inx
	bne -
	jmp a8_fix_gutters

; bmp_hi is 0 until init_vic. Both sta and lda high bytes get that page.
a8_ctx_patch
	lda bmp_hi
	bne +
	lda #>BMP_A
+
	sta a8_zp_st+2
	sta a8_zp_ld+2
	rts

; 24 rows, bytes 0..3 and 28..31. sio scratch is dead after the transfer.
a8_fix_gutters
	ldx #0
.row
	txa
	and #7
	asl
	asl
	asl
	asl
	asl
	sta sio_skip
	txa
	lsr
	lsr
	lsr
	clc
	adc a8_zp_ld+2
	sta .st+2
	lda #0
	sta sio_sec_l
.gb
	ldy sio_sec_l
	lda .gutter,y
	clc
	adc sio_skip
	tay
	lda #0
.st
	sta $c000,y
	inc sio_sec_l
	lda sio_sec_l
	cmp #8
	bcc .gb
	inx
	cpx #24
	bcc .row
	rts
.gutter
	!byte 0,1,2,3,28,29,30,31

a8_copy_page
	ldy #0
-
	lda (src_ptr),y
	sta (dst_ptr),y
	iny
	bne -
	rts

a8_os_saved	!byte 0

; First call sees the OS database still in page 2. Later calls see the HUD.
; LoadPrg has already copied ZP and pages 2–3 into the draw bitmap.
a8_os_capture
	lda a8_os_saved
	bne .cap_done
	lda #$00
	sta src_ptr
	lda #$02
	sta src_ptr+1
	lda #<A8_OSPAGE
	sta dst_ptr
	lda #>A8_OSPAGE
	sta dst_ptr+1
	jsr a8_copy_page
	inc src_ptr+1
	lda #<A8_OSPAGE+$100
	sta dst_ptr
	lda #>A8_OSPAGE+$100
	sta dst_ptr+1
	jsr a8_copy_page
	lda #1
	sta a8_os_saved
.cap_done
	rts

a8_os_install
	lda #<A8_OSPAGE
	sta src_ptr
	lda #>A8_OSPAGE
	sta src_ptr+1
	lda #$00
	sta dst_ptr
	lda #$02
	sta dst_ptr+1
	jsr a8_copy_page
	lda #<A8_OSPAGE+$100
	sta src_ptr
	lda #>A8_OSPAGE+$100
	sta src_ptr+1
	inc dst_ptr+1
	jmp a8_copy_page

a8_pokey_play
	lda #0
	sta $d208
	sta $d20e				; SIOV turns keyboard IRQ back on
	lda #$03
	sta $d20f
	lda #$3c
	sta $d302
	jmp install_irq_vectors

sio_load_dir
	lda #<A8_DIRBUF
	sta sio_dst_l
	lda #>A8_DIRBUF
	sta sio_dst_h
	lda #A8_DIR_SEC
	sta sio_sec_l
	lda #0
	sta sio_sec_h
	lda #4
	sta sio_skip			; reused as the sector count; SIOV eats X
.ld
	jsr sio_read_sec
	bcs .dir_bad
	inc sio_sec_l
	clc
	lda sio_dst_l
	adc #128
	sta sio_dst_l
	bcc +
	inc sio_dst_h
+
	dec sio_skip
	bne .ld
	clc
	rts
.dir_bad
	sec
	rts

sio_find
	lda #<A8_DIRBUF
	sta src_ptr
	lda #>A8_DIRBUF
	sta src_ptr+1
.ent
	ldy #0
	lda (src_ptr),y
	bne .have
	sec
	rts
.have
	lda sio_name_l
	sta dst_ptr
	lda sio_name_h
	sta dst_ptr+1
	ldy #0
.cm
	lda (dst_ptr),y
	beq .endn
	cmp (src_ptr),y
	bne .next
	iny
	cpy #8
	bcc .cm
	jmp .hit
.endn
	lda (src_ptr),y
	bne .next
.hit
	ldy #8
	lda (src_ptr),y
	sta sio_sec_l
	iny
	lda (src_ptr),y
	sta sio_sec_h
	ldy #12
	lda (src_ptr),y
	sta sio_left_l
	iny
	lda (src_ptr),y
	sta sio_left_h
	clc
	rts
.next
	clc
	lda src_ptr
	adc #16
	sta src_ptr
	bcc .ent
	inc src_ptr+1
	jmp .ent

sio_body
	lda #2
	sta sio_skip
.loop
	lda sio_left_l
	ora sio_left_h
	bne .more
	clc
	rts
.more
	lda #<A8_SECBUF
	sta sio_dst_l
	lda #>A8_SECBUF
	sta sio_dst_h
	jsr sio_read_sec
	bcs .body_bad
	lda #0
	sta $d40e
	lda #A8_RAM
	sta $d301
	jsr sio_take_sec
	lda #A8_OS_ON
	sta $d301
	bcs .body_bad
	inc sio_sec_l
	bne .loop
	inc sio_sec_h
	jmp .loop
.body_bad
	sec
	rts

sio_take_sec
	lda sio_left_h
	bne .full
	lda sio_left_l
	cmp #128
	bcs .full
	sta sio_take
	jmp .got
.full
	lda #128
	sta sio_take
.got
	lda sio_take
	sec
	sbc sio_skip
	sta sio_n
	beq .adv
	bcc .adv
	lda sio_pay_l
	sta dst_ptr
	lda sio_pay_h
	sta dst_ptr+1
	ldy #0
.cp
	tya
	clc
	adc sio_skip
	tax
	lda A8_SECBUF,x
	sta (dst_ptr),y
	iny
	cpy sio_n
	bne .cp
	clc
	lda dst_ptr
	adc sio_n
	sta dst_ptr
	sta sio_pay_l
	bcc .adv
	inc dst_ptr+1
	lda dst_ptr+1
	sta sio_pay_h
.adv
	sec
	lda sio_left_l
	sbc sio_take
	sta sio_left_l
	lda sio_left_h
	sbc #0
	sta sio_left_h
	lda #0
	sta sio_skip
	clc
	rts

sio_take	!byte 0
sio_n		!byte 0

; Sector sio_sec_* into sio_dst_*. OS must be mapped. C=0 and DSTATS=$01.
sio_read_sec
	lda #$52
	ldy #$40
; A = command, Y = DSTATS ($52/$40 read, $57/$80 write). sio_dst_* must be
; plain RAM: under the OS ROM a read never lands and a write sends ROM bytes.
sio_xfer
	sta $0302
	sty $0303
	lda #$31
	sta $0300
	lda #1
	sta $0301
	lda sio_dst_l
	sta $0304
	lda sio_dst_h
	sta $0305
	lda #7
	sta $0306
	lda #128
	sta $0308
	lda #0
	sta $0309
	lda sio_sec_l
	sta $030a
	lda sio_sec_h
	sta $030b
	jsr $e459
	lda $0303
	cmp #$01
	beq +
	sec
	rts
+
	clc
	rts

; Quicksave sector transfer for the overlay (PORTB=$FE, buffer may sit under
; the OS ROM window). A = $52 read / $57 write, sio_sec_* = sector,
; sio_dst_* = 128-byte caller buffer. C=1 on error. Clobbers sio_sec_l,
; sio_dst_*, sio_cmd. Same ceremony as LoadPrg around a single sector, with
; A8_SECBUF as the SIO buffer.
sio_cmd		!byte 0
qs_sector
	sta sio_cmd
	lda sio_dst_l
	sta .qw+1
	sta .qr+1
	lda sio_dst_h
	sta .qw+2
	sta .qr+2
	lda sio_cmd
	cmp #$57
	bne .qs_go
	ldy #127
.qw
	lda $ffff,y
	sta A8_SECBUF,y
	dey
	bpl .qw
.qs_go
	jsr load_irq_off
	jsr a8_ctx_save
	jsr a8_os_capture
	jsr a8_os_install
	lda #A8_OS_ON
	sta $d301
	lda #<A8_SECBUF
	sta sio_dst_l
	lda #>A8_SECBUF
	sta sio_dst_h
	lda sio_cmd
	ldy #$80
	cmp #$57
	beq .qx
	ldy #$40
.qx
	jsr sio_xfer
	php
	jsr a8_ctx_done
	plp
	bcs .qe
	lda sio_cmd
	cmp #$52
	bne .qok
	ldy #127
.qrl
	lda A8_SECBUF,y
.qr
	sta $ffff,y
	dey
	bpl .qrl
.qok
	clc
.qe
	rts
