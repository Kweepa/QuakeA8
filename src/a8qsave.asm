; QSAVE overlay: Shift-S quicksave / Shift-L quickload.
; poll_quick_keys (loader.asm) LoadPrg's this over bitmap A at QS_OVL with the
; screen blanked, jsr's it, then zeroes QS_OVL..$CFFF. The code and the payload
; buffer sit above the three context pages a8_ctx_save parks at the top of the
; draw bitmap, so every SIO through qs_sector (resident) leaves them alone.
; Build: after the reloc assemble of GAME (genqsyms.py reads game.lbl).
;
; A = QSO_SAVE / QSO_VERIFY / QSO_RESTORE. C=0 ok, C=1 failed (message shown).
;   SAVE     pack the state, write QSAVE_N sectors.
;   VERIFY   read, check magic / version / checksum, set level_num.
;   RESTORE  after restart_level has rebuilt that map: read again and apply.
;
; Disk slot (QSAVE_N sectors, zero padded, 8-bit checksum over all of it):
;   0 magic  1 version  2 checksum (sum of the slot == 0)  3 level_num
;   4 nenemies  5 ndoors  6 nbackpacks  7 nelevs  8 ntrigs
;   then the INV fields, the WLD fields, door bytes (key | hidden bit),
;   elevator destination Y.
; Map counts that do not match the map that was reloaded (editor rebuilt
; the level since the save) restore the inventory only.
; Overlay state lives in the overlay's own bytes; ZP pointers are scratch
; here (poll_quick_keys is called from the top of main and qs_sector
; restores ZP), nothing in them is live across the call.
!cpu 6502
!to "qsave.prg", cbm

!source "build_flags.asm"
!source "mem.asm"
!source "zp.asm"
!source "map_counts.asm"
!source "map_bss.asm"
!source "qsyms.asm"
!zone a8qsave

QSO_SAVE	= 0
QSO_VERIFY	= 1
QSO_RESTORE	= 2
QSO_MAGIC	= $a5
QSO_VER		= 1
QSO_HDR		= 9
QSO_BYTES	= QSAVE_N * 128
OP_READ		= $52			; same values as the SIO commands qs_sector takes
OP_WRITE	= $57

!macro qmsg .m {
	lda #<.m
	ldy #>.m
	jsr cheat_show
}

; Field descriptor: address, selector. Selector bit 7 = the address is a
; map column pointer word (en_x ...), low bits index qso_n (element count).
!macro qf .a, .s {
	!word .a
	!byte .s
}

*= QS_OVL
qso_entry
	cmp #QSO_VERIFY
	beq .go_v
	bcs .go_r
	bcc qso_save
.go_v
	jmp qso_verify
.go_r
	jmp qso_restore

; ---------------------------------------------------------------------
qso_save
	jsr qso_counts
	jsr qso_zero
	lda #QSO_MAGIC
	sta qso_buf
	lda #QSO_VER
	sta qso_buf+1
	lda level_num
	sta qso_buf+3
	lda map_nenemies
	sta qso_buf+4
	lda map_ndoors
	sta qso_buf+5
	lda map_nbackpacks
	sta qso_buf+6
	lda map_nelevs
	sta qso_buf+7
	lda map_ntrigs
	sta qso_buf+8
	lda #OP_WRITE
	sta qso_op
	jsr qso_cursor
	lda #0
	jsr qso_fields
	lda #qso_wld - qso_tab
	jsr qso_fields
	jsr qso_doors
	jsr qso_elevs
	lda src_ptr+1			; cursor must not pass the slot
	cmp #>(qso_buf + QSO_BYTES)
	bcc .sv_fit
	bne .sv_bad
	lda src_ptr
	cmp #<(qso_buf + QSO_BYTES)
	beq .sv_fit
	bcs .sv_bad
.sv_fit
	jsr qso_sum			; checksum byte is still 0
	eor #$ff
	clc
	adc #1
	sta qso_buf+2
	lda #OP_WRITE
	jsr qso_io
	bcs .sv_bad
	+qmsg qso_m_saved
	clc
	rts
.sv_bad
	+qmsg qso_m_fail
	sec
	rts

; ---------------------------------------------------------------------
qso_verify
	lda #OP_READ
	jsr qso_io
	bcs qso_none
	jsr qso_check
	bcs qso_none
	lda qso_buf+3
	beq qso_none
	cmp #MAP_NLEVELS + 1
	bcs qso_none
	sta level_num
	clc
	rts
qso_none
	+qmsg qso_m_none
	sec
	rts

; ---------------------------------------------------------------------
qso_restore
	lda #OP_READ
	jsr qso_io
	bcs qso_none
	jsr qso_check
	bcs qso_none
	jsr qso_counts
	lda #OP_READ
	sta qso_op
	jsr qso_cursor
	lda #0
	jsr qso_fields			; INV: hp, ammo, weapons, keys, powerup
	jsr qso_cmp_counts
	bcs .rs_inv
	lda #qso_wld - qso_tab
	jsr qso_fields			; WLD: position, pickups, enemies, drops, triggers
	jsr qso_doors
	jsr qso_elevs
	ldx #0				; living enemies wake up idle at frame 0, hp kept
.rs_en
	cpx map_nenemies
	bcs .rs_place
	lda en_state,x
	cmp #EN_DYING
	bcs .rs_en_n
	lda #EN_IDLE
	sta en_state,x
	lda #0
	sta en_frame,x
	sta en_pain_i,x
.rs_en_n
	inx
	bne .rs_en
.rs_place
	lda room_idx
	jsr set_room_idx
	lda #0
	sta pl_falling
	sta fall_vl
	sta fall_vh
	sta fall_y0
	sta fall_acc
	lda #$ff
	sta pl_on_elev
	sta palette_room		; main's maybe_room_palette repaints
	sec
	lda cam_yh
	sbc #EYE_HEIGHT
	sta floor_y
	jsr update_floor
	jsr sync_eye
.rs_inv
	lda cur_weapon
	pha
	lda #$ff
	sta cur_weapon
	pla
	tax
	jsr switch_weapon
	jsr hud_ammo
	jsr hud_powerup
	+qmsg qso_m_loaded
	clc
	rts

; ---------------------------------------------------------------------
; Element counts for the selectors: 0 one, 1 enemies, 2 backpacks, 3 triggers.
qso_counts
	lda #1
	sta qso_n
	lda map_nenemies
	sta qso_n+1
	lda map_nbackpacks
	sta qso_n+2
	lda map_ntrigs
	sta qso_n+3
	rts

; C=1 if the saved counts differ from the loaded map.
qso_cmp_counts
	lda qso_buf+4
	cmp map_nenemies
	bne .cc_bad
	lda qso_buf+5
	cmp map_ndoors
	bne .cc_bad
	lda qso_buf+6
	cmp map_nbackpacks
	bne .cc_bad
	lda qso_buf+7
	cmp map_nelevs
	bne .cc_bad
	lda qso_buf+8
	cmp map_ntrigs
	bne .cc_bad
	clc
	rts
.cc_bad
	sec
	rts

; C=1 if magic, version or checksum is wrong.
qso_check
	lda qso_buf
	cmp #QSO_MAGIC
	bne .ck_bad
	lda qso_buf+1
	cmp #QSO_VER
	bne .ck_bad
	jsr qso_sum
	bne .ck_bad
	clc
	rts
.ck_bad
	sec
	rts

; A = OP_READ / OP_WRITE: the whole slot <-> qso_buf. C=1 on a disk error.
qso_io
	sta qso_op
	lda #0
	sta qso_i
.io_lp
	lda qso_i
	clc
	adc #<QSAVE_SEC
	sta sio_sec_l
	lda #>QSAVE_SEC
	adc #0
	sta sio_sec_h
	lda qso_i			; buffer + i * 128
	lsr
	pha
	lda #0
	ror
	clc
	adc #<qso_buf
	sta sio_dst_l
	pla
	adc #>qso_buf
	sta sio_dst_h
	lda qso_op
	jsr qs_sector
	bcs .io_rts
	inc qso_i
	lda qso_i
	cmp #QSAVE_N
	bcc .io_lp
	clc
.io_rts
	rts

; ---------------------------------------------------------------------
qso_setbuf
	lda #<qso_buf
	sta src_ptr
	lda #>qso_buf
	sta src_ptr+1
	rts

qso_cursor
	lda #<(qso_buf + QSO_HDR)
	sta src_ptr
	lda #>(qso_buf + QSO_HDR)
	sta src_ptr+1
	rts

qso_adv
	clc
	lda src_ptr
	adc #128
	sta src_ptr
	bcc +
	inc src_ptr+1
+
	rts

qso_zero
	jsr qso_setbuf
	ldx #QSAVE_N
.z1
	ldy #127
	lda #0
.z2
	sta (src_ptr),y
	dey
	bpl .z2
	jsr qso_adv
	dex
	bne .z1
	rts

; A = 8-bit sum of the slot (Z set from it).
qso_sum
	jsr qso_setbuf
	ldx #QSAVE_N
	lda #0
	sta qso_t
.s1
	ldy #127
.s2
	lda qso_t
	clc
	adc (src_ptr),y
	sta qso_t
	dey
	bpl .s2
	jsr qso_adv
	dex
	bne .s1
	lda qso_t
	rts

; Payload cursor (src_ptr) byte out / in. Y preserved.
qso_put
	sty qso_y
	ldy #0
	sta (src_ptr),y
	jmp qso_post
qso_get
	sty qso_y
	ldy #0
	lda (src_ptr),y
qso_post
	inc src_ptr
	bne +
	inc src_ptr+1
+
	ldy qso_y
	rts

; Walk the descriptors from table offset A to the $ff entry. qso_op says
; which way: OP_WRITE packs, OP_READ unpacks.
qso_fields
	sta qso_ti
.fl
	ldx qso_ti
	lda qso_tab+2,x
	cmp #$ff
	beq .fl_done
	and #$7f
	tay
	lda qso_n,y
	sta qso_cnt
	lda qso_tab,x
	sta dst_ptr
	lda qso_tab+1,x
	sta dst_ptr+1
	lda qso_tab+2,x
	bpl .fl_go
	ldy #0				; dst_ptr holds the pointer word's address
	lda (dst_ptr),y
	pha
	iny
	lda (dst_ptr),y
	sta dst_ptr+1
	pla
	sta dst_ptr
.fl_go
	ldy #0
.fl_el
	cpy qso_cnt
	bcs .fl_nx
	lda qso_op
	cmp #OP_WRITE
	bne .fl_ld
	lda (dst_ptr),y
	jsr qso_put
	jmp .fl_in
.fl_ld
	jsr qso_get
	sta (dst_ptr),y
.fl_in
	iny
	bne .fl_el
.fl_nx
	lda qso_ti
	clc
	adc #3
	sta qso_ti
	jmp .fl
.fl_done
	rts

; One byte per door: door_key (0..3) | the DOOR_HIDDEN bit of door_type.
qso_doors
	lda door_key
	sta init_ptr
	lda door_key+1
	sta init_ptr+1
	lda door_type
	sta mp_l
	lda door_type+1
	sta mp_h
	ldy #0
.dr
	cpy map_ndoors
	bcs .dr_done
	lda qso_op
	cmp #OP_WRITE
	bne .dr_ld
	lda (mp_l),y
	and #DOOR_HIDDEN
	sta qso_t
	lda (init_ptr),y
	and #3
	ora qso_t
	jsr qso_put
	jmp .dr_in
.dr_ld
	jsr qso_get
	pha
	and #3
	sta (init_ptr),y
	lda (mp_l),y
	and #($ff - DOOR_HIDDEN)
	sta qso_t
	pla
	and #DOOR_HIDDEN
	ora qso_t
	sta (mp_l),y
.dr_in
	iny
	bne .dr
.dr_done
	rts

; One byte per elevator: where it is going. A running lower/raise thinker
; for it holds that in PROC_B, otherwise it is parked at elev_y.
qso_elevs
	ldx #0
.el
	cpx map_nelevs
	bcs .el_done
	lda qso_op
	cmp #OP_WRITE
	bne .el_ld
	lda elev_y,x
	sta qso_t
	ldy #PROC_NUM - 1
.el_pk
	lda PROC_KIND,y
	cmp #PROC_LOWER_ELEV
	beq .el_chk
	cmp #PROC_RAISE_ELEV
	bne .el_nx
.el_chk
	txa
	cmp PROC_L,y
	bne .el_nx
	lda PROC_B,y
	sta qso_t
.el_nx
	dey
	bpl .el_pk
	lda qso_t
	jsr qso_put
	jmp .el_in
.el_ld
	jsr qso_get
	sta elev_y,x
.el_in
	inx
	bne .el
.el_done
	rts

; ---------------------------------------------------------------------
qso_m_saved	!text "quicksaved", 0
qso_m_loaded	!text "quickloaded", 0
qso_m_none	!text "no quicksave", 0
qso_m_fail	!text "save failed", 0

qso_op		!byte 0
qso_i		!byte 0
qso_ti		!byte 0
qso_cnt		!byte 0
qso_t		!byte 0
qso_y		!byte 0
qso_n		!byte 1, 0, 0, 0

; INV: always restored. WLD: only when the map counts match.
qso_tab
	+qf player_hp, 0
	+qf player_armour, 0
	+qf ammo_shells, 0
	+qf ammo_nails, 0
	+qf ammo_grenades, 0
	+qf have_wpn, 0
	+qf cur_weapon, 0
	+qf have_keys, 0
	+qf pu_kind, 0
	+qf pu_ms_l, 0
	+qf pu_ms_h, 0
	+qf 0, $ff
qso_wld
	+qf room_idx, 0
	+qf cam_xl, 0
	+qf cam_xh, 0
	+qf cam_yl, 0
	+qf cam_yh, 0
	+qf cam_zl, 0
	+qf cam_zh, 0
	+qf yaw, 0
	+qf pitch, 0
	+qf rune_taken, 0
	+qf bp_taken, 2
	+qf en_state, 1
	+qf en_hp, 1
	+qf en_frame, 1
	+qf en_pain_i, 1
	+qf en_dir, 1
	+qf drop_taken, 1
	+qf drop_x, 1
	+qf drop_y, 1
	+qf drop_z, 1
	+qf drop_room, 1
	+qf drop_type, 1
	+qf en_x, $81
	+qf en_y, $81
	+qf en_z, $81
	+qf en_rot, $81
	+qf tr_purpose, $83
	+qf 0, $ff

qso_code_end = *
qso_buf = qso_code_end			; QSO_BYTES, not part of the PRG
!if qso_buf + QSO_BYTES > $d000 {
	!error "QSAVE overlay runs past bitmap A: end=", qso_buf + QSO_BYTES
}
