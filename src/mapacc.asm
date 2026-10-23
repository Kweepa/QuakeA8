; Packed-map SoA accessors.
;
; Field labels in map_bss.asm are 16-bit *pointers* (filled by bind_map),
; not the columns themselves. Never `lda en_x,x` / `sta room_bg,y` — that
; reads the pointer word in GAME BSS. Always these macros, or an explicit
; `lda (ptr),y` after setting a pointer from the bound table.
;
; Macros emit `lda $02id,x` (etc.) under a global smc_N label: operand lo =
; field id = (.fld-room_x)/2, hi = MAP_SMC_HI until LoadLevel patches both
; operand bytes to the bound column. mkreloc / genaimeta relocate only those
; labels. Do not execute the sites until after that patch.
;
; After GAME assemble, mkreloc.py must run before mkatr.py (see build-a8.bat).
!zone mapacc
!source "smc_tags.asm"

!macro lda_mx .fld {
	+smc_plant
	lda MAP_SMC_BASE + ((.fld - room_x) / 2),x
}
!macro sta_mx .fld {
	+smc_plant
	sta MAP_SMC_BASE + ((.fld - room_x) / 2),x
}
!macro cmp_mx .fld {
	+smc_plant
	cmp MAP_SMC_BASE + ((.fld - room_x) / 2),x
}
!macro adc_mx .fld {
	+smc_plant
	adc MAP_SMC_BASE + ((.fld - room_x) / 2),x
}
!macro sbc_mx .fld {
	+smc_plant
	sbc MAP_SMC_BASE + ((.fld - room_x) / 2),x
}
!macro ora_mx .fld {
	+smc_plant
	ora MAP_SMC_BASE + ((.fld - room_x) / 2),x
}
!macro and_mx .fld {
	+smc_plant
	and MAP_SMC_BASE + ((.fld - room_x) / 2),x
}
!macro eor_mx .fld {
	+smc_plant
	eor MAP_SMC_BASE + ((.fld - room_x) / 2),x
}
!macro ldy_mx .fld {
	+smc_plant
	ldy MAP_SMC_BASE + ((.fld - room_x) / 2),x
}
!macro ldx_mx .fld {
	+smc_plant
	lda MAP_SMC_BASE + ((.fld - room_x) / 2),x
	tax
}
!macro lda_my .fld {
	+smc_plant
	lda MAP_SMC_BASE + ((.fld - room_x) / 2),y
}
!macro sta_my .fld {
	+smc_plant
	sta MAP_SMC_BASE + ((.fld - room_x) / 2),y
}
!macro cmp_my .fld {
	+smc_plant
	cmp MAP_SMC_BASE + ((.fld - room_x) / 2),y
}
!macro adc_my .fld {
	+smc_plant
	adc MAP_SMC_BASE + ((.fld - room_x) / 2),y
}
!macro sbc_my .fld {
	+smc_plant
	sbc MAP_SMC_BASE + ((.fld - room_x) / 2),y
}
!macro ora_my .fld {
	+smc_plant
	ora MAP_SMC_BASE + ((.fld - room_x) / 2),y
}
!macro and_my .fld {
	+smc_plant
	and MAP_SMC_BASE + ((.fld - room_x) / 2),y
}
!macro eor_my .fld {
	+smc_plant
	eor MAP_SMC_BASE + ((.fld - room_x) / 2),y
}
!macro ldx_my .fld {
	+smc_plant
	ldx MAP_SMC_BASE + ((.fld - room_x) / 2),y
}
!macro ldy_my .fld {
	+smc_plant
	lda MAP_SMC_BASE + ((.fld - room_x) / 2),y
	tay
}

; Room slice: Y = room. X = first object of that room, sl_end = one past the last.
; Tables are room_<type>_o (nrooms+1 entries, objects baked room-sorted by genmap).
; Y is clobbered (+1). Loop bodies must not reach another slice user (sl_end).
!macro slice_x .tab {
	+lda_my .tab
	tax
	iny
	+lda_my .tab
	sta sl_end
}
