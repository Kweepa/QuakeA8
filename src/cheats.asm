; Cheat codes. C64: next CIA1 matrix cell, from accum_keys.
; Atari: SKSTAT key-down from the DLI and the VBI. IRQST bit 6 stays
; inactive while IRQEN is 0, so it cannot be polled. A changed KBCODE
; counts as a new press when the release fell between samples.
; apply_cheats on main does HUD, sound, and restart_level.
; Shared "id" prefix, then god / kfa / mapNN.
!zone cheats

CHEAT_IDLE	= 0
CHEAT_GOT_I	= 1
CHEAT_AFTER_ID	= 2
CHEAT_REQ_GOD	= 1
CHEAT_REQ_KFA	= 2
CHEAT_REQ_MAP	= 3

; god, kfa, map, three keys each. Index is the table offset; base/end
; bound it. Digits are a separate 1..9 pair.

; POKEY KBCODE & $3F. Same positions a8_keys uses for 1..4.
cheat_kc	!byte $3d, $08, $3a			; G O D
		!byte $05, $38, $3f			; K F A
		!byte $25, $3f, $0a			; M A P
cheat_kc_dig	!byte $1f, $1e, $1a, $18, $1d, $1b, $33, $35, $30

cheat_base	!byte 0, 3, 6
cheat_end	!byte 3, 6, 9

cheat_msg_on	!text "godmode on",0
cheat_msg_off	!text "godmode off",0
cheat_msg_kfa	!text "keys, full ammo",0
cheat_msg_map	!text "change map",0

; ---------------------------------------------------------------------------
cheat_init
	lda #0
	sta god_mode
	sta cheat_req
	sta cheat_ep_latch
	sta cheat_map_latch
	sta cheat_kdown
	jmp cheat_reset_all


CHEAT_KC_I	= $0d
CHEAT_KC_D	= $3a

; DLI and VBI. SKSTAT bit 2 clear = a key is down. cheat_kdown is 0
; after a sample saw the key up, else the last accepted code + 1.
; A new code while the bit stays down is the release we did not sample.
check_cheats
	lda $d20f
	and #$04
	beq .down
	lda #0
	sta cheat_kdown
	rts
.down
	lda $d209
	and #$3f
	clc
	adc #1
	cmp cheat_kdown
	beq .rts
	sta cheat_kdown
	lda player_hp
	beq .rts
	lda cheat_kdown
	sec
	sbc #1
	sta cheat_a
	lda cheat_phase
	beq .idle
	cmp #CHEAT_GOT_I
	beq .got_i
	jmp .after_id

.idle
	lda cheat_a
	cmp #CHEAT_KC_I
	bne .rts
	lda #CHEAT_GOT_I
	sta cheat_phase
.rts
	rts

.got_i
	lda cheat_a
	cmp #CHEAT_KC_D
	bne .rts
	jsr cheat_clear_suf
	lda #CHEAT_AFTER_ID
	sta cheat_phase
	rts

.after_id
	lda cheat_a
	cmp #CHEAT_KC_I			; another I restarts the prefix
	bne .suf
	jsr cheat_clear_suf
	lda #CHEAT_GOT_I
	sta cheat_phase
	rts

.suf
	ldx #0
.suf_lp
	jsr cheat_step
	inx
	cpx #3
	bcc .suf_lp
	rts

; X = suffix 0..2. cheat_a = keycode. Map takes two digits once its
; index reaches cheat_end. A miss does not reset the suffix.
cheat_step
	cpx #2
	bne .st_let
	lda cheat_map
	cmp cheat_end + 2
	bcs .st_dig
.st_let
	ldy cheat_god,x
	lda cheat_kc,y
	cmp cheat_a
	bne .st_rts
	inc cheat_god,x
	lda cheat_god,x
	cmp cheat_end,x
	bne .st_rts
	cpx #2
	beq .st_rts			; letters done; digits are later presses
	inx				; req = slot + 1
	pla
	pla				; drop cheat_step, rts back to the VBI
	jmp cheat_latch
.st_dig
	ldy #0
.std_lp
	lda cheat_kc_dig,y
	cmp cheat_a
	beq .std_hit
	iny
	cpy #9
	bcc .std_lp
	rts
.std_hit
	iny				; 1..9
	lda cheat_map
	cmp cheat_end + 2
	bne .st_mapn
	sty cheat_ep_dig
	inc cheat_map
	rts
.st_mapn
	sty cheat_map_dig
	lda cheat_ep_dig
	sta cheat_ep_latch
	lda cheat_map_dig
	sta cheat_map_latch
	pla
	pla
	ldx #CHEAT_REQ_MAP
	jmp cheat_latch
.st_rts
	rts


cheat_clear_suf
	ldx #2
.cs_b
	lda cheat_base,x
	sta cheat_god,x
	dex
	bpl .cs_b
	lda #0
	ldx #4				; cheat_was[4] + cheat_dig_prev
.cs_w
	sta cheat_was,x
	dex
	bpl .cs_w
	rts

cheat_reset_all
	jsr cheat_clear_suf
	lda #0
	sta cheat_phase
	rts

; X = CHEAT_REQ_*. Ignore it when one is already waiting.
cheat_latch
	lda cheat_req
	beq .lt_set
	jmp cheat_reset_all
.lt_set
	stx cheat_req
	jmp cheat_reset_all

; ---------------------------------------------------------------------------
; Main. cheat_req is IRQ-owned; copy it out under SEI.
; ---------------------------------------------------------------------------
apply_cheats
	php
	sei
	lda cheat_req
	beq .ac_none
	ldx cheat_ep_latch
	ldy cheat_map_latch
	pha
	lda #0
	sta cheat_req
	pla
	plp
	cmp #CHEAT_REQ_GOD
	beq apply_god
	cmp #CHEAT_REQ_KFA
	beq apply_kfa
	cmp #CHEAT_REQ_MAP
	beq apply_map
	rts
.ac_none
	plp
	rts

apply_god
	lda god_mode
	eor #1
	sta god_mode
	beq .ag_off
	lda #<cheat_msg_on
	ldy #>cheat_msg_on
	jmp .ag_msg
.ag_off
	lda #<cheat_msg_off
	ldy #>cheat_msg_off
.ag_msg
	jsr cheat_show
	lda #SOUND_ITEMS_DAMAGE
	jmp play_sound

apply_kfa
	lda #HAVE_AXE | HAVE_SHOT | HAVE_NAIL | HAVE_GREN
	sta have_wpn
	lda #AMMO_SHELLS_MAX
	sta ammo_shells
	lda #AMMO_NAILS_MAX
	sta ammo_nails
	lda #AMMO_GRENADES_MAX
	sta ammo_grenades
	lda #PLAYER_ARMOUR_MAX
	sta player_armour
	lda have_keys
	ora #HAVE_SILVER | HAVE_GOLD
	sta have_keys
	jsr hud_ammo
	lda #<cheat_msg_kfa
	ldy #>cheat_msg_kfa
	jsr cheat_show
	lda #SOUND_WEAPONS_PKUP
	jmp play_sound

; X = episode digit, Y = map digit. Message after play_up2 (inside restart).
apply_map
	cpx #1
	bne .am_rts
	cpy #1
	bcc .am_rts
	cpy #MAP_NLEVELS + 1
	bcs .am_rts
	sty level_num
	jsr restart_level
	bcs .am_fail
	lda #<cheat_msg_map
	ldy #>cheat_msg_map
	jmp cheat_show
.am_fail
	jmp episode_done
.am_rts
	rts

; A = lo, Y = hi. Status row, STATUS_MS.
cheat_show
	sta src_ptr
	sty src_ptr+1
	jsr hud_msg_blank
	jsr hud_msg_center
	lda #<STATUS_MS
	sta status_ms_l
	lda #>STATUS_MS
	sta status_ms_h
	rts
