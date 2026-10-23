; Jukebox track switch. The menu ships one embedded POKEY tune (a8music.asm).
; JUKEBOX=0, so the switch below is not assembled.

!zone menu_music

; Atari: the one tune is embedded in the menu and played by a8music.asm.


; Jukebox is off by default (JUKEBOX in build_flags.asm). Nothing below is
; reachable from the menu while it is 0.
!if  JUKEBOX {
; A = track 0..2, menu IRQs live. Silences, reloads, restarts, repaints.
jukebox_select
	sta music_track

	jsr sync_juke_title
	jmp draw_menu

; Jukebox heading follows music_track (menu id 4).
sync_juke_title
	ldx music_track
	lda juke_now_lo,x
	sta section_lo + 4
	lda juke_now_hi,x
	sta section_hi + 4
	rts

juke_now_lo	!byte <str_now1, <str_now2, <str_now3
juke_now_hi	!byte >str_now1, >str_now2, >str_now3
}


