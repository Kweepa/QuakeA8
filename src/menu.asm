; Menu overlay — load @ LOCODE_BASE ($0900), JSR from a8boot, then overwritten by GAME.
; difficulty → $08FF; effects_vol/game_complete → $08FD/$08FE (survive GAME overwrite).
; Music is the embedded POKEY tune (a8music.asm).
!cpu 6502
!to "menu.prg", cbm

MENU_HELP_ENDINGS = 0			; 1 = Read This! shows ending1/2 (spacing)

!source "mem.asm"
!source "build_flags.asm"

MENU_SLOTS	= 8
BOX_PAD		= 2
BOX_VGAP	= 1			; empty rows inside box top/bottom
CURSOR_GAP	= 1			; blank cols between Q cursor and text
CURSOR_CELLS	= 3			; 24px sprite slot (Q is 16px, left-aligned)
BAR_TOP		= 2			; leave 2 rows of main bg above bar
BAR_ROWS	= 3
BADGE_TOP	= BAR_TOP - 1		; content still starts below old logo band
MENU_LOGO_ROWS	= 5			; layout gap below title bar
BRAND_KEEP_ROWS	= 6			; rows 0..5 fixed (bar + title); skip on repaint
HINT_ROW	= 23
HINT_COL	= 0			; help text column (ink is TEXT_COL)
HINT_GAP	= 8			; px between key sprite and label

TEXT_COL	= 7			; yellow options
HILITE_COL	= 1			; white selected
TITLE_COL	= 7			; yellow titles
MENU_BORDER	= 0			; black
COL_MAIN	= 0			; black surround
COL_BAR		= 0			; black title strip
COL_BOX		= 9			; brown option box
HINT_BG		= 8			; orange bottom bar (old menu surround)
COL_PANEL_INK_A8 = 7			; mode 2 ink is PF1 luminance on the paper hue: lum C on brown = orange
COL_TITLE_INK	= 11			; dark grey QUAKE letters in the bar
HINT_KEY_COL	= 11			; dark grey key glyphs
STORY_BG	= 0			; black around story panel
STORY_BOX	= 7			; yellow story panel
STORY_TEXT	= 0			; black story text
STORY_GREY_TOP	= BRAND_KEEP_ROWS + 1	; panel area starts one row below brand
MARK_CARET	= $1e			; !scr "^" — toggle monospaced span, not drawn
FONT_GAP	= 1			; pixels after each glyph
SPACE_W		= 4			; empty-glyph / space width
MENU_FONT	= uifont_udgs + 32 * 8	; ASCII space; init_font_tabs scans 96 glyphs

NM_BACK		= 256 - 66
NM_START	= 256 - 10
NM_ORDER	= 256 - 3
NM_CTRL		= 256 - 4
NM_HELP		= 256 - 5
NM_CREDITS	= 256 - 7
NM_JUKE		= 256 - 8
NM_QUIT		= 256 - 6

UI_UP		= 1
UI_DOWN		= 2
UI_LEFT		= 4
UI_RIGHT	= 8
UI_SELECT	= 16
UI_ESC		= 32

ptr_l		= $fb
ptr_h		= $fc
ui_str_l	= $f9
ui_str_h	= $fa
ptr_r_l		= $f5			; bitmap cell to the right of ptr
ptr_r_h		= $f6
gptr_l		= $f7			; current glyph (8 bytes)
gptr_h		= $f8
tmp0		= $02
tmp1		= $03
tmp2		= $04
tmp3		= $05
tmp4		= $06
tmp5		= $07
aux_l		= $fd
aux_h		= $fe
; mouse_en is $cd in mem.asm. $38 is dt_ms once GAME is running.

*= LOCODE_BASE
	jmp run_menu

run_menu

	sei

	jsr set_video_ms
	jsr init_font_tabs
	jsr init_menu_vic
	lda #0
	sta menu_id
	sta menu_item
	sta menu_stack_d
	sta menu_can_ret
	sta hint_spr_en
	sta cursor_spr_en
	sta cursor_frame
	sta cursor_tick
	sta menu_mux_phase
	sta menu_raster_en

	jsr copy_menu_sprites
!if  JUKEBOX {
	jsr sync_juke_title
}
	jsr menu_sfx_init
	jsr detect_mouse
	jsr clear_screen_all
	jsr draw_brand
	jsr sync_vol_strings
	jsr sync_mouse_string
	lda game_complete
	cmp #1
	bne .rm_menu
	lda #0
	sta game_complete
	jsr show_ending_pages
.rm_menu
	jsr draw_menu
.rm_loop
	jsr ui_read_keys
	jsr wait_frame

	lda #UI_UP
	and ui_pressed
	beq .rm_nou
	jsr menu_move_up
.rm_nou
	lda #UI_DOWN
	and ui_pressed
	beq .rm_nod
	jsr menu_move_down
.rm_nod
	lda menu_id
	cmp #3
	bne .rm_nov
	jsr menu_vol_input
.rm_nov
	lda #UI_ESC
	and ui_pressed
	beq .rm_noe
	jsr menu_esc
.rm_noe
	lda #UI_SELECT
	and ui_pressed
	beq .rm_acted
	jsr menu_select
	bcs .rm_done
.rm_acted
	lda ui_pressed
	beq .rm_loop
.rm_rel
	jsr wait_frame
	jsr ui_read_keys
	lda ui_keys
	bne .rm_rel
	jmp .rm_loop
.rm_done
	jsr menu_sfx_done

	jmp a8_menu_exit
menu_move_up
	lda menu_item
	sta menu_prev
	tax
	dex
	bpl .mmu
	ldx menu_size
	dex
.mmu
	stx menu_item
	jmp update_selection

menu_move_down
	lda menu_item
	sta menu_prev
	tax
	inx
	cpx menu_size
	bcc .mmd
	ldx #0
.mmd
	stx menu_item
	jmp update_selection

; Repaint only old + new rows (no clear / full redraw)
update_selection

	jsr a8_cursor_erase

	ldx menu_prev
	stx tmp4
	jsr draw_menu_item
	ldx menu_item
	stx tmp4
	jsr draw_menu_item

	jsr a8_stamp_cursor

	rts

menu_esc
	lda menu_stack_d
	beq .me_rts
	tax
	dex
	stx menu_stack_d
	lda menu_stk_m,x
	sta menu_id
	lda menu_stk_i,x
	sta menu_item
	jsr draw_menu
.me_rts
	rts

menu_vol_input
	lda menu_item
	beq .mvi_vol
	cmp #1
	bne .mvi_o
	lda #UI_RIGHT
	ora #UI_LEFT
	and ui_pressed
	beq .mvi_o
	jmp mouse_toggle
.mvi_vol
	lda #UI_RIGHT
	and ui_pressed
	bne .mvi_i
	lda #UI_LEFT
	and ui_pressed
	beq .mvi_o
	jmp vol_fx_dec
.mvi_i
	jmp vol_fx_inc
.mvi_o
	rts

vol_fx_inc
	inc effects_vol
	lda effects_vol
	and #15
	sta effects_vol
	jmp sync_redraw
vol_fx_dec
	dec effects_vol
	lda effects_vol
	and #15
	sta effects_vol
sync_redraw
	jsr sync_vol_strings
	jsr sync_mouse_string
	ldx menu_item
	stx tmp4
	jmp draw_menu_item

detect_mouse
	rts

mouse_toggle
	lda mouse_en
	eor #1
	sta mouse_en
	jmp sync_redraw

sync_mouse_string
	ldx #2
	lda mouse_en
	bne .sms_on
.sms_off
	lda str_moff,x
	sta str_mouse_bit,x
	dex
	bpl .sms_off
	rts
.sms_on
	lda str_mon,x
	sta str_mouse_bit,x
	dex
	bpl .sms_on
	rts

str_mon		!scr "On "
str_moff	!scr "Off"

sync_vol_strings
	lda #<str_fx_vol
	sta ptr_l
	lda #>str_fx_vol
	sta ptr_h
	ldx #15
	lda effects_vol
	jmp write_vol2

write_vol2
	sta tmp0
	txa
	tay
	lda tmp0
	cmp #10
	bcc .wv1
	lda #'1'
	sta (ptr_l),y
	iny
	lda tmp0
	sec
	sbc #10
	clc
	adc #'0'
	sta (ptr_l),y
	rts
.wv1
	lda #' '
	sta (ptr_l),y
	iny
	lda tmp0
	clc
	adc #'0'
	sta (ptr_l),y
	rts

menu_select
	lda menu_id
	asl
	asl
	asl
	clc
	adc menu_item
	tax
	lda next_menu,x
	sta tmp0

	cmp #NM_BACK
	bne .ms_nb
	jsr menu_esc
	jmp .ms_st
.ms_nb
	lda tmp0
	cmp #NM_START
	bne .ms_nv
	lda menu_id
	cmp #2				; skill menu
	beq .ms_go
	jmp .ms_st
.ms_go
	lda menu_item
	sta difficulty
	jsr menu_raster_off

	lda #0
	sta $d400				; DMA off through the pause

	jsr clear_screen_all
	ldx #20
	jsr wait_frames_x
	sec
	rts
.ms_nv
	lda tmp0
	bmi .ms_tx
; same-menu nop (volume) or mouse toggle
	cmp menu_id
	bne .ms_ne
	cmp #3
	bne .ms_stay
	lda menu_item
	cmp #1
	bne .ms_stay
	jsr mouse_toggle
.ms_stay
	jmp .ms_st
.ms_ne
	bcc .ms_po
	ldx menu_stack_d
	lda menu_id
	sta menu_stk_m,x
	lda menu_item
	sta menu_stk_i,x
	inx
	stx menu_stack_d
	lda #0
	sta menu_item
	lda tmp0
	sta menu_id
	cmp #2					; skill: cursor starts on Hard as Nails
	bne .ms_nsk
	lda #1
	sta menu_item
.ms_nsk
	lda menu_id
	cmp #4					; Jukebox: cursor starts on the playing track
	bne .ms_nj
	lda music_track
	sta menu_item
.ms_nj
	jsr draw_menu
	jmp .ms_st
.ms_po
	ldx menu_stack_d
	dex
	stx menu_stack_d
	lda menu_stk_i,x
	sta menu_item
	lda tmp0
	sta menu_id
	jsr draw_menu
	jmp .ms_st
.ms_tx
	lda tmp0
	cmp #NM_ORDER
	beq .ms_ord
	cmp #NM_CTRL
	beq .ms_ctl
	cmp #NM_HELP
	beq .ms_hlp
	cmp #NM_CREDITS
	beq .ms_crd
	cmp #NM_QUIT
	beq quit_to_basic
	cmp #NM_JUKE
	beq .ms_juke
	jmp .ms_st
.ms_juke
!if  JUKEBOX {
	lda menu_item
	cmp music_track
	beq .ms_st				; already playing
	jsr jukebox_select			; ends in draw_menu; carry must be clear
}
	jmp .ms_st
.ms_ord
	lda #<order_text
	ldy #>order_text
	jsr show_text_screen
	jmp .ms_ret
.ms_ctl
	lda #<control_text
	ldy #>control_text
	jsr show_text_screen
	jmp .ms_ret
.ms_hlp
!if  MENU_HELP_ENDINGS {
	jsr show_ending_pages
} else {
	ldx #0
.ms_rt
	txa
	pha
	lda readthis_lo,x
	ldy readthis_hi,x
	jsr show_story_screen
	pla
	tax
	inx
	cpx #READTHIS_PAGES
	bne .ms_rt
}
	jmp .ms_ret
.ms_crd
	ldx #0
.ms_cr
	txa
	pha
	lda credits_lo,x
	ldy credits_hi,x
	jsr show_text_screen
	pla
	tax
	inx
	cpx #CREDITS_PAGES
	bne .ms_cr
.ms_ret
	jsr draw_menu
.ms_st
	clc
	rts

; Warm-start BASIC → READY.
quit_to_basic

	jmp a8_quit
next_menu
!if  JUKEBOX {
	!byte 1, 3, NM_CTRL, NM_HELP, NM_CREDITS, 4, NM_QUIT, 0
} else {
	!byte 1, 3, NM_CTRL, NM_HELP, NM_CREDITS, NM_QUIT, 0, 0
}
	!byte 2, NM_ORDER, NM_ORDER, NM_ORDER, NM_BACK, 0, 0, 0
	!byte NM_START, NM_START, NM_START, NM_BACK, 0, 0, 0, 0
	!byte 3, 3, NM_BACK, 0, 0, 0, 0, 0
	!byte NM_JUKE, NM_JUKE, NM_JUKE, NM_BACK, 0, 0, 0, 0

menu_sizes
	!byte 7 - (1 - JUKEBOX), 5, 4, 3, 4

; --- drawing ---------------------------------------------------------------
draw_menu
	lda #COL_MAIN
	sta clear_bg
	jsr menu_blank
	jsr clear_screen

	ldx menu_id
	lda menu_sizes,x
	sta menu_size

	jsr calc_box
	jsr draw_section_title
	lda #COL_BOX
	sta cell_bg
	jsr fill_option_box

	ldx #0
.dm_l
	stx tmp4
	jsr draw_menu_item
	ldx tmp4
	inx
	cpx menu_size
	bcc .dm_l

	jsr draw_hint
!if  JUKEBOX {
	jsr draw_track_credit
}
	lda #1
	sta cursor_spr_en

	jsr a8_stamp_cursor

	jmp menu_unblank

; Jukebox only: "Tracks by Mandy Kane" one blank row under the option box.
draw_track_credit
	lda menu_id
	cmp #4
	beq .dtc
	rts
.dtc
	lda #COL_MAIN
	sta cell_bg
	lda #TEXT_COL
	sta ui_text_col
	lda box_top
	clc
	adc menu_size
	adc #BOX_VGAP
	adc #BOX_VGAP
	adc #1
	tax
	lda #<str_track_credit
	ldy #>str_track_credit
	jmp print_centered

; Title two lines above the box. Empty string (main menu) = no heading.
draw_section_title
	ldy menu_id
	lda section_lo,y
	sta ui_str_l
	lda section_hi,y
	sta ui_str_h
	ldy #0
	lda (ui_str_l),y
	bne .dst_go
	rts
.dst_go
	lda box_top
	sec
	sbc #2
	tax
	lda #COL_MAIN
	sta cell_bg
	lda #TITLE_COL
	sta ui_text_col
	lda ui_str_l
	ldy ui_str_h
	jmp print_centered

; Key sprites + "move / adjust / select" on HINT_ROW.
draw_hint

	jmp a8_draw_hint
hint_print_px
	sta ui_str_l
	sty ui_str_h
	lda hint_px
	tax
	and #7
	sta pr_shift
	txa
	lsr
	lsr
	lsr
	sta pr_col
	ldx #HINT_ROW
	stx pr_row
	lda #0
	sta pr_mono
	jmp print_go

; box_top, box_left, box_width from menu strings
calc_box
	lda #0
	sta pix_max_l
	sta pix_max_h
	ldx #0
.cb_i
	stx tmp4
	lda menu_id
	asl
	asl
	asl
	clc
	adc tmp4
	tay
	lda menu_str_lo,y
	sta ui_str_l
	lda menu_str_hi,y
	sta ui_str_h
	jsr str_pix_len
	lda pr_len_h
	cmp pix_max_h
	bcc .cb_n
	bne .cb_u
	lda pr_len
	cmp pix_max_l
	bcc .cb_n
.cb_u
	lda pr_len
	sta pix_max_l
	lda pr_len_h
	sta pix_max_h
.cb_n
	ldx tmp4
	inx
	cpx menu_size
	bcc .cb_i
	; text_cells = ceil(max_pix / 8)
	lda pix_max_l
	clc
	adc #7
	sta pix_max_l
	lda pix_max_h
	adc #0
	lsr
	ror pix_max_l
	lsr
	ror pix_max_l
	lsr
	ror pix_max_l
	; Center option *text* on screen; spinning Q sits left with CURSOR_GAP.
	lda #40
	sec
	sbc pix_max_l			; text_cells
	lsr
	sta tmp3				; text column
	sec
	sbc #CURSOR_CELLS + CURSOR_GAP		; cursor col
	sec
	sbc #BOX_PAD
	clc
	adc #1					; nudge box one column right
	sta box_left
	lda pix_max_l
	clc
	adc #CURSOR_CELLS			; cursor slot; text is 8px closer than CURSOR_GAP
	adc #BOX_PAD
	adc #BOX_PAD
	sta box_width
	; Vertically center box (items + top/bottom gaps) below bar
	lda menu_size
	clc
	adc #BOX_VGAP
	adc #BOX_VGAP
	sta tmp5				; box_height
	lda #BADGE_TOP + MENU_LOGO_ROWS + 1
	sta box_top
	lda #HINT_ROW
	sec
	sbc tmp5				; last valid box_top
	sec
	sbc box_top
	bcc .cb_ok
	lsr
	clc
	adc box_top
	sta box_top
.cb_ok
	rts

draw_menu_item
	lda box_top
	clc
	adc #BOX_VGAP
	adc tmp4
	sta pr_row

	lda #COL_BOX
	sta cell_bg

	; Blank box row (bitmap OR would smear proportional glyphs on redraw)
	lda box_left
	ldx pr_row
	jsr bmp_cell_addr
	ldy #0
.di_clr
	jsr bmp_blank_cell_y
	iny
	cpy box_width
	bcc .di_clr

	lda tmp4
	cmp menu_item
	beq .di_h
	lda #TEXT_COL
	sta ui_text_col
	jmp .di_g
.di_h
	lda #HILITE_COL
	sta ui_text_col
	; Spinning Q: column is box_left+BOX_PAD. VIC X = 24 + col*8.
	lda box_left
	clc
	adc #BOX_PAD

	sec
	sbc #1					; monospace label: leave one blank cell

	sta cursor_col
	lda pr_row
	sta cursor_row
	lda box_left
	clc
	adc #BOX_PAD
	asl
	asl
	asl
	clc
	adc #24
	sta cursor_spr_x
	lda pr_row
	asl
	asl
	asl
	clc
	adc #44				; 6px above char row (was 50)
	sta cursor_spr_y
.di_g
	lda menu_id
	asl
	asl
	asl
	clc
	adc tmp4
	tax
	lda menu_str_lo,x
	sta ui_str_l
	lda menu_str_hi,x
	sta ui_str_h
	lda box_left
	clc
	adc #BOX_PAD
	adc #CURSOR_CELLS			; 8px closer to Q than CURSOR_CELLS+CURSOR_GAP
	ldx pr_row
	jmp print_at

; A/Y = text blob: body lines\0..., empty\0 ends.
; Brand bar + brown box; ^text^ = monospaced. Any key returns.
show_text_screen
	sta txt_ptr_l
	sty txt_ptr_h
	lda #COL_MAIN
	sta clear_bg
	lda #COL_BOX
	sta cell_bg

	lda #COL_PANEL_INK_A8

	sta ui_text_col
	lda #1
	sta pr_setcol
	jmp .sts_body

; Read This! / endings: black surround, yellow panel, black text. Restores COL_MAIN.
show_ending_pages
	ldx #0
.sep
	txa
	pha
	lda ending_lo,x
	ldy ending_hi,x
	jsr show_story_screen
	pla
	tax
	inx
	cpx #ENDING_PAGES
	bne .sep
	rts

show_story_screen
	sta txt_ptr_l
	sty txt_ptr_h
	lda #STORY_BG
	sta clear_bg


	lda #STORY_BOX				; yellow panel
	sta cell_bg
	lda #0					; black text
	sta ui_text_col
	lda #0
	sta pr_setcol

	jsr .sts_body
	lda #1
	sta pr_setcol
	lda #COL_MAIN
	sta clear_bg
	rts

.sts_body
	jsr menu_blank
	jsr clear_screen
	jsr calc_text_box
	jsr apply_story_layout
	jsr fill_option_box
	ldx #0
.st_l
	stx tmp4
	ldy #0
	lda (ui_str_l),y
	beq .st_wait
	lda box_top
	clc
	adc #BOX_VGAP
	adc tmp4
	tax

	lda box_left

	jsr print_marked
	jsr str_skip
	ldx tmp4
	inx
	cpx menu_size
	bcc .st_l
.st_wait
	jsr menu_unblank
	jmp wait_any_key

; Size box from body lines. Leaves ui_str at first line.
calc_text_box
	lda txt_ptr_l
	sta ui_str_l
	lda txt_ptr_h
	sta ui_str_h
	lda #0
	sta pix_max_l
	sta pix_max_h
	sta tmp4				; line count
.ct_l
	ldy #0
	lda (ui_str_l),y
	beq .ct_done
	jsr marked_str_pix_len
	lda pr_len_h
	cmp pix_max_h
	bcc .ct_n
	bne .ct_u
	lda pr_len
	cmp pix_max_l
	bcc .ct_n
.ct_u
	lda pr_len
	sta pix_max_l
	lda pr_len_h
	sta pix_max_h
.ct_n
	jsr str_skip
	inc tmp4
	bne .ct_l
.ct_done
	lda tmp4
	sta menu_size
	; text_cells = ceil(max_pix / 8)
	lda pix_max_l
	clc
	adc #7
	sta pix_max_l
	lda pix_max_h
	adc #0
	lsr
	ror pix_max_l
	lsr
	ror pix_max_l
	lsr
	ror pix_max_l

	lda #40
	sec
	sbc pix_max_l
	lsr
	sta box_left			; 38 chars → column 1, one spare each side
	lda pix_max_l
	sta box_width
	jmp .ct_vert

	lda pix_max_l
	clc
	adc #BOX_PAD
	adc #BOX_PAD
	adc #1					; extra cell; last glyph can spill
	sta box_width
	lda #40
	sec
	sbc box_width
	lsr
	sta box_left
.ct_vert
	lda menu_size
	clc
	adc #BOX_VGAP
	adc #BOX_VGAP
	sta tmp5
	lda #BADGE_TOP + MENU_LOGO_ROWS + 1
	sta box_top
	lda #HINT_ROW
	sec
	sbc tmp5
	sec
	sbc box_top
	bcc .ct_ok
	lsr
	clc
	adc box_top
	sta box_top
.ct_ok
	lda txt_ptr_l
	sta ui_str_l
	lda txt_ptr_h
	sta ui_str_h
	rts

; Story pages: leave one black row under the brand, center panel in brown.
apply_story_layout
	lda clear_bg
	cmp #STORY_BG
	bne .asl_rts
	ldx #0
	lda #COL_MAIN

	lda #BRAND_KEEP_ROWS
	sta pr_row
	lda #COL_MAIN
	jsr a8_note_col

	lda menu_size
	clc
	adc #BOX_VGAP
	adc #BOX_VGAP
	sta tmp5				; box height

	lda #24

	sec
	sbc #STORY_GREY_TOP
	sec
	sbc tmp5				; spare rows in grey
	bcc .asl_min
	lsr
	clc
	adc #STORY_GREY_TOP
	sta box_top
	rts
.asl_min
	lda #STORY_GREY_TOP
	sta box_top
.asl_rts
	rts

; --- hires bitmap (proportional Quake font) --------------------------------
init_menu_vic

	jmp a8_init_vic
clear_screen

	jmp a8_clear_screen
clear_screen_all

	jmp a8_clear_all
fill_top_bar
	ldx #BAR_TOP
.ftb_r
	stx tmp4
	lda #0
	ldx tmp4
	jsr bmp_cell_addr
	ldy #39
.ftb_c
	jsr bmp_blank_cell_y
	lda #COL_BAR

	jsr a8_note_col

	dey
	bpl .ftb_c
	ldx tmp4
	inx
	cpx #BAR_TOP + BAR_ROWS
	bcc .ftb_r
	rts

; Dark-grey QUAKE on the black bar (white highlights baked into the bitmap).
blit_menu_title

	jmp a8_blit_title
draw_brand
	jsr fill_top_bar
	jmp blit_menu_title

copy_menu_sprites

	jmp a8_setup_pm
fill_option_box
	lda pr_setcol
	bne .fob_bg
	lda ui_text_col
	asl
	asl
	asl
	asl
	ora cell_bg
	jmp .fob_sv
.fob_bg
	lda cell_bg
.fob_sv
	sta tmp0
	lda menu_size
	clc
	adc #BOX_VGAP
	adc #BOX_VGAP
	sta tmp5
	ldx #0
.fob_r
	stx tmp4
	txa
	clc
	adc box_top
	tax
	lda box_left
	jsr bmp_cell_addr
	ldy #0
.fob_c
	lda tmp0

	jsr a8_note_col

	iny
	cpy box_width
	bcc .fob_c
	ldx tmp4
	inx
	cpx tmp5
	bcc .fob_r
	rts

; Blank 8 bitmap bytes for cell Y relative to ptr (col base). Saves Y.
bmp_blank_cell_y

	jmp a8_blank_cell
bmp_cell_addr

	jmp a8_bmp_cell_addr
print_centered
	sta ui_str_l
	sty ui_str_h
	stx pr_row
	jsr str_pix_len
	lda #<320
	sec
	sbc pr_len
	sta pix_max_l
	lda #>320
	sbc pr_len_h
	bcs .pc
	lda #0
	sta pr_shift
	sta pr_mono
	sta pr_col
	ldx pr_row
	jmp print_go
.pc
	lsr
	ror pix_max_l
	lda pix_max_l
	tax
	and #7
	sta pr_shift
	txa
	lsr
	lsr
	lsr
	ldx pr_row
	sta pr_col
	stx pr_row
	lda #0
	sta pr_mono
	jmp print_go

print_at
	sta pr_col
	stx pr_row
	lda #0
	sta pr_shift
	sta pr_mono
print_go
	ldy #0
.pa
	lda (ui_str_l),y
	beq .pa_d
	sty pr_si
	jsr bmp_put_scr
	ldy pr_si
	iny
	bne .pa
.pa_d
	rts

; ^ toggles monospaced; A=col X=row.
print_marked
	sta pr_col
	stx pr_row
	lda #0
	sta pr_shift
	sta pr_mono
	ldy #0
.pm
	lda (ui_str_l),y
	beq .pm_d
	cmp #MARK_CARET
	bne .pm_ch
	lda pr_mono
	eor #1
	sta pr_mono
	beq .pm_sk				; left mono
	lda pr_shift
	beq .pm_sk
	inc pr_col				; snap to next cell
	lda #0
	sta pr_shift
.pm_sk
	iny
	bne .pm
.pm_ch
	sty pr_si
	jsr bmp_put_scr
	ldy pr_si
	iny
	bne .pm
.pm_d
	rts

; A = !scr byte → 16-bit shifted OR blit at pr_col/pr_shift.
bmp_put_scr
	cmp #MARK_CARET
	bne .bps_go
	rts
.bps_go

	ldx pr_row
	cpx #A8_TEXT0
	bcc .bps_bmp
	jmp a8_text_putc
.bps_bmp

	jsr scr_to_font
	sta ft_idx
	ldx pr_mono
	bne .bps_mono
	tax
	lda glyph_w_tab,x
	bne .bps_ink
	lda #SPACE_W
	sta glyph_w
	jmp bmp_advance
.bps_ink
	sta glyph_w
	jsr font_set_gptr
	jmp .bps_draw
.bps_mono
	lda #8
	sta glyph_w
	jsr font_set_gptr
.bps_draw
	jsr bmp_sync_ptr
	lda #0
	sta ft_spill
	tay
	lda pr_setcol
	beq .bps_pick
	lda ui_text_col
	asl
	asl
	asl
	asl
	ora cell_bg
	sta ft_color

	jsr a8_note_col

.bps_pick
	lda pr_shift
	bne .bps_sh
	jmp blit_z
.bps_sh
	tax
	lda shift_lo,x
	sta do_shift_j + 1
	lda shift_hi,x
	sta do_shift_j + 2
	jmp blit_nd

; pr_shift = 0: OR 8 rows, no right cell.
blit_z

	jmp a8_blit_z
blit_nd

	jmp a8_blit_nd
do_shift
	ldx #0
	stx ft_right
do_shift_j
	jmp shift0

shift0
	rts
shift1
	lsr
	ror ft_right
	rts
shift2
	lsr
	ror ft_right
	lsr
	ror ft_right
	rts
shift3
	lsr
	ror ft_right
	lsr
	ror ft_right
	lsr
	ror ft_right
	rts
shift4
	lsr
	ror ft_right
	lsr
	ror ft_right
	lsr
	ror ft_right
	lsr
	ror ft_right
	rts
shift5
	lsr
	ror ft_right
	lsr
	ror ft_right
	lsr
	ror ft_right
	lsr
	ror ft_right
	lsr
	ror ft_right
	rts
shift6
	lsr
	ror ft_right
	lsr
	ror ft_right
	lsr
	ror ft_right
	lsr
	ror ft_right
	lsr
	ror ft_right
	lsr
	ror ft_right
	rts
shift7
	lsr
	ror ft_right
	lsr
	ror ft_right
	lsr
	ror ft_right
	lsr
	ror ft_right
	lsr
	ror ft_right
	lsr
	ror ft_right
	lsr
	ror ft_right
	rts

shift_lo
	!byte <shift0, <shift1, <shift2, <shift3
	!byte <shift4, <shift5, <shift6, <shift7
shift_hi
	!byte >shift0, >shift1, >shift2, >shift3
	!byte >shift4, >shift5, >shift6, >shift7

bmp_advance
	lda glyph_w
	ldx pr_mono
	bne .ba_g
	clc
	adc #FONT_GAP
.ba_g
	clc
	adc pr_shift
	sta pr_shift
	lsr
	lsr
	lsr
	clc
	adc pr_col
	sta pr_col
	lda pr_shift
	and #7
	sta pr_shift
	rts

; ptr/aux follow pr_col/pr_row. Step +8 when the column advances.
bmp_sync_ptr

	jmp .sp_re
.sp_re
	lda pr_col
	ldx pr_row
	jsr bmp_cell_addr
	lda pr_col
	sta ft_cell
	lda pr_row
	sta ft_row
sync_ptr_r
	lda pr_col
	cmp #39
	bcc .spr_ok
	lda #<ft_sink
	sta ptr_r_l
	lda #>ft_sink
	sta ptr_r_h
	rts
.spr_ok
	lda ptr_l
	clc

	adc #1

	sta ptr_r_l
	lda ptr_h
	adc #0
	sta ptr_r_h
	rts

glyph_lda
	lda $ffff,y
	rts

; ft_idx → gptr (left-justified cache, or raw font if mono)
font_set_gptr
	lda #0
	sta ft_hi
	lda ft_idx
	asl
	rol ft_hi
	asl
	rol ft_hi
	asl
	rol ft_hi
	clc
	ldx pr_mono
	bne .fss_raw
	adc #<glyph_lj
	sta gptr_l
	lda ft_hi
	adc #>glyph_lj
	sta gptr_h
	rts
.fss_raw
	adc #<MENU_FONT
	sta gptr_l
	lda ft_hi
	adc #>MENU_FONT
	sta gptr_h
	rts

init_font_tabs
	lda #<MENU_FONT
	sta glyph_lda + 1
	lda #>MENU_FONT
	sta glyph_lda + 2
	lda #<glyph_lj
	sta gptr_l
	lda #>glyph_lj
	sta gptr_h
	ldx #0
.ift
	stx ft_idx
	jsr font_scan
	ldx ft_idx
	lda glyph_w
	sta glyph_w_tab,x
	ldy #0
.ift_c
	jsr glyph_lda
	ldx glyph_lead
	beq .ift_s
.ift_a
	asl
	dex
	bne .ift_a
.ift_s
	sta (gptr_l),y
	iny
	cpy #8
	bne .ift_c
	lda gptr_l
	clc
	adc #8
	sta gptr_l
	bcc .ift_g
	inc gptr_h
.ift_g
	lda glyph_lda + 1
	clc
	adc #8
	sta glyph_lda + 1
	bcc .ift1
	inc glyph_lda + 2
.ift1
	ldx ft_idx
	inx
	cpx #96
	bne .ift
	lda #$ff
	sta ft_row
	rts

; Occupancy of glyph_lda → glyph_lead, glyph_w (0 = empty / space)
font_scan
	lda #0
	sta ft_occ
	ldy #7
.fs_or
	jsr glyph_lda
	ora ft_occ
	sta ft_occ
	dey
	bpl .fs_or
	lda ft_occ
	bne .fs_ink
	lda #0
	sta glyph_lead
	sta glyph_w
	rts
.fs_ink
	ldx #0
.fs_lead
	lda ft_occ
	bmi .fs_gotl
	asl ft_occ
	inx
	cpx #8
	bcc .fs_lead
.fs_gotl
	stx glyph_lead
	ldx #0
	lda ft_occ
.fs_w
	inx
	asl
	bne .fs_w
	stx glyph_w
	rts

; !scr byte → font index (ascii-32). 1..26 = a..z; $20+ = ASCII.
scr_to_font
	cmp #27
	bcs .stf_asc
	cmp #1
	bcc .stf_sp
	clc
	adc #'a' - 1			; screencode → lowercase ASCII
	bne .stf_idx
.stf_asc
	cmp #' '
	bcc .stf_sp
	cmp #128
	bcc .stf_idx
.stf_sp
	lda #' '
.stf_idx
	sec
	sbc #' '
	rts

str_len
	ldy #0
.sl
	lda (ui_str_l),y
	beq .sl_d
	iny
	bne .sl
.sl_d
	tya
	rts

; Pixel width of ui_str (incl. FONT_GAP per char) → pr_len / pr_len_h
str_pix_len

	jmp a8_pix_len
marked_str_pix_len

	jmp a8_pix_len
pix_snap_len
	lda pr_len
	and #7
	beq .psn_r
	sta ft_hi
	lda #8
	sec
	sbc ft_hi
	clc
	adc pr_len
	sta pr_len
	bcc .psn_r
	inc pr_len_h
.psn_r
	rts

; Advance ui_str past current NUL-terminated string.
str_skip
	ldy #0
.ssk
	lda (ui_str_l),y
	beq .ssk_d
	iny
	bne .ssk
.ssk_d
	iny
	tya
	clc
	adc ui_str_l
	sta ui_str_l
	bcc .ssk_c
	inc ui_str_h
.ssk_c
	rts

; Hide full redraws: DEN off fills the screen with $d020. Sprites off.
; Menus/credits: black border. Story: black (STORY_BG).
menu_blank

	jmp a8_menu_blank
menu_unblank

	jmp a8_menu_unblank
wait_frame

	jmp a8_wait_frame
wait_frames_x
.wf
	jsr wait_frame
	dex
	bne .wf
	rts

wait_key
.wk_up
	jsr ui_read_keys
	lda ui_keys
	bne .wk_up
.wk_dn
	jsr ui_read_keys
	lda ui_keys
	beq .wk_dn
.wk_rel
	jsr ui_read_keys
	lda ui_keys
	bne .wk_rel
	rts

; Any key (full keyboard matrix) — text screens.
; Wait for release + a few quiet frames so Return-to-enter doesn't bounce-dismiss.
; wait_frame each poll so the WIP sprite keeps bouncing.
wait_any_key

	jmp a8_wait_any
ui_read_keys

	jmp a8_ui_read
menu_id		!byte 0
menu_item	!byte 0
menu_prev	!byte 0
menu_size	!byte 0
menu_stack_d	!byte 0
menu_can_ret	!byte 0
hint_spr_en	!byte 0
cursor_spr_en	!byte 0
cursor_frame	!byte 0
cursor_tick	!byte 0
menu_mux_phase	!byte 0
menu_raster_en	!byte 0
music_en	!byte 0
music_ok	!byte 0				; 1 = MUSn resident at $9000
music_track	!byte 0				; 0..2 playing / selected
music_zp	!fill MUSIC_ZP_N, 0		; player's $f0-$f7 while the menu owns ZP
hint_spr_x	!byte 0, 0, 0
cursor_spr_x	!byte 0
cursor_spr_y	!byte 0
cursor_col	!byte 0
cursor_row	!byte 0
hint_tx		!byte 0, 0, 0
hint_px		!byte 0
hint_w0		!byte 0
hint_w1		!byte 0
hint_w2		!byte 0
menu_stk_m	!byte 0, 0, 0
menu_stk_i	!byte 0, 0, 0
box_top		!byte 0
box_left	!byte 0
box_width	!byte 0
ui_keys		!byte 0
ui_old		!byte 0
ui_pressed	!byte 0
ui_text_col	!byte 0
pr_row		!byte 0
pr_col		!byte 0
pr_shift	!byte 0
pr_mono		!byte 0
pr_setcol	!byte 1				; 0 = ink only (story panel precoloured)
pr_si		!byte 0
pr_len		!byte 0
pr_len_h	!byte 0
glyph_lead	!byte 0
glyph_w		!byte 0
ft_cell		!byte 0
ft_row		!byte $ff
ft_color	!byte 0
ft_occ		!byte 0
ft_hi		!byte 0
ft_idx		!byte 0
ft_src		!byte 0
ft_left		!byte 0
ft_right	!byte 0
ft_spill	!byte 0
pix_max_l	!byte 0
pix_max_h	!byte 0
txt_ptr_l	!byte 0
txt_ptr_h	!byte 0
cell_bg		!byte 0
clear_bg	!byte COL_MAIN
glyph_w_tab	!fill 96, 0
glyph_lj	!fill 768, 0			; lead-justified copies of MENU_FONT
ft_sink		!fill 8, 0			; dummy right-cell when col=39

str_track_credit !scr "Tracks by Mandy Kane",0
str_hint_move	!scr "move",0
str_hint_adjust	!scr "adjust",0
str_hint_select	!scr "select",0
str_new_game	!scr "New Game",0
str_sound	!scr "Options",0
str_juke	!scr "Jukebox",0
str_control	!scr "Controls",0
str_read_this	!scr "Read This!",0
str_credits	!scr "Credits",0
str_quit	!scr "Quit",0
str_back	!scr "Back",0
str_trk1	!scr "Searching for Quake",0
str_trk2	!scr "Through the Slipgate",0
str_trk3	!scr "Realms of Chthon",0
str_e1		!scr "Dimension of the Doomed",0
str_e2		!scr "The Realm of Black Magic",0
str_e3		!scr "The Netherworld",0
str_e4		!scr "The Elder World",0
str_fx_vol	!scr "Effects Volume 15",0

str_mouse	!scr "ST mouse (port 2) "

str_mouse_bit	!scr "Off",0
str_flesh	!scr "Flesh and Bone",0
str_nails	!scr "Hard as Nails",0
str_uv		!scr "Nightmare",0

str_sec_main	!byte 0				; main: no heading, box is already centered
str_sec_new	!scr "Which episode to play?",0
str_sec_skill	!scr "Skill",0
str_sec_sound	!scr "Options",0
str_now1	!scr "Now playing: Searching for Quake",0
str_now2	!scr "Now playing: Through the Slipgate",0
str_now3	!scr "Now playing: Realms of Chthon",0

section_lo
	!byte <str_sec_main, <str_sec_new, <str_sec_skill, <str_sec_sound, <str_now1
section_hi
	!byte >str_sec_main, >str_sec_new, >str_sec_skill, >str_sec_sound, >str_now1

!source "menu_text.asm"

menu_str_lo
	!byte <str_new_game, <str_sound, <str_control, <str_read_this
!if  JUKEBOX {
	!byte <str_credits, <str_juke, <str_quit, 0
} else {
	!byte <str_credits, <str_quit, 0, 0
}
	!byte <str_e1, <str_e2, <str_e3, <str_e4
	!byte <str_back, 0, 0, 0
	!byte <str_flesh, <str_nails, <str_uv, <str_back
	!byte 0, 0, 0, 0
	!byte <str_fx_vol, <str_mouse, <str_back, 0
	!byte 0, 0, 0, 0
	!byte <str_trk1, <str_trk2, <str_trk3, <str_back
	!byte 0, 0, 0, 0
menu_str_hi
	!byte >str_new_game, >str_sound, >str_control, >str_read_this
!if  JUKEBOX {
	!byte >str_credits, >str_juke, >str_quit, 0
} else {
	!byte >str_credits, >str_quit, 0, 0
}
	!byte >str_e1, >str_e2, >str_e3, >str_e4
	!byte >str_back, 0, 0, 0
	!byte >str_flesh, >str_nails, >str_uv, >str_back
	!byte 0, 0, 0, 0
	!byte >str_fx_vol, >str_mouse, >str_back, 0
	!byte 0, 0, 0, 0
	!byte >str_trk1, >str_trk2, >str_trk3, >str_back
	!byte 0, 0, 0, 0

!source "menu_title.asm"
!source "menu_hint_spr.asm"
!source "menu_cursor_spr.asm"
!source "uifont_data.asm"

!source "menu_music.asm"

!source "a8menuhw.asm"
!source "a8music.asm"


end_menu = *

	!if  end_menu >= MUS_BSS {
		!error "Menu overlaps the music state / ring ($6F00-$7FFF, bitmap at $8000); end=$", end_menu
	}

