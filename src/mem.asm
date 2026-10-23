; Atari 800XL play map.
; Game PRG $0900. Heap grows down from HEAP_LIM. Bitmap A $C000, bitmap B $E000.
; $D000-$D7FF is I/O. Play state and alog/log sit at $D800-$DFFF, under bitmap B.
; $F000 sqt, $F800 UI font. a8_bind_tabs copies tab.prg from TAB_STAGE.
; Survives the GAME load: a8_pal_hue $06D5 (menu), video_ms $08F6, reboot stub
; $08F9, level_num $08FC, effects_vol/game_complete/difficulty $08FD-$08FF.
; mouse_en is ZP $cd.
; Low RAM through RB_CELL is the BSS ceiling (crusher, skeleton, cheats, mouse).

LOADER_BASE	= $0801
LOCODE_BASE	= $0900			; MENU overlay, then game
; $08F6 is video_ms (menu). $08F7-$08F8 are near_box_xz scratch during play.
RB_CELL		= $08F5
video_ms	= $08F6			; PAL 20 / NTSC 17, written by a8_music_start
nb_hi		= $08F7			; exclusive max of the axis under test
nb_lim		= $08F8			; Chebyshev range passed in A
REBOOT_STUB	= $08F9			; 3-byte JMP reboot_game (installed at start)
level_num	= $08FC			; 1..8 -> e1m1..e1m8
effects_vol	= $08FD			; menu SFX level 0..15
game_complete	= $08FE
difficulty	= $08FF			; menu skill 0..2 (Flesh / Nails / Nightmare)
; Mouse on/off. Not $38 — GAME uses that for dt_ms.
; init_irq / LoadLevel must not clear it.
mouse_en	= $cd

; Menu player scratch. The tune itself is in the menu image (a8music.asm).
MUSIC_ZP	= $f0
MUSIC_ZP_N	= 8

TAB_STAGING	= $8000			; offsets of the tab.prg payload
TAB_ALOG	= TAB_STAGING		; 512
TAB_LOG		= TAB_STAGING + 512	; 256
TAB_SIN		= TAB_STAGING + 768	; 320
TAB_INVZL	= TAB_STAGING + 1088	; 128
TAB_INVZH	= TAB_STAGING + 1216	; 128
TAB_BYTES	= 1344

COL_BORDER	= 0
COL_WHITE	= 1			; sample_ms tripwire latch
COL_HURT	= 2			; red $d020 flash on damage
COL_BG		= 9			; default viewport background (brown)
COL_HUD_BG	= 0
COL_LINE	= 7			; default vectors (yellow)
COL_OUTSIDE	= 0			; black frame (not $d021 brown)

VIEW_COL	= 8
VIEW_ROW	= 9			; HUD occupies rows 0–8
VIEW_W		= 24
VIEW_H		= 16
VIEW_OFF	= VIEW_ROW * 40 + VIEW_COL
SCREEN_CX	= 96			; 192px viewport centre
SCREEN_XMAX	= 192
MARGIN_CH	= 192			; col 24 row 0 — solid glyph, not cleared

; PAL text starts at raster 51 (YSCROLL=3). HUD 9 rows, then 16-row viewport.
; HUD→view is untimed (row 8 is a solid black bar, see .view in irq.asm).
; Mid split: IRQ two lines before the last top-half line L, poll $d012 to L
; (the edge, not IRQ latency, anchors the write), delay past col 31, $d018.
; UI+$d021 black runs in lower flyback after the last text row.
RASTER_TOP	= 251			; flyback after last text line (row 24 ends ~250)
RASTER_VIEW	= 118			; HUD row 8 = lines 115-122; stores land ~119
RASTER_SPLIT	= 184			; IRQ here (L-2); poll to 186, then right-border write
RASTER_SPLIT_LINE	= 186		; last top-half scanline (before badline 187)

D018_A_TOP	= $04			; matrix $C000, charset $D000
D018_A_BOT	= $06			; matrix $C000, charset $D800
D018_B_TOP	= $18			; matrix $C400, charset $E000
D018_B_BOT	= $1A			; matrix $C400, charset $E800
D018_A_UI	= $0E			; matrix $C000, UI charset $F800 (HUD band always this)
D018_B_UI	= $1E			; unused — HUD is not flipped with the viewport

UI_CHARSET	= $F800
UI_FONT_PAGES	= 8			; 256 glyphs, ASCII-indexed from quakefont.png
; 40-col HUD (rows 0–8 above VIEW_ROW):
;  0FFF              Quake64
;  1          The Slipgate Complex
;  2                             
;  3        S000   Health  Armour  PU
;  4        N000                   PU
;  5        G000    100     000  Damage
;  7                  trigger message
HUD_ROW		= 0			; frame ms FFF
HUD_ROW_TITLE	= 0			; "Quake64" (same row as FFF)
HUD_ROW_MAP	= 1			; map display name
HUD_ROW2	= 2			; HUD_POS / PROFILE verts
HUD_ROW_SHELL	= 3
HUD_ROW_NAIL	= 4
HUD_ROW_GREN	= 5			; grenades + health / armour values
HUD_ROW4	= 7			; trigger message
HUD_COL		= 0
HUD_OFF		= HUD_ROW * 40 + HUD_COL
HUD_OFF_TITLE	= HUD_ROW_TITLE * 40 + HUD_COL
HUD_OFF_MAP	= HUD_ROW_MAP * 40 + HUD_COL
HUD_OFF2	= HUD_ROW2 * 40 + HUD_COL
HUD_OFF_SHELL	= HUD_ROW_SHELL * 40 + HUD_COL
HUD_OFF_NAIL	= HUD_ROW_NAIL * 40 + HUD_COL
HUD_OFF_GREN	= HUD_ROW_GREN * 40 + HUD_COL
HUD_OFF3	= HUD_OFF2		; PROFILE vertex counts
HUD_OFF4	= HUD_ROW4 * 40 + HUD_COL
HUD_TITLE_COL	= 16
HUD_AMMO_ICON	= 8
HUD_AMMO_NUM	= 9
HUD_HP_LABEL	= 13
HUD_AR_LABEL	= 21
HUD_HP_NUM	= 15
HUD_AR_NUM	= 22
HUD_PU_LABEL = 26
HUD_PU_COL	= 28
HUD_CH_SP	= $20			; ASCII space / digits / letters in UI charset
HUD_CH_PLUS	= $2b
HUD_CH_MINUS	= $2d
HUD_CH_C	= $43
HUD_CH_U	= $55
HUD_CH_R	= $52
HUD_CH_P	= $50
HUD_CH_K	= $4b
HUD_CH_D	= $44
HUD_CH_H	= $48
HUD_CH_X	= $58
HUD_CH_Y	= $59
HUD_CH_Z	= $5a
HUD_CH_SHELL	= $7b			; { → shell icon
HUD_CH_NAIL	= $7c			; | → nail icon
HUD_CH_GREN	= $7d			; } → grenade icon
HUD_CH_QUAD	= $00			; 2×2 powerup tiles in $00–$1E (quad/pent/ring)
HUD_CH_PENT	= $04
HUD_CH_RING	= $08
COL_HUD		= 8			; orange digits
COL_HUD_DIM	= 2			; dark red stage letters

; Judd quarter-square (disk sqt @ $F000, page-aligned; mulset_* stores lo only)
; Under KERNAL — multiply only with $01=$30 (same as A-side LUTs).
sqlo		= $F000
sqhi		= $F200
negsqlo		= $F400
negsqhi		= $F600

; SMC map accessors: macros emit abs,x/y with this operand hi until LoadLevel
; patches from the map-file reloc prefix. Must not collide with a real GAME abs.
MAP_SMC_HI	= $02
MAP_SMC_BASE	= $0200
!if  (>MAP_SMC_BASE) != MAP_SMC_HI {
	!error "MAP_SMC_BASE hi must equal MAP_SMC_HI"
}

; Play BSS: default VIC matrix / leftover boot. VIC matrix in play is $C000.
; map_bss.asm occupies $0400–$0523. $08F6 video_ms, $08F9–$08FF reboot stub + selectors.
FRAME13_N	= 106			; offsets 0..105
ENEMY_PTR_N	= 9			; must == ENEMY_NTYPES (quake64.asm asserts)
frame13_lo	= $0524
frame13_hi	= $058E
enemy_gx_lo	= $05F8
enemy_gx_hi	= enemy_gx_lo + ENEMY_PTR_N
enemy_gy_lo	= enemy_gx_hi + ENEMY_PTR_N
enemy_gy_hi	= enemy_gy_lo + ENEMY_PTR_N
enemy_gz_lo	= enemy_gy_hi + ENEMY_PTR_N
enemy_gz_hi	= enemy_gz_lo + ENEMY_PTR_N
box_vis_edges	= enemy_gz_hi + ENEMY_PTR_N	; 24
room_pack_edges	= box_vis_edges + 24		; 64
pose_gx		= room_pack_edges + 64		; 13 — lerp scratch (ent_set_pose)
pose_gy		= pose_gx + 13
pose_gz		= pose_gy + 13
pose_map_lo	= pose_gz + 13			; patched at pose load (logical → packed)
pose_map_hi	= pose_map_lo + ENEMY_PTR_N
enemy_sfx_evt_lo	= pose_map_hi + ENEMY_PTR_N	; cue block + clip event table on pose heap
enemy_sfx_evt_hi	= enemy_sfx_evt_lo + ENEMY_PTR_N
en_sfx_old	= enemy_sfx_evt_hi + ENEMY_PTR_N	; local frame before this anim step; fire cross-check reads it, then the sfx scan rewrites it
en_sfx_new	= en_sfx_old + 1		; logical frame after the step
en_sfx_n	= en_sfx_new + 1		; remaining events while scanning
en_sfx_armed	= en_sfx_n + 1			; 1 = frame changed this anim step
play_bss_free	= en_sfx_armed + 1		; up to ENEMY_DATA_BASE
; Menu set_video_ms copies the PAL hue table here. GAME loads at $0900, so
; this is still here when a8_to_pal runs. NTSC never reads it.
a8_pal_hue	= play_bss_free			; 16: NTSC hue → PAL high nibble, lum 0
a8_hue_lo	= a8_pal_hue + 16		; a8_to_pal luminance scratch
; genenemies.py ENEMY_DATA_BASE must match.
; Per-type cue ids ride on the pose heap, not here: enemy_sfx_evt_* points at the
; 5-byte cue block, and the clip event table follows it (CUE_N bytes in).
CUE_SIGHT	= 0			; generic: enemy_enter_alert (Chthon: the rise)
CUE_WINCE	= 1			; generic: pain entry
CUE_MELEE	= 2			; clip-timed
CUE_SHOOT	= 3			; clip-timed
CUE_DEATH	= 4			; generic: kill_enemy
CUE_N		= 5
CUE_NONE	= $ff			; $00 is a real sound
ENEMY_DATA_BASE	= play_bss_free + 44	; boot-loaded enemy_data_blob.asm
!if  ENEMY_DATA_BASE != $0701 {
	!error "tools/genenemies.py ENEMY_DATA_BASE must be $0701"
}
!if  a8_hue_lo >= ENEMY_DATA_BASE {
	!error "PAL hue table overlaps enemy data"
}
; Boot skip_n is $06F0. The reboot stub uses $06F0–$06F3 while loading GAME.
!if  a8_hue_lo >= $06f0 {
	!error "PAL hue table hits boot scratch"
}
; Pose prefix copied into one of two resident rows. Offsets match genenemies.py.
META_STAND_START	= 0
META_ROW		= 41
AI_ENTRY_LO	= $0850			; streamed AI entry pointer per enemy type
AI_ENTRY_HI	= AI_ENTRY_LO + ENEMY_PTR_N
ENEMY_DATA_LIMIT	= AI_ENTRY_LO
AI_BANK_LO	= AI_ENTRY_HI + ENEMY_PTR_N	; base of complete fused bank per type
AI_BANK_HI	= AI_BANK_LO + ENEMY_PTR_N
AI_LOW_END	= AI_BANK_HI + ENEMY_PTR_N
; Crusher SoA pointers + tiny play scratch. Not in $0400 — that table
; ends at frame13_lo. Access via lda_cy/sta_cy (mp_l),y.
crush_x		= AI_LOW_END
crush_y		= crush_x + 2
crush_z		= crush_y + 2
crush_sx	= crush_z + 2
crush_sy	= crush_sx + 2
crush_sz	= crush_sy + 2
crush_home	= crush_sz + 2
crush_dest	= crush_home + 2
crush_face	= crush_dest + 2
crush_dir	= crush_face + 2		; live sign $01 / $FF
crush_room	= crush_dir + 2
crush_entry_lo	= crush_room + 2
crush_entry_hi	= crush_entry_lo + 1
crush_need	= crush_entry_hi + 1	; 1 = current room owns a crusher
crush_skip	= crush_need + 1	; $ff none, else SoA index for pos_ok
crush_st	= crush_skip + 1	; sta_cy scratch
crush_acc_l	= crush_st + 1
crush_acc_h	= crush_acc_l + 1
crush_i		= crush_acc_h + 1
crush_lo	= crush_i + 1		; min(home,dest) while stepping
crush_hi	= crush_lo + 1
CRUSH_BSS_END	= crush_hi + 1
; Custom-skeleton runtime. skel_base = 0 means the shared 13-vert stick.
; A bound prefix with skel_nv = 0 is an empty graph and draws nothing.
skel_nv		= CRUSH_BSS_END			; ENEMY_PTR_N
skel_ne		= skel_nv + ENEMY_PTR_N
skel_base_lo	= skel_ne + ENEMY_PTR_N		; pose prefix in the bank
skel_base_hi	= skel_base_lo + ENEMY_PTR_N
skel_mul_n	= skel_base_hi + ENEMY_PTR_N
skel_entry_lo	= skel_mul_n + 1		; streamed draw/lerp entry
skel_entry_hi	= skel_entry_lo + ENEMY_PTR_N
SKEL_BSS_END	= skel_entry_hi + ENEMY_PTR_N
!if  CRUSH_BSS_END > RB_CELL {
	!error "crusher BSS overlaps rb_n cell"
}
!if  SKEL_BSS_END > RB_CELL {
	!error "skeleton BSS overlaps rb_n cell"
}
; Cassette buffer / $0334-$03FF (204 B): free during play (KERNAL disk LOAD/SAVE
; never touches it). Not $02xx (MAP_SMC_HI sentinel), not $0314-$0319 (vectors).
; Atari: $0200-$03F9 is the text matrix and display list, so the line/sound
; tables sit under the NMI vectors ($FFFA).

LINE_TAB	= $FF40

LINE_TAB_END	= LINE_TAB + 72
SOUND_TABLE	= LINE_TAB_END		; sound_table: SOUND_COUNT words (playsound.asm)

SOUND_TABLE_MAX	= 128


; Shift-S / Shift-L. a8_keys sets the latch once per press (qk_held stays 1
; until all keys are up), poll_quick_keys clears it. in_qload must follow
; in_qsave (a8_keys indexes them). qk_held is not cleared by init_irq: a
; key still down after a quickload must not fire again.
in_qsave	= SKEL_BSS_END
in_qload	= in_qsave + 1
qk_held		= in_qload + 1
ls_first	= qk_held + 1		; 1 = line_solids_* stops at the first hit
sl_end		= ls_first + 1		; room-slice loop bound (leaf loops only, never nested)
ut_end		= sl_end + 1		; update_triggers slice bound (trig_enter may reach sl_end users)
QS_LATCH_END	= ut_end + 1
; Quicksave slot: the last QSAVE_N sectors of the ATR (tools/mkatr.py checks
; both numbers). The QSAVE overlay (a8qsave.asm) is loaded over bitmap A at
; QS_OVL, above the three context pages a8_ctx_save parks at the top of the
; draw bitmap, run with the screen blanked (den_arm = 1), and wiped after.
QSAVE_N		= 5
QSAVE_SEC	= 1036
QS_OVL		= $C300
!if  QS_LATCH_END > RB_CELL {
	!error "quicksave latches overlap rb_n"
}
; Cheat FSM + god_mode. Outside the quicksave image ($CB70–$D000) and not
; cleared by game_zp_init / LoadLevel, so god mode survives idmap and death.
; Cleared once from start. Hole ends at RB_CELL.
god_mode	= QS_LATCH_END		; 1 = idgod, take_damage returns
cheat_phase	= god_mode + 1
cheat_god	= cheat_phase + 1	; table offset; cheat_kfa, cheat_map follow
cheat_kfa	= cheat_god + 1
cheat_map	= cheat_kfa + 1		; letters typed, then digits
cheat_ep_dig	= cheat_map + 1
cheat_map_dig	= cheat_ep_dig + 1
cheat_ep_latch	= cheat_map_dig + 1	; stable copy for main
cheat_map_latch	= cheat_ep_latch + 1
cheat_was	= cheat_map_latch + 1	; 4 rising-edge slots
cheat_dig_prev	= cheat_was + 4
cheat_a		= cheat_dig_prev + 1
cheat_b		= cheat_a + 1
cheat_c		= cheat_b + 1
cheat_req	= cheat_c + 1		; 0 / CHEAT_REQ_*
cheat_kdown	= cheat_req + 1		; 0 = saw key up, else KBCODE+1. Not in cheat_was
CHEAT_BSS_END	= cheat_kdown + 1
; ST mouse port 2, X quadrature. Play only. mouse_en itself is ZP $cd.
mouse_x		= CHEAT_BSS_END		; previous raw 2-bit X state (pins 1–2, active low)
mouse_turn	= mouse_x + 1		; 16-bit signed sum of steps (2 = 1 yaw tick)
mouse_turn_h	= mouse_turn + 1
mouse_f		= mouse_turn_h + 1		; fast-mode timer: samples left (0 = slow decode)
mouse_rem	= mouse_f + 1		; sub-tick remainder (0..1) carried between frames
mouse_lim	= mouse_rem + 1		; read_input: max |ticks| this frame (2x stick rate)
mouse_v		= mouse_lim + 1		; last step direction (+1 / $ff), sign for a 2-step sample
MOUSE_BSS_END	= mouse_v + 1
!if  MOUSE_BSS_END > RB_CELL {
	!error "mouse BSS overlaps rb_n"
}

SKEL_MAX_VERTS	= 48
SKEL_MAX_EDGES	= 64
SKEL_PFX	= 7			; size.w, nv, ne, entry.w, shift; baked batches follow
SKEL_PFX_SHIFT	= 6			; pose coords stored as v >> shift

AI_BANK_MAGIC0	= 'Q'
AI_BANK_MAGIC1	= 'A'
AI_BANK_MAGIC2	= 'I'
AI_BANK_MAGIC3	= '1'
AIH_CODE_SIZE	= 4
AIH_RELOC_N	= 6
AIH_MAP_N	= 8
AIH_ENTRY	= 10
AIH_POSE_OFF	= 12
AIH_FLAGS	= 14
AIH_SIZE	= 15
AI_LINK_BASE	= $A000
; Boot parks tab.prg here and a8_bind_tabs copies it before LoadLevel.
; Resident game must end below this. a8boot.asm job dest is the same address.
TAB_STAGE	= $B000
AI_CMD_ATTACK_TICK	= 0
AI_CMD_FIRE		= 1
AI_CMD_ATTACK_END	= 2
AI_CMD_DYING_STEP	= 3
AI_CMD_APPROACH_MOVE	= 4
AI_CMD_APPROACH_ATTACK	= 5
AI_CMD_APPROACH_ENTER	= 6
AI_CMD_IDLE		= 7
AI_CMD_DRAW		= 8
AI_CMD_PAIN		= 9
AI_CMD_ELEC		= 10
AI_CMD_ANIM_FIRE	= 11
AI_CMD_PAIN_TICK	= 12
AI_CMD_PAIN_ASK		= 13
AI_CMD_DEATH		= 14		; corpse finished: grunt/ogre drop
AI_CMD_SCRAG_DODGE	= 15		; scrag bank: hold-bubble sidestep, C=1 if set
AI_CMD_RED_ON		= 16		; chthon bank: line bodies ora->eor (pixel %10 red on paper)
AI_CMD_RED_OFF		= 17		; chthon bank: restore ora
CRUSH_CMD_TICK		= 0
CRUSH_CMD_SOLID		= 1
CRUSH_CMD_DRAW		= 2
AI_AP_MOVE		= 0
AI_AP_STAND		= 1
AI_AP_NEXT		= 2

; Unique charset-tail LUTs. Char 192 ($x600) is $FF×8 in all four halves.
; ALOG is two pages (ALOGHI replaces ALOGTAB+$100). COSTAB = SINTAB+64.
; Atari: $D000-$D7FF is I/O. Bitmap B is the $E000 4K (ANTIC does not
; carry a screen pointer across a 4K boundary). Play state + alog/log
; sit in the RAM at $D800-$DFFF, under that bitmap.

SINTAB		= $FC00			; 320 bytes
COSTAB		= SINTAB + 64
invzl		= $FD40			; 128
invzh		= $FDC0			; 128
ALOGTAB		= $FE40			; 256
ALOGHI		= $DE00			; 256, after the $D800 play block
LOGTAB		= $DF00			; 256


SCR_A		= $C000
SCR_B		= $C400
CH_A_TOP	= $D000
CH_A_BOT	= $D800
CH_B_TOP	= $E000
CH_B_BOT	= $E800
MARGIN_GLYPH	= CH_A_TOP + 24 * 64	; $D600 — char 192, A top


A8_OFF		= $0E00			; $CA00-$CFFF -> $D800-$DDFF (under bitmap B)

PROJ_X		= $CA00 + A8_OFF			; 16 view/proj slots (NVERTS=13 used)
PROJ_Y		= $CA10 + A8_OFF
PROJ_Z		= $CA20 + A8_OFF
CAM_X		= $CA30 + A8_OFF
CAM_Y		= $CA40 + A8_OFF
CAM_Z		= $CA50 + A8_OFF
PROJ_XH		= $CA60 + A8_OFF
PROJ_YH		= $CA70 + A8_OFF
CAM_XH		= $CA80 + A8_OFF
CAM_YH		= $CA90 + A8_OFF
CAM_ZH		= $CAA0 + A8_OFF
PROJ_ZH		= $CAB0 + A8_OFF
EDGE_VIS	= $CAC0 + A8_OFF			; 32 edge flags (tetromino rooms ≤28)
CLIP_X0		= $CAE0 + A8_OFF
CLIP_Y0		= $CB00 + A8_OFF
CLIP_X1		= $CB20 + A8_OFF
CLIP_Y1		= $CB40 + A8_OFF
frame_t0	= $CB60 + A8_OFF			; 4-byte CIA2 cascade snapshot
frame_cy	= $CB64 + A8_OFF
casc_now	= $CB68 + A8_OFF

FOCAL		= 100
LOG_FOCAL	= 213			; round(32*log2(100))
NVERTS		= 13
NEDGES		= 13
MESH_MAX_VERTS	= 16			; CAM/PROJ / VOC / COL_* slot count
MESH_MAX_EDGES	= 32			; EDGE_VIS / CLIP_* slot count
ANIM_MS		= 100			; walk step interval (ms)
ZCLIP		= $0100			; 1.0 near plane (8.8)
YAW_STEP	= 3
PITCH_STEP	= 2
PITCH_MIN	= $d0			; -48, signed about horizon 0
PITCH_MAX	= 48
KEY_W		= 1
KEY_A		= 2
KEY_S		= 4
KEY_D		= 8
KEY_I		= 16
KEY_J		= 32
KEY_L		= 128
PERSP_MAX	= 127
CLIP_XMIN	= -96			; signed offset: x 0..191
CLIP_XMAX	= 95
CLIP_YMIN	= -64			; y 0..127
CLIP_YMAX	= 63
OC_LEFT		= 1
OC_RIGHT	= 2
OC_TOP		= 4
OC_BOT		= 8
OC_NEAR		= $80			; VOC only: z < ZCLIP (screen bits not set)

; Player / world
EYE_HEIGHT	= 3
PLAYER_H	= 4			; Y collision height [feet, feet+PLAYER_H)
DOOR_Y_SLACK	= 1			; |feet − door_y| to fire a wish-through
DOOR_AIM	= 32			; yaw ticks (45°) of through-heading to transit
MOVE_SPEED	= 2			; 8.8 step scale (asl count after wish)
PLAYER_R	= 1			; XZ collision radius
ENEMY_BLOCK_R	= 1			; XZ Chebyshev vs player (same cell + neighbors)
FALL_LEDGE	= 1			; start fall if feet-floor > this
STEP_UP		= 2			; max walk-up; 2 units plays SOUND_PLAYER_LAND
FALL_TICK_MS	= 32			; gravity cadence (like MOTION_STEP_MS)
FALL_ACCEL	= $10			; 8.8 added to downward vel per tick
FALL_SAFE	= 8			; no damage if eye-drop <= this
FALL_DAMAGE	= 15			; HP on hard landing
HURT_FLASH_MS	= 300			; red border duration
ENEMY_CULL_R	= 2			; view-space |x| vs z+R (8.8 high)
ENEMY_CULL_H	= 6			; view-space |y| vs z+H (figure height)
ENEMY_MAX		= 24		; MAP_NENEMIES ≤ this
EN_IDLE		= 0
EN_PATROL		= 1
EN_ALERT		= 2
EN_APPROACH		= 3
EN_ATTACK		= 4
EN_PAIN		= 5
EN_DYING		= 6
EN_DEAD		= 7			; last death frame hold
EN_GONE		= 8
ENEMY_DETECT	= 20		; Chebyshev XZ wake distance
ENEMY_STEP_MS	= 200		; approach cell cadence (dt acc + remainder)
ENEMY_STEP_JIT	= $7f		; approach entry step phase mask, < ENEMY_STEP_MS
PATROL_STEP_MS	= 400		; patrol cell cadence (2× approach; 16-bit)
OGRE_STEP_MS	= 400		; ogre approach cadence (2× ENEMY_STEP_MS)
DOG_REPATH_N	= 50		; dog chase frames between repaths (~1s at 20ms)
DOG_WAIT_MS	= 2000		; idle pause when player is on another floor piece
DEATH_HOLD_MS	= 1600		; EN_DEAD last-frame hold before EN_GONE
PATROL_MIN	= 6			; min clear cells along a cardinal before walking
PATROL_SCAN	= 32		; max cells probed when picking a patrol point
PATROL_WAIT_MS	= 1000		; idle after arriving; + rnd*4 → ~1–2s
GRUNT_BACKOFF	= 8		; Chebyshev ≤ this → weight dodge away from player
SCRAG_HOLD_R	= 12		; Chebyshev ≤ this + LOS → stop closing, spit
GRUNT_ATK_MS	= 1500		; min time in approach before the next attack
KNIGHT_ATK_MS	= 1500
ROTT_ATK_MS	= 1500
SCRAG_ATK_MS	= 2000		; Q1 wiz_fast14 SUB_AttackFinished(2)
OGRE_ATK_MS	= 1500
SHAM_ATK_MS	= 1500
SHAM_STEP_MS	= 400		; approach cadence (2× ENEMY_STEP_MS)
ZOMBIE_ATK_MS	= 1500
DEMON_ATK_MS	= 1500
OGRE_MELEE_R	= 6		; chainsaw Chebyshev; grenade uses enemy_range
OGRE_SWING_FIRE	= 4		; clip-local hit; shoot uses enemy_fire_frame
SHAM_MELEE_R	= 6		; Q1 vlen 100, same face range as the ogre saw
SHAM_VAR_SMASH	= 0
SHAM_VAR_SWINGR	= 1
SHAM_VAR_SWINGL	= 2
SHAM_VAR_MAGIC	= 3
SHAM_SMASH_FIRE	= 9		; smash10, 0-indexed
SHAM_CLAW_FIRE	= 6		; swingr7 / swingl7
SHAM_BOLT_LO	= 5		; magic6..magic8, three CastLightning ticks
SHAM_BOLT_HI	= 8
SHAM_BOLT_H	= 6		; chest above feet (Q1 origin+40)
SHAM_BOLT_DROP	= EYE_HEIGHT - 2	; end Y = cam_yh − this (feet + 2)
SHAM_BOLT_DMG	= 10		; Q1 LightningDamage 10; player HP is 100
SHAM_BODY_R	= 4		; hitscan half-width; pixels += R*FOCAL/z
SHAM_HIT_R	= 4		; grenade XZ chebyshev
SHAM_HIT_H	= 10		; grenade Y span above feet (exclusive)
SHAM_PAIN_MS	= 2000		; Q1 pain_finished = time + 2
SHAM_PAIN_ALWAYS	= 80		; damage/80 flinch; 400÷5 because HP is ÷5
CHTHON_FIRE2	= 17		; second throw in the attack clip (vert 13)
OGRE_SAW_DMG	= 12		; 12/14/16/18 = 2×(6+(rnd&3))
KNIGHT_SLASH_DMG	= 4		; 4–7 with rnd&3 (Quake ai_melee *3 vs ogre *4)
KNIGHT_RUNATK_FIRE	= 5		; runattack clip-local hit (0-indexed)
KNIGHT_ATKB_FIRE	= 7		; attackb clip-local hit (0-indexed)
DEMON_MELEE_R	= 4		; claw Chebyshev; leap closes until this
DEMON_LEAP_STEP_MS	= 100		; leap cell cadence
DEMON_MELEE_FIRE	= 5		; attacka clip-local hit (0-indexed)
DEMON_LEAP_FIRE	= 9		; leap clip-local hit (0-indexed)
DEMON_DMG		= 8		; 8–15 with rnd&7
ZOMBIE_STEP_MS	= 400		; slow walk; 2× grunt approach cadence
ZOMBIE_HOLD_FRAME	= 10		; paine local frame held while down
ZOMBIE_DOWN_BASE	= 50		; anim ticks at 10 before get-up (~5s)
FLESH_DMG		= 10		; Quake zombie missile 10 (player HP 100)
AXE_DMG		= 4			; Quake axe 20 ÷ 5
AXE_HIT_R		= 3			; XZ chebyshev radius for axe hit test
SHOT_DMG_MAX	= 11		; Quake SSG 14×4=56 ÷ 5
SHOT_HIT_X	= 20		; |sx − SCREEN_CX| ≤ this (pixels)
SHOT_Z_MAX	= 32		; view-Z high max range; SSG ceiling = SHOT_DMG_MAX − (z>>1), min 1
SHOT_MID_H	= 3			; mid-body Y above feet (≈ ENEMY_CULL_H/2)
NAIL_DMG_MAX	= 2			; Quake nail 9 ÷ 5; ceiling = this − (z>>2), min 1
NAIL_HIT_X	= 6			; |sx − SCREEN_CX| ≤ this (pixels)

ITEM_CULL_Y	= 2			; AABB |y| vs Chebyshev XZ + pad
FOV_HALF	= 31			; yaw ticks ≈ atan(SCREEN_CX/FOCAL)

; Process SoA + mutable map state in VIC-bank scratch past profiler
PROC_NUM	= 8
PROC_FREE	= 0
PROC_TIMER	= 1
PROC_OPEN_DOOR	= 2
PROC_LOWER_DOOR	= 3
PROC_LOWER_ELEV	= 4
PROC_RAISE_ELEV	= 5

PROC_KIND	= $CB70 + A8_OFF
PROC_A		= $CB78 + A8_OFF			; world object id (door_id / elev_id)
PROC_B		= $CB80 + A8_OFF			; dest / next kind
PROC_C		= $CB88 + A8_OFF			; timer/accum lo
PROC_D		= $CB90 + A8_OFF			; timer/accum hi
PROC_E		= $CB98 + A8_OFF			; elev home return Y
PROC_L		= $CBA0 + A8_OFF			; local door/elev SoA index
floor_slope	= $CBA8 + A8_OFF			; 1 if this frame's floor is a ramp
trig_inside	= $CBA9 + A8_OFF			; occupancy bits, Nth same-room trigger
hurt_ms_l	= $CBAA + A8_OFF			; hurt-trigger cooldown remaining
hurt_ms_h	= $CBAB + A8_OFF
vic_border	= $CBAC + A8_OFF			; staged $d020 (IRQ)
palette_dirty	= $CBAD + A8_OFF			; 1 = IRQ refill viewport colour RAM
flash4_col	= $CBAE + A8_OFF			; staged sprite 4 colour
flash5_col	= $CBAF + A8_OFF			; staged sprite 5 colour
HURT_MS		= 1000			; hurt trigger period (both sizes)
HURT_SM_HP	= 2			; small hurt, once per second
HURT_LG_HP	= 10			; large hurt, once per second

elev_y		= $CBB0 + A8_OFF			; MAP_NELEVS (≤4)
elev_noise_n	= $CBB4 + A8_OFF			; refcount: SID V3 rumble while elevs move
den_arm		= $CBB5 + A8_OFF			; 1 = DEN held off, 2 = view IRQ may set DEN
pub_ff		= $CBB6 + A8_OFF			; frame_flag when the draw buffer was published
pub_ph		= $CBB7 + A8_OFF			; irq_phase then (0 = before this frame's view IRQ)
proc_tmp0	= $CBB8 + A8_OFF
proc_tmp1	= $CBB9 + A8_OFF
proc_tmp2	= $CBBA + A8_OFF
proc_tmp3	= $CBBB + A8_OFF
proc_tmp4	= $CBBC + A8_OFF
proc_tmp5	= $CBBD + A8_OFF
MOTION_STEP_MS	= 64
ELEV_STEP_MS	= 128			; half elevator travel speed vs doors
CRUSH_STEP_MS	= 512			; 1/4 elevator travel (4× ELEV_STEP_MS)
DOOR_RECLOSE_MS	= 5000
ELEV_WAIT_MS	= 5000
STATUS_MS	= 5000			; backpack / status HUD line

; Box / mesh draw
BOX_NVERTS	= 8
BOX_NEDGES	= 12
HUD_MSG_COL	= 0
HUD_MSG_W	= 40
SAMPLE_MS_PAL	= 20			; ms per mid-split tick (50 Hz)
SAMPLE_MS_NTSC	= 17			; ≈1000/60
in_fwd		= $CBBE + A8_OFF			; 16-bit hold ms (IRQ accum)
in_back		= $CBC0 + A8_OFF
in_strafel	= $CBC2 + A8_OFF
in_strafer	= $CBC4 + A8_OFF
in_turn_l	= $CBC6 + A8_OFF
in_turn_r	= $CBC8 + A8_OFF
hold_fwd	= $CBCA + A8_OFF			; 16-bit snapshots (read_input)
hold_back	= $CBCC + A8_OFF
hold_strafel	= $CBCE + A8_OFF
hold_strafer	= $CBD0 + A8_OFF
hold_turn_l	= $CBD2 + A8_OFF
hold_turn_r	= $CBD4 + A8_OFF
in_use		= $CBD6 + A8_OFF			; unused; quicksave span
key_use		= $CBD7 + A8_OFF			; unused; quicksave span
key_use_was	= $CBD8 + A8_OFF			; door_blk rising edge
pl_falling	= $CBD9 + A8_OFF			; 0 grounded, 1 airborne
fall_vl		= $CBDA + A8_OFF			; 8.8 downward vel lo
fall_vh		= $CBDB + A8_OFF
fall_y0		= $CBDC + A8_OFF			; cam_yh when fall started
fall_acc	= $CBDD + A8_OFF			; leftover ms toward FALL_TICK_MS

; Unique world X/Z + 8.8 sin/cos products for xform_mesh_xz (6+6 unique, 16 verts)
UX		= $CBDE + A8_OFF			; 6 bytes
UZ		= $CBE4 + A8_OFF
VY		= $CBEA + A8_OFF			; 16 bytes (vert Y)
XC_L		= $CBFA + A8_OFF			; 6
XC_H		= $CC00 + A8_OFF
XS_L		= $CC06 + A8_OFF
XS_H		= $CC0C + A8_OFF
ZC_L		= $CC12 + A8_OFF
ZC_H		= $CC18 + A8_OFF
ZS_L		= $CC1E + A8_OFF
ZS_H		= $CC24 + A8_OFF			; last byte $CC29

; Hardware sprite view-model (VIC bank 3). Atari body/flash cells are baked.
; Muzzle and splat are mode-E pointers (emuz_src, splat_src). Buffers sit
; under the heap ceiling so they miss bitmap A.

WPN_RAM		= $BE00
WPN_FLASH	= $BF00
WPN_FLASH2	= $BF40
WPN_EMUZ	= $BF80
WPN_SPLAT	= $BFC0
HEAP_LIM	= $BC00
HUD_SCR		= $0200
BMP_A		= $C000			; 4K, does not cross a 4K boundary
BMP_B		= $E000
WPN_PTR0	= 0
WPN_PTR_FLASH	= 0
WPN_PTR_FLASH2	= 0
WPN_PTR_EMUZ	= 0
WPN_PTR_SPLAT	= 0

FLASH_EN_L	= $10			; $d015 sprite 4
FLASH_EN_R	= $20			; $d015 sprite 5
COL_WPN		= 0 			; weapon sprite colour (C64 only)
COL_FX		= 1 			; enemy muzzle sprite colour (C64 only)
COL_FLASH_Y	= 1			    ; yellow
COL_FLASH_R	= 2			    ; red
COL_SPLAT_HIT	= 2			; red (blood) (DO NOT CHANGE BACK TO PINK!)
COL_SPLAT_MISS	= 0			; wall hit / spark; must differ from COL_SPLAT_HIT
SPLAT_MSB	= $80			; $d010 / $d015 bit for sprite 7
WPN_X0		= 160			; 2×2 top-left, visual centre 184
WPN_Y_FLUSH	= 208			; 42px tall, viewport bottom ~250
WPN_Y_SHOTIDLE	= 218		; shotgun: 10px below WPN_Y_FLUSH
WPN_Y_AXEIDLE	= 229		; half off: top pair only
WPN_Y_NAILIDLE	= 214
WPN_COL		= 24			; native sprite width
WPN_ROW		= 21			; native sprite height
FLASH_X_C	= 172			; 24px flash centred on visual 184
FLASH_X_NL	= 160			; nail left
FLASH_X_NR	= 184			; nail right
FLASH_DY	= 10			; axe spark vs body top
FLASH_DY_GUN	= 20			; shotgun / grenade muzzle
FLASH_DY_NAIL	= -15			; nail vs weapon top
FLASH_YEL_MS	= 60
FLASH_RED_MS	= 60
SPLAT_MS		= FLASH_YEL_MS + FLASH_RED_MS	; same total as muzzle flash
FX_N			= 24			; one explosion, 24 pixels
EXPLODE_MS		= 768			; ~3× frame budget for particle expand
FX_START_MS		= 100			; spawn elapsed head-start (skip origin speck)
FX_VEL_SPEED		= 32			; (dir*speed)>>7 → ~±31 into 8.8
GREN_MAX		= 4
GREN_OWN_PL		= 0
GREN_OWN_EN		= 1
GREN_F_BOUNCE		= 1			; fuse running
GREN_F_PEND		= 2			; waiting on fx_on
GREN_F_FLESH		= 4			; zombie chunk: no bounce/explode
GREN_F_LAVA		= 8			; straight flight, burst on contact
GREN_TICK_MS		= 32
GREN_FLOOR_XZ_ASR	= 1			; /2 XZ per floor hop
GREN_GRAV		= $01EC			; 60 u/s² × 32ms as 8.8
GREN_SPEED		= 30			; enemy horizontal (ogre uses this; was 2×)
GREN_SPEED_PL		= 64			; player outward; loft stays GREN_SPEED_Y
GREN_SPEED_Y		= 10		; upward (was 20; ~22° not 45°)
GREN_OGRE_Y		= 8			; ogre loft: double air time for half horizontal speed
GREN_FUSE_MS		= 2000
GREN_LIFE_MS		= 5000
GREN_DMG_MAX		= 24		; Quake 120 ÷ 5
GREN_RAD		= 6
GREN_HIT_R		= 1
GREN_WRIST_L		= 5			; skeleton "Wrist L"
GREN_WRIST_R		= 7			; skeleton "Wrist R"
GREN_R			= $60			; screen-triangle half-extent 0.375
GREN_VEL_ASR		= 5			; tip = view-vel >> 5
; Scrag spit — tracer + delayed hitscan
SPIT_DMG		= 9			; Quake wizard spike (unscaled; player HP is 100)
SPIT_TIP_VERT		= 12			; muzzle tip bone
SPIT_LEN		= 16			; tracer Chebyshev length toward player
SPIT_FLIGHT_MS		= 160			; ~1.3 units at 8 u/s; strafe clears perp > 1
VIEW_SPR_X0	= 24 + VIEW_COL * 8	; 88 — viewport (0,0) → VIC
VIEW_SPR_Y0	= 50 + VIEW_ROW * 8	; 122
SPLAT_INSET_X	= 24		; melee cue never on viewport edge (0..191)
SPLAT_INSET_Y	= 16		; 0..127
EMUZ_OX		= 12			; tip −12 X (center 24px)
EMUZ_OY		= 10			; tip −10 Y (center 21px)
EMUZ_MS		= 100
EMUZ_MSB	= $40			; $d010 / $d015 bit for sprite 6
EMUZ_Z0		= 8			; tip CAM_ZH LOD bands → spr 0..2
EMUZ_Z1		= 16

; Weapon BSS (after unique-XZ products)
in_fire		= $CC2A + A8_OFF
in_wpn_axe	= $CC2B + A8_OFF			; 4 bytes: axe shot nail gren
in_wpn_shot	= $CC2C + A8_OFF
in_wpn_nail	= $CC2D + A8_OFF
in_wpn_gren	= $CC2E + A8_OFF
key_fire	= $CC2F + A8_OFF
key_wpn_axe	= $CC30 + A8_OFF			; 4 bytes
key_wpn_shot	= $CC31 + A8_OFF
key_wpn_nail	= $CC32 + A8_OFF
key_wpn_gren	= $CC33 + A8_OFF
cur_weapon	= $CC34 + A8_OFF
wpn_pose	= $CC35 + A8_OFF			; POSE_*
fire_rpt_l	= $CC36 + A8_OFF
fire_rpt_h	= $CC37 + A8_OFF
; Line-vs-AABB temps (util.asm). Not rot0–rot2.
ln_r0		= $CC38 + A8_OFF
ln_r1		= $CC39 + A8_OFF
ln_r2		= $CC3A + A8_OFF
mg_frame	= $CC3B + A8_OFF
wpn_x		= $CC3C + A8_OFF
wpn_y		= $CC3D + A8_OFF
spr_en		= $CC3E + A8_OFF
anim_step	= $CC3F + A8_OFF
anim_ms_l	= $CC40 + A8_OFF
anim_ms_h	= $CC41 + A8_OFF
wpn_flash_en	= $CC42 + A8_OFF
wpn_flash_dy	= $CC43 + A8_OFF
wpn_tmp0	= $CC44 + A8_OFF
ws_slot		= $CC45 + A8_OFF			; WS_EMUZ / WS_SPLAT during start_world_spr
; Pose stream scratch (was flash5 timer + emuz on/ms)
need0		= $CC46 + A8_OFF			; type id or $FF
need1		= $CC47 + A8_OFF			; type id or $FF
pose_dump	= $CC48 + A8_OFF			; type being dumped
pose_keep	= $CC49 + A8_OFF			; surviving type while dumping ($FF = none)
load_device	= $CC4A + A8_OFF			; IEC device (KERNAL $ba is not ours during play)
emuz_xmsb	= $CC4B + A8_OFF			; $d010 bit6 when X>=256
item_spin	= $CC4C + A8_OFF			; world pickup yaw (0..255)
item_spin_l	= $CC4D + A8_OFF			; 8.8 fraction
map_sv_a	= $CC4E + A8_OFF			; heap_alloc size hi scratch
map_sv_y	= $CC4F + A8_OFF			; enemy slot / keep type scratch
bind_cur	= $CC50 + A8_OFF			; word: bind_map cursor
heap_top	= $CC52 + A8_OFF			; word: next LOAD dest (grows down from SCR_A)
map_base	= $CC54 + A8_OFF			; word: packed map payload
load_dest	= $CC56 + A8_OFF			; word: current LOAD dest
load_in_play	= $CC58 + A8_OFF
load_namelen	= $CC59 + A8_OFF
load_name_l	= $CC5A + A8_OFF
load_name_h	= $CC5B + A8_OFF
load_type	= $CC5C + A8_OFF
bind_n		= $CC5D + A8_OFF
reloc_base	= $CC5E + A8_OFF			; word: reloc dest words in the map prefix

; Per-vertex clip data hoisted out of mesh_clip (16 slots each)
VOC		= $CC60 + A8_OFF			; Cohen–Sutherland outcode, or OC_NEAR
clip_n		= $CC70 + A8_OFF			; mesh_clip edges left
nc_n		= $CC71 + A8_OFF			; near clip: scaled (ZCLIP - zB) / (zF - zB)
nc_d		= $CC72 + A8_OFF
nc_v		= $CC73 + A8_OFF			; near clip: CAM index across lerp16
nc_s		= $CC74 + A8_OFF			; near clip: behind endpoint's ox/oy slot (0/4)
emuz_src	= $CC75 + A8_OFF			; mode-E muzzle rows (21×3)
; $CC77–$CC7F free
VSX		= $CC80 + A8_OFF			; screen X/Y (front verts with outcode 0)
VSY		= $CC90 + A8_OFF

; Per-XZ-column project cache (verts sharing x,z share z_eye/inv/PROJ_X)
COL_DONE	= $CCA0 + A8_OFF			; 0 = new, 1 = front cached, 2 = behind
COL_INVL	= $CCB0 + A8_OFF
COL_INVH	= $CCC0 + A8_OFF
COL_INVK	= $CCD0 + A8_OFF
COL_PXL		= $CCE0 + A8_OFF
COL_PXH		= $CCF0 + A8_OFF

; Player inventory + backpack taken flags (after project cache)
AMMO_SHELLS_MAX		= 100
AMMO_NAILS_MAX		= 200
AMMO_GRENADES_MAX	= 100
AMMO_SHELLS_BOX		= 20
AMMO_SHELLS_DEATH	= 5			; grunt death backpack
AMMO_NAILS_BOX		= 25
AMMO_GRENADES_BOX	= 5
AMMO_NAILS_GUN		= 30
AMMO_GRENADES_GUN	= 5
AMMO_SHELLS_START	= 25
PLAYER_HP_MAX		= 100
PLAYER_HP_START		= 100
PLAYER_ARMOUR_START	= 0
PLAYER_ARMOUR_MAX	= 100
HP_PACK_25		= 25
HP_PACK_50		= 50
BP_FOOT_SX		= 2			; AABB around equilateral-ish base
BP_FOOT_SZ		= 2
BP_FOOT_SY		= 2			; ≈ 1.5 tall (C64 int)
BP_GRAB_R		= 3			; Chebyshev pad outside that footprint
BP_MAX			= 32		; MAP_NBACKPACKS ≤ this

HAVE_AXE	= 1
HAVE_SHOT	= 2
HAVE_NAIL	= 4
HAVE_GREN	= 8
HAVE_START	= HAVE_AXE | HAVE_SHOT

WPN_AXE		= 0
WPN_SHOT	= 1
WPN_NAIL	= 2
WPN_GREN	= 3

ammo_shells	= $CD00 + A8_OFF
ammo_nails	= $CD01 + A8_OFF
ammo_grenades	= $CD02 + A8_OFF
have_wpn	= $CD03 + A8_OFF			; bitfield HAVE_*
bp_taken	= $CD04 + A8_OFF			; MAP_NBACKPACKS (≤ BP_MAX)
player_hp	= $CD24 + A8_OFF			; 0..PLAYER_HP_MAX
player_armour	= $CD25 + A8_OFF			; 0..PLAYER_ARMOUR_MAX
en_state	= $CD26 + A8_OFF			; ENEMY_MAX: EN_*
en_frame	= $CD3E + A8_OFF			; ENEMY_MAX: local frame in current clip
drop_taken	= $CD56 + A8_OFF			; ENEMY_MAX: 1=inactive/taken, 0=active
drop_x		= $CD6E + A8_OFF
drop_y		= $CD86 + A8_OFF
drop_z		= $CD9E + A8_OFF
drop_room	= $CDB6 + A8_OFF
drop_type	= $CDCE + A8_OFF			; BP_* when active
en_hp		= $CDE6 + A8_OFF			; ENEMY_MAX
en_timer	= $CDFE + A8_OFF			; ENEMY_MAX: attack pause / dog idle / death hold ms lo
en_timer_h	= $CE16 + A8_OFF			; ENEMY_MAX: attack pause / dog idle / death hold ms hi
en_step		= $CE2E + A8_OFF			; ENEMY_MAX: walk acc lo
en_step_h	= $CE46 + A8_OFF			; ENEMY_MAX: walk acc hi
en_dir		= $CE5E + A8_OFF			; ENEMY_MAX: 0..7 dodge facing
gunshot_wake	= $CE76 + A8_OFF			; 1 = gun fired this frame (room wake)
ai_dirtry	= $CE77 + A8_OFF			; 5 bytes dodge dir candidates
ai_turn		= $CE7C + A8_OFF			; turnaround dir or $ff
ai_probe	= $CE7D + A8_OFF			; dir under test (probe must not clobber)
emuz_vx		= $CE7E + A8_OFF			; VIC X lo staged (IRQ apply_en)
emuz_vy		= $CE7F + A8_OFF			; VIC Y staged
emuz_col		= $CE80 + A8_OFF			; sprite colour staged (C64 only)
emuz_pending	= $CE81 + A8_OFF			; enemy idx waiting to muzzle, $ff = none
fb_probe_y	= $CE82 + A8_OFF			; floor_below: inclusive max walkable Y
death_wait_l	= $CE83 + A8_OFF			; death hold ms acc
death_wait_h	= $CE84 + A8_OFF
col_room	= $CE85 + A8_OFF			; collision room for inset/floor/solid
splat_xmsb	= $CE86 + A8_OFF			; $d010 bit7 when X>=256
splat_vx		= $CE87 + A8_OFF
splat_vy		= $CE88 + A8_OFF
splat_col	= $CE89 + A8_OFF			; COL_SPLAT_HIT or COL_SPLAT_MISS
trig_seen	= $CE8A + A8_OFF			; update_triggers: b0=hurt ticked, b1=msg overlap
shot_hit_i	= $CE8B + A8_OFF			; closest hitscan enemy, $ff = miss
shot_hit_z	= $CE8C + A8_OFF			; CAM_ZH of that hit
hurt_flash_l	= $CE8D + A8_OFF			; remaining red-border ms
hurt_flash_h	= $CE8E + A8_OFF
bite_splat_i	= $CE8F + A8_OFF			; dog idx pending blood splat, $ff = none
status_ms_l	= $CE90 + A8_OFF			; status HUD remaining ms
status_ms_h	= $CE91 + A8_OFF
door_i0		= $CE92 + A8_OFF			; room door slice start
door_i1		= $CE93 + A8_OFF			; exclusive end
sw_match	= $CE94 + A8_OFF			; cooked door/enable-tag id while unlocking/arming
en_pat_n	= $CE95 + A8_OFF			; ENEMY_MAX: patrol cells left, or dog repath frames
en_pain_i	= $CEAD + A8_OFF			; ENEMY_MAX: pain/death/attack variant index
have_keys	= $CEC5 + A8_OFF			; HAVE_SILVER / HAVE_GOLD / HAVE_EARTH
pu_kind		= $CEC6 + A8_OFF			; 0 or BP_QUAD / BP_PENT / BP_RING
pu_ms_l		= $CEC7 + A8_OFF
pu_ms_h		= $CEC8 + A8_OFF
fx_oxl		= $CEC9 + A8_OFF			; world origin 8.8 (same as grenade)
fx_oyl		= $CECA + A8_OFF
fx_ozl		= $CECB + A8_OFF
fx_ox		= $CECC + A8_OFF
fx_oy		= $CECD + A8_OFF
fx_oz		= $CECE + A8_OFF
sample_ms_chk	= $CECF + A8_OFF			; shadow of sample_ms (init_irq); tripwire restore
spd_trip	= $CED0 + A8_OFF			; sample_ms corruption count (IRQ .top)
; Grenade SoA — 4 slots × 20 bytes, $CED1–$CF20
gr_on		= $CED1 + A8_OFF
gr_owner	= $CED5 + A8_OFF
gr_flags	= $CED9 + A8_OFF
gr_acc		= $CEDD + A8_OFF
gr_xl		= $CEE1 + A8_OFF
gr_xh		= $CEE5 + A8_OFF
gr_yl		= $CEE9 + A8_OFF
gr_yh		= $CEED + A8_OFF
gr_zl		= $CEF1 + A8_OFF
gr_zh		= $CEF5 + A8_OFF
gr_vxl		= $CEF9 + A8_OFF
gr_vxh		= $CEFD + A8_OFF
gr_vyl		= $CF01 + A8_OFF
gr_vyh		= $CF05 + A8_OFF
gr_vzl		= $CF09 + A8_OFF
gr_vzh		= $CF0D + A8_OFF
gr_fuse_l	= $CF11 + A8_OFF
gr_fuse_h	= $CF15 + A8_OFF
gr_life_l	= $CF19 + A8_OFF
gr_life_h	= $CF1D + A8_OFF
sham_alert_ph	= $CF21 + A8_OFF			; flips each anim tick; 1 = hold Shambler alert or magic frame
hit_dmg		= $CF22 + A8_OFF			; applied damage for the current damage_enemy call
dodge_dx	= $CF23 + A8_OFF			; select_dodge_dir: signed dx toward player
dodge_dz	= $CF24 + A8_OFF			; signed dz toward player
dodge_i		= $CF25 + A8_OFF			; 0..4 probe index, live across enemy_probe_dir
; Hitscan params (live during gun_hitscan / splat_aim_jitter)
scan_hit_x	= $CF26 + A8_OFF			; |sx−CX| max (inclusive)
scan_hit_y	= $CF27 + A8_OFF			; |sy−64| max, $ff = no Y gate (both guns)
scan_dmg_max	= $CF28 + A8_OFF			; SSG ceiling = this − (z>>1); nail = this − (z>>2)
scan_dmg_all	= $CF29 + A8_OFF			; 1 = damage every cone hit (SSG)
scan_jx_mask	= $CF2A + A8_OFF			; splat rnd X mask
scan_jx_bias	= $CF2B + A8_OFF
scan_jy_mask	= $CF2C + A8_OFF
scan_jy_bias	= $CF2D + A8_OFF
; Timed FX headers: +0 on/phase, +1 skip, +2 ms_l, +3 ms_h
FXH_ON		= 0
FXH_SKIP	= 1
FXH_MS_L	= 2
FXH_MS_H	= 3
FXH_COUNT	= 5
fxh_flash4	= $CF2E + A8_OFF
flash_phase	= fxh_flash4 + FXH_ON	; sprite 4: 0 off, 1 yellow, 2 red
flash_skip	= fxh_flash4 + FXH_SKIP
flash_ms_l	= fxh_flash4 + FXH_MS_L
flash_ms_h	= fxh_flash4 + FXH_MS_H
fxh_flash5	= $CF32 + A8_OFF
flash5_phase	= fxh_flash5 + FXH_ON	; sprite 5 (nail right)
flash5_skip	= fxh_flash5 + FXH_SKIP
flash5_ms_l	= fxh_flash5 + FXH_MS_L
flash5_ms_h	= fxh_flash5 + FXH_MS_H
fxh_emuz	= $CF36 + A8_OFF
emuz_on		= fxh_emuz + FXH_ON	; 1 = sprite 6 enabled
emuz_skip	= fxh_emuz + FXH_SKIP
emuz_ms_l	= fxh_emuz + FXH_MS_L
emuz_ms_h	= fxh_emuz + FXH_MS_H
fxh_splat	= $CF3A + A8_OFF
splat_on	= fxh_splat + FXH_ON	; 1 = sprite 7 enabled
splat_skip	= fxh_splat + FXH_SKIP
splat_ms_l	= fxh_splat + FXH_MS_L
splat_ms_h	= fxh_splat + FXH_MS_H
fxh_explode	= $CF3E + A8_OFF
fx_on		= fxh_explode + FXH_ON	; 1 = explosion live
fx_skip		= fxh_explode + FXH_SKIP
fx_ms_l		= fxh_explode + FXH_MS_L
fx_ms_h		= fxh_explode + FXH_MS_H
; Room whose pose banks are currently resident; $ff = none yet.
stream_room	= $CF42 + A8_OFF
; Explosion particle vel — FX_N × vx/vy s8 (integrated at draw)
fx_vx		= $CF43 + A8_OFF			; 24
fx_vy		= $CF5B + A8_OFF			; 24
; Scrag spit — 4 control + 3 axes (player 8.8, wrist 8.8).
; Axis stride 4: player lo, player hi, wrist lo, wrist hi. X, Y, Z.
; Tracer end is rebuilt at draw.
spit_on		= $CF73 + A8_OFF
spit_room	= $CF74 + A8_OFF
spit_owner	= $CF75 + A8_OFF			; enemy index
spit_flash	= $CF76 + A8_OFF			; 0 = tracer done, hitscan next update
spit_axes	= $CF77 + A8_OFF
spit_xl		= spit_axes		; player X lo at fire
spit_xh		= spit_axes+1
spit_oxl	= spit_axes+2		; wrist X
spit_oxh	= spit_axes+3
spit_yl		= spit_axes+4		; aim Y lo (eye − 1)
spit_yh		= spit_axes+5
spit_oyl	= spit_axes+6		; wrist Y
spit_oyh	= spit_axes+7
spit_zl		= spit_axes+8		; player Z lo at fire
spit_zh		= spit_axes+9
spit_ozl	= spit_axes+10		; wrist Z
spit_ozh	= spit_axes+11
spit_prod	= spit_axes+4		; 32-bit product, lo first. Y axis is dead once the hitscan runs.
splat_src	= $CF83 + A8_OFF			; mode-E splat rows (21×3)
; Evicted from KERNAL ZP ($90–$bf / SETNAM $b7–$bc). Abs OK — not (ptr),y.
wish_dx		= $CF85 + A8_OFF			; signed move intent X
wish_dz		= $CF86 + A8_OFF
wish_dxh	= $CF87 + A8_OFF			; wish 8.8 high
wish_dzh	= $CF88 + A8_OFF
save_xh		= $CF89 + A8_OFF
save_zh		= $CF8A + A8_OFF
save_xl		= $CF8B + A8_OFF
save_zl		= $CF8C + A8_OFF
col_x		= $CF8D + A8_OFF			; collision test point
col_z		= $CF8E + A8_OFF
col_y		= $CF8F + A8_OFF
obj_i		= $CF90 + A8_OFF
face_bits	= $CF91 + A8_OFF			; which box faces visible
box_x		= $CF92 + A8_OFF			; box under test (line/point/draw). A nested load replaces it.
box_y		= $CF93 + A8_OFF
box_z		= $CF94 + A8_OFF
box_sx		= $CF95 + A8_OFF
box_sy		= $CF96 + A8_OFF
box_sz		= $CF97 + A8_OFF
msg_off		= $CF98 + A8_OFF			; offset into map_text
vel_ms		= $CF99 + A8_OFF			; hold duration ms (lo)
vel_msh		= $CF9A + A8_OFF
turn_acc_l	= $CF9B + A8_OFF
turn_acc_h	= $CF9C + A8_OFF
dt_msh		= $CF9D + A8_OFF			; frame dt milliseconds (hi)
inv_l		= $CF9E + A8_OFF			; (FOCAL<<16)/(z>>k) lo, mesh project
inv_h		= $CF9F + A8_OFF
inv_k		= $CFA0 + A8_OFF
mesh_vmask	= $CFA1 + A8_OFF
mesh_nwork	= $CFA2 + A8_OFF
random8		= $CFA3 + A8_OFF
scale_s		= $CFA4 + A8_OFF
fn_lx		= $CFA5 + A8_OFF			; frustum inward normals (XZ)
fn_lz		= $CFA6 + A8_OFF
fn_rx		= $CFA7 + A8_OFF
fn_rz		= $CFA8 + A8_OFF
fn_fx		= $CFA9 + A8_OFF
fn_fz		= $CFAA + A8_OFF
pv0		= $CFAB + A8_OFF			; glyph / ramp / door fill
pv1		= $CFAC + A8_OFF
pv2		= $CFAD + A8_OFF
pv3		= $CFAE + A8_OFF
pv4		= $CFAF + A8_OFF
col_bg		= $CFB0 + A8_OFF			; active room paper: Atari colour byte (editor-made) → COLPF0
; $CFB1, $CFB2, $CFB5 were col_fx, col_line, col_wpn
palette_room	= $CFB3 + A8_OFF			; last room_idx palette ($ff = none)
far_scale	= $CFB4 + A8_OFF			; FOCAL/z integer, far enemy project
sfx_ch		= $CFB6 + A8_OFF			; current channel 0..2
sfx_id		= $CFB7 + A8_OFF			; sound id / freq scratch
sample_ms	= $CFB8 + A8_OFF			; PAL 20 / NTSC 17 — set at init
ps_save_x	= $CFB9 + A8_OFF
ps_save_y	= $CFBA + A8_OFF
door_blk	= $CFBB + A8_OFF			; bit0 X slide blocked, bit1 Z
mv0_xl		= $CFBC + A8_OFF			; cam 8.8 at start of apply_move_world
mv0_xh		= $CFBD + A8_OFF
mv0_zl		= $CFBE + A8_OFF
mv0_zh		= $CFBF + A8_OFF
; $CFC0+ free
ai_code_lo	= $CFC0 + A8_OFF			; runtime code base while patching a bank
ai_code_hi	= $CFC1 + A8_OFF
ai_delta_lo	= $CFC2 + A8_OFF			; runtime code base - AI_LINK_BASE
ai_delta_hi	= $CFC3 + A8_OFF
ai_reloc_nlo	= $CFC4 + A8_OFF
ai_reloc_nhi	= $CFC5 + A8_OFF
ai_map_nlo	= $CFC6 + A8_OFF
ai_map_nhi	= $CFC7 + A8_OFF
ai_pose_lo	= $CFC8 + A8_OFF
ai_pose_hi	= $CFC9 + A8_OFF
ai_cmd		= $CFCA + A8_OFF
ai_field	= $CFCB + A8_OFF
rune_taken	= $CFCC + A8_OFF			; 1 = rune of earth magic picked up
ch_anim_phase	= $CFCD + A8_OFF			; flips each anim tick; 1 = skip Chthon this step
ch_crate	= $CFCE + A8_OFF			; two crate SoA indices
ch_home		= $CFD0 + A8_OFF			; home Y of each electrode
ch_phase	= $CFD2 + A8_OFF			; 0 up, 1 lowering, 2 hold, 3 rising
ch_acc_l	= $CFD4 + A8_OFF			; per-crate ms accumulator lo
ch_acc_h	= $CFD6 + A8_OFF			; per-crate ms accumulator hi
ch_bolt_l	= $CFD8 + A8_OFF			; lightning remaining
ch_bolt_h	= $CFD9 + A8_OFF
ch_req		= $CFDA + A8_OFF			; 1 lower, 2 fire
ch_trig		= $CFDB + A8_OFF			; trigger SoA index for the request
ch_shock	= $CFDC + A8_OFF			; 1 = shockc loops until the bolt ends
ch_enemy	= $CFDD + A8_OFF			; Chthon index, $ff until the crates are cached
ch_psx		= $CFDE + A8_OFF			; electrode scratch
ch_psy		= $CFDF + A8_OFF
ch_pok		= $CFE0 + A8_OFF
ch_ax		= $CFE1 + A8_OFF			; bolt endpoints (crate centres)
ch_ay		= $CFE2 + A8_OFF
ch_az		= $CFE3 + A8_OFF
ch_by		= $CFE4 + A8_OFF
ch_bz		= $CFE5 + A8_OFF
ch_best		= $CFE6 + A8_OFF
ch_dist		= $CFE7 + A8_OFF
ch_i		= $CFE8 + A8_OFF
ch_prod		= $CFE9 + A8_OFF
ch_prod_h	= $CFEA + A8_OFF
; Shambler pain lock + bolt scratch. Ends at $CFFF (charset A is $D000).
sham_arc	= $CFEB + A8_OFF			; 1 = magic frames 5..7, V3 crackle
sham_pain_i	= $CFEC + A8_OFF			; locked enemy, $ff = none
sham_pain_l	= $CFED + A8_OFF
sham_pain_h	= $CFEE + A8_OFF
sham_ax		= $CFEF + A8_OFF			; segment start (chest)
sham_ay		= $CFF0 + A8_OFF
sham_az		= $CFF1 + A8_OFF
sham_bx		= $CFF2 + A8_OFF			; segment end (player or blocker)
sham_by		= $CFF3 + A8_OFF
sham_bz		= $CFF4 + A8_OFF
sham_hx		= $CFF5 + A8_OFF			; nearest blocker
sham_hy		= $CFF6 + A8_OFF
sham_hz		= $CFF7 + A8_OFF
sham_best	= $CFF8 + A8_OFF			; nearest t, $ff = clear
sham_i		= $CFF9 + A8_OFF
sham_px		= $CFFA + A8_OFF
sham_py		= $CFFB + A8_OFF
sham_pz		= $CFFC + A8_OFF
sham_pok	= $CFFD + A8_OFF
sham_psx	= $CFFE + A8_OFF
sham_psy	= $CFFF + A8_OFF
CH_PHASE_UP	= 0
CH_PHASE_DOWN	= 1
CH_PHASE_HOLD	= 2
CH_PHASE_RISE	= 3
CH_STEP_MS	= 256			; 1 world unit; ~2s for the 8-unit drop
CH_DROP		= 8
CH_HOLD_MS	= 30000
CH_BOLT_MS	= 5000
CH_SHOCK_DMG	= 40			; half of Chthon's 80 HP
CH_REQ_LOWER	= 1
CH_REQ_FIRE	= 2
HAVE_SILVER	= 1
HAVE_GOLD	= 2
HAVE_EARTH	= 4
POWERUP_MS	= 45000
