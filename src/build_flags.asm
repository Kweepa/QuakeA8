; --- build flags -------------------------------------------

PROFILE		    = 0				; 1 = R/P/K/D bucket HUD + VBI samples
HUD_FRAME_MS	= 0				; 1 = frame time ms on HUD row 0
HUD_POS		    = 0				; 1 = X/Y/Z/yaw/pitch on HUD row 2 (blank line when off)
INF_AMMO		= 0				; 1 = guns fire without spending ammo
JUKEBOX		= 0				; 1 = Jukebox row in the menu (one tune; off for now)

; Stage buckets closed by prof_add_bucket. Same ids in GAME and skel_draw.
PROF_CLEAR	= 0
PROF_ROT	= 1
PROF_PROJ	= 2
PROF_CLIP	= 3
PROF_DRAW	= 4
PROF_UPDATE	= 5			; stamp, sim, enemy update — closed at the bottom of main
PROF_NBUCKET = 6
