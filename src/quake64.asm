; Quake64 — portal-room maps + enemy poses loaded from disk


!cpu 6502

!to "game.prg", cbm

!source "build_flags.asm"

!source "mem.asm"
!source "zp.asm"
!source "map_counts.asm"
!source "mapacc.asm"
!if  ENEMY_PTR_N != ENEMY_NTYPES {
	!error "mem.asm ENEMY_PTR_N must equal ENEMY_NTYPES"
}

*= LOCODE_BASE
mod_quake
start
	sei
	cld
	ldx #$ff
	txs

	lda #$fe				; bit 0 clear: RAM under the OS
	sta $d301
	jsr a8_bind_tabs


	lda #0
	sta load_in_play
	jsr cheat_init
	lda $ba
	bne +
	lda #8
+
	sta load_device
	jsr install_reboot_stub
	lda #START_LEVEL
	sta level_num
	jsr LoadLevel
	bcc .start_ok
	jmp load_fail_hang
.start_ok
	jsr play_up1
	jsr init_weapon
	jsr play_up2

main
	jsr poll_quick_keys			; Shift-S save / Shift-L load; view stays blank until the next frame
	cld
!if  PROFILE = 1 {
	jsr prof_reset_frame
} else {
	lda #$ff
	sta mesh_vmask
}
	jsr wait_draw_free
	jsr clear_draw
!if  PROFILE = 1 {
	ldy #PROF_CLEAR
	jsr prof_add_bucket
}
	jsr draw_world
	jsr draw_enemies
	jsr draw_grenades
	jsr draw_explosion

	jsr stamp_view


	lda draw_buf
	sta show_buf
	jsr apply_show
	lda den_arm
	cmp #1				; hold until this frame is published
	bne .den_pub
	lda #2
	sta den_arm
.den_pub
	jsr prof_frame_sample
	jsr calc_frame_dt
	jsr update_hurt_flash
	jsr update_powerup
	jsr update_item_spin

	lda draw_buf
	eor #1
	sta draw_buf
	jsr set_draw_ptrs
	jsr read_input
	jsr apply_cheats
	jsr update_weapon
	jsr apply_move_world
	jsr maybe_room_palette
	jsr maybe_stream_room			; after movement, before the next draw
	jsr try_proximity
	jsr proc_update
	jsr crush_update
	jsr update_floor
	jsr update_fall
	jsr update_grenades
	jsr update_status
	jsr update_triggers
	jsr update_chthon_elec
	jsr enemies_update
!if  PROFILE = 1 {
	ldy #PROF_UPDATE
	jsr prof_add_bucket
}
	jsr hud_print
	jmp main

mod_vic

!source "a8vic.asm"

mod_irq

!source "a8irq.asm"

mod_profil
!source "profil.asm"
mod_hud
!source "hud.asm"
mod_math
!source "math.asm"
mod_util
!source "util.asm"
mod_line

!source "a8line.asm"

mod_fx
!source "fx.asm"
mod_grenade
!source "grenade.asm"
mod_playsound
!source "playsound.asm"
mod_pcsounds
!source "pcsounds.asm"
mod_weapon
!source "weapon.asm"

!source "a8stamp.asm"

mod_weapon_spr
!source "weapon_spr.asm"
mod_splat_spr
!source "splat_spr.asm"
mod_enemy_muzzle
!source "enemy_muzzle.asm"
mod_process
!source "process.asm"
mod_elevator
!source "elevator.asm"
mod_crusher
!source "crusher.asm"
mod_door
!source "door.asm"
mod_world
!source "world.asm"
mod_item_mesh
!source "item_mesh.asm"
mod_mesh
!source "mesh.asm"
mod_cube
!source "cube.asm"
mod_enemy
!source "enemy.asm"
mod_cheats
!source "cheats.asm"
mod_loader
!source "loader.asm"

!source "a8sio.asm"
!source "a8tabs.asm"
!source "a8reboot.asm"


!source "map_bss.asm"

!if  PROFILE = 1 {
casc_snap
	!fill 4, 0
prof_dt
	!fill 4, 0
prof_cy
	!fill PROF_NBUCKET * 4, 0
; Per-frame vertex totals (R/P/K stages)
nv_cnt
nv_rot
	!fill 2, 0
nv_proj
	!fill 2, 0
nv_clip
	!fill 2, 0
}

end_game = *
!if  end_game > HEAP_LIM {
	!error "game overlaps screen A at $C000; end=$", end_game
}

	!if  end_game > TAB_STAGE {
		!error "game overlaps tab staging; end=$", end_game
	}
	; heap_alloc fails when end_game >= HEAP_LIM-(map+prefix). E1M1 map is 2373.
	!if  end_game + LEVEL_PREFIX + 2373 >= HEAP_LIM {
		!error "game overlaps e1m1 heap; end=$", end_game
	}

