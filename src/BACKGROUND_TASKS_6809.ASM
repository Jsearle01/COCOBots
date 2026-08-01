;PETSCII Robots (Color Computer 3 Version)
;by Jay searle 2021
;jay.searle1973@gmail.com

;PETSCII Robots (PET 4032 version)
;by David Murray 2020
;dfwgreencars@gmail.com

BACKGROUND_TASKS:
	LDA	REDRAW_WINDOW		Get redraw window flag (0=No, 1=Yes)
	BEQ	UNIT_AI			No, go handle next AI
	LDA	BGTIMER1		Is all of current VSYNC cycle work done?
	BEQ	UNIT_AI			Yes, go handle next AI
	CLR	REDRAW_WINDOW    	No, clear flag to redraw window
	JSR	DRAW_MAP_WINDOW		And go draw it
UNIT_AI:
; Now check to see if it is time to run background tasks
	LDA	BGTIMER1		Is all of current VSYNC cycle work done?
	BNE	AI000			No, continue processing AI for each active unit
	RTS				Yes, return

; More AI to process this current cycle. Go through all units 0-63; if 1) the unit still exists
; and 2) it's timer (after dropping it by 1) hits 0, then call the appropriate AI routine
AI000:
	CLR	BGTIMER1		Flag VSYNC cycle work done
;INC	$83C0	;-TROUBLESHOOTING on PET
	LDB	#64			Init <UNIT to 1 past end for entry to loop
	STB	UNIT
;ALL AI routines must JMP back to here at the end (or we JSR to routine and have the dispatch routine
; come here saving some room in all 24 AI routinesAILP:
	DEC	UNIT			ALL AI routines must JMP back to here at the end.
	BPL	AI001			Still more units, go check timer for this one
	RTS				Yes, all units done, RETURN CONTROL TO MAIN PROGRAM

AI001:	
	LDX	UNITPRE			Get 16 bit unit #
	LDA	UNIT_TYPE,X		Get unit type (0 means it's dead/doesn't exist)
	BEQ	AILP			Dead or gone, on to the next one
;Unit found to exist, now check it's timer. Unit code won't run until timer hits zero.
	LDB	UNIT_TIMER_A,X		Get # of clock ticks until AI Routine for this unit is to be called
	BEQ	AI003			0=trigger, go call AI routine
	DEC	UNIT_TIMER_A,X		Not time to trigger yet, decrease timer by one.
	BRA	AILP			And onto the next unit

;Unit exists and timer has triggered
;The unit type determines which AI routine is run.
AI003:  
;	LDA 	UNIT_TYPE,X
	CMPA	#24			;MAX DIFFERENT UNIT TYPES IN CHART
	BHI	AILP			;ABORT IF GREATER
	LSLA				;2 BYTES / ENTRY
	LDY	#AI_ROUTINE_CHART	Point to jump table
	JMP	[A,Y]			Call routine

AI_ROUTINE_CHART:
	.WORD	DUMMY_ROUTINE		;UNIT TYPE 00	;non-existent unit
	.WORD	DUMMY_ROUTINE		;UNIT TYPE 01	;player unit - can't use
	.WORD	LEFT_RIGHT_DROID	;UNIT TYPE 02 LCB
	.WORD	UP_DOWN_DROID		;UNIT TYPE 03 LCB
	.WORD	HOVER_ATTACK		;UNIT TYPE 04 !!!TESTED
	.WORD	WATER_DROID		;UNIT TYPE 05 !!!TESTED
	.WORD	TIME_BOMB		;UNIT TYPE 06 !!!TESTED
	.WORD	TRANSPORTER_PAD		;UNIT TYPE 07 !!!TESTED
	.WORD	DEAD_ROBOT		;UNIT TYPE 08 !!!TESTED
	.WORD	EVILBOT			;UNIT TYPE 09 !!!TESTED
	.WORD	AI_DOOR			;UNIT TYPE 10 !!!TESTED
	.WORD	SMALL_EXPLOSION		;UNIT TYPE 11 !!!TESTED
	.WORD	PISTOL_FIRE_UP		;UNIT TYPE 12 !!!TESTED
	.WORD	PISTOL_FIRE_DOWN	;UNIT TYPE 13 !!!TESTED
	.WORD	PISTOL_FIRE_LEFT	;UNIT TYPE 14 !!!TESTED
	.WORD	PISTOL_FIRE_RIGHT	;UNIT TYPE 15 !!!TESTED
	.WORD	TRASH_COMPACTOR		;UNIT TYPE 16 !!!TESTED
	.WORD	UP_DOWN_ROLLERBOT	;UNIT TYPE 17 LCB
	.WORD	LEFT_RIGHT_ROLLERBOT	;UNIT TYPE 18 LCB
	.WORD	ELEVATOR		;UNIT TYPE 19 !!!TESTED
	.WORD	MAGNET			;UNIT TYPE 20 !!!TESTED
	.WORD	MAGNETIZED_ROBOT	;UNIT TYPE 21 !!!TESTED
	.WORD	WATER_RAFT_LR		;UNIT TYPE 22 ?? works but doesn't disappear at edges
	.WORD	DEMATERIALIZE		;UNIT TYPE 23 !!!TESTED

;Dummy routine does nothing, but I need it for development.
DUMMY_ROUTINE:
	BRA	AILP

;First check which direction raft is moving.
; New code (eliminates 2 byte branch by using fall through):
WATER_RAFT_LR:
;	LDX	UNITPRE			Get 16 bit unit #
	JSR	CHECK_FOR_WINDOW_REDRAW	If old position is on screen, flag for redraw (in case moves off)
	LDA	UNIT_A,X		Get direction raft is going (X set in above subroutine)
	BEQ	RAFT_LEFT		Going left? (0=left, 1=right)
RAFT_RIGHT:
	JSR	RAFT_DELETE
;Check to see if player is on raft
	LDA	UNIT_LOC_X,X		;raft
	CMPA	UNIT_LOC_X		;player
	BNE	WARF05
	LDA	UNIT_LOC_Y,X		;raft
	CMPA	UNIT_LOC_Y		;player
	BNE	WARF05
	INC	UNIT_LOC_X		;player
	INC	UNIT_LOC_X,X		;raft
	JSR	RAFT_PLOT
	JSR	CALCULATE_AND_REDRAW
	BRA	WARF5B

WARF05:	
	INC	UNIT_LOC_X,X		;raft
	JSR	RAFT_PLOT
;Now check if it has reached its destination
	JSR	CHECK_FOR_WINDOW_REDRAW
WARF5B:	
	LDX	UNITPRE			Get 16 bit unit #
	LDA	UNIT_LOC_X,X		Get raft's X location
	CMPA	UNIT_C,X		As far right as it can go?
	BEQ	WARF06			Yes, pause it then reverse direction
	LDA	#6			No, stay in this position for 6 ticks before moving again
	STA	UNIT_TIMER_A,X
	JMP	AILP			

WARF06:	
	LDD	#100*256		A=100 (100 ticks to stay in place), B=0 (moving left after pause)
	STA	UNIT_TIMER_A,X
	STB	UNIT_A,X
	JMP	AILP

RAFT_LEFT:
	BSR	RAFT_DELETE		Replace Raft's old location with water tile
;Check to see if player is on raft
	LDA	UNIT_LOC_X,X		Get raft's X location
	CMPA	UNIT_LOC_X		Same as players?
	BNE	WARF07			No, just go move raft left
	LDA	UNIT_LOC_Y,X		Yes, get raft's Y location
	CMPA	UNIT_LOC_Y		Same as players?
	BNE	WARF07			No, just go move raft left
	DEC	UNIT_LOC_X		Yes, move player left
	DEC	UNIT_LOC_X,X		and move raft left
	BSR	RAFT_PLOT		Put Raft tile in new location
	JSR	CALCULATE_AND_REDRAW	Calculate new viewable window position and flag we need a redraw
	BRA	WARF7B			Check if we have hit X limits of raft, set up timers either way, return from there

WARF07:	
	DEC	UNIT_LOC_X,X		move raft left 1
	BSR	RAFT_PLOT		Put Raft tile in new location
;Now check if it has reached its destination
	JSR	CHECK_FOR_WINDOW_REDRAW
WARF7B:	
	LDX	UNITPRE			Get 16 bit unit #
;Now check if it has reached its destination
	LDA	UNIT_LOC_X,X		Get Raft X location
	CMPA	UNIT_B,X		Hit as far left as it will go?
	BEQ	WARF08			Yes, pause it here then start moving to right
	LDA	#6			No, stay in this position for 6 ticks
	STA	UNIT_TIMER_A,X
	JMP	AILP

WARF08:	
	LDD	#100*256+1		A=100 ticks to stay at far left, B=1: direction=right
	STA	UNIT_TIMER_A,X
	STB	UNIT_A,X
	JMP	AILP

; Replace Raft with water at it's current location
RAFT_DELETE:
	LDA	UNIT_LOC_X,X		Get Raft's X location
	LDB	UNIT_LOC_Y,X		Get Raft's Y location
	STD	MAP_X			Save both of them for subroutine
	LDA	#204			WATER TILE
	STA	TILE			Save for subroutine
	JMP 	PLOT_TILE_TO_MAP	Replace Raft tile on map with water tile; return from there

; Replace tile at raft's new location with Raft tile
RAFT_PLOT:
	LDA	UNIT_LOC_X,X		Get Raft's new X location
	LDB	UNIT_LOC_Y,X		Get Raft's new Y location
	STD	MAP_X			Save for subroutine
	LDA	#242			;RAFT TILE
	STA	TILE			Save for subroutine
	JMP 	PLOT_TILE_TO_MAP	Put RAFT tile in rafts new location; return from there

; Routine shrink by 3 bytes (all the branches immediately reload A when they call REQUEST_WALK*):
MAGNETIZED_ROBOT:
	JSR	CHECK_FOR_WINDOW_REDRAW	If old position is on screen, flag for redraw (in case moves off)
	LDA	#1			Flag walking movement for robot
	STA	MOVE_TYPE
	BSR	GENERATE_RANDOM_NUMBER
	LDA	RANDOM
	ANDA	#%00000011  		; only keep 0-3
	DECA				; 1 - request walk down
	BEQ	MAGRO2
	DECA				; 2 - request walk left
	BEQ	MAGRO3
	DECA				; 3 - request walk right
	BEQ	MAGRO4
MAGRO1:	
	JSR	REQUEST_WALK_UP
	BRA	MAGR10

MAGRO2:	
	JSR	REQUEST_WALK_DOWN
	BRA	MAGR10

MAGRO3:	
	JSR	REQUEST_WALK_LEFT
	BRA	MAGR10

MAGRO4:	
	JSR	REQUEST_WALK_RIGHT
MAGR10:	
	JSR	CHECK_FOR_WINDOW_REDRAW
;	LDX	UNITPRE			Get 16 bit Unit #
	LDA	#10			10 ticks until it moves again
	STA	UNIT_TIMER_A,X
	DEC	UNIT_TIMER_B,X		Dec timer until magnet wears off
	LDA	UNIT_TIMER_B,X
	BNE	MAGR11
	LDA	UNIT_D,X
	STA	UNIT_TYPE,X
MAGR11:	
	JMP	AILP

GENERATE_RANDOM_NUMBER:
 	LDA	RANDOM
	BEQ 	DOEOR 			;added this
	ASLA
	BLO	NOEOR
DOEOR:	
	EORA	#$1D
NOEOR:	
	STA	RANDOM
	RTS

;First let's take care of the timers.  This unit runs
;every cycle so that it can detect contact with another
;unit.  But it still needs to count down to terminate
;So, it uses two timers for a 16-bit value.
MAGNET:	
	LDX	UNITPRE			Get 16 bit unit #
	DEC	UNIT_TIMER_B,X
	LDA	UNIT_TIMER_B,X
	BNE	MAGN1
	DEC	UNIT_A,X
	LDA	UNIT_A,X
	BNE	MAGN1
;Both timers have reached zero, time to deactivate.
MAGN0:	
	LDX	UNITPRE			Get 16 bit unit #
	CLR	UNIT_TYPE,X
	CLR	MAGNET_ACT
MAGN2:
	JMP	AILP

;Now let's see if another units walks on the magnet.
MAGN1:
	LDA	UNIT_LOC_X,X		Get unit X,Y location
	LDB	UNIT_LOC_Y,X
	STD	MAP_X			Save for subroutine
	JSR	CHECK_FOR_UNIT		See if player or robot in that spot
	BMI	MAGN2			No, return
	BNE	MAGN4			Robot, go handle
;Player - pick the magnet up
MAGN3:	
	INC	INV_MAGNET		Increase magnets in players inventory
	JSR	DISPLAY_ITEM		Update item display & quantity (if magnet currently selected)
	BRA	MAGN0			Deactivate the magnet unit & back to AI loop

;Collision with robot detected.
MAGN4:
;LDA	#4		;HAYWIRE SOUND
;JSR	PLAY_SOUND	;SOUND PLAY
	LDX	UNIT_FINDPRE		Get 16 bit unit found #
	LDA	UNIT_TYPE,X
	STA	UNIT_D,X		;make backup of unit type
	LDD	#21*256+60		A=21 (Crazy robot AI), B=60 (# ticks before it wears off)
	STA	UNIT_TYPE,X
	STB	UNIT_TIMER_B,X
	BRA	MAGN0			Deactivate the magnet unit & back to AI loop

DEAD_ROBOT:
	LDX	UNITPRE			Get 16 bit unit # of robot
	CLR	UNIT_TYPE,X		type 0=deleted unit
	JMP	AILP

UP_DOWN_ROLLERBOT:
;	LDX	UNITPRE			Get 16 bit unit #
	JSR	CHECK_FOR_WINDOW_REDRAW	If old position is on screen, flag for redraw (in case moves off)
	LDA	#7			7 ticks until next Rollerbot movement/fire update
	STA	UNIT_TIMER_A,X
	JSR	ROLLERBOT_ANIMATE	Switch animation tile # for rollerbots (SHOULD NOT CHANGE X)
	LDA	UNIT_A,X		;GET DIRECTION
	BNE	UDR01			1=DOWN, go handle
; Move ROLLERBOT up
	LDA	#%00000001		Up (0), set move type to walking
	STA	MOVE_TYPE
	JSR	REQUEST_WALK_UP		Returns with A=result (and Z flag set)
	BNE	UDR02			Successful, go move rollerbot up
	LDX	UNITPRE			Not successful, get 16 bit unit #
	LDA	#1
	STA	UNIT_A,X		;CHANGE DIRECTION to DOWN
	BSR	ROLLERBOT_FIRE_DETECT
	JSR	CHECK_FOR_WINDOW_REDRAW
	JMP	AILP

; Move ROLLERBOT down
UDR01:	
	LDA	#%00000001		Down, set move type to walking
	STA	MOVE_TYPE
	JSR	REQUEST_WALK_DOWN	returns with A=result (and Z flag set)
	BNE	UDR02			Successful, go move rollerbot down
	LDX	UNITPRE			Not successful, get 16 bit unit #
	CLR	UNIT_A,X		;CHANGE DIRECTION
UDR02:	
	BSR	ROLLERBOT_FIRE_DETECT
	JSR	CHECK_FOR_WINDOW_REDRAW
	JMP	AILP

LEFT_RIGHT_ROLLERBOT:
;	LDX	UNITPRE			Get 16 bit unit #
	JSR	CHECK_FOR_WINDOW_REDRAW	If old position is on screen, flag for redraw (in case moves off)
	LDA	#7			7 ticks until next Rollerbot movement/fire update
	STA	UNIT_TIMER_A,X
	JSR	ROLLERBOT_ANIMATE
	LDA	UNIT_A,X		GET DIRECTION
	BNE	LRR01			1=right, go handle
; Move Rollerbot Left
	LDA	#%00000001		Left (0), set move type to walking
	STA	MOVE_TYPE
	JSR	REQUEST_WALK_LEFT	Returns with A=result (and Z flag set)
	BNE	LRR02			successful, go move rollerbot left
	LDX	UNITPRE			Not successful, get 16 bit unit #
	LDA	#1
	STA	UNIT_A,X		CHANGE DIRECTION to RIGHT
	BSR	ROLLERBOT_FIRE_DETECT
	JSR	CHECK_FOR_WINDOW_REDRAW
	JMP	AILP

; Move Rollerbot Right
LRR01:	
	LDA	#%00000001		Set move type to walking
	STA	MOVE_TYPE
	JSR	REQUEST_WALK_RIGHT	returns with A=result (and Z flag set)	
	BNE	LRR02			Successful, move rollerbot right
	LDX	UNITPRE			Not successful, get 16 bit unit #
	CLR	UNIT_A,X		CHANGE DIRECTION to LEFT
LRR02:	
	BSR	ROLLERBOT_FIRE_DETECT
	JSR	CHECK_FOR_WINDOW_REDRAW
	JMP	AILP

; Use fallthroughs to shrink 4 bytes
ROLLERBOT_FIRE_DETECT:
	LDA	UNIT_LOC_X,X
	LDB	UNIT_LOC_Y,X
	STD	TEMP_A
;See if we're lined up vertically
	LDA	UNIT_LOC_Y,X		;robot
	CMPA	UNIT_LOC_Y		;player
	BEQ	ROLLERBOT_FIRE_LR
RFDE2:	
;See if we're lined up horizontally
	LDA	UNIT_LOC_X,X		;robot
	CMPA	UNIT_LOC_X		;player
	BEQ	ROLLERBOT_FIRE_UD
RFDE3:	
	RTS

; Multiple optimizations for size/speed (9 bytes smaller):
ROLLERBOT_FIRE_LR:
	LDA	UNIT_LOC_X,X		Get Rollerbot X coord
	CMPA	UNIT_LOC_X		Is player X location left or right of Rollerbot?
	BLS	ROLLERBOT_FIRE_RIGHT   	player is to right, so fire in that direction
ROLLERBOT_FIRE_LEFT:
;Check to see if distance is less than 5
	LDA	UNIT_LOC_X,X		Get robot X coord
	SUBA	UNIT_LOC_X		subtract player X coord
	CMPA	#6			If distance between them <6?
	BLO	RFL0			Yes, go find empty weapon unit slot
	RTS				otherwise, return

RFL0:	
	LDX	#28
RFL1:	
	LDA	UNIT_TYPE,X
	BEQ	RFL2
	LEAX	1,X
	CMPX	#32
	BNE	RFL1
	RTS
RFL2:	
	LDD	#14*256+245		A=14 (pistol fire left AI),B=245 (vertical shot tile #)
	BRA	ROLLERBOT_AFTER_FIRE
	
ROLLERBOT_FIRE_RIGHT:
;Check to see if distance is less than 5
	LDA	UNIT_LOC_X		;player
	SUBA	UNIT_LOC_X,X		;robot
	CMPA	#6
	BLO	RFR0
	RTS	

RFR0:	
	LDX	#28
RFR1:	
	LDA	UNIT_TYPE,X
	BEQ	RFR2
	LEAX	1,X
	CMPX	#32
	BNE	RFR1
	RTS

RFR2:	
	LDD	#15*256+245		A=15 (pistol fire RIGHT AI),B=245 (vertical shot tile #)
	BRA	ROLLERBOT_AFTER_FIRE
	
ROLLERBOT_FIRE_UD:
	LDA	UNIT_LOC_Y,X		Get rollerbot Y coord
	CMPA	UNIT_LOC_Y		Is player Y coord > then rollerbot's?
	BLS	ROLLERBOT_FIRE_DOWN 	Yes, will be firing down	
ROLLERBOT_FIRE_UP:
;Check to see if distance is less than 5
	LDA	UNIT_LOC_Y,X		;robot
	SUBA	UNIT_LOC_Y		;player
	CMPA	#4
	BLO	RFU0
	RTS	

RFU0:	
	LDX	#28
RFU1:	
	LDA	UNIT_TYPE,X
	BEQ	RFU2
	LEAX	1,X
	CMPX	#32
	BNE	RFU1
	RTS

RFU2:	
	LDD	#12*256+244		A=12 (pistol fire UP AI), B=244 (horizontal shot tile #)
	BRA	ROLLERBOT_AFTER_FIRE
	
ROLLERBOT_FIRE_DOWN:
;Check to see if distance is less than 5
	LDA	UNIT_LOC_Y		;player
	SUBA	UNIT_LOC_Y,X		;robot
	CMPA	#4
	BLO	RFD0
	RTS	

RFD0:	
	LDX	#28
RFD1:	
	LDA	UNIT_TYPE,X
	BEQ	RFD2
	LEAX	1,X
	CMPX	#32
	BNE	RFD1
	RTS
RFD2:	
	LDD	#13*256+244		A=13 (pistol fire DOWN AI), B=244 (horizontal shot tile #)
ROLLERBOT_AFTER_FIRE:
	STA	UNIT_TYPE,X
	STB	UNIT_TILE,X
	LDA	#5			;travel distance.
	STA	UNIT_A,X
	CLRA				;weapon-type = pistol
	STA	UNIT_B,X
	STA	UNIT_TIMER_A,X
	LDA	TEMP_A
	STA	UNIT_LOC_X,X
	LDA	TEMP_B
	STA	UNIT_LOC_Y,X
;LDA	#9			;PISTOL SOUND
;JSR	PLAY_SOUND		;SOUND PLAY
	RTS

ROLLERBOT_ANIMATE:
	LDA	UNIT_TIMER_B,X
	BEQ	ROLAN2
	DEC	UNIT_TIMER_B,X
	RTS

ROLAN2:	
	LDA	#3
	STA	UNIT_TIMER_B,X		;RESET ANIMATE TIMER
	LDA	UNIT_TILE,X
	CMPA	#164
	BNE	ROLAN1
	LDA	#165			;ROLLERBOT TILE
	STA	UNIT_TILE,X
	JMP	CHECK_FOR_WINDOW_REDRAW

ROLAN1:	
	LDA	#164			;ROLLERBOT TILE
	STA	UNIT_TILE,X
	JMP	CHECK_FOR_WINDOW_REDRAW

;UNIT_A: 0=always active		1=only active when all robots are dead
;UNIT_B: 0=completes level 1=send to coordinates
;UNIT_C: X-coordinate
;UNIT_D: Y-coordinate

;The "DEMATERIALIZE" part of this AI routine has to be in the main 
;source for each individual computer, because the screen effects
;are created uniquely for each one.

TRANSPORTER_PAD:
;first determine if the player is standing here
	LDX	UNITPRE			Get 16 bit unit #
	LDA	UNIT_LOC_X,X
	CMPA	UNIT_LOC_X
	BNE	TRP01
	LDA	UNIT_LOC_Y,X
	CMPA	UNIT_LOC_Y
	BEQ	TRANS_PLAYER_PRESENT
TRP01:	;player not present
	LDA	UNIT_A,X
	CMPA	#1
	BNE	TRANS_ACTIVE
; LCB NOTE: Should be able to do this in reverse order (LDX #27 / LEAX -1,X / BNE TRP03)?
TRP02:	;test if all robots are dead
	LDX	#1
TRP03:	
	LDA	UNIT_TYPE,X
	BNE	TRP04
	LEAX	1,X
	CMPX	#28
	BNE	TRP03
	LDX	UNITPRE			Get 16 bit unit #
	STA	UNIT_A,X		;make unit active
TRP04:
	LDX	UNITPRE			Get 16 bit unit #
	LDA	#30
	STA	UNIT_TIMER_A,X
	JMP	AILP			

TRANS_PLAYER_PRESENT:
	LDX	UNITPRE			Get 16 bit unit #
	LDA	UNIT_A,X
;unit active
	BEQ	TRPL1
	LDY	#MSG_TRANS1
	JSR	PRINT_INFO
;LDA	#11		;error-SOUND
;JSR	PLAY_SOUND	;SOUND PLAY
	LDX	UNITPRE			Get 16 bit unit #
	LDA	#100
	STA	UNIT_TIMER_A,X
	JMP	AILP

TRPL1:	;start transport process
	LDA	#23			;Convert to different AI
	STA	UNIT_TYPE,X
	LDA	#5
	STA	UNIT_TIMER_A,X
	CLRA
	STA	UNIT_TIMER_B,X
	JMP	AILP

TRANS_ACTIVE:
	LDA	UNIT_TIMER_B,X
	CMPA	#1
	BEQ	TRAC1
	LDA	#1
	STA	UNIT_TIMER_B,X
	LDA	#30
	STA	TILE
	BRA	TRAC2
TRAC1:	
  CLRA
	STA	UNIT_TIMER_B,X
	LDA	#31
	STA	TILE
TRAC2:	
	LDA	UNIT_LOC_X,X
	STA	MAP_X
	LDA	UNIT_LOC_Y,X
	STA	MAP_Y
	JSR	PLOT_TILE_TO_MAP
	JSR	CHECK_FOR_WINDOW_REDRAW
	LDA	#30
	STA	UNIT_TIMER_A,X
	JMP	AILP

TIME_BOMB:
	LDX	UNITPRE			Get 16 bit unit #
	LDA	UNIT_A,X		Get which phase (0=phase 1, 1=phase 2) the explosion is in
	BEQ	BIG_EXP_PHASE1		0=Phase 1, go handle
TB01:	
	DECA
	LBEQ	BIG_EXP_PHASE2		1=Phase 2, go handle
TB02:	
	JMP	AILP			Illegal phase value, just return

;This is the large explosion used by the time-bomb
;and plasma gun, and maybe others.  This is the first
;phase of the explosion, which stores the tiles to
;a buffer and then changes each tile to an explosion.

; THE WAY THIS KEEPS TRACK OF WHAT TILES ARE PART OF AN EXPLOSION IS BY THE FACT THAT IT HAS REPLACED EACH TILE
; THAT CAN HOST AN EXPLOSION WITH TILE #246. RESTORE_TILE CHECKS FOR THIS; IF THE TILES IS NOT A 246, IT KNOWS
; TO SKIP CHECKING EXP_BUFFER FOR THE CORRESPONDING POSITION, SINCE IT COULDN'T SET AN EXPLOSION TILE THERE IN
; THE FIRST PLACE (IE A WALL OR SOME OTHER IMPASSABLE OBJECT).
BIG_EXP_PHASE1:
	LDA	BIG_EXP_ACT		;Big Explosion already active?
;Check that no other explosion active.
	BEQ	BEX001			No, start one up
	LDX	UNITPRE			Get 16 bit unit #
	LDA	#10
	STA	UNIT_TIMER_A,X
	JMP	AILP			wait for existing explosion to finish.

BEX001:
	LDA	#1			;Set flag so no other explosions
	STA	BIG_EXP_ACT		;can begin until this one ends.
	STA	SCREEN_SHAKE
; Copy center of explosion coordinates to DP for faster access (since we copy them multiple times)
	LDX	UNITPRE			Get 16 bit unit #
	LDA	UNIT_LOC_X,X		Get it's X,Y location
	LDB	UNIT_LOC_Y,X
	STD	BIGEXP_CENTER		Save fast access copy
;CLRA	;explosion-sound
;JSR	PLAY_SOUND	;SOUND PLAY
	JSR	BEX_PART1		;Copy UNIT_LOC_X,UNIT_LOC_Y to MAP_X,MAP_Y
	JSR	BEXCEN			;Check if player or robot on that spot (Saves in UNIT_FIND)
	BSR	BEX1_NORTH		;Attempt explosion 1 tile up, damage player or robot if present
	BSR	BEX1_SOUTH
	BSR	BEX1_EAST
	JSR	BEX1_WEST
	JSR	BEX1_NE
	JSR	BEX1_NW
	JSR	BEX1_SE
	JSR	BEX1_SW
	LDX	UNITPRE			Get 16 bit unit #
	LDD	#246*256+12		A=246 (explosion tile),B=12 (# ticks before next explosion phase)
	STA	UNIT_TILE,X
	STB	UNIT_TIMER_A,X
	LDA	#1			;move to next phase of explosion.
	STA	UNIT_A,X
	STA	REDRAW_WINDOW
	JMP	AILP

;There are 8 separate subroutines for the large explosion
;with each one handling a specific outward direction of motion.
;The "unit" itself changes tiles to an explosion, so we don't
;need to mess with the center tile.
; LCB NOTE: Since we constantly reload MAP_X,MAP_Y from UNIT_LOC_X,UNIT_LOC_Y (8 times, based on UNIT), copy them over to
; TEMP_D or similar at beginning here. Then just do LDD TEMP_D / STD MAP_X / RTS in BEX_PART1
BEX1_NORTH:
	JSR	BEX_PART1		Copy coords of explosion center to MAP_X,MAP_Y
;first tile
	DEC	MAP_Y			Y coord up 1 from center
	JSR	BEX_PART2		Get tile # there to <TILE, check if see through bit set for that tile #
	BNE	BEX1N1			Bit is set (can see through it), continue with explosion in this direction
	RTS				Bit is clear, explosion stops in this direction

BEX1N1:	
	LDA	TILE			Get original tile # for CENTER X, CENTER Y-1
	STA	EXP_BUFFER+0		Save in explosion buffer slot 0
	JSR	BEX_PART3		change tile to 246 (Explosion). If player/robot at location, inflict 11 damage
;second tile
	DEC	MAP_Y			Y coord up 2 from center
	JSR	BEX_PART2		Get tile # there to <TILE, check if 'see through' bit set for that tile #	BNE	BEX1N2			Bit is set (can see through it), continue with explosion in this direction	RTS				Bit is clear, explosion stops in this direction

BEX1N2:	
	LDA	TILE			Get original tile # for CENTER X,CENTER Y-2
	STA	EXP_BUFFER+1		Save in explosion buffer slot 1
	JMP	BEX_PART3		change tile to 246 (Explosion). If player/robot at location, inflict 11 damage. Return from there

;---
BEX1_SOUTH:
	JSR	BEX_PART1		Copy coords of explosion center to MAP_X,MAP_Y;first tile
	INC	MAP_Y			Y coord down 1 from center
	JSR	BEX_PART2		Get tile # there to <TILE, check if 'see through' bit set for that tile #	BNE	BEX1S1			Bit is set (can see through it), continue with explosion in this direction	
	RTS				Bit is clear, explosion stops in this direction

BEX1S1:	
	LDA	TILE			Get original tile # for CENTER X,CENTER Y+1	STA	EXP_BUFFER+2		Save in explosion buffer slot 2	JSR	BEX_PART3		change tile to 246 (Explosion). If player/robot at location, inflict 11 damage.
;second tile
	INC	MAP_Y			Y coord down 2 from center
	JSR	BEX_PART2		Get tile # there to <TILE, check if 'see through' bit set for that tile #
	BNE	BEX1S2			Bit is set (can see through it), continue with explosion in this direction
	RTS				Bit is clear, explosion stops in this direction

BEX1S2:	
	LDA	TILE			Get original tile # for CENTER X,CENTER Y+2
	STA	EXP_BUFFER+3		Save in explosion buffer slot 3
	JMP	BEX_PART3		change tile to 246 (Explosion). If player/robot at location, inflict 11 damage. Return from there	

;---
BEX1_EAST:
	JSR	BEX_PART1		Copy coords of explosion center to MAP_X,MAP_Y
;first tile
	INC	MAP_X			X coord right 1 from center
	JSR	BEX_PART2		Get tile # there to <TILE, check if 'see through' bit set for that tile #
	BNE	BEX1E1			Bit is set (can see through it), continue with explosion in this direction
	RTS				Bit is clear, explosion stops in this direction

BEX1E1:	
	LDA	TILE			Get original tile # for CENTER X+1,CENTER Y
	STA	EXP_BUFFER+4		Save in explosion buffer slot 4
	JSR	BEX_PART3		change tile to 246 (Explosion). If player/robot at location, inflict 11 damage.
;second tile
	INC	MAP_X			X coord right 2 from center
	JSR	BEX_PART2		Get tile # there to <TILE, check if 'see through' bit set for that tile #
	BNE	BEX1E2			Bit is set (can see through it), continue with explosion in this direction
	RTS				Bit is clear, explosion stops in this direction

BEX1E2:	
	LDA	TILE			Get original tile # for CENTER X+2,CENTER Y
	STA	EXP_BUFFER+5		Save in explosion buffer slot 5
	JMP	BEX_PART3		change tile to 246 (Explosion). If player/robot at location, inflict 11 damage. Return from there
;---
BEX1_WEST:
	JSR	BEX_PART1		Copy coords of explosion center to MAP_X,MAP_Y
;first tile
	DEC	MAP_X			X coord left 1 from center
	JSR	BEX_PART2		Get tile # there to <TILE, check if 'see through' bit set for that tile #
	BNE	BEX1W1			Bit is set (can see through it), continue with explosion in this direction
	RTS				Bit is clear, explosion stops in this direction

BEX1W1:	
	LDA	TILE			Get original tile # for CENTER X-1,CENTER Y
	STA	EXP_BUFFER+6		Save in explosion buffer slot 6
	JSR	BEX_PART3		change tile to 246 (Explosion). If player/robot at location, inflict 11 damage.
;second tile
	DEC	MAP_X			X coord left 2 from center
	JSR	BEX_PART2		Get tile # there to <TILE, check if 'see through' bit set for that tile #
	BNE	BEX1W2			Bit is set (can see through it), continue with explosion in this direction
	RTS				Bit is clear, explosion stops in this direction

BEX1W2:	
	LDA	TILE			Get original tile # for CENTER X-2,CENTER Y
	STA	EXP_BUFFER+7		Save in explosion buffer slot 7
	JMP	BEX_PART3		change tile to 246 (Explosion). If player/robot at location, inflict 11 damage. Return from there	

;---
BEX1_NE:
	BSR	BEX_PART1		Copy coords of explosion center to MAP_X,MAP_Y
;first tile
	INC	MAP_X			X coord right 1 from center
	DEC	MAP_Y			Y coord up 1 from center
	BSR	BEX_PART2		Get tile # there to <TILE, check if 'see through' bit set for that tile #
	BNE	BEX1NE1			Bit is set (can see through it), continue with explosion in this direction
	RTS				Bit is clear, explosion stops in this direction

BEX1NE1:
	LDA	TILE			Get original tile # for CENTER X+1,CENTER Y-1
	STA	EXP_BUFFER+8		Save in explosion buffer slot 8
	JSR	BEX_PART3		change tile to 246 (Explosion). If player/robot at location, inflict 11 damage.
;second tile
	INC	MAP_X			X coord right 2 from center
	DEC	MAP_Y			Y coord up 2 from center
	BSR	BEX_PART2		Get tile # there to <TILE, check if 'see through' bit set for that tile #	
	BNE	BEX1NE2			Bit is set (can see through it), continue with explosion in this direction
	RTS				Bit is clear, explosion stops in this direction

BEX1NE2:
	LDA	TILE			Get original tile # for CENTER X+2,CENTER Y-2
	STA	EXP_BUFFER+9		Save in explosion buffer slot 9
	BRA	BEX_PART3		change tile to 246 (Explosion). If player/robot at location, inflict 11 damage. Return from there

;---
BEX1_NW:
	BSR	BEX_PART1		Copy coords of explosion center to MAP_X,MAP_Y
;first tile
	DEC	MAP_X			X coord left 1 from center
	DEC	MAP_Y			Y coord up 1 from center
	BSR	BEX_PART2		Get tile # there to <TILE, check if 'see through' bit set for that tile #
	BNE	BEX1NW1			Bit is set (can see through it), continue with explosion in this direction
	RTS				Bit is clear, explosion stops in this direction

BEX1NW1:
	LDA	TILE			Get original tile # for CENTER X-1,CENTER Y-1
	STA	EXP_BUFFER+10		Save in explosion buffer slot 10
	BSR	BEX_PART3		change tile to 246 (Explosion). If player/robot at location, inflict 11 damage.
;second tile
	DEC	MAP_X			X coord left 2 from center
	DEC	MAP_Y			Y coord up 2 from center
	BSR	BEX_PART2		Get tile # there to <TILE, check if 'see through' bit set for that tile #
	BNE	BEX1NW2			Bit is set (can see through it), continue with explosion in this direction
	RTS				Bit is clear, explosion stops in this direction

BEX1NW2:
	LDA	TILE			Get original tile # for CENTER X-2,CENTER Y-2
	STA	EXP_BUFFER+11		Save in explosion buffer slot 11
	BRA	BEX_PART3		change tile to 246 (Explosion). If player/robot at location, inflict 11 damage. Return from there	

;---
BEX1_SE:
	BSR	BEX_PART1		Copy coords of explosion center to MAP_X,MAP_Y
;first tile
	INC	MAP_X			X coord right 1 from center
	INC	MAP_Y			Y coord down 1 from center
	BSR	BEX_PART2		Get tile # there to <TILE, check if 'see through' bit set for that tile #
	BNE	BEX1SE1			Bit is set (can see through it), continue with explosion in this direction
	RTS				Bit is clear, explosion stops in this direction

BEX1SE1:
	LDA	TILE			Get original tile # for CENTER X+1,CENTER Y+1
	STA	EXP_BUFFER+12		Save in explosion buffer slot 12
	BSR	BEX_PART3		change tile to 246 (Explosion). If player/robot at location, inflict 11 damage.
;second tile
	INC	MAP_X			X coord right 2 from center
	INC	MAP_Y			Y coord down 2 from center
	BSR	BEX_PART2		Get tile # there to <TILE, check if 'see through' bit set for that tile #
	BNE	BEX1SE2			Bit is set (can see through it), continue with explosion in this direction
	RTS				Bit is clear, explosion stops in this direction

BEX1SE2:
	LDA	TILE			Get original tile # for CENTER X+2,CENTER Y+2
	STA	EXP_BUFFER+13		Save in explosion buffer slot 13
	BRA	BEX_PART3		change tile to 246 (Explosion). If player/robot at location, inflict 11 damage. Return from there

;---
BEX1_SW:
	BSR	BEX_PART1		Copy coords of explosion center to MAP_X,MAP_Y
;first tile
	DEC	MAP_X			X coord left 1 from center
	INC	MAP_Y			Y coord down 1 from center
	BSR	BEX_PART2		Get tile # there to <TILE, check if 'see through' bit set for that tile #
	BNE	BEX1SW1			Bit is set (can see through it), continue with explosion in this direction
	RTS				Bit is clear, explosion stops in this direction

BEX1SW1:
	LDA	TILE			Get original tile # for CENTER X-1,CENTER Y+1
	STA	EXP_BUFFER+14		Save in explosion buffer slot 14
	BSR	BEX_PART3		change tile to 246 (Explosion). If player/robot at location, inflict 11 damage.
;second tile
	DEC	MAP_X			X coord left 2 from center
	INC	MAP_Y			Y coord down 2 from center
	BSR	BEX_PART2		Get tile # there to <TILE, check if 'see through' bit set for that tile #
	BNE	BEX1SW2			Bit is set (can see through it), continue with explosion in this direction
	RTS				Bit is clear, explosion stops in this direction

BEX1SW2:
	LDA	TILE			Get original tile # for CENTER X-2,CENTER Y+2
	STA	EXP_BUFFER+15		Save in explosion buffer slot 15
	BRA	BEX_PART3		change tile to 246 (Explosion). If player/robot at location, inflict 11 damage. Return from there
	
; LCB NOTE - see my note above. Since this is called 8 times, pre-copy the center coords before going through
; the 8 directions to TEMP_D (or similar). Then this routine simply becomes LDD TEMP_D / STD MAP_X / RTS
BEX_PART1:
	LDD	BIGEXP_CENTER		Get fast access center X,Y of explosion
	STD	MAP_X			Save as origin location of all explosion directions & return
	RTS

; LCB NOTE: CAN LIKELY USE X HERE INSTEAD OF Y, SAVING A CYCLE/BYTE.
BEX_PART2:
	JSR	GET_TILE_FROM_MAP	Get tile # from MAP_X,MAP_Y
	LDY	TILEPRE			Get 16 bit tile #
	LDA	TILE_ATTRIB,Y		Get attributes of tile
	ANDA	#%00010000		See through tile flag set? (means explosion can go through it too)
EPT2:	
	RTS				Return with compare flags set

BEX_PART3:
	LDA	#246			Explosion tile
	STA	TILE			Save for subroutine
	JSR	PLOT_TILE_TO_MAP	replace tile in map with explosion tile
BEXCEN:	
	JSR	CHECK_FOR_UNIT		See if player or robot also at that location (MAP_X,MAP_Y)
	BMI	EPT2			Neither, return
	LDA	#11			Yes, 11 damage
	STA	TEMP_A
	JMP	INFLICT_DAMAGE		Go inflict that damage & return

;-------------------------------------------
BIG_EXP_PHASE2:
;Do the center tile first.
	BSR	BEX_PART1		Copy coords of explosion center to MAP_X,MAP_Y
	JSR	GET_TILE_FROM_MAP	Get tile # at that position in map into TILE (probably into B later automatically too)
	LDB	TILE			Get tile to preserve
	LDA	#246			Explosion tile
	STB	TEMP_A			Back up the original tile
	STA	TILE			Save for subroutine
	JSR	PLOT_TILE_TO_MAP	Replace with explosion tile in map (MAP_X,MAP_Y)
;Get tile # from MAP_X,MAP_Y into <TILE ??? we just replaced it? Checks is 246 (explosion), if it is, checks if
; original tile (saved in TEMP_A) was a cannister; if not, checks attributes to see if it can be destroyed. If it
; is destroyable, replace tile in map with tile lookup from DESTRUCT_PATH (what tile replaces original when blowed
; up real good). If it was a cannister, it will replace the cannister tile with an exploded cannister tile, and then
; setup a Bomb explosion in the weapons units if possible (remember, 4 max bullets, explosions at a time). If not
; possible, it just returns. If successful, sets a 10 tick delay for cannister explosion to start.
	JSR	RESTORE_TILE		Check what to do with tile explosion is on (like delayed cannister explosion). Replace tile with appropriate post explosion tile 
;tile #0 north 1
	BSR	BEX_PART1		Copy coords of explosion center to MAP_X,MAP_Y
	DEC	MAP_Y			Y coord up 1 from center
	LDA	EXP_BUFFER+0		Get original tile from that location
	STA	TEMP_A			Save in temp for subroutine
	JSR	RESTORE_TILE		Check what to do with tile explosion is on (like delayed cannister explosion). Replace tile with appropriate post explosion tile	
;tile #1 north 2
	DEC	MAP_Y			Y coord 2 up from center
	LDA	EXP_BUFFER+1
	STA	TEMP_A
	JSR	RESTORE_TILE
;tile #2 south 1
	BSR	BEX_PART1		Copy coords of explosion center to MAP_X,MAP_Y
	INC	MAP_Y			Y coord 1 down from center 
	LDA	EXP_BUFFER+2
	STA	TEMP_A
	JSR	RESTORE_TILE	
;tile #3 south 2
	INC	MAP_Y			Y coord 2 down from center
	LDA	EXP_BUFFER+3
	STA	TEMP_A
	JSR	RESTORE_TILE
;tile #4 east 1
	BSR	BEX_PART1		Copy coords of explosion center to MAP_X,MAP_Y
	INC	MAP_X			X coord 1 right from center
	LDA	EXP_BUFFER+4
	STA	TEMP_A
	JSR	RESTORE_TILE
;tile #5 east 2
	INC	MAP_X			X coord 2 right from center
	LDA	EXP_BUFFER+5
	STA	TEMP_A
	BSR	RESTORE_TILE
;tile #6 west 1
	BSR	BEX_PART1		Copy coords of explosion center to MAP_X,MAP_Y
	DEC	MAP_X			X coord 1 left from center
	LDA	EXP_BUFFER+6
	STA	TEMP_A
	BSR	RESTORE_TILE
;tile #7 west 2
	DEC	MAP_X			X coord 2 left from center
	LDA	EXP_BUFFER+7
	STA	TEMP_A
	BSR	RESTORE_TILE
;tile #8 northeast 1
	JSR	BEX_PART1		Copy coords of explosion center to MAP_X,MAP_Y
	DEC	MAP_Y			Y coord 1 up from center
	INC	MAP_X			X coord 1 right from center
	LDA	EXP_BUFFER+8
	STA	TEMP_A
	BSR	RESTORE_TILE
;tile #9 northeast 2
	DEC	MAP_Y			Y coord 2 up from center
	INC	MAP_X			X coord 2 right from center
	LDA	EXP_BUFFER+9
	STA	TEMP_A
	BSR	RESTORE_TILE
;tile #10 northwest 1
	JSR	BEX_PART1		Copy coords of explosion center to MAP_X,MAP_Y
	DEC	MAP_Y			Y coord 1 up from center
	DEC	MAP_X			X coord 1 left from center
	LDA	EXP_BUFFER+10
	STA	TEMP_A
	BSR	RESTORE_TILE
;tile #11 northwest 2
	DEC	MAP_Y			Y coord 2 up from center
	DEC	MAP_X			X coord 2 left from center
	LDA	EXP_BUFFER+11
	STA	TEMP_A
	BSR	RESTORE_TILE
;tile #12 southeast 1
	JSR	BEX_PART1		Copy coords of explosion center to MAP_X,MAP_Y
	INC	MAP_Y			Y coord 1 down from center
	INC	MAP_X			X coord 1 right from center
	LDA	EXP_BUFFER+12
	STA	TEMP_A
	BSR	RESTORE_TILE
;tile #13 southeast 2
	INC	MAP_Y			Y coord 2 down from center
	INC	MAP_X			X coord 2 right from center
	LDA	EXP_BUFFER+13
	STA	TEMP_A
	BSR	RESTORE_TILE
;tile #14 southwest 1
	JSR	BEX_PART1		Copy coords of explosion center to MAP_X,MAP_Y
	INC	MAP_Y			Y coord 1 down from center
	DEC	MAP_X			X coord 1 left from center
	LDA	EXP_BUFFER+14
	STA	TEMP_A
	BSR	RESTORE_TILE
;tile #15 southwest 2
	INC	MAP_Y			Y coord 2 down from center
	DEC	MAP_X			X coord 2 left from center
	LDA	EXP_BUFFER+15
	STA	TEMP_A
	BSR	RESTORE_TILE
	LDA	#1			Set flag that we need to redraw viewable map
	STA	REDRAW_WINDOW
	LDX	UNITPRE			Get 16 bit unit #
	CLR	UNIT_TYPE,X		Deactivate this AI
	CLR	BIG_EXP_ACT		No active big explosion
	CLR	SCREEN_SHAKE		Shake the screen (not implemented yet)
	JMP	AILP

; Restore preserved tile (from TEMP_A) to map *IF* the current map tile is an explosion tile (246).
; If it is not, just return
; There are some special overrides (like changing a normal cannister to an exploded one), and that
; particular case will also instigate a delayed (10 tick) explosion of the cannister itself
RESTORE_TILE:
	JSR	GET_TILE_FROM_MAP	Get tile from MAP_X,MAP_Y into <TILE & A
	CMPA	#246			Explosion tile?
	BEQ	REST0			Yes, go restore original tile
	RTS				No, return
	
REST0:
	LDB	TEMP_A			Get original tile #
	CMPB	#131			Cannister tile?
	BEQ	REST3			Yes, need special handling for that one
	CLRA
	TFR	D,Y			Y=original tile #
	LDA	TILE_ATTRIB,Y		Get attributes for that tile
	ANDA	#%00001000		can it be destroyed?
	BEQ	REST2			No, just restore original tile
; Tile can be destroyed; look up the tile # to replace it with from table
	LDA	DESTRUCT_PATH,Y		Yes, get the tile # from "destroyed tile conversion table" to change it to
	STA	TILE			Save for subroutine
	JMP	PLOT_TILE_TO_MAP	Replace this spot with the new tile #

; Tile can not be destroyed, just replace the tile as it was
REST2:	
	LDA	TEMP_A			Get saved tile
	STA	TILE			Put in for subroutine
	JMP	PLOT_TILE_TO_MAP	Put saved tile back into map

;What to do if we encounter an explosive cannister
REST3:
	LDA	#135			Blown cannister tile
	STA	TILE			Put it in map at MAP_X,MAP_Y
	JSR	PLOT_TILE_TO_MAP
	LDX	#28			Start of weapons units
; Find a free weapon unit (max 4) if we can. Change the unit details to kick in the BOMB AI after 10 ticks
; from the cannister tile location
REST4:	
	LDA	UNIT_TYPE,X		Active weapon?
	BEQ	REST5			BUG FIX; WAS BNE. No, go add explosive cannister into this unit #
	LEAX	1,X			Yes, point to next one
	CMPX	#32			Done all 4 possible active weapons at a time?
	BNE	REST4			No, try next one
	RTS				Yes, no slots available right now, abort.

REST5:	
; LCB NOTE: Some LDD and/or STD opportunities here (like MAP_X/Y)
	LDD	#6*256+131		A=bomb AI, B=cannister tile
	STA	UNIT_TYPE,X
	STB	UNIT_TILE,X
	LDD	MAP_X			Copy our current X,Y coords to unit's		
	STA	UNIT_LOC_X,X
	STB	UNIT_LOC_Y,X
	LDD	#10*256			A=10 ticks until explosion, B=Big explosion phase 1 (B=0)
	STA	UNIT_TIMER_A,X
	STB	UNIT_A,X
	RTS

TC_CLOSED_STATE:
	LDD	#146*256+147
	STD	TCPIECE1
	LDD	#150*256+151
	STD	TCPIECE3
	BSR	DRAW_TRASH_COMPACTOR
	INC	UNIT_A,X
	LDA	#10
	STA	UNIT_TIMER_A,X	
	JMP	AILP

TC_MID_OPENING:
	LDD	#144*256+144
	STD	TCPIECE1
	LDD	#148*256+148
	STD	TCPIECE3
	BSR	DRAW_TRASH_COMPACTOR	
	CLR	UNIT_A,X
	LDA	#20
	STA	UNIT_TIMER_A,X
;LDA	#14		;door sound
;JSR	PLAY_SOUND	;SOUND PLAY	
	JMP	AILP

DRAW_TRASH_COMPACTOR:
; (2x2 tiles):
	LDB	UNIT_LOC_Y,X
	DECB				;start one tile above
	LDA	UNIT_LOC_X,X
	STD	MAP_X			Save working X,Y
	LDA	TCPIECE1
	STA	TILE
	JSR	PLOT_TILE_TO_MAP	Change tile in map
	INC	MAP_X			Next to right
	LDA	TCPIECE2
	STA	TILE
	JSR	PLOT_TILE_TO_MAP	Change 2nd tile in map
;ADDA #127
	LDA	TCPIECE3
	STA	TILE
	DEC	MAP_X			down 1, let 1
	INC	MAP_Y
	JSR	PLOT_TILE_TO_MAP	Change 3rd tile in map
	LDA	TCPIECE4
	INC	MAP_X			Next to right
	STA	TILE
	JSR	PLOT_TILE_TO_MAP	And 4th tile map
	JMP	CHECK_FOR_WINDOW_REDRAW	Flag for redraw if trash compactor on viewable window; return from there

TRASH_COMPACTOR:
	LDX	UNITPRE			Get 16 bit unit #
	LDA	UNIT_A,X		Get current opening/closing state of compactor
; LCB NOTE: Might be able to use DECA trick to shrink these branches, and can change branches for fall throughs
;OPEN
	BEQ	TC_OPEN_STATE		0=Open state, go handle
TRS01:	
	DECA				1=Mid-Closing state?
	BEQ	TC_MID_CLOSING		Yes, go handle
TRS02:	
	DECA				2=Closed state?
	BEQ	TC_CLOSED_STATE		Yes, go handle
TRS03:	
	DECA				3=Mid-opening state?
	BEQ	TC_MID_OPENING		Yes, go handle
	JMP	AILP			Anything else is illegal (should never get here), so ignore

TC_OPEN_STATE:
	LDA	UNIT_LOC_X,X		Copy unit's X,Y coords to MAP_X,MAP_Y for subroutine
	LDB	UNIT_LOC_Y,X
	STD	MAP_X
	JSR	GET_TILE_FROM_MAP
	CMPA	#148			Usual tile for trash compactor danger zone
	BNE	TRS15
TRS10:	
	INC	MAP_X			Move check X coord 1 to right
	JSR	GET_TILE_FROM_MAP	Get tile # from map at that location
	CMPA	#148			Is it the usual tile for trash compactor danger zone?
	BNE	TRS15			No, something in compactor, go start closing it
	LDA	#20			Yes, Set timer to 20 ticks
	STA	UNIT_TIMER_A,X
;now check for units in the compactor
	LDA	UNIT_LOC_X,X		Copy unit X,Y location to MAP_X/Y for subroutine
	LDB	UNIT_LOC_Y,X
	STD	MAP_X
	JSR	CHECK_FOR_UNIT		See if player or robot in that spot
	BPL	TRS15			Yes, go handle
	JMP	AILP			Nothing found, so do nothing & return

TRS15:	
;Object has been detected in TC, start closing.
	LDD	#146*256+147
	STD	TCPIECE1
	LDD	#150*256+151
	STD	TCPIECE3
	JSR	DRAW_TRASH_COMPACTOR
	INC	UNIT_A,X
	LDA	#10
	STA	UNIT_TIMER_A,X	
;LDA	#14		;door sound
;JSR	PLAY_SOUND	;SOUND PLAY
	JMP	AILP

TC_MID_CLOSING:
	LDD	#152*256+153		tiles 152/153
	STD	TCPIECE1		Save them
	LDD	#156*256+157		tiles 156/157
	STD	TCPIECE3		Save them
	JSR	DRAW_TRASH_COMPACTOR	Draw trash compactor
	INC	UNIT_A,X
	LDA	#50			Set A timer to 50 ticks
	STA	UNIT_TIMER_A,X
;Now check for any live units in the compactor
	LDA	UNIT_LOC_X,X		Copy unit X,Y location to MAP_X/Y for subroutine
	LDB	UNIT_LOC_Y,X
	STD	MAP_X
	JSR	CHECK_FOR_UNIT		See if player or robot in that spot
	BPL	TCMC1			Yes, go handle
	INC	MAP_X			check second tile (to right of 1st)
	JSR	CHECK_FOR_UNIT		See if player or robot in that spot
	BPL	TCMC1			Yes, go handle
	JMP	AILP			No, just return

;Found unit in compactor, kill it.
TCMC1:
	LDY	#MSG_TERMINATED		Print "you're terminated!"
	JSR	PRINT_INFO
;CLRA	;EXPLOSION sound
;JSR	PLAY_SOUND	;SOUND PLAY
	LDX	UNIT_FINDPRE		Get 16 bit unit #
	CLR	UNIT_TYPE,X		Erase unit type
	CLR	UNIT_HEALTH,X		And it's health
	LDX	#28			start of weapons
TCMC2:	
	LDA	UNIT_TYPE,X		Is this slot active?
	BEQ	TCMC3			No, go add a small explosion
	LEAX	1,X			Yes, onto next one
	CMPX	#32		 	Done checking all 4 slots?
	BNE	TCMC2			No, keep going
	JSR	CHECK_FOR_WINDOW_REDRAW	Yes, check if unit on viewable window, flag redraw if needed, & return
	JMP	AILP

TCMC3:	
	LDD	#11*256+248		A=11 (Set AI type to small explosion), B=248 (first tile # for explosion)
	STA	UNIT_TYPE,X
	STB	UNIT_TILE,X
	LDY	UNITPRE			Get 16 bit unit # into Y
	LDA	UNIT_LOC_X,Y		Copy it's X,Y location to Found unit's X,Y
	STA	UNIT_LOC_X,X
	LDA	UNIT_LOC_Y,Y
	STA	UNIT_LOC_Y,X
	LDA	UNIT_FIND		Get found unit #
;is it the player?
	BNE	TCMC4			Not the player, check if on screen & request redraw if it is
	LDA	#10			Yes, set border flash timing to 10 ticks
	STA	BORDER
TCMC4:	
	JSR	CHECK_FOR_WINDOW_REDRAW	
	JMP	AILP

WATER_DROID:
;first rotate the tiles
	LDX	UNITPRE			Get 16 bit unit #
	INC	UNIT_TILE,X
	LDA	UNIT_TILE,X
	CMPA	#143
	BNE	WD01
	LDA	#140
	STA	UNIT_TILE,X
WD01:	
	DEC	UNIT_A,X
; LCB NOTE: LDA should be unnecessary
	LDA	UNIT_A,X
	BEQ	WD02
	JSR	CHECK_FOR_WINDOW_REDRAW	
	JMP	AILP

;kill unit after countdown reaches zero. 
WD02:
; LCB NOTE: ldd
	LDD	#08*256+255		Dead robot type, 255 tick timer until actual death
	STA	UNIT_TYPE,X
	STB	UNIT_TIMER_A,X
	LDA	#115			dead robot tile
	STA	UNIT_TILE,X
	JSR	CHECK_FOR_WINDOW_REDRAW	
	JMP	AILP

PISTOL_FIRE_UP:
;Check if it has reached limits.
	LDX	UNITPRE			Get 16 bit unit #
	LDA	UNIT_A,X
	BNE	PFU02
;if it has reached max range, then it vanishes.
	BSR	DEACTIVATE_WEAPON
	BRA	PFU05

PFU02:	
	DEC	UNIT_LOC_Y,X	;move it up one.
	BRA	PISTOL_AI_COMMON

PFU05:	
	JSR	CHECK_FOR_WINDOW_REDRAW	
	JMP	AILP

PISTOL_FIRE_DOWN:
;Check if it has reached limits.
	LDX	UNITPRE			Get 16 bit unit #
	LDA	UNIT_A,X
	BNE	PFD02
;if it has reached max range, then it vanishes.
	BSR	DEACTIVATE_WEAPON
	BRA	PFD05

PFD02:	
	INC	UNIT_LOC_Y,X		;move it down one.
	BRA	PISTOL_AI_COMMON

PFD05:	
	JSR	CHECK_FOR_WINDOW_REDRAW	
	JMP	AILP

PISTOL_FIRE_LEFT:
;Check if it has reached limits.
	LDX	UNITPRE			Get 16 bit unit #
	LDA	UNIT_A,X
	BNE	PFL02
;if it has reached max range, then it vanishes.
	BSR	DEACTIVATE_WEAPON
	BRA	PFL05

PFL02:	
	DEC	UNIT_LOC_X,X	;move it left one.
	BRA	PISTOL_AI_COMMON

PFL05:	
	JSR	CHECK_FOR_WINDOW_REDRAW	
	JMP	AILP

PISTOL_FIRE_RIGHT:
;Check if it has reached limits.
	LDX	UNITPRE			Get 16 bit unit #
	LDA	UNIT_A,X
	BNE	PFR02
;if it has reached max range, then it vanishes.
	BSR	DEACTIVATE_WEAPON
	BRA	PFR05

PFR02:	
	INC	UNIT_LOC_X,X	;move it right one.
	BRA	PISTOL_AI_COMMON

PFR05:	
	JSR	CHECK_FOR_WINDOW_REDRAW	
	JMP	AILP

DEACTIVATE_WEAPON:
	CLR	UNIT_TYPE,X
	LDA	UNIT_B,X
	CMPA	#1
	BNE	DEW1
	CLRA
	STA	UNIT_B,X
	STA	PLASMA_ACT
DEW1:	RTS

; if we move the gun type check to later, there is some common code that can be merged:
; Also, check all calls to GET_TILE_FROM_MAP - may be worth changing that subroutine to return TILE #
; in B instead of A

; Entry: X=unit # of traveling bullet?
; Uses Y as the TILE # (for looking up tile attributes)
PISTOL_AI_COMMON:
	DEC	UNIT_A,X		reduce range by 1
; Now check what map object it is on
	LDA	UNIT_LOC_X,X		Get updated X&Y coords of bullet
	LDB	UNIT_LOC_Y,X
	STD	MAP_X			Save them for subroutine
	JSR	GET_TILE_FROM_MAP	Get the tile type the new position of the bullet is on (both in A & in <TILE). X IS NOT MODIFIED
	LDA	UNIT_B,X		Is the fired gun a pistol or plasma?
	BNE	PLASMA_AI_COMMON	Plasma, go handle
	LDB	TILE			Get tile # in B
	LDY	TILEPRE			Get 16 bit tile #
; start of pistol routines
	CMPB	#131			Pistol, hit an explosive cannister?
	BNE	PAIC04			No, skip ahead
;hit an explosive cannister
	LDA	#135			Yes, change it to a Blown cannister
	STA	TILE
	JSR	PLOT_TILE_TO_MAP	And replace it in the main map
	LDD	#6*256+131		Set unit_type to Bomb AI & unit_tile# to explosive cannister
	STA	UNIT_TYPE,X
	STB	UNIT_TILE,X
	LDD	MAP_X			Get copies of X,Y coords
	STA	UNIT_LOC_X,X		Put them into UNIT (aren't they already there?!?)
	STB	UNIT_LOC_Y,X
	LDD	#5			A=UNIT_A (0), B=UNIT_TIMER_A (range of shot to 5?)
	STA	UNIT_A,X
	STB	UNIT_TIMER_A,X
	JMP	AILP

PAIC04:	
	LDA	TILE_ATTRIB,Y		Not a cannister, get tile attributes
	ANDA 	#%00010000		can see through tile?
 	BNE	PAIC05			Yes, go handle
;Hit object that can't pass through, convert to explosion
	LDD	#11*256+248		A=SMALL EXPLOSION type, B=first tile # for explosion animation
	STA	UNIT_TYPE,X
	STB	UNIT_TILE,X
	JSR	CHECK_FOR_WINDOW_REDRAW	Check if tile is in viewing window, flag for screen redraw if it is
	JMP	AILP			Onto the next unit

;check if it encountered a robot/human
PAIC05:
	JSR	CHECK_FOR_UNIT		See if player or robot at MAP_X,MAP_Y
	BPL	PAIC06			Yes, go handle
	JSR	CHECK_FOR_WINDOW_REDRAW	No, check if tile is in viewing window, flag for screen redraw if it is
	JMP	AILP			Onto next unit

PAIC06:	;struck a robot/human
	LDX	UNITPRE			Get 16 bit unit # back into X (CHECK_FOR_UNIT does destroy X)
	LDD	#11*256+248		Small explosion unit type (11), first tile # for explosion (248)
	STA	UNIT_TYPE,X
	STB	UNIT_TILE,X
	LDA	#1			set damage for pistol
	STA	TEMP_A	
	BSR	INFLICT_DAMAGE		Do the damage
	BSR	ALTER_AI		If bullet hit hoverbot, switch it to attack mode
	JSR	CHECK_FOR_WINDOW_REDRAW	Check if tile is in viewing window, flag for screen redraw if it is
	JMP	AILP			Onto next unit

; start of plasma routines
PLASMA_AI_COMMON:
	LDB	TILE			Get tile #
	LDY	TILEPRE			Get 16 bit tile #
	CMPB	#131			cannister tile?
	BEQ	PLAI11			Yes, go blow it up. Real good.
	LDA	TILE_ATTRIB,Y		Get tile attribute
	ANDA 	#%00010000		can see through tile?
	BEQ	PLAI11			No, handle impact
; No, check if it encountered a human/robot
PLAI05:
	JSR	CHECK_FOR_UNIT		See if player or robot at MAP_X,MAP_Y
	BPL	PLAI11			Yes, go handle
;no impacts detected:
PLAI10:
	JSR	CHECK_FOR_WINDOW_REDRAW	No, check if tile is in viewing window, flag for screen redraw if it is
	JMP	AILP			Onto next unit

PLAI11:	;impact detected. convert to explosion
	LDX	UNITPRE			Get 16 bit unit # back into X (CHECK_FOR_UNIT does destroy X)
	LDD	#6*256+1		A=Bomb AI Unit type(6), B=timer until explosion(1)(?)
	STA	UNIT_TYPE,X
	STB	UNIT_TIMER_A,X
	CLRA
	STA	UNIT_A,X
	STA	PLASMA_ACT		Flag no plasma fire active
	JSR	CHECK_FOR_WINDOW_REDRAW	Check if tile is in viewing window, flag for screen redraw if it is
	JMP	AILP			Onto next unit

;This routine checks to see if the robot being shot
;is a hoverbot, if so it will alter it's AI to attack 
;mode.
ALTER_AI:
	LDX	UNIT_FINDPRE		Get 16 bit found unit #
	LDA	UNIT_TYPE,X
	CMPA	#2			hoverbot left/right
	BEQ	ATKMOD
	CMPA	#3			hoverbot UP/DOWN
	BEQ	ATKMOD
	RTS

ATKMOD:	
	LDA	#4			Switch to Attack AI
	STA	UNIT_TYPE,X
	RTS
	
;This routine will inflict damage on whatever is defined in
;UNIT_FIND in the amount set in TEMP_A.  If the damage is more
;than the health of that unit, it will delete the unit.
INFLICT_DAMAGE:
	LDX	UNIT_FINDPRE		Get 16 bit unit # into X
	LDA	UNIT_HEALTH,X		Get unit's health	
	SUBA	TEMP_A			Subtract damage
	STA	UNIT_HEALTH,X		Save updated health
	BLE	UNIT_DEAD		If 0 or negative, handle unit death
	LEAX	,X			still alive, was it the player (is X=0)?
	BNE	IND1			No, return
	JSR	DISPLAY_PLAYER_HEALTH	Yes, update player health
	LDA	#10			Set border flashing timer (flash when player hit)
	STA	BORDER
IND1:	
	RTS

; Unit died (player or robot)
UNIT_DEAD:
	CLR	UNIT_HEALTH,X		Zero out unit's health
	LEAX    ,X			Is it the player that is dead?
	BEQ	UD01			Yes, special handling
	LDA	#08			Dead robot type
	CMPA	UNIT_TYPE,X		is it a dead robot already?
	BEQ	UD0A			Yes, return
	STA	UNIT_TYPE,X		No, change to dead robot type
; LCB NOTE: LDD (Should be safe, but haven't fully followed all paths that call this)
	LDA	#255			Set timer before dead robot disappears
	STA	UNIT_TIMER_A,X
	LDA	#115			dead robot tile
	STA	UNIT_TILE,X		
UD0A:	
	RTS

; Player died
UD01:	
	CLRA				0 out player type
	STA	UNIT_TYPE,X
	JSR	DISPLAY_PLAYER_HEALTH	Update player health bar to empty
	LDA	#10			Set border flash timer & return
	STA	BORDER
	RTS
	
SMALL_EXPLOSION:
	CLRA				Clear timer until next Explosion tile
	STA	UNIT_TIMER_A,X
	INC	UNIT_TILE,X		INC explosion tile #
	LDA	UNIT_TILE,X
	CMPA	#252			Did we finish all from 246-251?
	BEQ	SEXP1			Yes, go shut off the explosion
	JSR	CHECK_FOR_WINDOW_REDRAW
	JMP	AILP

SEXP1:	
	CLRA				Small explosion done, clear out unit
	STA	UNIT_TYPE,X
	JSR	CHECK_FOR_WINDOW_REDRAW	
	JMP	AILP		
	
; Hoverbot attack AI routine - handles firing AND moving
HOVER_ATTACK:
;	LDX	UNITPRE			Get 16 bit unit #
	JSR	CHECK_FOR_WINDOW_REDRAW	If old position is on screen, flag for redraw (in case moves off)
	CLR	UNIT_TIMER_B,X		Force hoverbot to animate (0 the animation timer for Hoverbot)
	JSR	HOVERBOT_ANIMATE	Set up hoverbot animation counters/flags (98 or 99 is animation char #'s)
	LDD	#7*256+%00000010	Set timer between shots to 7, Hover movement type
	STA	UNIT_TIMER_A,X
	STB	MOVE_TYPE
;CHECK FOR HORIZONTAL MOVEMENT
	LDA	UNIT_LOC_X,X		Get hoverbot's X location
	CMPA	UNIT_LOC_X		Same as players?
	BEQ	HOAT13			Yes, go check Y location
	BLO	HOAT12			Hoverbot left of player, try moving hoverbot to right
	JSR	REQUEST_WALK_LEFT	Hoverbot right of player, try moving hoverbot to left
	BRA	HOAT13

HOAT12:	
	JSR	REQUEST_WALK_RIGHT	Try moving hoverbot to right
;NOW CHECK FOR VERTICAL MOVEMENT
HOAT13:
	LDA	UNIT_LOC_Y,X		Get hoverbots Y location
	CMPA	UNIT_LOC_Y		Same as players Y?
	BEQ	HOAT20			Yes, go check if in range of attacking player
	BLO	HOAT14			Hoverbot above player, try moving hoverbot down
	JSR	REQUEST_WALK_UP		Hoverbot below player, try moving hoverbot up
	BRA	HOAT20			Go check if hoverbot within attack range of player

HOAT14:	
	JSR	REQUEST_WALK_DOWN	Try moving hoverbot down
HOAT20:	
	JSR	ROBOT_ATTACK_RANGE	Is hoverbot in attack range of player (1 tile)? (returns PROX_DETECT in A)
	BEQ	HOAT21			Nope, skip ahead
	STA	TEMP_A			Save damage (1)
	CLRA				unit to inflict damage on (player is 0)
	STA	UNIT_FIND		Save UNIT # to damage
	JSR	INFLICT_DAMAGE		Go damage player
	BSR	CREATE_PLAYER_EXPLOSION	Create explosion effect on player
;LDA	#07		;electric shock
;JSR	PLAY_SOUND	;SOUND PLAY
	LDX	UNITPRE			Get 16 bit unit # of Hoverbot
	LDA	#30			Set rate of attack on player.
	STA	UNIT_TIMER_A,X
;add some code here to create explosion
HOAT21:	
	JSR	CHECK_FOR_WINDOW_REDRAW	
	JMP	AILP

CREATE_PLAYER_EXPLOSION:
	LDX	#28			Start of bullet/explosion sprites
TE01:	
	LDA	UNIT_TYPE,X		In use?
	BEQ	TE02			No, go add small explosion at this spot
	LEAX	1,X			Yes, go onto next one
	CMPX	#32			All 4 full?
	BNE	TE01			No, try next
TE02:	
	LDD	#11*256+248		Small explosion AI type, first tile # for explosion
	STA	UNIT_TYPE,X
	STB	UNIT_TILE,X
	LDA	#1
	STA	UNIT_TIMER_A,X
	LDA	UNIT_LOC_X		Copy player X,Y to explosion X,Y
	STA	UNIT_LOC_X,X
	LDA	UNIT_LOC_Y
	STA	UNIT_LOC_Y,X
	RTS	

; Evilbot in attack mode
EVILBOT:
;	LDX	UNITPRE			Get 16 bit unit #
	JSR	CHECK_FOR_WINDOW_REDRAW	If old position is on screen, flag for redraw (in case moves off)
	LDA	#5			X=UNITPRE from sub, reset animation timer to 5 ticks (when it next comes here again)
	STA	UNIT_TIMER_A,X
;first animate evilbot
	LDA	UNIT_TILE,X		Get current animation frame #
	CMPA	#103			Last frame?
	BHS	EVIL3			Yes, wrap back to 100
	CMPA	#100			This is not initialized to 100, so this will force it to the 1st time 
	BLO	EVIL3
	INC	UNIT_TILE,X		No, INC to next frame (100-103)
	BRA    EVIL10

EVIL3:    
	LDA	#100			Reset animation frame to first evilbot animation
	STA	UNIT_TILE,X
EVIL10:	
;now figure out movement
	LDA	UNIT_TIMER_B,X		Get move timer
	BEQ	EVIL11			Already down to 0, go move
	DEC	UNIT_TIMER_B,X		Dec move timer
; Because we pre-check if on screen above, shouldn't need this here. If animation changed, but didn't move,
; already flagged for redraw.
;	JSR	CHECK_FOR_WINDOW_REDRAW
	JMP	AILP

EVIL11:	
; LCB NOTE: LDD 
	LDD	#1*256+%00000001	A=Reset timer B (move) to 1, B=1 (WALK movetype)
	STA	UNIT_TIMER_B,X
	STB	MOVE_TYPE
;CHECK FOR HORIZONTAL MOVEMENT
	LDA	UNIT_LOC_X,X		Get Evilbot's X coord
	CMPA	UNIT_LOC_X		Compare with pLayers X coord
	BEQ	EVIL13			Same, go check vertical
	BLO	EVIL12			Evilbot is left of player, go try moving right
	JSR	REQUEST_WALK_LEFT	Evilbot is to right of player, try moving Evilbot left
	BRA	EVIL13

EVIL12:	
	JSR	REQUEST_WALK_RIGHT	Try moving Evilbot to the right
EVIL13:
;NOW CHECK FOR VERTICAL MOVEMENT
	LDA	UNIT_LOC_Y,X		Get Evilbot's Y location
	CMPA	UNIT_LOC_Y		Compare with Players Y
	BEQ	EVIL20			Same, proceed with attack (if close enough)
	BLO	EVIL14			Evilbot is above player, try moving Evilbot down
	JSR	REQUEST_WALK_UP		Evilbot is below player, try moving Evilbot up
	BRA	EVIL20

EVIL14:	
	JSR	REQUEST_WALK_DOWN	Try moving Evilbot down
EVIL20:	
	JSR	ROBOT_ATTACK_RANGE	Check if Evilbot is within attack range (returns A with 0=no, 1=yes & zero flag set)
	BEQ	EVIL21			Not in range, return
	LDA	#5			In range, set amount of damage it will inflict to 5
	STA	TEMP_A	
	CLRA				Set unit to inflict damage on to 0 (player)
	STA	UNIT_FIND
	JSR	INFLICT_DAMAGE		Reduce players health
	JSR	CREATE_PLAYER_EXPLOSION	Start explosion animation over player
;LDA	#07		;electric shock sound
;JSR	PLAY_SOUND	;SOUND PLAY
	LDX	UNITPRE			Get 16 bit unit # of Hoverbot
	LDA	#15			set rate of attack on player.
	STA	UNIT_TIMER_A,X
EVIL21:	
	JSR	CHECK_FOR_WINDOW_REDRAW	
	JMP	AILP

;DOOR routines:
;This routine handles automatic sliding doors.
;UNIT_B register means:
;0=opening-A 1=opening-B 2=OPEN 3=closing-A 4=closing-B 5-CLOSED
AI_DOOR:
	LDX	UNITPRE			Get 16 bit unit #
	LDB	UNIT_B,X		Get door status
	ANDB    #7			Force to 0-7
	LSLB				*2 since 2 bytes/table entry
	LEAY	<AIDB,PCR		Point to jump table
	JMP	[B,Y]			Call appropriate routine

AIDB:
	.WORD	DOOR_OPEN_A		0
	.WORD	DOOR_OPEN_B		1
	.WORD	DOOR_OPEN_FULL		2
	.WORD	DOOR_CLOSE_A		3
	.WORD	DOOR_CLOSE_B		4
	.WORD	DOOR_CLOSE_FULL		5
	.WORD	AILP			6 should never happen
	.WORD	AILP			7 should never happen

DOOR_OPEN_A:
	LDA	UNIT_A,X		Get Door orientation
	BNE	DOA1			Vertical door, go handle
;HORIZONTAL DOOR
	LDD #88*256+89
	STD	DOORPIECE1
	LDA	#86
	STA	DOORPIECE3
	JSR	DRAW_HORIZONTAL_DOOR
	BRA	DOA2

;VERTICAL DOOR
DOA1:
	LDD #70*256+74
	STD	DOORPIECE1
	LDA	#78
	STA	DOORPIECE3
	JSR	DRAW_VERTICAL_DOOR
DOA2:	
; LCB NOTE: LDD
	LDA	#1
	STA	UNIT_B,X		Initialize door status to opening-B
	LDA	#5			Set timer for next door animation
	STA	UNIT_TIMER_A,X
	JSR	CHECK_FOR_WINDOW_REDRAW	
	JMP	AILP

DOOR_OPEN_B:
	LDA	UNIT_A,X		Get Door orientation
	BNE	DOB1			Vertical, go handle	
;HORIZONTAL DOOR
	LDD #17*256+09
	STD	DOORPIECE1
	LDA	#91
	STA	DOORPIECE3
	JSR	DRAW_HORIZONTAL_DOOR
	BRA	DOB2

; VERTICAL DOOR
DOB1:
	LDD	#27*256+09
	STD	DOORPIECE1
	LDA	#15
	STA	DOORPIECE3
	JSR	DRAW_VERTICAL_DOOR
DOB2:	
	LDD	#2*256+30		Initialize door status to OPEN, 30 ticks until next possible door animation
	STA	UNIT_B,X
	STB	UNIT_TIMER_A,X
	JSR	CHECK_FOR_WINDOW_REDRAW	
	JMP	AILP

DOOR_OPEN_FULL:
	JSR	DOOR_CHECK_PROXIMITY	Check if player is close enough to "hold" the door open (returns in A & PROX_DETECT & zero flag set)
	BEQ	DOF1			Nope, go try closing it
	LDA	#30			Yes, reset timer to try and close to 30
	STA	UNIT_TIMER_B,X
	JMP	AILP

;if nobody near door, lets close it. Check for object in the way first.
DOF1:	
	LDA	UNIT_LOC_X,X		Get door X/Y location & save into MAP_X,MAP_Y for subroutine
	LDB	UNIT_LOC_Y,X
	STD	MAP_X
	JSR	GET_TILE_FROM_MAP	See if something else is in doorway (returns tile in A)
	CMPA	#09			Empty floor-tile?
	BEQ	DOFB			Yes, start closing the door
;SOMETHING IN THE WAY, ABORT
	LDA	#35			No, set next attempt at door animation to 35 ticks
	STA	UNIT_TIMER_A,X
	JMP	AILP

; Start closing an open door
DOFB:	
;LDA	#14		;DOOR-SOUND
;JSR	PLAY_SOUND	;SOUND PLAY
	LDX	UNITPRE			Get 16 bit unit #
	LDA	UNIT_A,X		Get door orientation
	BNE	DOF2			Vertical, go handle
;HORIZONTAL_DOOR
	LDD	#88*256+89
	STD	DOORPIECE1
	LDA	#86
	STA	DOORPIECE3
	JSR	DRAW_HORIZONTAL_DOOR
	BRA	DOF3

; VERTICAL DOOR
DOF2:
	LDD	#70*256+74
	STD	DOORPIECE1
	LDA	#78
	STA	DOORPIECE3
	JSR	DRAW_VERTICAL_DOOR
DOF3:	
	LDD	#3*256+5		Flag door status as Closing-A, 5 ticks until next status change
	STA	UNIT_B,X
	STB	UNIT_TIMER_A,X
	JSR	CHECK_FOR_WINDOW_REDRAW	
	JMP	AILP

DOOR_CLOSE_A:
	LDA	UNIT_A,X		Get door orientation
	BNE	DCA2			Vertical, go handle
;HORIZONTAL DOOR
	LDD	#84*256+85
	STD	DOORPIECE1
	LDA	#86
	STA	DOORPIECE3
	JSR	DRAW_HORIZONTAL_DOOR
	BRA	DCA3

DCA2:	;VERTICAL DOOR
	LDD	#69*256+73
	STD	DOORPIECE1
	LDA	#77
	STA	DOORPIECE3
	JSR	DRAW_VERTICAL_DOOR
DCA3:	
	LDD	#4*256+5		Flag door status as Closing-B, 5 ticks until next status change
	STA	UNIT_B,X
	STB	UNIT_TIMER_A,X
	JSR	CHECK_FOR_WINDOW_REDRAW	
	JMP	AILP

DOOR_CLOSE_B:
	LDA	UNIT_A,X		Get door orientation
	BNE	DCB2			Vertical, go handle
;HORIZONTAL DOOR
	LDD	#80*256+81
	STD	DOORPIECE1
	LDA	#82
	STA	DOORPIECE3
	JSR	DRAW_HORIZONTAL_DOOR
	BRA	DCB3

; VERTICAL DOOR
DCB2:
	LDD	#68*256+72
	STD	DOORPIECE1
	LDA	#76
	STA	DOORPIECE3
	BSR	DRAW_VERTICAL_DOOR
DCB3:	
	LDA	#5			Flag door status as closed AND time before next allowed status change
	STA	UNIT_B,X
	STA	UNIT_TIMER_A,X
	JSR	CHECK_FOR_WINDOW_REDRAW	
	JMP	AILP

DOOR_CLOSE_FULL:
	JSR	DOOR_CHECK_PROXIMITY	Player close enough to door to affect it? (A=result with Z flag set)
	BNE	DCF1			Yes, go handle
DCF0:	
	LDA	#20			No, set time before next allowed change to 20
	STA	UNIT_TIMER_A,X		RESET TIMER
	JMP	AILP

;if player near door, lets open it. First check if locked
DCF1:	
	LDA	UNIT_C,X		Get Lock status
	BEQ	DCFZ			Not locked, go open
; LCB NOTE: Get keys in B and use BITB to check keys without reloading B
; Also, use DECA to go through keys
	LDB	KEYS			Get keys
	DECA				SPADE key door?
	BNE	DCFB			No, check next
	BITB	#%00000001		Player have SPADE key?
	BNE	DCFZ			Yes, go open door
	BRA	DCF0			No, restart door open check timer to 20 & return

DCFB:	
	DECA				HEART key door?
	BNE	DCFC			No, check next
	BITB	#%00000010		Player have HEART key?
	BNE	DCFZ			Yes, open door
	BRA	DCF0			No, restart door open check timer to 20 & return

DCFC:	
	DECA				STAR key door?
	BNE	DCF0			SHOULD NEVER HAPPEN, restart door open timer to 20 & return
	LDB	KEYS
	BITB	#%00000100		Player have STAR key?
	BEQ	DCF0			No, restart door open check timer to 20 & return
; Start open door process
DCFZ:
;LDA	#14		;DOOR-SOUND
;JSR	PLAY_SOUND	;SOUND PLAY
	LDX	UNITPRE			Get 16 bit unit #
	LDA	UNIT_A,X		Get door orientation
	BNE	DCF2			Vertical, go do
;HORIZONTAL DOOR
	LDD	#84*256+85
	STD	DOORPIECE1
	LDA	#86
	STA	DOORPIECE3
	BSR	DRAW_HORIZONTAL_DOOR
	BRA	DCF3

;VERTICAL DOOR
DCF2:	
	LDD	#69*256+73
	STD	DOORPIECE1
	LDA	#77
	STA	DOORPIECE3
	BSR	DRAW_VERTICAL_DOOR
DCF3:	
	LDX	UNITPRE			Get 16 bit unit #
	CLR	UNIT_B,X		Flag door as OPENING
	LDA	#5			Set timer to 5 for next opening stage
	STA	UNIT_TIMER_A,X
	JSR	CHECK_FOR_WINDOW_REDRAW	
	JMP	AILP

DRAW_VERTICAL_DOOR:
	LDB	UNIT_LOC_Y,X		Get Y location of center of door
	DECB				Move up 1 for start of door
	LDA	UNIT_LOC_X,X		Get X location of door
	STD	MAP_X			Save for draw subroutine
	LDA	DOORPIECE1		Get top of 3 chars for door
	STA	TILE			Save for subroutine
	JSR	PLOT_TILE_TO_MAP	Save into main map NOTE: RETURNS MAP ADDRESS IN U
; Now that we have map location, we can copy over ourselves
	LDD	DOORPIECE2		Get bottom 2 chars for door
	LEAU	128,U			Move next line down
	STA	,U			Save middle into main map
	STB	128,U			And save bottom into main map
	RTS

DRAW_HORIZONTAL_DOOR:
	LDA	UNIT_LOC_X,X		Get X location of center of door
	DECA				Move left 1 for start of door
	LDB	UNIT_LOC_Y,X		Get Y location of center of door
	STD	MAP_X			Save locations for subroutine
	LDA	DOORPIECE1		Get left char of door
	STA	TILE			Save for sub
	JSR	PLOT_TILE_TO_MAP	Save it into main map (NOTE: RETURNS MAP ADDRESS IN U)
	LDD	DOORPIECE2		Get middle & right char of door
	STD	1,U			Save into map
	RTS
  
; Flag if hoverbot or evilbot is in range (and alignment) to shoot at player
; Exit: PROX_DETECT: 0=robot not in range, 1=robot in range
;First check horizontal proximity to player
; NOTE: Entry is sometimes not from UNIT, so grab it here
ROBOT_ATTACK_RANGE:
	LDB	UNIT			Get robot unit #
	LDX	UNITPRE			Get 16 bit robot unit #
	LDA	UNIT_LOC_X,X		Get Hoverbot/Evilbot's X location
	SUBA 	UNIT_LOC_X		Subtract Player's X location
	BPL	RAR2			Positive #, check range
	NEGA				Negative, ABS the value
RAR2:	
	CMPA	#1			Within 1 HORIZONTAL TILE FROM PLAYER?
	BLS	RAR3			If within 1 horizontal tile, check vertical
ROBOT_OUTOFRANGE:
	CLR	PROX_DETECT		player not detected, flag as such in PROX_DETECT
	RTS	

	;Now check vertical proximity
RAR3:
	LDA	UNIT_LOC_Y,X		Get hoverbot/evilbot's Y location
	SUBA 	UNIT_LOC_Y		Subtract Player's Y position
	BPL	RAR5			If positive, check distance
RAR4:	
	NEGA				Negative, ABS the value
RAR5:	
	CMPA	#1			Within 1 VERTICAL TILE FROM PLAYER?
	BHI	ROBOT_OUTOFRANGE	No, flag out of range
RAR6:
	LDA	#1			Yes, flag in range
	STA	PROX_DETECT
	RTS

;First check horizontal proximity to door
;Exit: PROX_DETECT: 0=door not in range, 1=door in range
DOOR_CHECK_PROXIMITY:
	LDA	UNIT_LOC_X,X		Get Door X location
	SUBA 	UNIT_LOC_X		Subtract player's X location
	BPL	PRD2			Positive already, go check range
	NEGA				Negative, do ABS
PRD2:	  
	CMPA	#2			Door within 2 HORIZONTAL TILES FROM PLAYER?
	BLO	PRD3			Yes, go check vertical
DOOR_OUTOFRANGE:
	CLR	PROX_DETECT		player not near door, flag as such
	RTS

PRD3:	;Now check vertical proximity
	LDA	UNIT_LOC_Y,X		Get door Y location
	SUBA 	UNIT_LOC_Y		subtract Player Y location
	BPL	PRD5			already positive, check distance
PRD4:	
	NEGA				negative, ABS it
PRD5:	
	CMPA	#2			Door within 2 VERTICAL TILES FROM PLAYER?
	BHS	DOOR_OUTOFRANGE		No, flag out of range
	LDA	#1			Yes, flag in range
	STA	PROX_DETECT
	RTS	

PROX_DETECT	.BYTE	00	;0=NO 1=YES


;DOOR_CHECK_PROXIMITY:
;	;First check horizontal proximity to door
;	LDA	UNIT_LOC_X,X	;DOOR UNIT
;	SUBA 	UNIT_LOC_X	;PLAYER UNIT
;	BLO 	PRD1 ;if carry cleared then its negative
;	BRA	PRD2
;PRD1:	
;  NEGA
;PRD2:	  
;  CMPA	#2	;2 HORIZONTAL TILES FROM PLAYER
;	BLO	PRD3
;	CLRA	;player not detected
;	STA	PROX_DETECT
;	RTS	
;PRD3:	;Now check vertical proximity
;	LDA	UNIT_LOC_Y,X	;DOOR UNIT
;	SUBA 	UNIT_LOC_Y	;PLAYER UNIT
;	BLO 	PRD4 ;if carry cleared then its negative
;	BRA	PRD5
;PRD4:	
;  NEGA
;PRD5:	
;  CMPA	#2	;2 VERTICAL TILES FROM PLAYER
;	BLO	PRD6
;	CLRA	;player not detected
;	STA	PROX_DETECT
;	RTS		
;PRD6:	;PLAYER DETECTED, CHANGE DOOR MODE.
;	LDA	#1
;	STA	PROX_DETECT
;	RTS	
;PROX_DETECT	.BYTE	00	;0=NO 1=YES

; NOTE: DRAW_HORIZONTAL_DOOR does *not* modify X, so we don't need to keep
; reloading it based on UNIT.
;This routine handles automatic sliding doors.
;UNIT_B register means:
;0=opening-A 1=opening-B 2=OPEN 3=closing-A 4=closing-B 5-CLOSED
ELEVATOR:
	LDX	UNITPRE			Get 16 bit unit #
	LDB	UNIT_B,X		Get elevator/door status
	CMPB 	#6			Out of range 0-5?
	BHS	ELBA			Yes, just return
	LSLB				2 bytes per entry
	LEAY	<ELDB,PCR		Point to branch table
	JMP	[B,Y]			Jump to routine	

ELBA:
	JMP AILP			Return to main unit processing loop
ELDB:
	.WORD	ELEV_OPEN_A
	.WORD	ELEV_OPEN_B
	.WORD	ELEV_OPEN_FULL
	.WORD	ELEV_CLOSE_A
	.WORD	ELEV_CLOSE_B
	.WORD	ELEV_CLOSE_FULL
  
ELEV_OPEN_A:
	LDD	#181*256+89		Set up 3 tiles for drawing Elevator door
	STD	DOORPIECE1
	LDA	#173
	STA	DOORPIECE3
	JSR	DRAW_HORIZONTAL_DOOR	Update map with door opening A tiles
	LDD	#1*256+5		A=1 (ELEV_OPEN_B), B=5 tickets until next door sequence			
	STA	UNIT_B,X		Update Door status to OPEN-B
	STB	UNIT_TIMER_A,X		5 ticks until next update
	JSR	CHECK_FOR_WINDOW_REDRAW	Figure out if door is on viewable window; set flag if it is
	JMP	AILP			Return to main AI check loop
	
ELEV_OPEN_B:
	LDD	#182*256+09
	STD	DOORPIECE1
	LDA	#172
	STA	DOORPIECE3
	JSR	DRAW_HORIZONTAL_DOOR
	LDD	#2*256+50		A=2 (ELEV_OPEN_FULL), B=50 ticks until door can close
	STA	UNIT_B,X
	STB	UNIT_TIMER_A,X
	JSR	CHECK_FOR_WINDOW_REDRAW	
	JMP	AILP

ELEV_OPEN_FULL:
;CLOSE DOOR. check for object in the way first.
	LDA	UNIT_LOC_X,X		Get X,Y coords
	LDB	UNIT_LOC_Y,X
	STD	MAP_X			Save for subroutine
	JSR	GET_TILE_FROM_MAP	Get tile from that location
	LDA	TILE			Get the tile #
	CMPA	#09			FLOOR-TILE?
	BEQ	EVOF3			Yes, see if a unit is on that floor tile
;SOMETHING IN THE WAY, ABORT
EVOF2:	
	LDA	#35			Some other tile type blocking it, time delay of 35 ticks before trying again
	STA	UNIT_TIMER_A,X
	JMP	AILP

; check for player or robot in the way
EVOF3:
	JSR	CHECK_FOR_UNIT		See if player or robot at MAP_X,MAP_Y (Save result in UNIT_FIND)
	LDX	UNITPRE			X=16 bit Unit # of elevator
	LDA	UNIT_FIND		Get result of robot/player at location check
	BPL	EVOF2			There was one, delay 35 ticks before trying again
;START TO CLOSE ELEVATOR DOOR
;LDA	#14		;DOOR SOUND
;JSR	PLAY_SOUND	;SOUND PLAY
	LDD	#181*256+89		Elevator clear, start closing door
	STD	DOORPIECE1
	LDA	#173
	STA	DOORPIECE3
	JSR	DRAW_HORIZONTAL_DOOR
	LDX	UNITPRE			Get 16 bit unit #
	LDD	#3*256+5		A=3 (ELEV_CLOSE_A stage), B=5 ticks until next door close sequence
	STA	UNIT_B,X
	STB	UNIT_TIMER_A,X
	JSR	CHECK_FOR_WINDOW_REDRAW	Check if unit on viewable window, flag for redraw if yes
	JMP	AILP

ELEV_CLOSE_A:
	LDD	#84*256+85
	STD	DOORPIECE1
	LDA	#173
	STA	DOORPIECE3
	JSR	DRAW_HORIZONTAL_DOOR
	LDX	UNITPRE
	LDD	#4*256+5		A=4 (ELEV_CLOSE_B stage), B-5 ticks until next door close sequence
	STA	UNIT_B,X
	STB	UNIT_TIMER_A,X
	JSR	CHECK_FOR_WINDOW_REDRAW	Check if unit on viewable window, flag for redraw if yes	JMP	AILP

ELEV_CLOSE_B:
	LDD	#80*256+81
	STD	DOORPIECE1
	LDA	#174
	STA	DOORPIECE3
	JSR	DRAW_HORIZONTAL_DOOR
	LDX	UNITPRE			Get 16 bit unit #
	LDD	#5*256+5		A=4 (ELEV_CLOSE_FULL stage), B-5 ticks until next door sequence	STA	UNIT_B,X
	STB	UNIT_TIMER_A,X
	JSR	CHECK_FOR_WINDOW_REDRAW	Check if unit on viewable window, flag for redraw if yes
	BSR	ELEVATOR_PANEL
	JMP	AILP

ELEV_CLOSE_FULL:
; LCB NOTE: X is still UNIT (DRAW_HORIZONTAL_DOOR doesn't modify X), so we don't need these.
	JSR	DOOR_CHECK_PROXIMITY	
	BNE	EVF1
	LDA	#20
	STA	UNIT_TIMER_A,X		RESET TIMER to 20 ticks before door can be opened again
	JMP	AILP

EVF1:	;Start open door process
;LDA	#14		;DOOR SOUND
;JSR	PLAY_SOUND	;SOUND PLAY
	LDD	#84*256+85
	STD	DOORPIECE1
	LDA	#173
	STA	DOORPIECE3
	JSR	DRAW_HORIZONTAL_DOOR
	LDX	UNITPRE			Get 16 bit unit #
	CLR	UNIT_B,X		Set ELEV_OPEN_A
	LDA	#5			5 ticks until next door sequence
	STA	UNIT_TIMER_A,X
	JSR	CHECK_FOR_WINDOW_REDRAW	
	JMP	AILP

ELEVATOR_PANEL:
;Check to see if player is standing in the
;elevator first.
	LDX	UNITPRE			Get 16 bit unit #
	LDA	UNIT_LOC_X,X		;elevator X location
	CMPA	UNIT_LOC_X		;player X location
	BEQ	ELPN1			Match, check Y
	RTS				No, return

ELPN1:	
	LDA	UNIT_LOC_Y,X		;elevator Y location
	SUBA	#01			Is player in elevator (1 Y location up from elevator door)?
	CMPA	UNIT_LOC_Y		;player Y location
	BEQ	ELPN2			Yes, start elevator panel, else return
	RTS

;PLAYER DETECTED, START ELEVATOR PANEL
ELPN2:	
	LDY	#MSG_ELEVATOR		Print dialog for player to use elevator
 	JSR	PRINT_INFO
	LDY	#MSG_LEVELS
 	JSR	PRINT_INFO
	JMP	ELEVATOR_SELECT		Go get player to select a level or exit the elevator

; Returns $FD-$FE address in MAP array based on MAP_X,MAP_Y - not sure if that is needed.
; Main function is to take tile value in TILE and save it into the map at MAP_X,MAP_Y
; Modifies D,U & <$FD-$FE (and one byte in the 8K MAP)
PLOT_TILE_TO_MAP:
; New routine: 21 bytes, 44 cycles
; LCB NOTE: Change to use LDB TILE/STB ,U at the end later, then a lot of calling routines can shorten/speed up
	CLRB
	LDA	MAP_Y			Get Y map coord into high byte (So *256)
	LSRA				Divide by 2 (so now *128, which is the length of each row in the map)
	RORB
	ADDB	MAP_X			Add X coord
	ADCA	#0
	ADDD	#MAP			Add start of map ptr
	TFR	D,U			Point to spot in map to put tile
	STU	<$FD			Save address (NOT SURE IF THIS LINE IS NEEDED?)
	LDA	TILE			Get tile # to save into map
	STA	,U
	RTS

;This routine will return the tile for a specific X/Y
;on the map.  You must first define MAP_X and MAP-Y.
;The result is stored in TILE, and also returned in A
; Y and <$FD are modified
;NOTE: CALLING ROUTINES NEED X PRESERVED. SOME ALSO NEED $FD TO POINT
;  TO THE MAP POSITION PTR
; original routine was 35 bytes, 81 cycles
; current routine
; newest routine: 22 bytes, 45 cycles
GET_TILE_FROM_MAP:
	CLRB				1/2
	LDA	MAP_Y			2/4 Get current Y location on map (0-63)
	LSRA				1/2 Quick & dirty *128
	RORB				1/2
	ADDB	MAP_X			2/4 Add X offset (0-127)
	ADCA	#0			2/2
	ADDD	#MAP			3/4 Add map start ptr
	TFR	D,Y			2/6 Y=ptr to specific tile in map
	STY	<$FD			3/6 Save ptr
	LDA	,Y			2/4 Get tile
	STA	<TILE			2/4 Save tile # for some calling routines
	RTS

;In this AI routine, the droid simply goes left until it
;hits an object, and then reverses direction and does the
;same, bouncing back and forth.
LEFT_RIGHT_DROID:
;	LDX	UNITPRE			Get 16 bit unit #
	JSR	CHECK_FOR_WINDOW_REDRAW	If old position is on screen, flag for redraw (in case moves off)
	BSR	HOVERBOT_ANIMATE	X=UNITPRE from above call - Update hoverbot tile # for animation
	LDA	#10			reset timer until next move to 10 ticks
	STA	UNIT_TIMER_A,X	
	LDA	UNIT_A,X		GET DIRECTION
	DECA				0=LEFT 1=RIGHT
	BEQ	LRD01			Go handle hoverbot moving to right
	LDA	#%00000010		Set move type to HOVER
	STA	MOVE_TYPE
	JSR	REQUEST_WALK_LEFT	Attempt to move hoverbot left (Returns flags set & A=result: 0=failed,1=successful)
	BNE	LRD02			move left was successful, check if on screen & return from there
	LDX	UNITPRE			Unsuccessful; get 16 bit unit # back
	LDA	#1
	STA	UNIT_A,X		CHANGE DIRECTION to move to right
	JSR	CHECK_FOR_WINDOW_REDRAW
	JMP	AILP

; Hoverbot moving to right
LRD01:	
	LDA	#%00000010		Set move type to HOVER
	STA	MOVE_TYPE
	BSR	REQUEST_WALK_RIGHT	Attempt to move hoverbot right (Returns flags set & A=result: 0=failed,1=successful)
	BNE	LRD02			move right was successful, check if on screen & return from there
	LDX	UNITPRE			Unsuccessful; get 16 bit unit # back
	CLR	UNIT_A,X		CHANGE DIRECTION to move to left
LRD02:	
	JSR	CHECK_FOR_WINDOW_REDRAW
	JMP	AILP

;In this AI routine, the droid simply goes UP until it
;hits an object, and then reverses direction and does the
;same, bouncing back and forth.
UP_DOWN_DROID:
;	LDX	UNITPRE			Get 16 bit unit #
	JSR	CHECK_FOR_WINDOW_REDRAW	If old position is on screen, flag for redraw (in case moves off)
	BSR	HOVERBOT_ANIMATE	X=UNITPRE from sub call - Change animation tile # for hoverbot
	LDA	#10			reset timer to 10 until next animation
	STA	UNIT_TIMER_A,X	
	LDA	UNIT_A,X		GET DIRECTION
	DECA				0=UP 1=DOWN
	BEQ	UDD01			was 1, go attempt to move down
; Hoverbot move up
	LDA	 #%00000010		Set move type to HOVER
	STA	MOVE_TYPE
	JSR	REQUEST_WALK_UP		Attempt to move hoverbot up (Returns flags set & A=result: 0=failed,1=successful)	BNE	UDD02			Move up was successful; check if on screen & return from there	LDX	UNITPRE			Get 16 bit unit # back	LDA	#1
	STA	UNIT_A,X		CHANGE DIRECTION to move down
	JSR	CHECK_FOR_WINDOW_REDRAW
	JMP	AILP

; Hoverbot move down
UDD01:	
	LDA	#%00000010		Set move type to HOVER
	STA	MOVE_TYPE
	JSR	REQUEST_WALK_DOWN	Attempt to move hoverbot down (Returns flags set & A=result: 0=failed,1=successful)
	BNE	UDD02			move down was successful, check if on screen & return from there
	LDX	UNITPRE			Unsuccessful; get 16 bit unit # back
	CLR	UNIT_A,X		CHANGE DIRECTION to move up
UDD02:	
	JSR	CHECK_FOR_WINDOW_REDRAW
	JMP	AILP
  
HOVERBOT_ANIMATE:
	LDA	UNIT_TIMER_B,X		Get animation timer
	BEQ	HOVAN2			At 0, time switch hoverbot tile #
	DEC	UNIT_TIMER_B,X		Still going, dec timer & return
	RTS

HOVAN2:	
	LDA	#3
	STA	UNIT_TIMER_B,X		RESET ANIMATE TIMER to 3 ticks
	LDA	UNIT_TILE,X		Get current tile #
	CMPA	#98			1st animation tile (98)?
	BNE	HOVAN1			No, go set it to 1st
	INCA				Yes, bump it 99
	STA	UNIT_TILE,X		and save it back & return
	RTS

HOVAN1:	
	LDA	#98			Set hoverbot animation tile # to 98 (1st) & return
	STA	UNIT_TILE,X
	RTS
		
;The following 4 routines are used by both the player and some
;of the enemy units.  It checks to see if you can walk in a
;specific direction.  It checks for edge of map and also that
;the tile you want to walk onto can allow that.  There is a
;separate routine for hovering robots.
; Crunched to use a single FAIL routine shared by all 4 directions. I think the branches will all
;   reach. Should save 12 bytes, no speed loss.
REQUEST_WALK_RIGHT:
	LDY	UNITPRE			Get 16 bit unit #
	LDA	UNIT_LOC_X,Y 		Get X location of unit
	CMPA	#122			Farthest right we allow (X=122)? (rightmost 5 we can't scroll into)
	BEQ	MGFAIL			Yes, exit flagging walk request failed
	INCA				No, move 1 more location to right
	LDB	UNIT_LOC_Y,Y		And get Y coord
	STD	MAP_X			Save temp version for subroutine
	JSR	GET_TILE_FROM_MAP	Get what tile is in that location
	LDY	TILEPRE			Get 16 bit tile #
	LDA	TILE_ATTRIB,Y		Get attribute flags for that tile
	ANDA 	MOVE_TYPE		Check, can walk on this tile?
	BEQ	MGFAIL			No, flag move failed & return
	JSR	CHECK_FOR_UNIT		See if player or robot at MAP_X,MAP_Y
	BPL	MGFAIL			Yes, can't move there so flag move failed & return
	LDX	UNITPRE			Get 16 bit unit # into X
	INC	UNIT_LOC_X,X		Move that unit 1 to right
	LDA	#1			Flag move successful & return
	STA	MOVE_RESULT
	RTS

REQUEST_WALK_LEFT:
	LDY	UNITPRE			Get 16 bit unit #
	LDA	UNIT_LOC_X,Y		Get X location of unit
	CMPA	#5			Farthest left we allow (X=5)? (leftmost 5 we can't scroll into)
	BEQ	MGFAIL			Yes, exit flagging walk request failed
	DECA				No, move 1 more location to left
	LDB	UNIT_LOC_Y,Y		and get Y coord
	STD	MAP_X			Save temp version for subroutine
	JSR	GET_TILE_FROM_MAP	Get what tile is in that location
	LDY	TILEPRE			Get 16 bit tile #
	LDA	TILE_ATTRIB,Y		Get attribute flags for that tile
	ANDA 	MOVE_TYPE		Check, can walk on this tile?
	BEQ	MGFAIL			Yes, can't move there so flag move failed & return
	BSR	CHECK_FOR_UNIT		See if player or robot at MAP_X,MAP_Y
	BPL	MGFAIL			Yes, can't move there so flag move failed & return
	LDX	UNITPRE			Get 16 bit unit # into X
	DEC	UNIT_LOC_X,X		Move that unit 1 to left
	LDA	#1			Flag move successful & return
	STA	MOVE_RESULT
	RTS

MGFAIL:	
	CLRA				Flag move failed & return
	STA	MOVE_RESULT
	RTS

REQUEST_WALK_DOWN:
	LDY	UNITPRE			Get 16 bit unit #
	LDB	UNIT_LOC_Y,Y		Get it's Y location
	CMPB	#60			Already as far down as we will allow (60 - we don't let them get to 64)?
	BEQ	MGFAIL			Yes, exit with failed move
	INCB				No, move it down 1
	LDA	UNIT_LOC_X,Y		Get X location as well
	STD	MAP_X			Save updated coords
	JSR	GET_TILE_FROM_MAP	Get the tile from the new location
	LDY	TILEPRE			Get 16 bit tile #
	LDA	TILE_ATTRIB,Y		Get attributes for that tile type
	ANDA 	MOVE_TYPE		Check, can walk on this tile? (NOTE: MOVE_TYPE WAS SET TO 0 WHEN ROBOT LANDS ON MAGNET- WHICH WAS WRONG)
 	BEQ	MGFAIL			If AND results in no bits set, exit with move request failed (don't move)
	BSR	CHECK_FOR_UNIT		See if player or robot at MAP_X,MAP_Y
	BPL	MGFAIL			Yes, don't allow move
	LDX	UNITPRE			Get 16 unit # we are moving into X
	INC	UNIT_LOC_Y,X		Move it's Y location down 
	LDA	#1			Flag that move was successful & return (sets A to 1, saves 1 byte)
	STA	MOVE_RESULT		
	RTS

REQUEST_WALK_UP:
	LDY	UNITPRE			Get 16 bit unit # that wants to move
	LDB	UNIT_LOC_Y,Y		Get it's Y location
	CMPB	#3			Already as far up as we will allow (3 - we don't let them get to 0)?
	BEQ	MGFAIL			Yes, exit with failed move
	DECB				No, move it up 1
	LDA	UNIT_LOC_X,Y		Get X location as well
	STD	MAP_X			Save updated coords for subroutines
	JSR	GET_TILE_FROM_MAP	Get the tile # from the new location
	LDY	TILEPRE			Get 16 bit tile #
	LDA	TILE_ATTRIB,Y		Get attributes for that tile type
	ANDA 	MOVE_TYPE		Check, can walk on this tile?
	BEQ	MGFAIL			If AND results in no bits set, exit with move request failed (don't move)
	BSR	CHECK_FOR_UNIT		See if player or robot at MAP_X,MAP_Y
	BPL	MGFAIL			Yes, don't allow move
	LDX	UNITPRE			No, get unit # we are moving into X
	DEC	UNIT_LOC_Y,X		Move it's Y location down
	LDA	#1			Flag that move was successful & return (sets A to 1, saves 1 byte)
	STA	MOVE_RESULT
	RTS

;This routine checks a specific place on the map specified
;in MAP_X and MAP_Y to see if there is a unit present at 
;that spot. If so, the unit# will be stored in UNIT_FIND
;otherwise 255 will be stored.
; NOTE: 'Unit' in this case is players or robots ONLY
; Exit: B=unit found (255=none) (also stored in UNIT_FIND)
;   if no unit found, Negative bit set on exit. If found,
;   negative bit clear 
CHECK_FOR_UNIT:
	LDB	#27			Start on unit 27 (last robot)
	LDX	#UNIT_TYPE		Point to Unit_type table to start
CFU0:
	LDA	B,X			Is this unit active?
	BNE	CFU02			Yes, go check coordinates
CFU0B:
	DECB				Check previous unit
	BPL	CFU0			Until done down to (and including) player unit            
	BRA	CFU01			Exit with unit not found in B / UNIT_FIND

CFU0A:
	LDX	#UNIT_TYPE		Reset X to point to Unit_type 
	BRA	CFU0B			And continue onto next

; active unit, check X,Y coords
CFU02:	LDX	#UNIT_LOC_X		Point to X coord table    
	LDA	B,X			Get unit X coord
	CMPA	MAP_X			Match one we are looking for?
	BNE	CFU0A			No, onto next one
	LDX	#UNIT_LOC_Y		Point to Y coord table
	LDA	B,X			Get unit Y coord
	CMPA	MAP_Y			Match one we are looking for?
	BNE	CFU0A			No, onto next one
CFU01:
	STB	UNIT_FIND		Flag no units found & return
	RTS

;This routine checks a specific place on the map specified
;in MAP_X and MAP_Y to see if there is a hidden unit present 
;at that spot. If so, the unit# will be stored in UNIT_FIND
;otherwise 255 will be stored. 
CHECK_FOR_HIDDEN_UNIT:
	LDX	#48		Hidden units start at unit #48
CFH00:	
	LDA	UNIT_TYPE,X 	Unit exist?
	BNE	CFH02		Yes, check it's position
CFH01:	
	LEAX	1,X		No, bump up to next unit
	CMPX	#64		Done checking all hidden units?
	BNE	CFH00		No, try next one
	LDB	#255		Yes, flag no units found
	STB	UNIT_FIND
	RTS

;first compare horizontal position
CFH02:
	LDB	UNIT_LOC_X,X	Get X coord of hidden unit
	CMPB	MAP_X		Match X coord of where we are searching?
	BEQ	CFH05		Yes, go check Y coord
	BHI	CFH01		If unit's start X is right of player, go onto next unit
CFH03:
; Hidden unit's start X is left of the player - see if player X is within width of hidden object
	ADDB	UNIT_C,X	Add hidden unit width (B=far right coord that is part of search)
	CMPB	MAP_X		Is that now equal to where we are searching?
	BLO	CFH01		If unit's rightmost X < our search X, go onto next unit
; now compare vertical position
CFH05: 
	LDB	UNIT_LOC_Y,X	Get Y coord of hidden unit
	CMPB	MAP_Y		Match Y coord we are searching?
	BEQ	CFH10		Yes, exit with this unit number
	BHI	CFH01		If unit's start Y is > search Y then onto next unit
CFH06:
	ADDB	UNIT_D,X	Add hidden unit height
	CMPB	MAP_Y		Is that now equal to where we are searching?
	BLO	CFH01		If unit's bottom most Y < our search  Y, go onto next unit
CFH10:
; LCB NOTE: SHOULD BE ABLE TO STX UNIT_FINDPRE HERE, OR INSTEAD CHANGE CALLING ROUTINE TO CHECK B ON RETURN
	TFR	X,D	 	Move unit # to B
	STB	UNIT_FIND	Save for caller & return
	RTS

;NOTES ABOUT UNIT TYPES
;----------------------
;000=no unit (does not exist)
;001=player unit
;002=hoverbot left-to-right
;003=hoverbot up-down
;004=hoverbot attack mode
;005=hoverbot chase player
;006=
;007=transporter
;008=
;009=evilbot chase player
;010=door
;011=small explosion
;012=pistol fire up
;013=pistol fire down
;014=pistol fire left
;015=pistol fire right
;016=trash compactor
;017=
;018=
;019=
;020=

;NOTES ABOUT UNIT NUMBERING SCHEME
;---------------------------------
;0 = player unit
;1-27 = enemy robots	(max 28 units)
;28-31 = weapons fire
;32-47 = doors and other units that don't have sprites (max 16 units)
;48-63 = hidden objects to be found (max 16 units)

;NOTES ABOUT DOORS.
;-------------------
;A-0=horitzonal 1=vertical
;B-0=opening-A 1=opening-B 2=OPEN / 3=closing-A 4=closing-B 5-CLOSED
;C-0=unlocked / 1=locked spade 2=locked heart 3=locked star
;D-0=automatic / 0=manual

;HIDDEN OBJECTS
;--------------
;UNIT_TYPE:128=key UNIT_A: 0=SPADE 1=HEART 2=STAR
;UNIT_TYPE:129=time bomb
;UNIT_TYPE:130=EMP
;UNIT_TYPE:131=pistol
;UNIT_TYPE:132=charged plasma gun
;UNIT_TYPE:133=medkit
;UNIT_TYPE:134=magnet

;NOTES ABOUT TRANSPORTER
;----------------------
;UNIT_A: 0=always active	1=only active when all robots are dead
;UNIT_B:	0=completes level 1=send to coordinates
;UNIT_C:	X-coordinate
;UNIT_D:	Y-coordinate

;Sound Effects
;----------------------
;0 explosion
;1 small explosion
;2 medkit
;3 emp
;4 haywire
;5 evilbot
;6 move
;7 electric shock
;8 plasma gun
;9 fire pistol
;10 item found
;11 error
;12 change weapons
;13 change items
;14 door
;15 menu beep
;16 walk
;17 sfx (short beep)
;18 sfx
