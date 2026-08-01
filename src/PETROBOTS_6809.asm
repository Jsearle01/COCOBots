; NOTE: Hacked in shutting IRQ's off while redrawing the screen. This way VSYNC timer counts stop while
; refreshing the screen, making it more fair to the player (until dirty tile speed ups are done).
; Otherwise, since it takes several VSYNC's to draw the screen, the robot AI's keep processing while
; the player waits for the screen.
; See DRAW_MAP_WINDOW: if you want to shut it off.
; LCB 01/28/2022

;PETSCII Robots (Color Computer 3 Version)
;by Jay searle 2021-2022, L. Curtis Boyle
;jay.searle1973@gmail.com

;PETSCII Robots (PET 4032 version)
;by David Murray 2020
;dfwgreencars@gmail.com

  PRAGMA operandsizewarning
  PRAGMA 6809

  ORG $01FF

STACK RMB 1

  ORG $0200

;***These arrays can go anywhere in RAM***
UNIT_TIMER_A	RMB	64		;Primary timer for units (64 bytes)
UNIT_TIMER_B	RMB	64		;Secondary timer for units (64 bytes)
UNIT_TILE	RMB	32		;Current tile assigned to unit (32 bytes)
UNIT_ALT_MOVE	RMB	32		;For moving around objects (32 bytes)
UNIT_DEST_X	RMB	32		;Destination X coordinate (32 bytes)
UNIT_DEST_Y	RMB	32		;Destination X coordinate (32 bytes)
MAP_PRECALC	RMB	77		;Stores pre-calculated objects for map window (77 bytes)

;PLASMA Gun (PET / C64)
WEAPON1A:	.BYTE	$2c,$20,$20,$20,$20,$2c
WEAPON1B:	.BYTE	$e2,$f9,$ef,$e4,$66,$66
WEAPON1C:	.BYTE	$20,$20,$20,$20,$5f,$df
WEAPON1D:	.BYTE	$20,$20,$20,$20,$20,$20

;PISTOL (PET / C64)
PISTOL1A:	
		.BYTE	$20,$20,$20,$20,$20,$20
		.BYTE	$20,$68,$62,$62,$62,$20
		.BYTE	$20,$20,$20,$5f,$df,$20
BLANK1A:	
		.BYTE	$20,$20,$20,$20,$20,$20
		.BYTE	$20,$20,$20,$20,$20,$20
		.BYTE	$20,$20,$20,$20,$20,$20
		.BYTE	$20,$20,$20,$20,$20,$20

;Time Bomb  (PET / C64)
TBOMB1A		.BYTE	$20,$20,$55,$2a,$20,$20
TBOMB1B		.BYTE	$20,$55,$66,$49,$20,$20
TBOMB1C		.BYTE	$20,$42,$20,$48,$20,$20
TBOMB1D		.BYTE	$20,$4a,$46,$4b,$20,$20

;EMP (PET / C64)
EMP1A		.BYTE	$20,$55,$43,$43,$49,$20
EMP1B		.BYTE	$66,$df,$55,$49,$e9,$66
EMP1C		.BYTE	$66,$69,$4a,$4b,$5f,$66
EMP1D		.BYTE	$20,$4a,$46,$46,$4b,$20

;Magnet (PET / C64)
MAG1A		.BYTE	$4d,$70,$6e,$70,$6e,$4e
MAG1B		.BYTE	$20,$42,$42,$48,$48,$20
MAG1C		.BYTE	$63,$42,$4a,$4b,$48,$63
MAG1D		.BYTE	$4e,$4a,$46,$46,$4b,$4d

MAP_BUFFER RMB 128

  ORG $41F6
PETSCII_COCO	RMB	4096		4x32 bytes/char PETSCII font (0-127)

  ORG $5200
DESTRUCT_PATH   RMB	256		;Destruct path array (256 bytes)
TILE_ATTRIB	RMB	256		;Tile attrib array (256 bytes)
TILE_DATA_TL    RMB	256		;Tile character top-left (256 bytes)
TILE_DATA_TM    RMB	256		;Tile character top-middle (256 bytes)
TILE_DATA_TR    RMB	256		;Tile character top-right (256 bytes)
TILE_DATA_ML    RMB	256		;Tile character middle-left (256 bytes)
TILE_DATA_MM    RMB	256		;Tile character middle-middle (256 bytes)
TILE_DATA_MR    RMB	256		;Tile character middle-right (256 bytes)
TILE_DATA_BL    RMB	256		;Tile character bottom-left (256 bytes)
TILE_DATA_BM    RMB	256		;Tile character bottom-middle (256 bytes)
TILE_DATA_BR    RMB	256		;Tile character bottom-right (256 bytes)

    ORG $5d00
;map preamble
UNIT_TYPE	RMB	64		;Unit type 0=none (64 bytes)	
UNIT_LOC_X	RMB	64		;Unit X location (64 bytes) 5D40
UNIT_LOC_Y	RMB	64		;Unit Y location (64 bytes) 5D80
UNIT_A		RMB	64		;Varies by unit type 5DC0
UNIT_B		RMB	64		;Varies by unit type 5E00
UNIT_C		RMB	64		;Varies by unit type 5E40
UNIT_D		RMB	64		;Varies by unit type 5E80
UNIT_HEALTH	RMB	64		;Unit health (0 to 11) (64 bytes) 5EC0

MAP		RMB	$2000		;Location of MAP (8K) 5F00

  ORG $0000
;*** Direct Page locations. All inited to zero when program initializes
TILEPRE		RMB	1		;To allow 16 bit loads w/o CLRA/B TFR's
TILE		RMB	1		;Current tile # for many routines
TEMP_X		RMB	1		;Temporarily used for loops
TEMP_Y		RMB	1		;Temporarily used for loops
MAP_X		RMB	1		;Current X location on map
MAP_Y		RMB	1		;Current Y location on map
MAP_WINDOW_X	RMB	1		;Top left location of what is displayed in map window
MAP_WINDOW_Y	RMB	1		;Top left location of what is displayed in map window
MAP_WINDOW_XMAX	RMB	1		;Bottom right X location of what is displayed in map window
MAP_WINDOW_YMAX	RMB	1		;Bottom right Y location of what is displayed in map window
DECNUM		RMB	1		;a decimal number to be displayed onscreen as 3 digits.
ATTRIB		RMB	1		;Tile attribute value
UNITPRE		RMB	1		;To allow 16 bit loads w/o CLRA/B TFR's
UNIT		RMB	1		;Current unit being processed
TEMP_A		RMB	1		;used within some routines
TEMP_B		RMB	1		;used within some routines
TEMP_C		RMB	1		;used within some routines
TEMP_D		RMB	1		;used within some routines
CURSOR_X	RMB	1		;For on-screen cursor
CURSOR_Y	RMB	1		;For on-screen cursor
CURSOR_ON	RMB	1		;Is cursor active or not? 1=yes 0=no
REDRAW_WINDOW	RMB	1		;1=yes 0=no
MOVE_RESULT	RMB	1		;1=Move request success, 0=fail.
UNIT_FINDPRE	RMB	1		;To allow 16 bit loads w/o CLRA/B TFR's
UNIT_FIND	RMB	1		;255=no unit present, else Unit # found
MOVE_TYPE	RMB	1		;%00000001=WALK %00000010=HOVER
PRECALC_COUNT	RMB	1		;part of screen draw routine
; CUR_PATTERN_L	=$3A	;stores the memory location of the current
; CUR_PATTERN_H	=$3B	;musical pattern being played.
INVERSE		RMB	1		;INVERSE FLAG FOR CHARACTER PLOTTING
CURRENTSCREEN	RMB	2		;(16 BIT) HOLD CURRENT CHARACTER SCREEN POSITION
SCRATCH		RMB	2		;SCRATCH AREA (WORD SIZE) USUALLY USED FOR GRAPHICS PAGE INDEXING
;The following are the locations where the current
;key controls are stored.  These must be set before
;the game can start.
KEY_MOVE_UP	RMB	1
KEY_MOVE_DOWN	RMB	1
KEY_MOVE_LEFT	RMB	1
KEY_MOVE_RIGHT	RMB	1
KEY_FIRE_UP	RMB	1	
KEY_FIRE_DOWN	RMB	1
KEY_FIRE_LEFT	RMB	1
KEY_FIRE_RIGHT	RMB	1
KEY_CYCLE_WEAPONS	RMB	1
KEY_CYCLE_ITEMS	RMB	1
KEY_USE		RMB	1
KEY_SEARCH      RMB	1
KEY_MOVE        RMB	1
KEY_MAP   RMB 1
BGTIMER1	.BYTE	00
BGTIMER2	.BYTE	00
KEYTIMER:	RMB	1		# of ticks until a repeated key will be issued (1st key is longer than subsequent)
KEYTIMER_STARTDELAY:	RMB	1		Initial delay before key repeat kicks in (usually longer than actual repeat delay)
KEYTIMER_DELAY:	RMB	1		What to reset keytimer to when it hits 0
PREV_KEY:	RMB	1		Saved copy of previous key pressed when key repeat enabled (KEY_FAST)
CURRENT_KEY:	RMB	1		Saved copy of current key pressed
COUNTER		.BYTE	15
CLOCK_ACTIVE	.BYTE	00
MOVTEMP_O:	.BYTE	00		;origin tile
MOVTEMP_D:	.BYTE	00		;destination tile
MOVTEMP_X:	.BYTE	00		;x-coordinate
MOVTEMP_Y:	.BYTE	00		;y-coordinate
MOVTEMP_U:	.BYTE	00		;unit number (255=none)
MOVTEMP_UX	.BYTE	00
MOVTEMP_UY	.BYTE	00
RPT		RMB	1		;repeat value
BYTECOUNT	RMB	1		;TRACKS X AXIS BYTE TRANSITION
TEMPY		RMW	1
TEMPB		RMB	1
DOORPIECE1	.BYTE	00		; character 1 for Door graphics
DOORPIECE2	.BYTE	00		; character 2 for Door graphics
DOORPIECE3	.BYTE	00		; character 3 for Door graphics
ELEVATOR_MAX_FLOOR	.BYTE	00
ELEVATOR_CURRENT_FLOOR	.BYTE	00
DECREM		.BYTE	$00
MENUY		.BYTE	$00		;CURRENT MENU SELECTION
KEYS		.BYTE	$00		;Players KEY inventory flags bit0=spade bit1=heart bit2=star 
AMMO_PISTOL	.BYTE	0		;how much ammo for the pistol
AMMO_PLASMA	.BYTE	0		;how many shots of the plasmagun
INV_BOMBS	.BYTE	0		;How many bombs do we have
INV_EMP	 	.BYTE	0		;How many EMPs do we have
INV_MEDKIT	.BYTE	0		;How many medkits do we have?
INV_MAGNET	.BYTE	0		;How many magnets do we have?
SELECTED_WEAPON	.BYTE	0		;0=none 1=pistol 2=plasmagun
SELECTED_ITEM	.BYTE	0		;0=none 1=bomb 2=EMP 3=medkit 4=magnet
MAGNET_ACT	.BYTE	00		;0=no magnet active 1=magnet active
PLASMA_ACT	.BYTE	00		;0=No plasma fire active 1=plasma fire active
BIG_EXP_ACT	.BYTE	00		;0=No explosion active 1=big explosion active
CYCLES		.BYTE	60		# VSYNC cycles / second (60 for NTSC, 50 for PAL)
SECONDS		.BYTE	00
MINUTES		.BYTE	00
HOURS		.BYTE	00
SELECT_TIMEOUT	.BYTE	00		;Delay before player can make new selection - can only change weapons once it hits zero
ANIMATE		.BYTE 	01		;0=DISABLED 1=ENABLED  Animate water flag (we will likely tie in with palette change?)
RANDOM		.BYTE	00		;used for random number generation
BORDER		.BYTE	00		;Used for border flash timing
SCREEN_SHAKE	.BYTE	00		;1=shake 0=no shake
CONTROL		.BYTE	00		;0=keyboard 1=custom keys 2=snes
SELECTED_MAP	.BYTE	00		Which map player has selected
TCPIECE1	.BYTE	00		Character 1 for Trash Compactor
TCPIECE2	.BYTE	00		Character 2 for Trash Compactor
TCPIECE3	.BYTE	00		Character 3 for Trash Compactor
TCPIECE4	.BYTE	00		Character 4 for Trash Compactor
EXP_BUFFER	RMB	16		;Explosion Buffer (16 bytes)
SCRN_ADDRESS	RMB	2		Upper left corner character position on screen of 6x4 object
LINE_COUNTER	RMB	1		Which line # (1-4) we are doing
BIGEXP_CENTER:	RMB	2		Center of current Big Explosion (for faster access)
WATER_TEMP1:	.BYTE	00		Temp to hold animation tile char we are swapping around (trash compactor, water)
CINEMA_STATE:	.WORD	00		Current character offset for cinema messages (0-196)
PIA_COLUMN:	RMB	1		Keeps track of PIA column for keyboard read
WATER_TIMER	.BYTE 20
HVAC_STATE	.BYTE 00
FLASH_DELAY .BYTE 00

;Some constants for screen positioning (equates for assembler to use - put near start). Will be used for character positioning,
;etc. so that we can see where stuff is getting placed rather than having to work backwards from a screen address (will aid in
;Coco 1/2 port)
SCREEN:		EQU	$8000		Start address of 320x200x16 graphics screen
PIXEL_ROWSIZE:	EQU	160		# bytes per row of pixels
CHAR_ROWSIZE:	EQU	PIXEL_ROWSIZE*8	# bytes per row characters (1280)
CHAR_WIDTH:	EQU	4		# bytes wide per character (8 pixels)


; Load address of PETSCII.BIN
	ORG	$0E00

BLACK	equ	%00000000

; LCB NOTE: Likely move any of these we need into DP
;seed	RMB	2
;irqcnt	RMB	1
color	RMB	1

START
; Relocate stack
	LDS	#STACK
; Set direct page to 0
	CLRA
	TFR	A,DP

; ;load file loader to 0200
;   LDY #$0200
;   LDU #FILELOADER
;   JSR LOAD_FILE
; ;load levela to $5d00
;   LDY #$5D00
;   LDU #MAPNAME
;   JSR LOAD_FILE

; Disable IRQ and FIRQ
	ORCC	#%01010000
; Turn off ROMs
	LBSR	romsoff
; 1.78 Mhz CPU
	LBSR	fast
; Init graphics
	LBSR	gfxinit
; Clear screen
	LDA	#BLACK
	STA	color
	LBSR	gfxclear
INTRO: 
; Disable IRQ and FIRQ
	ORCC	#%01010000
; CLEAR DIRECT PAGE
	LDX	#0
	CLRB
CLRLP:      
	CLR	,X+
	INCB
	BNE	CLRLP
	LDA	#15
	STA	COUNTER

;JSR	DISPLAY_LOAD_MESSAGE1
;JSR	TILE_LOAD_ROUTINE

	JSR	SETUP_INTERRUPT
	JSR	SET_CONTROLS		copy initial key controls
; LCB NOTE: once level loading working, remove this label
RESTART_GAME:
	JSR	INTRO_SCREEN		Draw title screen

INIT_GAME:
	LDA	#96
	STA	UNIT_TILE
	CLRA
	STA	CURSOR_ON		Default cursor to OFF
	STA	SCREEN_SHAKE		Default screen shake to off
	JSR	RESET_KEYS_AMMO		Reset inventory & active event flags, timer (may need to save a 1 to UNIT_TYPE)
	JSR	DISPLAY_GAME_SCREEN	Draw game screen

; JSR	DISPLAY_LOAD_MESSAGE2
; JSR	MAP_LOAD_ROUTINE		LCB NOTE: Until this is working, restarting the game will not work right.

  JSR CHEATER		Cheat mode - max us out for posessions
	JSR	SET_DIFF_LEVEL		Set difficulty level
	JSR	ANIMATE_PLAYER		Change animation tile # for player
	JSR	DISPLAY_PLAYER_HEALTH	Display player's health bar
	JSR	DISPLAY_KEYS		Display keys in player's possession
	JSR	DISPLAY_WEAPON		Display default selected weapon for player
	JSR	DISPLAY_ITEM		Display default selected item for player
	JSR	CALCULATE_AND_REDRAW	Calculate MAP_WINDOW_X/Y (where in map our viewable window starts) & flag to redraw screen
	JSR	DRAW_MAP_WINDOW		Actually draw the viewable 11x7 map portion of screen
	LDA	#1			Set player's unit_type to 1 (alive)
	STA	UNIT_TYPE
	JSR	SET_INITIAL_TIMERS	Init various timers
	JSR	PRINT_INTRO_MESSAGE	Print "welcome to pet-robots" etc. message in 3 line text window
	LDD	#13*256+6		Set defaults to 13 tick delay before key repeat starts, 6 ticks between repeats
	STD	KEYTIMER_STARTDELAY
	LDA	#30			Init keyboard timer to 30 ticks temporarily for start of game
	STA	KEYTIMER
	JMP	MAIN_GAME_LOOP		Enter the main game loop

; LCB NOTE: I see that other ports change the name to reflect the system. 'CocoBots' maybe?
INTRO_MESSAGE:
	.STR	"welcome to pet-robots! "
	.BYTE	255
	.STR	"by david murray 2021"
	.BYTE	255
	.STR	"coco3 by jsearle & lcboyle 2022"
	.BYTE	0

MSG_CANTMOVE:
	.STR	"can't move that!"
	.BYTE	0

MSG_BLOCKED:
	.STR	"blocked!"
	.BYTE	0

MSG_SEARCHING:
	.STR	"searching"
	.BYTE	0 

MSG_NOTFOUND:	
	.STR	"nothing found here."
	.BYTE	0

MSG_FOUNDKEY:
	.STR	"you found a key card!"
	.BYTE	0

MSG_FOUNDGUN:
	.STR	"you found a pistol!"
	.BYTE	0

MSG_FOUNDEMP:	
	.STR	"you found an emp device!"
	.BYTE	0

MSG_FOUNDBOMB:
	.STR	"you found a timebomb!"
	.BYTE	0

MSG_FOUNDPLAS:
	.STR	"you found a plasma gun!"
	.BYTE	0

MSG_FOUNDMED:
	.STR	"you found a medkit!"
	.BYTE	0

MSG_FOUNDMAG:
	.STR	"you found a magnet!"
	.BYTE	0

MSG_MUCHBET:
	.STR	"ahhh, much better!"
	.BYTE	0

MSG_EMPUSED:	
	.STR	"emp activated!"
	.BYTE	255
	.STR	"nearby robots are rebooting."
	.BYTE	0

MSG_TERMINATED:	
	.STR	"you're terminated!"
	.BYTE	0

MSG_TRANS1:	
	.STR	"transporter will not activate"
	.BYTE	255
	.STR	"until all robots destroyed."
	.BYTE	0

MSG_ELEVATOR:
	.BYTE	$1B			'[' character
	.STR	" elevator panel "
	.BYTE	$1D			']' character
	.STR	"  down"
	.BYTE	255
	.BYTE	$1B			'[' character
	.STR	"  select level  "
	.BYTE	$1D 			']' character
	.STR	"  opens"
	.BYTE	0

MSG_LEVELS:
	.BYTE	$1B			'[' character
	.STR	"                "
	.BYTE	$1D			']' character
	.STR	"  door"
	.BYTE	0

MSG_PAUSED:	
	.STR	"game paused."
	.BYTE	255
	.STR	"exit game (y/n)"
	.BYTE	0 

CINEMA_MESSAGE:
	.STR "coming soon: space balls 2 - the search for more money       "
	.STR "attack of the paperclips: clippy's revenge       "
	.STR "it came from planet earth       "
	.STR "rocky 5000, all my circuits the movie       "
	.STR "conan the librarian, and more!       " 

MAP_NAMES:	
	.STR "01-research lab "
	.STR "02-headquarters "
	.STR "03-the village  "
	.STR "04-the islands  "
	.STR "05-downtown     "
	.STR "06-pi university"
	.STR "07-more islands "
	.STR "08-robot hotel  "
	.STR "09-forest moon  "
	.STR "10-death tower  "

MAP_FILENAME:
	.STR	"LEVELA  BIN"

SETUP_INTERRUPT:
; Set IRQ interrupt vector
	LDA	#$7E			JMP opcode 
	STA	$10C			Save to IRQ vector
	LEAU	<IRQ,PCR		Point to our IRQ handling routine
	STU	$10D			Save as address to jump to
* Disable HSYNC on PIA
	LDA	$FF01
	ANDA	#$FE
	STA	$FF01
* Enable VSYNC on PIA
	LDA	$FF03
	ORA	#$01
	STA	$FF03
* Enable IRQ/FIRQ again & return
	ANDCC	#%10101111
	RTS

; MAIN IRQ HANDLING ROUTINE
;This is the routine that runs every 60 seconds from the IRQ.
;BGTIMER1 is always set to 1 every cycle, after which the main
;program will reset it to 0 when it is done with it's work for
;that cycle.  BGTIMER2 is a count-down to zero and then stays
;there.
IRQ:
	ORCC	#%01010000		disable IRQ/FIRQ
; Turn on border (DEBUG)
	
* Begin poll keyboard
;	LBSR	romson			Enable BASIC ROM's to "borrow" keyboard poll routine
;	JSR	[$A000]			Call POLCAT Color BASIC keyboard routine (keypress in A, zero flag set depending on A. 0=no key)
;	LBSR	romsoff  		Turn ROM's back off
;	CMPA	CURRENT_KEY		Same key held now as previous key? (note: POLCAT only sends newly pressed keys, no repeat)
;	BEQ	COUNT			Yes, skip ahead
;	STA	CURRENT_KEY		No, save new key (will save 0 if no key pressed)
;	BRA	SKIP2
;
;COUNT:  DEC	COUNTER			Same key as previous; dec repeat counter
;	BNE	SKIP2			Still more waiting before we key repeat, skip ahead
;	LDA	#15			Key repeat timer reached, reset key repeat time to 15
;	STA	COUNTER
SKIP2:
  ;LDA	ARP_MODE	;ARP ROUTINE DISABLED
  ;CMP	#00		;SINCE NO MUSIC IS USING IT
  ;BEQ	IRQ20
  ;JSR	CYCLE_ARP
IRQ20:	
  ;JSR	MUSIC_ROUTINE
	BSR	UPDATE_GAME_CLOCK	Update game clock variables (ticks, seconds, minutes, hours) if clock is active
	JSR	ANIMATE_WATER		Animate water, cinema, HVAC, Server computer light
	LDA	#1
	STA	BGTIMER1		Init BGTIMER1 to 1
	LDA	BGTIMER2		Get BGTIMER2
	BEQ	IRQ1			If 0, skip ahead
	DEC	BGTIMER2		Otherwise drop by 1
IRQ1:	
;	LDA	KEYTIMER		Get keytimer (# ticks between keypresses getting released to game?)
;	BEQ	IRQ30			If ready to trigger, skip ahead
	DEC	KEYTIMER		Otherwise drop by 1
;	BRA	IRQ31			And skip reading the keyboard

IRQ30:	
	BSR	GETKEY			Go get key into A & <CURRENT_KEY
  ; LDA	BORDER			Get border flash timer
  ; BEQ	IRQ31			Ready to update flash, skip ahead
  ; DEC	BORDER			Otherwise drop by 1
IRQ31:
* Dismiss interrupt
	TST	$FF02			Acknowledge VSYNC IRQ on PIA

	ANDCC	#%10101111		Enable IRQ/FIRQ again
	RTI				and return from interrupt

; First, change the initial load value of CYCLES to 60 (or 50 for PAL) at the beginning of the code
;   (the 'CYCLES  .BYTE  00') part
; This will save a little room, and let 59 of 60 clock ticks exit 8 cycles faster
UPDATE_GAME_CLOCK:
	LDA	CLOCK_ACTIVE		Is clock active? (0=no, 1=yes)
	BEQ	UGC5			No, return
	DEC	CYCLES			Dec VSYNC counter
	BNE	UGC5			Haven't completed 1 second, return
	LDA	#60			Completed a second, Reset to 60 (50 for PAL/Dragon 64)
	STA	CYCLES		
	INC	SECONDS			Increase # of seconds that have elapsed this game
	LDA	SECONDS			Get new seconds value
	CMPA	#60			Finished a minute?
	BNE	UGC5			No, return
	CLR	SECONDS			Yes, reset seconds to 0			
	INC	MINUTES			Increase # of minutes that have elapsed this game
	LDA	MINUTES			Get new minutes value
	CMPA	#60			Finished an hour?
	BNE	UGC5			No, return
	CLR	SECONDS			Yes, reset seconds to 0
	CLR	MINUTES			And minutes to 0
	INC	HOURS			Increase # of hours that have elapsed this game
UGC5:	RTS

;This routine spaces out the timers so that not everything
;is running out once. It also starts the game_clock.
;essentially: $0200-$022F is $00 to $2F, $0240-$026F is $00
; (player, robots, weapons fire are cascaded timers)
SET_INITIAL_TIMERS:
	LDD	#$0001
	STB	CLOCK_ACTIVE		Flag Clock is active
	LDX	#UNIT_TIMER_A+$30	Point to end of first UNIT_TIMER table
	LDB	#47			Start 47 into each table (and last entry in A as 47)
SIT1:	
	STA	UNIT_TIMER_B-UNIT_TIMER_A-1,X	clear B timer entry
	STB	,-X			Save # into A timer entry
	DECB
	BPL	SIT1
	RTS

; Nick Marentes keyboard scanning to ASCII routine, modified by LCB for PETSCII. 
; GETKEY: Gets key directly from PIA, but only when KEYTIMER=0. Only single key (SHIFT, ALT, CTRL are treated as separate keys)
; Entry conditions: none
; Exit conditions: A=ASCII key value (0=no key is pressed). <CURRENT_KEY will also have copy of key
; Modifies: B,X
* THIS VERSION BASICALLY WORKS:
;GETKEY:
;	LDA	#$FE			start on least sig bit (column) - note a 0 bit defines the column
;	LDX	#ASCTBL			Point to start of ASCII conversion table
;COLUMN:
;	STA	$FF02			Set column on PIA
;ROW:
;	LDB	$FF00			Read back current row bits
;	BITB	#1			LCB NOTE: Test as is 1st, but then try lsrb / bcc instead of bitb (smaller, faster in native mode)
;	BEQ	GETASC			This row is pressed, look up ASCII of key
;	LEAX	1,X			Next row in ASCII table
;	BITB	#2			Next bit row on PIA
;	BEQ	GETASC
;	LEAX	1,X
;	BITB	#4			SPECULATION: If we use A instead of B for rows, and save column either on stack or DP
;	BEQ	GETASC			(adding a LDA (4 cycles) after all bits tested), we could preload B=0 before this check loop.
;	LEAX	1,X			Then these LEAX 1,X (5 cycles/2 bytes) could change to INCB (2 cycles/1 byte). The end of the
;	BITB	#8			inner loop (the lsla / ora #1 / cmpa) would need expanded and slowed down, though. Have to 
;	BEQ	GETASC			figure out cycle times for each of 7 cases to figure out if it's worth it.
;	LEAX	1,X			(Also, once a key is found and it goes to GETASC, insert an ABX to point to the correct char)
;	BITB	#16
;	BEQ	GETASC
;	LEAX	1,X
;	BITB	#32
;	BEQ	GETASC
;	LEAX	1,X
;	BITB	#64
;	BEQ	GETASC			Key press, go process
;	LEAX	1,X
;	LSLA				Shift to next column (remember, 0 bit is the active column)
;	ORA	#1			fill new bit with a 1
;	CMPA	#$FF			If we hit $FF, we have done all columns possible
;	BNE	COLUMN			Still more, go do
;NOKEY:
;	LDB	KEYTIMER_STARTDELAY	Get "reset" values for both initial repeat delay
;	STB	KEYTIMER		Save for repeating (if needed) later	
;	CLRA				No key pressed, return A=0
;	STA	PREV_KEY		Clear previous key (obviously no key repeat)
;SAVECURKEY:
;	STA	CURRENT_KEY		And clear current key
;	RTS
;
; Got a key - look up ASCII code and return to caller in A
;GETASC:
;	LDA	,X			Get key ASCII code from table
;	CMPA	PREV_KEY		Same as previous key?
;	BEQ	REPEAT			Yes, check if we should release as key repeat
; New key press different than previous. Immediately send as current key, clear previous, reset repeat timer to initial longer delay
;	STA	PREV_KEY		Save as previous key for repeat later
;	LDB	KEYTIMER_STARTDELAY	No, set initial key repeat timer
;	STB	KEYTIMER
;	BRA	SAVECURKEY		Save as current keypress & return
;
; Same key as previous is held down - only send out if timer=0. If it is 0, reset timer to regular delay
;REPEAT:	LDB	KEYTIMER		Is it time to release a repeat key?
;	BEQ	SENDREPEAT		Yes, send it out, reset timer
;	CLRA				No, clear out current key & return
;	BRA	SAVECURKEY
;
; Repeat key (timer triggered)
;SENDREPEAT:
;	LDB	KEYTIMER_DELAY		Yes, set regular key repeat timer
;	STB	KEYTIMER
;	BRA	SAVECURKEY		And return keypress to caller

;============ NEW OPTIMIZED VERSION (I HOPE) ===============
GETKEY:
	LDD	#$FE00			start on least sig bit (column) - note a 0 bit defines the column, And B=table offset
	LDX	#ASCTBL			Point to start of ASCII conversion table
COLUMN:	STA	PIA_COLUMN		Save copy
	STA	$FF02			and set column on PIA
ROW:
	LDA	$FF00			Read back current row bits
	LSRA				Bit 0 clear?
	BCC	GETASC			Yes, this key is pressed, get ASCII value
	INCB				No, onto next
	LSRA				Bit 1 clear?
	BCC	GETASC			Yes, this key is pressed, get ASCII value
	INCB				No, onto next
	LSRA				Bit 2 clear?
	BCC	GETASC			Yes, this key is pressed, get ASCII value
	INCB				No, onto next
	LSRA				Bit 3 clear?
	BCC	GETASC			Yes, this key is pressed, get ASCII value
	INCB				No, onto next
	LSRA				Bit 4 clear?
	BCC	GETASC			Yes, this key is pressed, get ASCII value
	INCB				No, onto next
	LSRA				Bit 5 clear?
	BCC	GETASC			Yes, this key is pressed, get ASCII value
	INCB				No, onto next
	LSRA				Bit 6 clear?
	BCC	GETASC			Yes, this key is pressed, get ASCII value
	INCB				No, onto next
	LDA	PIA_COLUMN		Get current Column select
	LSLA				Shift to next column (remember, 0 bit is the active column)
	ORA	#1			fill new bit with a 1
	CMPA	#$FF			If we hit $FF, we have done all columns possible
	BNE	COLUMN			Still more, go do
NOKEY:
	LDB	KEYTIMER_STARTDELAY	Get "reset" values for both initial repeat delay
	STB	KEYTIMER		Save for repeating (if needed) later	
	CLRA				No key pressed, return A=0
	STA	PREV_KEY		Clear previous key (obviously no key repeat)
SAVECURKEY:
	STA	CURRENT_KEY		And clear current key
	RTS

; Got a key - look up ASCII code and return to caller in A
GETASC:
	LDA	B,X			Get key ASCII code from table
	CMPA	PREV_KEY		Same as previous key?
	BEQ	REPEAT			Yes, check if we should release as key repeat
; New key press different than previous. Immediately send as current key, clear previous, reset repeat timer to initial longer delay
	STA	PREV_KEY		Save as previous key for repeat later
	LDB	KEYTIMER_STARTDELAY	No, set initial key repeat timer
	STB	KEYTIMER
	BRA	SAVECURKEY		Save as current keypress & return

; Same key as previous is held down - only send out if timer=0. If it is 0, reset timer to regular delay
REPEAT:	LDB	KEYTIMER		Is it time to release a repeat key?
	BEQ	SENDREPEAT		Yes, send it out, reset timer
	CLRA				No, clear out current key & return
	BRA	SAVECURKEY

; Repeat key (timer triggered)
SENDREPEAT:
	LDB	KEYTIMER_DELAY		Yes, set regular key repeat timer
	STB	KEYTIMER
	BRA	SAVECURKEY		And return keypress to caller
			

ASCTBL  FCB     $40,$48,$50,$58,$30,$38,$0D	@ H P X 0 8 ENTER
        FCB     $41,$49,$51,$59,$31,$39,$0C	A I Q Y 1 9 CLEAR
        FCB     $42,$4A,$52,$5A,$32,$3A,$03	B J R Z 2 : BREAK
        FCB     $43,$4B,$53,$5E,$33,$3B,$40	C K S UP 3 ; ALT
        FCB     $44,$4C,$54,$0A,$34,$2C,$BD	D L T DOWN 4 , CTRL
        FCB     $45,$4D,$55,$08,$35,$2D,$67	E M U LEFT 5 - F1
        FCB     $46,$4E,$56,$09,$36,$2E,$04	F N V RIGHT 6 . F2
        FCB     $47,$4F,$57,$20,$37,$2F,$01	G O W SPACE 7 / SHIFT (either; they are non-distinguishable)


* Loop back entry point after:firing weapon, use/search/move object, cycle weapon/unit. This clears the current keypress
* out as well, 
MAIN_GAME_LOOP2:
	LDD	#20			A=0 (no keypress), B=20 (key repeat start timer: 1/3rd of a second)
	STB	KEYTIMER_STARTDELAY
	STA	CURRENT_KEY
	STB	KEYTIMER
MAIN_GAME_LOOP:
	JSR	COCO_SCREEN_SHAKE	Shake screen if required
	JSR	BACKGROUND_TASKS	Perform background tasks (runs through AI routines for all non-player units)
	ANDCC	#%10101111		Enable interrupts
	LDA	UNIT_TYPE		Get player's unit type
	BNE	MG00			Player is still alive, proceed normally
DEAD_END:
	JMP	GAME_OVER		Player is dead, call game over routine

; Main game loop - check for keyboard commands
MG00:
;Keyboard controls here.
;	JSR	KEY_REPEAT		NOT ACTIVE YET (Check for key repeat (if key still pressed when timer runs out))
	LDA	CURRENT_KEY		Get current key pressed
	BEQ	MAIN_GAME_LOOP		None, go back to main game loop
;	LDB	#5			Got a key, reset the keytimer for 5 ticks until we register next keypress
;	STB	KEYTIMER
MG05:	
	CMPA	KEY_CYCLE_WEAPONS	Player hit CYCLE WEAPONS key? (default='1')
	BNE	MG06			No, check next
	JSR	CYCLE_WEAPON		Yes, cycle to next weapon in players inventory
;	JSR	CLEAR_KEY_BUFFER	Clear keypress & set timer until next key read to 20 ticks (1/3rd of a second)
	BRA	MAIN_GAME_LOOP2		Reset keyboard buffer/timer & back to main loop

MG06:	
	CMPA	KEY_CYCLE_ITEMS		Player hit CYCLE ITEMS key? (default='2')
	BNE	MG07			No, check next
	JSR	CYCLE_ITEM		Yes, cycle to next item in players inventory
;	JSR	CLEAR_KEY_BUFFER	Clear keypress & set timer until next key read to 20 ticks (1/3rd of a second)
	BRA	MAIN_GAME_LOOP2		Reset keyboard buffer/timer & back to main loop

MG07:	
	CMPA	KEY_MOVE		Player hit MOVE OBJECT key? (default='M')
	BNE	MG08			No, check next
	JSR	MOVE_OBJECT		Yes, attempt to move the object
;	JSR	CLEAR_KEY_BUFFER	Clear keypress & set timer until next key read to 20 ticks (1/3rd of a second)
	BRA	MAIN_GAME_LOOP2		Reset keyboard buffer/timer & back to main loop
MG08:	
	CMPA	KEY_SEARCH		Player hit SEARCH OBJECT key? (default='Z')
	BNE	MG09			No, check next
	JSR	SEARCH_OBJECT		Yes, attempt to search the object
;	JSR	CLEAR_KEY_BUFFER	Clear keypress & set timer until next key read to 20 ticks (1/3rd of a second)
	BRA	MAIN_GAME_LOOP2		Reset keyboard buffer/timer & back to main loop

MG09:	
	CMPA	KEY_USE			Player hit USE SELECTED ITEM key? (default=' ')
	BNE	MG10			No, check next
	JSR	USE_ITEM		Yes, attempt to use the item
;	JSR	CLEAR_KEY_BUFFER	Clear keypress & set timer until next key read to 20 ticks (1/3rd of a second)
	BRA	MAIN_GAME_LOOP2		Reset keyboard buffer/timer & back to main loop

MG10:	
	CMPA	KEY_MOVE_LEFT		Player hit MOVE LEFT key? (default='A')
	BNE	MG11			No, check next
	CLRA				Yes, Set UNIT to 0 (player unit)
	STA	UNIT
	INCA				Set move type to 1 (walk)
	STA	MOVE_TYPE
	JSR	REQUEST_WALK_LEFT	Attempt to move player left
	JMP	AFTER_MOVE		All 4 player movement directions go here
  
MG11:	
	CMPA	KEY_MOVE_DOWN		Player hit MOVE DOWN key? (default="S")
	BNE	MG12			No, check next
	CLRA				Yes, set UNIT to 0 (player unit)
	STA	UNIT
	INCA				Set move type to 1 (walk)
	STA	MOVE_TYPE
	JSR	REQUEST_WALK_DOWN	Attempt to move player down
	JMP	AFTER_MOVE		All 4 player movement directions go here
  
MG12:	
	CMPA	KEY_MOVE_RIGHT		Player hit MOVE RIGHT key? (default="D")
	BNE	MG13			No, check next
	CLRA				Yes, set UNIT to 0 (player unit)
	STA	UNIT
	INCA				Set move type to 1 (walk)
	STA	MOVE_TYPE
	JSR	REQUEST_WALK_RIGHT	Attempt to move player right
	JMP	AFTER_MOVE		All 4 player movement directions go here
  
MG13:	
	CMPA	KEY_MOVE_UP		Player hit MOVE UP key? (default="W")
	BNE	MG14			No, check next
	CLRA				Yes, set UNIT to 0 (player unit)
	STA	UNIT
	INCA				Set move type 1 (walk)
	STA	MOVE_TYPE
	JSR	REQUEST_WALK_UP		Attempt to move player up
	JMP	AFTER_MOVE		All 4 player movement directions go here
  
MG14:	
	CMPA	KEY_FIRE_UP		Player hit FIRE UP key? (default=Up Arrow)
	BNE	MG15			No, check next
	JSR	FIRE_UP			Attempt to fire up
	JMP	MAIN_GAME_LOOP2

MG15:	
	CMPA	KEY_FIRE_LEFT		Player hit FIRE LEFT key? (default=Left Arrow)
	BNE	MG16			No, check next
	JSR	FIRE_LEFT		Attempt for fire left
	JMP	MAIN_GAME_LOOP2

MG16:	
	CMPA	KEY_FIRE_DOWN		Player hit FIRE DOWN key? (default=Down Arrow)
	BNE	MG17			No, check next
	JSR	FIRE_DOWN		Attempt to fire down
	JMP	MAIN_GAME_LOOP2

MG17:	
	CMPA	KEY_FIRE_RIGHT		Player hit FIRE RIGHT key? (default=Right Arrow)
	BNE	MG18			No, check next
	JSR	FIRE_RIGHT		Attempt to fire right
	JMP	MAIN_GAME_LOOP2

MG18:
  CMPA KEY_MAP	;X		
	BNE	MG22
  BSR TOP_MAP
  JMP	MAIN_GAME_LOOP2		Reset keyboard buffer/timer & back to main loop

;MG18:	
  ;CMPA	#03	;RUN/STOP		Pause game key? (currently disabled)
	;BNE	MG19
  ;BRA	PAUSE_GAME

MG19:	
  ;CMPA	#195	;SHIFT-C		Cheat mode key? (currently disabled)
	;BNE	MG20
  ;BSR	CHEATER
  ;JMP	MAIN_GAME_LOOP

MG20:	
;CMPA	#205	;SHIFT-M		Toggle Music on/off key (currently disabled)
	;BNE	MG21
;JSR	TOGGLE_MUSIC
;BSR	CLEAR_KEY_BUFFER



MG22:	
	JMP	MAIN_GAME_LOOP		;All other keys ignored ; back to start of game loop


; change to stack blast later (per row). Probably call CLEAR5 one line at a time:
;CLEAR5 entry:
; X,Y contains color to clear with
; B=# bytes to clear / 4
; A=# of lines to clear (do 1 each call since routine hadcoded for different line width to clear
; U=ptr to end of part to clear +1

TOP_MAP:  
	LDX	#$0000			zero value to clear table with (Black)
	LEAY	,X			Same for Y
	LDU	#SCREEN+132		point to start of screen+132
	LDA	#20  			clear 20 rows of pixels to black (above actual map display)
	STA	<TEMPMAP		Save ctr
TOP_MAP_LOOP:
	LDD	#1*256+(132/4)		1 line, 33 four-byte chunks to clear (132 bytes/264 pixels)
	JSR	CLEAR5			Clear the line (returns with U -164 from original position)
	LEAU	PIXEL_ROWSIZE+132,U	Point U to end of next line
	DEC	<TEMPMAP		Dec line ctr
	BNE	TOP_MAP_LOOP		Keep going until all 20 lines cleared

;TOP_MAP_LOOP:
;	STX	,U++			Zero out one lines worth
;	DECB
;	BNE	TOP_MAP_LOOP		Still more for current line, keep clearing
;	DECA				Dec # lines left to clear
;	BEQ	MAP_BODY		Done, continue
;	LEAU	28,U			Bump to next line on screen
;	BRA	TOP_MAP_LOOP2		And continue clearing
;MAP_BODY:
;	LEAU 2,U

; rewritten routine here
	LDU	#SCREEN+(PIXEL_ROWSIZE*20)+3	Point to 4 pixels in on 21st line where map drawing actually starts
	LDY	#MAP			Point to start of map data (128x64 tiles)
	LDD	#128*256+64		X & Y sizes of map
	PSHS	D			Save column/row counters on stack
MAP_NEXT_TILE:
	LDB	,Y+			Get tile from current map position
	LDX	#TILE_ATTRIB		Point to start of tile attributes table
	ABX				Point to attributes for current tile	
	LDA	,X			Get attributes for tile
	LDX	#ATTRIB_TO_MAP_TBL	Point to attrib color map table
NEXT_ATTRIB:
	CMPA    ,X++			Matching attribute?
	BEQ	FOUND_ATTRIB		Yes, go get color
	LDB	-2,X			Get attribute value
	BNE	NEXT_ATTRIB		Not $00 end marker, check next in table
	FCB	$8C			Is 0 end marker, CMPX immediate opcode (skip 2 bytes) with B=0
FOUND_ATTRIB:
	LDB	-1,X			Get color
BLACK_ATTRIB:
	STB	,U+			Save to screen
	STB	159,U			And one line below
	DEC	,S			Dec column ctr
	BNE	MAP_NEXT_TILE		Still more, continue
	DEC	1,S			Dec row ctr
	BEQ	BOTTOM_MAP		Done all rows, go clear out some lines on the bottom
	LDA	#128			Reset column ctr
	STA	,S
	LEAU	160+32,U		Point to start of next row on screen
	BRA	MAP_NEXT_TILE		Onto next row


* 2 bytes per entry: 1st byte is attribute byte, 2nd byte is color byte. attribute byte of $00
ATTRIB_TO_MAP_TBL:
	FCB	%00011011,$22		$1b,Green
	FCB	%00010010,$33		$12,Blue
	FCB	%00010000,$44		$10,Dark Grey
	FCB	%01000000,$55		$40,Light Grey
	FCB	%00010011,$66		$13,Brown
	FCB	%00110011,$77		$33,Light Blue
	FCB	%01010000,$88		$50,Tan
	FCB	%01011100,$99		$5C,Orange
	FCB	%00001100,$AA		$0C,Yellow
	FCB	%01010011,$55		$53,Light Grey
	FCB	%00001000,$BB		$08,Light Green
	FCB	%00011110,$CC		$1E,Light Orange
	FCB	%00011100,$CC		$1C,Light Orange
	FCB	%00011000,$BB		$18,Light Green
	FCB	%10000000,$BB		$80,Light Green
	FCB	%10001011,$66		$8B,Brown
	FCB	%10001000,$55		$88,Light Grey
	FCB	0,0			End of attribute color table marker (black for all other attributes)

**************************************
;	LEAU	28,U			Point to start of 21st line where map drawing actually starts;
;	LDA	#64
;	LDB	#64
;	LDY	#MAP			Point to start of current map
  
; This draws each map tile based on tile attributes. It draw 2x2 pixels of a single color per tile
;MAP_BODY_LOOP:
;	LDX	#0000			Clear 2 bytes/4 pixels to black at start of line
;	STX	,U++
;MAP_LOOP: 
;	PSHS	D			Preserve counters(?)
;	LDD	,Y			Get 2 bytes from map 
;	STD	TEMPMAP			Save copy
;	TFR	A,B			X=B
;	CLRA
;	TFR	D,X
;	LDA	TILE_ATTRIB,X		Get tile attributes
;	BNE	TEST_GREEN		There are some, go figure out color 
;	LDA	#$11			No attributes, default to color 1 (white)
;	JMP	TEST_B
;
;TEST_GREEN:
;	CMPA	#%00011011		$1B 
;	BNE	TEST_BLUE
;	LDA	#$22			Color 2 (green)
;	JMP	TEST_B

;TEST_BLUE:
;	CMPA	#%00010010		$12
;	BNE	TEST_GRAY
;	LDA	#$33			Color 3 (blue)
;	BRA	TEST_B

;TEST_GRAY:
;	CMPA	#%00010000		$10
;	BNE	TEST_LIGHT_GRAY
;	LDA	#$44			Color 4 (dark grey)
;	BRA	TEST_B

;TEST_LIGHT_GRAY:
;	CMPA	#%01000000		$40
;	BNE	TEST_BROWN
;	LDA	#$55			Color 5 (light grey)
;	BRA	TEST_B

;TEST_BROWN:
;	CMPA	#%00010011		$13
;	BNE	TEST_LIGHT_BLUE
;	LDA	#$66			Color 6 (brown)
;	BRA	TEST_B

;TEST_LIGHT_BLUE:
;	CMPA	#%00110011		$33
;	BNE	TEST_TAN
;	LDA	#$77			Color 7 (light blue)
;	BRA	TEST_B

;TEST_TAN:
;	CMPA	#%01010000		$50
;	BNE	TEST_ORANGE
;	LDA	#$88			Color 8 (tan)
;	BRA	TEST_B

;TEST_ORANGE:
;	CMPA	#%%01011100		$5C
;	BNE	TEST_YELLOW
;	LDA	#$99			Color 9 (orange)
;	BRA	TEST_B

;TEST_YELLOW:
;	CMPA	#%00001100		$0C
;	BNE	TEST_53
;	LDA	#$AA			Color $A (yellow)
;	BRA	TEST_B

;TEST_53:
;	CMPA	#%01010011		$53
;	BNE	TEST_08
;	LDA	#$55
;	BRA	TEST_B			Color 5 (light grey)

;TEST_08:
;	CMPA	#%00001000		$08
;	BNE	TEST_1E
;	LDA	#$BB			Color $B (light green)
;	BRA	TEST_B

;TEST_1E:
;	CMPA	#%00011110		$1E
;	BNE	TEST_1C
;	LDA	#$CC			Color $C (light orange)
;	BRA	TEST_B

;TEST_1C:
;	CMPA	#%00011100		$1C
;	BNE	TEST_18
;	LDA	#$CC			Color $C (light orange)
;	BRA	TEST_B

;TEST_18:
;	CMPA	#%00011000		$18
;	BNE	TEST_80
;	LDA	#$BB			Color $B (light green)
;	BRA	TEST_B

;TEST_80:
;	CMPA	#%10000000		$80
;	BNE	TEST_8B
;	LDA	#$BB			Color $B (light green)
;	BRA	TEST_B

;TEST_8B:
;	CMPA	#%10001011		$8B
;	BNE	TEST_88
;	LDA	#$66			Color 6 (brown)
;	BRA	TEST_B

;TEST_88:
;	CMPA	#%10001000		$88 (bug fix, was $80)
;	BNE	BLK
;	LDA	#$55			Color 5 (light grey)
;	BRA	TEST_B

;BLK:
;	LDA	#$00			Set color to black (use CLRA instead)

;TEST_B:
;	PSHS	A			Save color byte
;	LDD	TEMPMAP			X=2nd byte from map we saved earlier
;	CLRA
;	TFR	D,X
;	LDB	TILE_ATTRIB,X		Get attribute for 2nd map entry
;	BNE	TEST_GREEN2		There is one, go check for what colors we need
;	LDB	#$11 			No attributes set, 2 pixels of color 1
;	JMP	TRANS


; These are the same as ones above for the 2nd map byte. merge together
;TEST_GREEN2:
;  CMPB #$1B
;  BNE TEST_BLUE2
;  LDB #$22 
;  JMP TRANS 
;TEST_BLUE2:
;  CMPB #$12
;  BNE TEST_GRAY2
;  LDB #$33
;  BRA TRANS
;TEST_GRAY2:
;  CMPB #$10
;  BNE TEST_LIGHT_GRAY2
;  LDB #$44
;  BRA TRANS
;TEST_LIGHT_GRAY2:
;  CMPB #$40
;  BNE TEST_BROWN2
;  LDB #$55
;  BRA TRANS
;TEST_BROWN2:
;  CMPB #$13
;  BNE TEST_LIGHT_BLUE2
;  LDB #$66
;  BRA TRANS
;TEST_LIGHT_BLUE2:
;  CMPB #$33
;  BNE TEST_TAN2
;  LDB #$77
;  BRA TRANS
;TEST_TAN2:
;  CMPB #$50
;  BNE TEST_ORANGE2
;  LDB #$88
;  BRA TRANS
;TEST_ORANGE2:
;  CMPB #$5C
;  BNE TEST_YELLOW2
;  LDB #$99
;  BRA TRANS
;TEST_YELLOW2:
;  CMPB #$0C
;  BNE TEST_532
;  LDB #$AA
;  BRA TRANS
;TEST_532:
;  CMPB #$53
;  BNE TEST_082
;  LDB #$55
;  BRA TRANS
;TEST_082:
;  CMPB #$08
;  BNE TEST_1E2
;  LDB #$BB
;  BRA TRANS
;TEST_1E2:
;  CMPB #$1E
;  BNE TEST_1C2
;  LDB #$CC
;  BRA TRANS
;TEST_1C2:
;  CMPB #$1C
;  BNE TEST_182
;  LDB #$CC
;  BRA TRANS
;TEST_182:
;  CMPB #$18
;  BNE TEST_802
;  LDB #$22
;  BRA TRANS
;TEST_802:
;  CMPB #$80
;  BNE TEST_8B2
;  LDB #$BB
;  BRA TRANS
;TEST_8B2:
;  CMPB #$8B
;  BNE TEST_882
;  LDB #$66
;  BRA TRANS
;TEST_882:
;  CMPB #$88
;  BNE BLK2
;  LDB #$55
;  BRA TRANS
;BLK2:
;  LDB #$00

;TRANS:
;  PULS A
;  TFR D,X
;  PULS D  
;  STX ,U
;  LEAU 160,U
;  STX ,U
;  LEAU -158,U
;  ;LEAU 2,U
;  LEAY 2,Y
;  DECB
;  LBNE MAP_LOOP
;  DECA
;  BEQ BOTTOM_MAP
;  LDX #$0000
;  STX ,U
;  LEAU 2,U
;  LEAU 188,U
;  LDB #64
;  JMP MAP_BODY_LOOP

;BOTTOM_MAP: 
;  LEAU 30,U
;  LDX #$0000
;  LDB #66
;  LDA #20  
;BOTTOM_MAP_LOOP:  
;  STX ,U
;  LEAU 2,U
;  DECB
;  BNE BOTTOM_MAP_LOOP
;  DECA
;  BEQ SET_Y
;  LEAU 28,U
;  LDB #66
;  BRA BOTTOM_MAP_LOOP

;CLEAR5 entry:
; X,Y contains color to clear with
; B=# bytes to clear / 4
; A=# of lines to clear (do 1 each call since routine hardcoded for different line width to clear
; U=ptr to end of part to clear +1

BOTTOM_MAP:  
	LEAS 	2,s			Eat our temp stack
	LDX	#$0000			zero value to clear table with (Black)
	LEAY	,X			Same for Y
	LDU	#SCREEN+(20+128)*PIXEL_ROWSIZE+132		point to start of 2nd block to clear screen+132
	LDA	#20  			clear 20 rows of pixels to black (above actual map display)
	STA	<TEMPMAP		Save ctr
BOTTOM_MAP_LOOP:
	LDD	#1*256+(132/4)		1 line, 33 four-byte chunks to clear (132 bytes/264 pixels)
	JSR	CLEAR5			Clear the line (returns with U -164 from original position)
	LEAU	PIXEL_ROWSIZE+132,U	Point U to end of next line
	DEC	<TEMPMAP		Dec line ctr
	BNE	BOTTOM_MAP_LOOP		Keep going until all 20 lines cleared

; Display units - player in green, others in red
; swap X and Y register to shrink code
SET_Y:
	LDY	#28			Unit counter
KEY_CHECK_LOOP:
	LDA	CURRENT_KEY		Get current key pressed
	CMPA	KEY_MAP			'X'?
	BEQ	EXIT			Yes, user requested to exit map, go redraw screen
Y_LOOP:
	LEAY	-1,Y			Drop unit counter
	LDU	#SCREEN+(PIXEL_ROWSIZE*20)	($8c80) Point to start of 21st line screen
	LDA	UNIT_HEALTH,Y		Get unit's health
	BEQ	Y_LOOP 			Dead, skip to next one
	LDA	#PIXEL_ROWSIZE		Live, # of bytes/screen line
	LDB	UNIT_LOC_Y,Y		Get Y location
	LSLB				*2 (each unit location will be 2x2)
	MUL				Get Y offset
	LEAU	D,U			Point U to start of line
	LDA	UNIT_LOC_X,Y		Get unit's X location
	ADDA	#03			Offset 6 pixels in
	LEAU	A,U			Point to start of 2x2 square we will be displaying
	CLR	,U 			Set top 2 pixels to black
	CLR	160,U			And bottom 2 as well
	LDX	#$00FF			Small time delay
SLOW_DOWN:  
	LEAX	-1,X 
	BNE	SLOW_DOWN
COLOR_PLAYER:
	LEAY    ,Y			Done all units yet? (does CMPY #0 in only 2 bytes instead of 4)
	BEQ	PLAYER_GREEN		Yes, go do player
	LDA	#$DD			No, 2 red pixels for any robot
	FCB	$8C			CMPX immediate opcode (skip 2 bytes)
PLAYER_GREEN:
	LDA	#$BB			2 light green pixels for player
	STA	,U 			Put top 2 pixels on screen
	STA	160,U			And bottom 2 pixels
	LDX	#$00FF			Small time delay
SLOW_DOWN2:  
	LEAX	-1,X 
	BNE	SLOW_DOWN2
	LEAY    ,Y			Done all units yet? (does CMPY #0 in only 2 bytes instead of 4)
	BEQ	SET_Y	 		Yes, restart at last unit
	BRA	KEY_CHECK_LOOP		No, check for keypress & onto next unit

EXIT:
	LDA	#01			;Flag to redraw window
	STA	REDRAW_WINDOW
	RTS

TEMPMAP	RMB	1			Temp byte for map routine

;TEMP ROUTINE TO GIVE ME ALL ITEMS AND WEAPONS
CHEATER:
	LDA	#%00000111		least 3 sig bits are keys
	STA	KEYS			
	LDA	#100			100 ammo for both pistol and plasma gun
	STA	AMMO_PISTOL	
	STA	AMMO_PLASMA	
	STA	INV_BOMBS		And bombs, EMP's, Medkits and magnets
	STA	INV_EMP		
	STA	INV_MEDKIT	
	STA	INV_MAGNET
	LDA	#1			Default to Pistol, bomb
	STA	SELECTED_WEAPON
	STA	SELECTED_ITEM	
	JSR	DISPLAY_KEYS		Display Keys on screen
	JSR	DISPLAY_WEAPON		Display pistol on screen
	JMP	DISPLAY_ITEM		Display bomb on screen, and return from there.
	
; Currently disabled in MAIN_LOOP
PAUSE_GAME:
;LDA	#15
;JSR	PLAY_SOUND
;pause clock
	CLRA
	STA	CLOCK_ACTIVE
;display message to user
	JSR	SCROLL_INFO		Empty out the text window at the bottom
	LDY	#MSG_PAUSED		Display message that game is paused, do they want to quit
	JSR	PRINT_INFO
	CLRA
	STA	BGTIMER1		Clear out main TIMER1
PG0:	
	LDA	BGTIMER1		to prevent double-tap of run/stop
	BNE	PG0
;BSR	CLEAR_KEY_BUFFER
PG1:	
	LDA	CURRENT_KEY		Get last key pressed
	BEQ	PG1			None, keep reading until we get one.
	CMPA	#03	;RUN/STOP	Continue game?
	BEQ	PG5			Yes, do so
	CMPA	#78	;N-KEY		'N'o to exit game?
	BEQ	PG5			Yes, just continue game
	CMPA	#89	;Y-KEY		'Y'es to exit game?
	BEQ	PG6			Yes, force player to die
	BRA	PG1			Any other key, wait for a different keypress

; Continue game after pause
PG5:	
	JSR	CLEARALL		Clear all 3 lines in text window	
;BSR	CLEAR_KEY_BUFFER
	LDA	#1			Activate clock based routines again
	STA	CLOCK_ACTIVE
;LDA	#15
;JSR	PLAY_SOUND
	JMP	MAIN_GAME_LOOP		And back to the main game

PG6:	
	CLRA
	STA	UNIT_TYPE		;make player dead
;LDA	#15
;JSR	PLAY_SOUND
	JMP	GOM4
  
CLEAR_KEY_BUFFER:
	CLR  	CURRENT_KEY		Clear any key in the keyboard buffer
	LDA	#20			20 ticks until key repeat can kick in (1/3rd sec)
	STA	KEYTIMER
	RTS

;NEW - Use EMP
USE_EMP:
	JSR	EMP_FLASH		Flash the screen (likely replace with palette changes later)
	CLR	REDRAW_WINDOW		;attempt to delay window redrawing (pet only)
;LDA	#3		;EMP sound
;JSR	PLAY_SOUND	;SOUND PLAY
	DEC	INV_EMP
	JSR	DISPLAY_ITEM
	LDX	#27		Start with unit 27 (last robot)
EMP1:	;CHECK THAT UNIT EXISTS
	LDA	UNIT_TYPE,X	Robot active?
	BEQ	EMP5		No, on to next
;CHECK HORIZONTAL POSITION
	LDA	UNIT_LOC_X,X	Get robot X location
	CMPA	MAP_WINDOW_X	Robot left of viewable window?
	BLO	EMP5		Yes, skip
	CMPA	MAP_WINDOW_XMAX Robot right of viewable window?
	BHI	EMP5		Yes, skip
;NOW CHECK VERTICAL POSITION
	LDB	UNIT_LOC_Y,X	Get robot Y location
	CMPB	MAP_WINDOW_Y	Robot left of viewable window?
	BLO	EMP5		Yes, skip
	CMPB	MAP_WINDOW_YMAX Robot right of viewable window?
	BHI	EMP5		Yes, skip
	LDA	#255		Robot is on window with player, Set 255 timer before it can move again
	STA	UNIT_TIMER_A,X
;test to see if unit is above water
	LDA	UNIT_LOC_X,X	Get robot X location back
	STD	MAP_X		Save robot X,Y for subroutine
	JSR	GET_TILE_FROM_MAP Get tile # under robot (returns in A)
	CMPA	#204		Water?
	BNE	EMP5		No, skip to next one
	LDD	#5*256+60	Yes, change type and TIMER_A both to 5, how long to show sparks to 60
	STA	UNIT_TYPE,X
	STA	UNIT_TIMER_A,X
	STB	UNIT_A,X
	LDA	#140		;Electrocuting tile
	STA	UNIT_TILE,X
EMP5:	
	LEAX 	-1,X		Point to next unit
	BNE	EMP1		Still more left, go check
	LDY	#MSG_EMPUSED	Print message that EMP is activated
	JSR	PRINT_INFO
	LDA	#3		;3 cycles before next item can be used
	STA	SELECT_TIMEOUT
	RTS

USE_ITEM:
;check select timeout to prevent accidental double-tap
	LDA	SELECT_TIMEOUT		Timeout done yet?
	BEQ	UI01			Yes, go use item
	RTS				No, just return

;First figure out which item to use.
UI01:    
	LDA	SELECTED_ITEM		Get player's currently selected item
	DECA				BOMB? (1)
	BEQ    USE_BOMB			Yes, go use it
UI02:    
	DECA				EMP? (2)
	BEQ	USE_EMP			Yes, go use it
UI03:    
	DECA				MEDKIT? (3)
	LBEQ    USE_MEDKIT		Yes, go use it
UI04:    
	DECA				MAGNET? (4)
	BEQ	USE_MAGNET		Yes, go use it
UI05:    
	RTS				Otherwise return

USE_BOMB:
	JSR	USER_SELECT_OBJECT	Let user select object (invert the tile they select)
;NOW TEST TO SEE IF THAT SPOT IS OPEN
	JSR	BOMB_MAGNET_COMMON1	See if spot can be walked on
	BEQ	BM3A			If not, then exit routine.
BM30:
	JSR	CHECK_FOR_UNIT		Yes, check if player or robot at MAP_X,MAP_Y
	BMI	BM31			No, skip ahead
BM3A:	
	JMP	BOMB_MAGNET_COMMON2	Yes, print "BLOCKED!" & return from there

BM31:	
	LDX	#28			Start of weapons units
BOMB1:	
	LDA	UNIT_TYPE,X		Get type
	BEQ	BOMB2			Empty slot, go add in bomb
	LEAX	1,X			Full, bump next one
	CMPX	#32			Hit end of weapons (28-31 allowed)?
	BNE	BOMB1			No, try next
	RTS				no slots available right now, abort.
BOMB2:	
	LDD	#6*256+130		Bomb AI=6, Bomb tile=130
	STA	UNIT_TYPE,X
	STB	UNIT_TILE,X
	LDD	MAP_X			Get MAP_X,MAP_Y of spot player dropped bomb
	STA	UNIT_LOC_X,X		Save as bomb's X,Y
	STB	UNIT_LOC_Y,X
	LDD	#100*256+0		Time delay until explosion (100 ticks = 1&2/3 seconds), B=0
	STA	UNIT_TIMER_A,X
	STB	UNIT_A,X		? Not sure, but set to 0
	DEC	INV_BOMBS		Dec # of bombs in players inventory
	JSR	DISPLAY_ITEM		Update item display to show new bomb quantity
	LDD	#1*256+3		Flag to redraw window, 3 cycles before next item can be used
	STA	REDRAW_WINDOW
	STB	SELECT_TIMEOUT 		;pet version only (# ticks before another select can be made)
;LDA	#06		;move sound
;JSR	PLAY_SOUND	;SOUND PLAY
MAGEXIT:
	RTS

USE_MAGNET:
	LDA	MAGNET_ACT		Is there a magnet already active?
	BNE	MAGEXIT			Yes, we can only have one at a time, so return
MG32:	
	JSR	USER_SELECT_OBJECT	No, let player select the direction they are dropping the magnet (inverts tile)
;NOW TEST TO SEE IF THAT SPOT IS OPEN
	BSR	BOMB_MAGNET_COMMON1	Check if spot available can be walked over
	BEQ	BOMB_MAGNET_COMMON2	No, print "Blocked!" & return from there
MG31:  
	LDX	#28			Yes, go through weapons units (28-31)
MAG1:	
	LDA	UNIT_TYPE,X		Get unit type
	BEQ	MAG2			Empty slot, go add magnet
	LEAX	1,X			Full, bump to next one
	CMPX	#32			Hit end of weapons units?
	BNE	MAG1			No, try next slot
	RTS				no slots available right now, abort.

MAG2:	
	LDD	#20*256+134		A=Magnet AI, B=Magnet tile #
	STA	UNIT_TYPE,X
	STB	UNIT_TILE,X
	LDD	MAP_X			Get X,Y coord that player selected to drop magnet on
	STA	UNIT_LOC_X,X		Save as magnets X,Y coords
	STB	UNIT_LOC_Y,X
	LDD	#1*256+255		A=How long until activated, B=MSB of how long does magnet last
	STA	UNIT_TIMER_A,X
	STB	UNIT_TIMER_B,X
	LDD	#3*256+1		A=LSB of how long does magnet last, B=flag that magnet is active
	STA	UNIT_A,X
	STB	MAGNET_ACT		only one magnet allowed at a time.
	DEC	INV_MAGNET		Dec # of magnets player has in inventory
	JSR	DISPLAY_ITEM		Update # magnets on display
	LDA	#01			Flag to redraw window
	STA	REDRAW_WINDOW
;LDA	#06		;move sound
;JSR	PLAY_SOUND	;SOUND PLAY
	RTS

BOMB_MAGNET_COMMON1:
	CLRA				Flag cursor off
	STA	CURSOR_ON
	JSR	DRAW_MAP_WINDOW		ERASE THE CURSOR (by redrawing whole window!)
	LDD	CURSOR_X		Get cursor X,Y start
	ADDD	MAP_WINDOW_X		Add to window X,Y start
	STD	MAP_X			Save in MAP_X,MAP_Y for sub
	STD	MOVTEMP_UX		And in MOVEMTP X,Y
	JSR	GET_TILE_FROM_MAP	Get tile from MAP_X,MAP_Y location
	LDY	TILEPRE			Get that tile # into Y
	LDA	TILE_ATTRIB,Y		Get attributes for the tile
	ANDA	#%00000001		Can it be walked on?
	RTS				Exit with flags set based on that

BOMB_MAGNET_COMMON2:
	LDY	#MSG_BLOCKED		Print "Blocked!" in text window & return
	JSR	PRINT_INFO
;LDA	#11		;ERROR SOUND
;JSR	PLAY_SOUND	;SOUND PLAY
	RTS	


USE_MEDKIT:
	LDA	UNIT_HEALTH		Get players health
	CMPA	#12			Already maxed out at 12?
	BNE	UMK1			No, go top the player up
	RTS				Yes, do nothing & return

;Now figure out how many HP we need to be healthy.
UMK1:
	LDB	#12			Max health is 12
	SUBB	UNIT_HEALTH		Subtract amount player actually has
	STB	TEMP_A			Save maximum we could heal
	LDA	INV_MEDKIT		Get how much health can we heal
	SUBA	TEMP_A			Subtract amount we need for full healing
	BLO	UMK2			Wrapped negative, only heal as much as we have in medkit
;we had more than we need, so go to full health.
	LDA	#12			Set player health to maximum
	STA	UNIT_HEALTH
	LDA	INV_MEDKIT		Get amount of health in medkit
	SUBA	TEMP_A			Subtract the amount we needed to top player up
	STA	INV_MEDKIT		Save that as the amount of health left in medkit
	BRA	UMK3			Go update player health on screen & return from there

;We had less than we needed, so we'll use what is available.
UMK2:
	LDA	INV_MEDKIT		Get amount of health left in medkit
	ADDA	UNIT_HEALTH		Add to player's current health
	STA	UNIT_HEALTH		Save new player's health
	CLR	INV_MEDKIT		Zero out medkit health remaining
UMK3:	
	JSR	DISPLAY_PLAYER_HEALTH	Update player's health on screen
	JSR	DISPLAY_ITEM		Update MedKit on screen (or switch to another item if medkit empty)
;LDA	#2		;MEDKIT SOUND
;JSR	PLAY_SOUND	;SOUND PLAY
	LDY	#MSG_MUCHBET		Print "ahhh, much better!" in text window & return from there
	JMP	PRINT_INFO
	
;FIRE_* routines
;For shots in progress:
;UNIT_TYPE = which gun AI routine (12=up, 13=down, 14=left, 15=right) (bullet path direction)
;UNIT_TILE = graphic for bullet (244=vertical bullet, 240=vertical plasma, 245=horizontal bullet, 241=horizontal plasma)
;UNIT_A = travel distance
;UNIT_B = weapon type (0=pistol, 1=plasma)
;  (note that plasma also sets the PLASMA_ACT (plasma active) flag in direct page)
; NOTE: FU02, FUP2, ETC. have bits of common code. May be able to merge a little of it
; to shrink further. Also, the "scan through active bullets" routines are identical except where it goes
; to when it finds an empty slot. So that can become a BSR (lose some speed, but save room - I already
; sped it up a bit, so it shouldn't be a hit on performance)
;========================================================
FIRE_UP:
	LDA	SELECTED_WEAPON		Does player have weapon selected?
	BEQ	FIREUP_EXIT		No, return
	DECA
	BNE	FIRE_UP_PLASMA		Type 2 is Plasma, go handle
	LDA	AMMO_PISTOL		Type 1 (Pistol), any bullets left?
	BNE	FU00			Yes, continue
FIREUP_EXIT:				;No, return
	RTS

FU00:
	JSR	FIND_EMPTY_BULLET_SLOT	Find empty bullet slot (max 4 active at once)
	TSTA				Did we find one?
	BNE	FIREUP_EXIT		No, all full so return
	LDD	#12*256+244		12=Fire pistol up AI routine, 244=tile # for vertical weapons fire
	STA	UNIT_TYPE,X
	STB	UNIT_TILE,X
	LDD	#3*256+0		travel distance=3, 0 weapon type=pistol
	STA	UNIT_A,X
	STB	UNIT_B,X
	JMP	AFTER_FIRE	
   ;----
FIRE_UP_PLASMA:
	LDA	BIG_EXP_ACT		Big explosion active?
	BNE	FIREUP_EXIT		Yes, return
	LDA	PLASMA_ACT		Plasma fire active?
	BNE	FIREUP_EXIT		Yes, return
	LDA	AMMO_PLASMA		Get # of shots in plasma gun
	BEQ	FIREUP_EXIT		None, return
	BSR	FIND_EMPTY_BULLET_SLOT	Find empty bullet slot (max 4 active at once)
	TSTA				Did we find one?
	BNE	FIREUP_EXIT		No, all full so return		
	LDD	#12*256+240		A=Fire pistol up AI routine, 240=tile # for vertical plasma fire
	STA	UNIT_TYPE,X
	STB	UNIT_TILE,X
	LDD	#3*256+1		Travel distance=3, 1 weapon type=plasma
	STA	UNIT_A,X
	STB	UNIT_B,X
	STB	PLASMA_ACT		Flag that plasma fire is active
	BRA	AFTER_FIRE
  ;-----
FIRE_DOWN:
	LDA	SELECTED_WEAPON		Does player have weapon selected?
	BEQ	FIRE_DOWN_EXIT		No, return
	DECA
	BNE	FIRE_DOWN_PLASMA	Type 2 is Plasma, go handle
	LDA	AMMO_PISTOL		Type 1 (Pistol), and bullets left?
	BNE	FD00			Yes, continue
FIRE_DOWN_EXIT:
	RTS				No, return

FD00:	
	BSR	FIND_EMPTY_BULLET_SLOT	Find empty bullet slot (max 4 active at once)
	TSTA				Did we find one?
	BNE	FIRE_DOWN_EXIT		No, all full so return
	LDD	#13*256+244		13=Fire pistol down AI routine, 244=tile # for vertical weapons fire
	STA	UNIT_TYPE,X
	STB	UNIT_TILE,X
	LDD	#3*256+0		travel distance=3, 0 weapon type=pistol
	STA	UNIT_A,X
	STB	UNIT_B,X
	BRA	AFTER_FIRE

FIRE_DOWN_PLASMA:
	LDA	BIG_EXP_ACT		Big explosion active?
	BNE	FIRE_DOWN_EXIT		Yes, return
	LDA	PLASMA_ACT		Plasma fire active?
	BNE	FIRE_DOWN_EXIT		Yes, return
	LDA	AMMO_PLASMA		Get # of shots in plasma gun
	BEQ	FIRE_DOWN_EXIT		None, return
	BSR	FIND_EMPTY_BULLET_SLOT	Find empty bullet slot (max 4 active at once)
	TSTA				Did we find one?
	BNE	FIRE_DOWN_EXIT		No, all full so return
	LDD	#13*256+240		13=Fire pistol down AI routine, 240=tile # for vertical plasma fire
	STA	UNIT_TYPE,X
	STB	UNIT_TILE,X
	LDD	#3*256+1		travel distance=3, 1 weapon type=plasma
	STA	UNIT_A,X
	STB	UNIT_B,X
	STB	PLASMA_ACT		Flag that plasma fire is active
	BRA	AFTER_FIRE

;=====================
; Next 2 routines inserted in the middle in the vainglorious hope that we can use BSR in instead of JSR. If not,
; just replace that few that don't with a JSR or JMP as appropriate.
; Entry: none
; Exit: A=0 means we found empty slot at X
;       A<>0 means all 4 slots full
; Modifies: A,B,X
FIND_EMPTY_BULLET_SLOT:
	LDX	#28			Start of weapons fire units (unit 28)
	LDB	#1			1 byte per entry
FIND_BULLET_LOOP:	
	LDA	UNIT_TYPE,X		Get unit type
	BEQ	FIND_BULLET_EXIT	If 0, return with A=0 and init bullet
	ABX				If not, go onto next weapons fire object
	CMPX	#32			weapons fire are units 28-31 only
	BNE	FIND_BULLET_LOOP	Still more left, keep going
FIND_BULLET_EXIT:
	RTS				Done, return

AFTER_FIRE:
	CLR	UNIT_TIMER_A,X		0 time delay on bullets
	LDA	UNIT_LOC_X		Copy player X,Y to bullet X,Y
	STA	UNIT_LOC_X,X
	LDA	UNIT_LOC_Y
	STA	UNIT_LOC_Y,X
	STX 	UNITPRE
	LDA	SELECTED_WEAPON		Get weapon type
	DECA
	BNE	AF01			Plasma, skip ahead
;LDA	#09		;PISTOL-SOUND
;JSR	PLAY_SOUND	;SOUND PLAY
	DEC	AMMO_PISTOL		Dec # of bullets left (Pistol)
	JMP	DISPLAY_WEAPON		Update weapon display

AF01:	
	;LDA	#08		;PLASMA-GUN-SOUND
	;JSR	PLAY_SOUND	;SOUND PLAY
	DEC	AMMO_PLASMA		Dec # of bullets left (Plasma)
	JMP	DISPLAY_WEAPON		Update weapon display & return from there

;------
FIRE_LEFT:
	LDA	SELECTED_WEAPON		Does player have weapon selected?
	BEQ	FIRELEFT_EXIT		No, return
	DECA
	BNE	FIRE_LEFT_PLASMA	Type 2 is Plasma, go handle
	LDA	AMMO_PISTOL		Type 1 (Pistol), any bullets left?
	BNE	FRL0			Yes, continue
FIRELEFT_EXIT:
	RTS				No, return

FRL0:
	BSR	FIND_EMPTY_BULLET_SLOT	Find empty bullet slot (max 4 active at once)
	TSTA				Did we find one?
	BNE	FIRELEFT_EXIT		No, all full so return
	LDD	#14*256+245		14=Fire pistol left AI routine, 245=tile # for horizontal weapons fire
	STA	UNIT_TYPE,X
	STB	UNIT_TILE,X
	LDD	#5*256+0		travel distance=5, 0 weapon type=pistol
	STA	UNIT_A,X
	STB	UNIT_B,X
	BRA	AFTER_FIRE	

FIRE_LEFT_PLASMA:
	LDA	BIG_EXP_ACT		Big explosion active?
	BNE	FIRELEFT_EXIT		Yes, return
	LDA	PLASMA_ACT		Plasma fire active?
	BNE	FIRELEFT_EXIT		Yes, return
	LDA	AMMO_PLASMA		Get # of shots in plasma gun
	BEQ	FIRELEFT_EXIT		None, return
	BSR	FIND_EMPTY_BULLET_SLOT	Find empty bullet slot (max 4 active at once)
	TSTA				Did we find one?
	LBNE	FIRE_DOWN_EXIT		No, all full so return
	LDD	#14*256+241		A=fire pistol left AI routine, 241=tile # for horizontal plasma fire
	STA	UNIT_TYPE,X
	STB	UNIT_TILE,X
	LDD	#5*256+1		Travel distance=5, 1 weapon type=plasma
	STA	UNIT_A,X
	STB	UNIT_B,X
	STB	PLASMA_ACT		Flag that plasma fire is active
	BRA	AFTER_FIRE

  ;------
FIRE_RIGHT:
	LDA	SELECTED_WEAPON		Does player have weapon selected?
	BEQ	FIRERIGHT_EXIT		No, return
	DECA
	BNE	FIRE_RIGHT_PLASMA	Type 2 is plasma, go handle
	LDA	AMMO_PISTOL		Type 1 (pistol), any bullets left?
	BNE	FR00			Yes, continue
FIRERIGHT_EXIT:
	RTS				No, return

FR00:	
	JSR	FIND_EMPTY_BULLET_SLOT	Find empty bullet slot (max 4 active at once)
	TSTA				Did we find one?
	BNE	FIRERIGHT_EXIT		No, all full so return
	LDD	#15*256+245		15=fire pistol right AI routine, 245=tile # for horizontal weapons fire
	STA	UNIT_TYPE,X
	STB	UNIT_TILE,X
	LDD	#5*256+0		travel distance=5, 0 weapon type=pistol
	STA	UNIT_A,X
	STB	UNIT_B,X
	JMP	AFTER_FIRE

FIRE_RIGHT_PLASMA:
	LDA	BIG_EXP_ACT		Big explosion active?
	BNE	FIRERIGHT_EXIT		Yes, return
	LDA	PLASMA_ACT		Plasma fire active?
	BNE	FIRERIGHT_EXIT		yes, return
	LDA	AMMO_PLASMA		Get # of shots in plasma gun
	BEQ	FIRERIGHT_EXIT		None, return
	JSR	FIND_EMPTY_BULLET_SLOT	Find empty bullet slot (max 4 active at once)
	TSTA				Did we find one?
	BNE	FIRERIGHT_EXIT
	LDD	#15*256+241		15=fire pistol right AI routine, 241=tile # for horizontal plasma fire
	STA	UNIT_TYPE,X
	STB	UNIT_TILE,X
	LDD	#5*256+1		Travel distance=5, 1 weapon type=plasma
	STA	UNIT_A,X
	STB	UNIT_B,X
	STB	PLASMA_ACT		Flag that plasma fire is active
	JMP	AFTER_FIRE

;This routine checks KEYTIMER to see if it has
;reached zero yet.  If so, it clears the LSTX
;variable used by the kernal, so that it will
;register a new keypress.

;KEY_REPEAT:
;	LDA	KEYTIMER		Get keyboard repeat tick timer
;	BNE	KEYR2			Still counting down, so just return without doing anything
;	LDA	$97			;no key pressed
;	BEQ	KEYR1
;	CLRA	;clear LSTX register
;	STA	$97	;clear LSTX register
;	LDA	#6			Reset keytimer 6 (1/10th of a second) before key repeat
;	STA	KEYTIMER
;	RTS
;
;KEYR1:	;No key pressed, reset all to defaults
;	CLRA	
;	STA	KEY_FAST
;	LDA	#6
;	STA	KEYTIMER
;KEYR2:	
;	RTS

;This routine handles things that are in common to
;all 4 directions of movement.
AFTER_MOVE:
	LDA	MOVE_RESULT		Get successful move flag (0=unsuccessful)
	BEQ	AM01			Move unsuccessful, skip doing anything on screen
	JSR	ANIMATE_PLAYER		Move successful; switch player tile between 97 and 98 for animation
	JSR	CALCULATE_AND_REDRAW	Update viewable window start, flag for redraw

;now reset key-repeat rate
AM01:	LDD	#13*256+6		Movement keys have different key repeat delays than other commands
	STD	KEYTIMER_STARTDELAY
	STA	KEYTIMER		Default to non repeating delay
	LDA	PREV_KEY		Already key repeating?
	CMPA	CURRENT_KEY
	BNE	AM02			No, leave keytimer at 13
	STB	KEYTIMER		Yes, set to 6
AM02:	
	CLR	CURRENT_KEY		Erase current keypress
	JMP	MAIN_GAME_LOOP		Back to main game loop

;	LDA	KEY_FAST		Are we already key repeating?
;	BNE	KEYR3			Yes, reset next key timer to 6 ticks & back to main game loop
;FIRST REPEAT
;	LDA	#13			Set initial delay before key repeat kicks in to 13 ticks
;	STA	KEYTIMER
;	INC	KEY_FAST		Flag that we are key repeating
;	JMP	MAIN_GAME_LOOP		Back to main game loop

;SUBSEQUENT REPEATS
;KEYR3:	
;	LDA	#6			already have been repeating, set smaller delay until next key & back to main game loop
;	STA	KEYTIMER
;	JMP	MAIN_GAME_LOOP

;This routine is invoked when the user presses S to search
;an object such as a crate, chair, or plant.
SEARCH_OBJECT:
	JSR	USER_SELECT_OBJECT	Have user select what direction to search in
	LDA	#1
	STA	REDRAW_WINDOW		Flag window update
CHS1:
;first check of object is searchable
	JSR	CALC_COORDINATES	Calculate X,Y coordinates within map into MAP_X,MAP_Y
	JSR	GET_TILE_FROM_MAP	Get the tile from the map
	LDX	TILEPRE			X=tile #
	LDA	TILE_ATTRIB,X		Get tile attributes
	ANDA	#%01000000		Is tile searchable?  
	BNE	CHS2			Yes, go search
	CLR	CURSOR_ON		No, flag cursor off
	BRA	CHS3			Print "Nothing found here" & return from there

; Searchable object
CHS2:
	LDB	TILE			Get tile #
	CMPB	#41			Is it a BIG CRATE?
	BEQ	CHS2B			Yes, go handle
	CMPB	#45			Is it a SMALL CRATE?
	BEQ	CHS2B			Yes, go handle
	CMPB	#199			Is it a "PI" CRATE?
	BNE	CHS2C			None of the crates, skip ahead
; One of 3 searchable crate types
CHS2B:	
	LDA	DESTRUCT_PATH,X		Get ??? (from tileset)
	STA	TILE			Save tile #
	JSR	PLOT_TILE_TO_MAP	Add that tile to the map in current position
CHS2C:	;Now check if there is an object there.
	CLR	SEARCHBAR		Init searchbar position to 0 (for '.' when searching)
	LDY	#MSG_SEARCHING		Print "searching" in text window
	JSR	PRINT_INFO
SOBJ1:	
	LDA	#18			18 tick delay time between search periods
	STA	BGTIMER2		Save for IRQ routine
SOBJ2:	
	JSR	COCO_SCREEN_SHAKE	Screen shake (not implemented yet)
	JSR	BACKGROUND_TASKS	Process background tasks (AI, etc.)
	LDA	BGTIMER2		Get search delay tick counter (# ticks between periods)
	BNE	SOBJ2			Not done all 18 yet, keep going until IRQ routine drops BGTIMER2 down to 0
	LDB	SEARCHBAR		Get current period count
	LSLB				* 4 bytes/character on screen
	LSLB	
	LDA	#46			PERIOD character
	LDU	#SCREEN+(CHAR_ROWSIZE*24)+(CHAR_WIDTH*9)	Point to 9,24 on screen (in text window) $F824
	LEAU	B,U			Add horizontal offset
	STU	<$FD			Save address to print character at
	JSR	BITMAP_PLOTTER		Print the period on screen
	INC	SEARCHBAR		Inc searchbar position
	LDA	SEARCHBAR		Get new searchbar position
	CMPA	#8			Done all 8 periods?
	BNE	SOBJ1			No, go finish the rest
	CLR	CURSOR_ON		Flag cursor off
	JSR	DRAW_MAP_WINDOW		Redraw whole map with cursor off
	JSR	CALC_COORDINATES
	JSR	CHECK_FOR_HIDDEN_UNIT	Is there a hidden unit (sets negative flag if object not found, object unit # in B)?
	BPL	SOBJ5			Yes, go handle
CHS3:	
	LDY	#MSG_NOTFOUND		No, print "nothing found here."
	JMP	PRINT_INFO

; Hidden object found (unit # in B)
SOBJ5:    
	LDX	UNIT_FINDPRE		X=hidden object number (48-63)
	LDA	UNIT_TYPE,X		Get hidden object's type
	LDB	UNIT_A,X		Get hidden object's UNIT_A (quantity if appropriate)
	STD	TEMP_A        		store object type & object secondary info into TEMP_A/TEMP_B
	CLR	UNIT_TYPE,X		DELETE ITEM ONCE FOUND
;***NOW PROCESS THE ITEM FOUND***
;LDA    #10        ;ITEM-FOUND-SOUND
;JSR    PLAY_SOUND    ;SOUND PLAY
;	LDA	TEMP_A			Get hidden objects type
	CMPA    #128			Is it a key?
; change so can fall through if equal, saving 2 bytes
	BNE	SOBJ15			No, check next
SOBJ10:    
	LDB	KEYS			Get players KEY flags
	LDA	TEMP_B			Yes, get key type (lowest 3 bits)
	BNE	SOBJK1			Not SPADE key (TEMP_B=0), try next
	ORB	#%00000001		Add spade key
	BRA	SOBJ11			Save updated keys

SOBJK1:    
	DECA				Heart key? (TEMP_B=1)
	BNE	SOBJK2			No, try star key
	ORB	#%00000010		Add heart key
	BRA	SOBJ11

SOBJK2:    
	ORB	#%00000100		Add star key (TEMP_B was 2 or up)
SOBJ11:
	STB	KEYS			Save updated key flags
SOBJ12:    
	LDY	#MSG_FOUNDKEY		Print 'You found a key card!'
	JSR	PRINT_INFO
	JMP	DISPLAY_KEYS    	Update key display on screen & return from there

SOBJ15:    
	CMPA	#129			Is hidden object a TIME BOMB?
	BNE	SOBJ17			No, check next
	LDB	TEMP_B			Get # of bombs from secondary info
; LCB NOTE: Doesn't this mean that bombs will wrap to 0 after passing 255? (for all count items other than pistol)
	ADDB	INV_BOMBS		Add to how many bombs player has
	STB	INV_BOMBS		Save updated total
	LDY	#MSG_FOUNDBOMB		Print "You found a timebomb!" on text window
SOBJ16:
	JSR	PRINT_INFO
	JMP	DISPLAY_ITEM		Update # of bombs on screen (if time bomb is active selection) & return from there

SOBJ17:    
	CMPA	#130			Is hidden object an EMP?
	BNE	SOBJ20			No, check next
	LDB	TEMP_B			Yes, Get # of EMP charges
	ADDB	INV_EMP			Add to # of EMP charges player has
	STB	INV_EMP			Save updated total
	LDY	#MSG_FOUNDEMP		Print "You found an EMP Device!" to text window & return from there
	BRA	SOBJ16	

SOBJ20:	
	CMPA	#131			Is hidden object a PISTOL?
	BNE	SOBJ21			No, check next
	LDB	TEMP_B			Yes, get # of shots in hidden pistol
	ADDB	AMMO_PISTOL		Add to players # of pistol shots
	BCC	SOBJ2A			<=255, update total & screen
	LDB	#255			Would overflow, force to 255.
SOBJ2A:	
	STB	AMMO_PISTOL		Save updated total
	LDY	#MSG_FOUNDGUN		Print "You found a pistol!" to text window
	JSR	PRINT_INFO
	JMP	DISPLAY_WEAPON		Update displayed weapon count (if pistol was selected)

SOBJ21:	
	CMPA	#132			Is hidden object a PLASMA GUN?
	BNE	SOBJ22			No, check next
	LDB	TEMP_B			Get # of bullets in hidden plasma gun
	ADDB	AMMO_PLASMA		Add to player's # of plasma shots
	STB	AMMO_PLASMA		Save updated # of shots
	LDY	#MSG_FOUNDPLAS		Print "You found a plasma gun!"
	JSR	PRINT_INFO
	JMP	DISPLAY_WEAPON		Update display weapon count (if plasma gun was selected)

SOBJ22:	
	CMPA	#133			Is hidden object a MEDKIT?
	BNE	SOBJ23			No, check next
	LDB	TEMP_B			Get # health points in hidden medkit
	ADDB	INV_MEDKIT		Add to players medkit points
	STB	INV_MEDKIT		Save updated medkit points
	LDY	#MSG_FOUNDMED		Print "You found a medkit!"
	JSR	PRINT_INFO
	JMP	DISPLAY_ITEM		Update displayed medkit count on screen (if medkit was selected)

SOBJ23:	
	CMPA	#134			Is hidden object a MAGNET?
	BNE	SOBJ99			No, anything else is illegal so just return
	LDB	TEMP_B			Get # magnet charges in hidden Magnet 
	ADDB	INV_MAGNET		Add to players magnet charges
	STB	INV_MAGNET		Save updated magnet charges
	LDY	#MSG_FOUNDMAG		Print "You found a magnet!"
	JSR	PRINT_INFO
	JMP	DISPLAY_ITEM		Update displayed magnet count on screen (if magnet was selected)

SOBJ99:	;ADD CODE HERE FOR OTHER OBJECT TYPES
	RTS

SEARCHBAR	.BYTE 00		to count how many periods to display.

;combines cursor location with window location
;to determine coordinates for MAP_X and MAP_Y
CALC_COORDINATES:
	LDD	CURSOR_X		Get cursor X/Y coords
	ADDD	MAP_WINDOW_X		Add to upper left window start coords
	STD	MAP_X			Save coords for subroutines
	RTS

;This routine is called by routines such as the move, search,
;or use commands.  It displays a cursor and allows the user
;to pick a direction of an object.
USER_SELECT_OBJECT:
;LDA	#16		;beep sound
;JSR	PLAY_SOUND	;SOUND PLAY
	LDD	#5*256+3		Set cursor to center of viewable window (5,3)
	STD	CURSOR_X
	LDA	#1			Flag that inverted tile cursor should be ON
	STA	CURSOR_ON
	JSR	REVERSE_TILE		Invert the 24x24 tile directly
;First ask user which object to move
MV01:	
	JSR	COCO_SCREEN_SHAKE	Screen shake to start search (not enabled yet)
	JSR	BACKGROUND_TASKS	Update all background task stuff (including AI for units)
	LDA	UNIT_TYPE		Get player live/dead status
;Did player die wile moving something?
	BNE	MVCONT			Still alive, continue move routine
	CLR	CURSOR_ON		Dead, flag cursor off & return
	RTS

MVCONT:	
	LDA	CURRENT_KEY		Get current keypress
MV06:	
	CMPA	KEY_MOVE_LEFT		Left? (default='A')
	BNE	MV07			No, check next
	DEC	CURSOR_X		Yes, move cursor left 1 & return
	RTS	
MV07:	
	CMPA	KEY_MOVE_DOWN		Down? (default='S')
	BNE	MV08			No, check next
	INC	CURSOR_Y		Yes, move cursor down 1 & return
	RTS
MV08:	
	CMPA	KEY_MOVE_RIGHT		Right? (default='D')
	BNE	MV09			No, check next
	INC	CURSOR_X		Yes, move cursor right & return
	RTS
MV09:	
	CMPA	KEY_MOVE_UP		Up? (default='W')
	BNE	MV01			No, update AI's and try for key again
	DEC	CURSOR_Y		Yes, move cursor up & return
	RTS

MOVE_OBJECT:
	BSR	USER_SELECT_OBJECT	Get which tile user is moving CURSOR_X,CURSOR_Y
;now test that object to see if it is allowed to be moved.
MV10:	
	CLR	CURSOR_ON		Flag tile cursor OFF
	JSR	DRAW_MAP_WINDOW		;ERASE THE CURSOR (could we REVERSE_TILE instead here, I wonder?)
	BSR	CALC_COORDINATES	Calculate MAP_X,MAP_Y based on cursor & current viewable window position
	JSR	CHECK_FOR_HIDDEN_UNIT	See if hidden unit on that tile (returns it in B)
	STB	MOVTEMP_U		Save copy of hidden unit # (or 255 if none) to temp
	JSR	GET_TILE_FROM_MAP	Get "normal" tile # for this spot
; LCB NOTE: Change GET_TILE_FROM_MAP to return in B instead of A later
	LDB	TILE			Get tile # into B
	LDY	TILEPRE			and 16 bit version into Y
	LDA	TILE_ATTRIB,Y		Get attributes for that tile type
	ANDA	#%00000100		can it be moved?
	BNE	MV11			Yes, go move
	LDY	#MSG_CANTMOVE		No, print "can't move that!" & return (after sound enabled, final JSR can change to JMP)
	JSR	PRINT_INFO
;LDA	#11		;ERROR SOUND
;JSR	PLAY_SOUND	;SOUND PLAY
	RTS

MV11:	
	STB	MOVTEMP_O		Store which tile it is we are moving (still in B from above)
	LDD	MAP_X			Get X,Y coords
	STD	MOVTEMP_X		Store original location of object
	LDA	#1			Flag tile cursor ON
	STA	CURSOR_ON
	JSR	REVERSE_TILE		Invert the tile
;NOW ASK THE USER WHICH DIRECTION TO MOVE IT TO
MV15:	
	JSR	COCO_SCREEN_SHAKE	Shakes screen (not implemented yet)
	JSR	BACKGROUND_TASKS	Go update AI tasks, etc.
	LDA	UNIT_TYPE		Player still alive?
;Did player die wile moving something?
	BNE	MVCONT2			Yes, continue
	CLR	CURSOR_ON		No, flag cursor off & return
	RTS	

MVCONT2:	;which controller are we using?
;keyboard control
MV15B:
	LDA	CURRENT_KEY		Get current keypress
	BEQ	MV15			None, update AI/clock stuff and try again
MV20:	
	CMPA	KEY_MOVE_LEFT		Left? (default='A')
	BNE	MV2A			No, try next
	DEC	CURSOR_X		Yes, move cursor left
	BRA	MV25			and continue
MV2A:	
	CMPA	KEY_MOVE_DOWN		Down? (default='S')
	BNE	MV2B			No, try next
	INC	CURSOR_Y		Yes, move cursor up
	BRA	MV25			and continue
MV2B:	
	CMPA	KEY_MOVE_RIGHT		right? (default='D')
	BNE	MV2C			No, try next
	INC	CURSOR_X		Yes, move cursor right
	BRA	MV25			and continue
MV2C:	
	CMPA	KEY_MOVE_UP		Up? (default='W')
	BNE	MV15			No, do background tasks & try again
	DEC	CURSOR_Y		Yes, move cursor up
;NOW TEST TO SEE IF THAT SPOT IS OPEN
MV25:	
	CLR	CURSOR_ON		Flag cursor off
	JSR	DRAW_MAP_WINDOW		;ERASE THE CURSOR
	LDD	CURSOR_X		Get X,Y to move to, adding in current viewable window offsets
	ADDD	MAP_WINDOW_X
	STD	MAP_X			Save as MAP_X,MAP_Y coords for subroutines
	STD	MOVTEMP_UX		And to temp X,Y as well
	JSR	GET_TILE_FROM_MAP	Get tile from destination coord
	LDY	TILEPRE			Y=tile #
	LDA	TILE_ATTRIB,Y		Get attributes for that tile type
	ANDA	#%00100000		is that spot available for something to move onto it?
	BEQ	MV3A			If not, notify user & exit routine.
MV30:
	JSR	CHECK_FOR_UNIT		Yes, see if player or robot on that tile at MAP_X,MAP_Y into B & UNIT_FIND
	BMI	MV31			No, go move object
MV3A:
	LDY	#MSG_BLOCKED		Yes, print 'blocked!'
; LCB NOTE: once sound added, JMP PLAY_SOUND and remove RTS
	JSR	PRINT_INFO
;LDA	#11		;ERROR SOUND
;JSR	PLAY_SOUND	;SOUND PLAY
	RTS

MV31:	
;LDA	#06		;move sound
;JSR	PLAY_SOUND	;SOUND PLAY
	LDA	TILE			Get tile # (seeing if this works rather than reloading it)
	STA	MOVTEMP_D		Save as temp destination tile
	LDA	MOVTEMP_O		Get temp original tile
	STA	TILE			Save as 'current' tile
	JSR	PLOT_TILE_TO_MAP	replace with object we are moving in map
;RETRIEVE original location of object
	LDD	MOVTEMP_X      		Get coords of original tile moved from
	STD	MAP_X			Save for subroutine
	JSR	GET_TILE_FROM_MAP	Get tile from map
	LDA	MOVTEMP_D		Get our saved destination tile
	CMPA	#148			trash compactor tile?
	BNE	MV31A			No, save it back to the map
	LDA	#09			Yes, replace as Floor tile
MV31A:
	STA	TILE			Save tile for subroutine
	JSR	PLOT_TILE_TO_MAP	;Replace former location
	LDA	#1
	STA	REDRAW_WINDOW		;See the result by flagging we need a window redraw
	LDB	MOVTEMP_U		Get temp: hidden unit #
	CMPB	#255			None?
	BNE	MV32			there is a hidden unit inside, go handle
	RTS				No hidden unit in moved object, we are done

; Hidden unit in moved object - so move it too
MV32:	
	CLRA				Move hidden unit # to X
	TFR	D,X
	LDD	MOVTEMP_UX		Get hidden unit X,Y coords, and copy to unit's X,Y
	STA	UNIT_LOC_X,X
	STB	UNIT_LOC_Y,X
	RTS

DISPLAY_ENDGAME_SCREEN:
	LDY	#SCR_ENDGAME		Point to RLE end game screen (prints border and static text)
	JSR	DECOMPRESS_SCREEN	Display it
;display map name
	LDY	#SCREEN+(CHAR_ROWSIZE*7)+(CHAR_WIDTH*22)	$A358
 	JSR	PRINT_MAP_NAME		Print current map name
;display elapsed time
	LDA	HOURS			Print hours as leading zero 3 digit number
	STA	DECNUM
	LDX	#SCREEN+(CHAR_ROWSIZE*9)+(CHAR_WIDTH*21)	$AD54
	STX 	$FD
	JSR	DECWRITE
	LDA	MINUTES			Print minutes as leading zero 3 digit number
	STA	DECNUM
	JSR	DECWRITE
	LDA	SECONDS			Print seconds as leading zero 3 digit number
	STA	DECNUM
	JSR	DECWRITE
	LDA	#32			Write SPACE char over 1st zero of hours
	LDX	#SCREEN+(CHAR_ROWSIZE*9)+(CHAR_WIDTH*21)	$AD54
	STX	$FD
	JSR	BITMAP_PLOTTER
	LDA	#58			Write COLON char over 1st zero of minutes
	LDX	#SCREEN+(CHAR_ROWSIZE*9)+(CHAR_WIDTH*24)	$AD60
	STX	$FD
	JSR	BITMAP_PLOTTER
	LDA	#58			Write COLON char over 1st zero of seconds
	LDX	#SCREEN+(CHAR_ROWSIZE*9)+(CHAR_WIDTH*27)	$AD6C
	STX	$FD
	JSR	BITMAP_PLOTTER
;count robots remaining
	CLRA				Init robot count to 0
	LDX	#UNIT_TYPE		Point to table of unit types (0=dead)
	LDB	#28			Start on last possible robot unit (27)
DEG7:	DECB				Go to previous robot
	BEQ	DEG8			done all of them, report #
	TST	B,X			Active robot?
	BEQ	DEG7			No, onto next one
	INCA				Yes, bump up active count
	BRA	DEG7			And onto next one

DEG8	STA	DECNUM			Save # of active robots
	LDX	#SCREEN+(CHAR_ROWSIZE*11)+(CHAR_WIDTH*22)	$B758
	STX	$FD
	JSR	DECWRITE		Print # robots remaining

;Count secrets remaining
	CLRA				Init secrets remaining count to 0
	LDX	#UNIT_TYPE		Point to table of unit types
	LDB	#64			Start on last possible hidden object (63)
DEG9:	DECB				Go to previous hidden object
	CMPB	#48			Done all from 48-63?
	BLO	DEG10			done all of them, report #
	TST	B,X			Hidden object present?
	BEQ	DEG9			No, onto next one
	INCA				Yes, bump up active count
	BRA	DEG9			And onto next one

DEG10:	STA	DECNUM			Save # of secrets remaining
	LDX	#SCREEN+(CHAR_ROWSIZE*13)+(CHAR_WIDTH*22)	$C158
	STX	$FD
	JSR	DECWRITE		Print # secrets (hidden objects) remaining
;display difficulty level - changing to stop printing on NUL
	LDX	#SCREEN+(CHAR_ROWSIZE*15)+(CHAR_WIDTH*22)	$CB58
	STX	$FD			Save where to print on screen
	LDX	#DIFF_LEVEL_LEN		Point to difficulty level text offset table
	LDB	DIFF_LEVEL		Get players difficulty level
DEG11:	LDB	B,X			Get offset to difficulty text 
	LDX	#DIFF_LEVEL_WORDS	Point to difficulty level text table
	ABX				Point to level text that player as playing at
	JMP	DMN3			Print difficulty name to screen & return from there	
	
DIFF_LEVEL_LEN:
	.BYTE	0,5,12			Offset to each difficulty name (including NUL)

DIFF_LEVEL_WORDS:
	.STR	"easy"
	.BYTE	0
	.STR	"normal"
	.BYTE	0
	.STR	"hard"
	.BYTE	0

; This prints text characters to the screen (for title screen, for example) using an RLE
; encoding method to compress it. Basically, any character other than CHR$(96) (apostrophe - $60)
; print as is. If the char is a $60, then the 3 byte sequence (including the $60) is:
; $60 (RLE block start marker), xx (character to repeat), yy (# of times to repeat-add 1 to this
;   value for actual count)
;called from:
;  DISPLAY_INTRO_SCREEN 
;  DISPLAY_ENDGAME_SCREEN 
;  DISPLAY_GAME_SCREEN
; New Entry/Exit/user parameters
; Entry: Y=ptr to RLE encoded text to fill screen with
; Exit: Entire screen always filled
; Modifies: BYTECOUNT (# chars left on current line whilst RLE decoding)
;	    TEMP_A / TEMP_B (to preserve RLE char / # of repeats)
;	    CURRENTSCREEN (actually ptr to start of current line on screen)
;	    $FD (current char ptr)
DECOMPRESS_SCREEN:
	LDD	#$8000			Point to start of graphics screen
	STB	INVERSE			Inverse OFF
NEXTLINE:
	STD	CURRENTSCREEN		Save start of current line on screen
	STD	$FD			And save as current position on screen to draw text character for subroutine
	LDB	#40			Init chars left in line counter
DGS1:	
	LDA	,Y+			Get next text char
	CMPA 	#$60			Is it the special RLE style REPEAT FLAG? (an apostrophe)
	BEQ	DGS10			Yes, go handle compressed source data
; No, regular one char at a time routine
DGS2:
	PSHS    B,Y			Save horizontal char # & source ptr
	BSR	BITMAP_PLOTTER		Print char in A to screen @ [$FD] (UPDATES $FD TO NEXT CHAR OVER)
	PULS	B,Y			Get horizontal char # & source ptr back
	DECB				Drop # of chars left on current line
	BNE	DGS1			Still more chars on current line
	LDD	CURRENTSCREEN		Get current line screen address
DGS4:
	CMPA	#$F8			Did we just finish last line (25th) on the screen?
	BHS	DECOMPSCR_DONE		Yes, we are done
	ADDA	#5			No, down one line (this adds the high byte of (160*8). Each line always starts on even 256 byte boundary)
	BRA	NEXTLINE		And continue from there

DECOMPSCR_DONE:
	RTS				Yes, we are done

; start of RLE decode related routines
; RLE decompression routine entry point
DGS10:
	STB	BYTECOUNT		Save # chars left in current line
	LDD	,Y++			Get char to repeat & # times to repeat
	BRA	DGS11			And enter RLE loop

; Draw REL char
DGS11:	
	PSHS	Y,D			Save regs (source offset, character being repeated, repeat counter)
	BSR	BITMAP_PLOTTER		Draw char in A to screen (NOTE: updates $FD to next char to right!)
	PULS	D,Y			Restore regs (char to repeat, repeat counter, source offset)
	DEC	BYTECOUNT		Dec # of chars left in current line
	BNE	DGS5			Still more, check RLE length
; Starting new line - update ptrs and # chars left on screen
	STD	TEMP_A			Save char and RLE count
	LDD	CURRENTSCREEN		Get current line screen address
	CMPA	#$F8			Are we already on last line on screen?
	BHS	DECOMPSCR_DONE		Yes, we are done (use existing RTS)
	ADDA	#5			Down 1 line (this adds the high byte of (160*8). Each line always starts on even 256 bytes)
	STD	CURRENTSCREEN		Save updated address
	STD	$FD			And make active address for BITMAP_PLOTTER
	LDB	#40			Re-init # of chars left on current line
	STB	BYTECOUNT
	LDD	TEMP_A			Get char & RLE counts back
; Update RLE count (we know we have more chars to print on current line (BYTECOUNT))
DGS5:
	DECB				Dec # of chars left in RLE block
	BPL	DGS11			Still more, continue
	LDB	BYTECOUNT		Get # of chars left in current line for regular loop
	BRA	DGS1			And continue with next char from source stream

; BITMAP_PLOTTER: should be 5 bytes shorter, and 16 CPU cycles/char faster per
;   text character drawn
; Entry: A=character to print (0-127). Hi bit set means to print inversed.
;        [$FD] Pointer to where on screen to print 8x8 character
; Uses: INVERSE (0=regular char, <>0=invert)
; Exit: [$FD] points to the start of the next character to the right (original [$FD]+4)
; 128 characters, which are 8x8 pixels, in 16 color mode, so 4 bytes x 8 bytes
BITMAP_PLOTTER:
	CLR	INVERSE			Default to regular chars
	TSTA				Hi bit set (inverse flag)?
	BPL	NEXT			No, leave flag alone
	STA	INVERSE			Yes, Set inverse flag
	ANDA	#%01111111		Clear the built in inverse flag from the character
NEXT:
	LDB	#32			32 bytes / character (graphics)
	MUL				Calculate offset to character in table we want to print
	LDU	#PETSCII_COCO	Point to start of ASCII table
	LEAU	D,U			Point U to start of character
;New unroll with inverted separate - should be a little faster yet for both cases, although a little longer
	LDX	$FD			Get ptr to where we are drawing on screen
	LDA	INVERSE			Do we need to invert?
	BEQ	DoRegular		No, do full 4x8 byte char normally
 	LDY	#8			8 rows to do
NextRowInv:
	PULU	D			Get left 2 bytes
	COMA				Invert them
	COMB
	STD	,X			Save to screen
	PULU	D			Get right 2 bytes
	COMA				Invert them
	COMB
	STD	2,X			Save to screen
	LDB	#160			Bump screen ptr down one line
	ABX
	LEAY	-1,Y			Done all 8 lines of char?
	BNE	NextRowInv		Keep going until done
	LEAX	-(CHAR_ROWSIZE)+CHAR_WIDTH,X		Move screen ptr to top left of next char to right (+4 from start position).
	STX	$FD			Save updated screen ptr (points to 8x8 character to the right of the one we drew)
	RTS

DoRegular:
	LDB	#8			8 rows to do (+2 cyc)
	STB	<TEMP_B			Save ctr
NextRowRegular:
	PULU	D,Y			Get left 2 bytes
	STD	,X			Save to screen
	STY	2,X			Save to screen
	LDB	#160			Bump screen ptr down one line
	ABX				Move to next line
	DEC	<TEMP_B			Done all 8 lines of char?
	BNE	NextRowRegular		Keep going until done
	LEAX	-(CHAR_ROWSIZE)+CHAR_WIDTH,X	Move screen ptr to top left of next char to right (+4 from start position).
	STX	$FD			Save updated screen ptr (points to 8x8 character to the right of the one we drew)
	RTS

; Draws players health bar (6 characters including full, half and empty chars)
; Modifies X,D (and Y,U in BITMAP_PLOTTER)
; prints health bard (full char, 1/2 char and tailing spaces) up to 6 chars max
DISPLAY_PLAYER_HEALTH:
	LDX	#SCREEN+(23*CHAR_ROWSIZE)+(CHAR_WIDTH*34)	($F388); 23rd line, 34th character
	STX	$FD			save as current text position ptr on screen
	LDB	UNIT_HEALTH		No index needed because it is the player
	LSRB				divide by two (# of full health chars to draw)
	BEQ	DPH02			No full blocks, skip ahead to a half block
	LDA	#$66			Full width GRAY BLOCK
; Draw full blocks first
DPH01:
	STD	TEMP_X			Save counter & char (USING X SINCE BITMAP_PLOTTER uses TEMP_B already)
	BSR	BITMAP_PLOTTER		Draw the bar char
	LDD	TEMP_X			Get counter & char back
	DECB				dec counter
	BNE	DPH01			Continue until all full chars are done
; Draw half block (if needed)
DPH02:	
	LDB	UNIT_HEALTH		Get player health
	ANDB	#%00000001		Odd number?
	BEQ	DPH03			No, just fill rest of 6 char health bar with spaces
	LDA	#$5C			Yes, draw a half gray block
	BSR	BITMAP_PLOTTER
; Fill remaining with spaces (cleans up if player lost health)
DPH03:	
	LDD	#$20*256+12		A=space char, B=max # of 1/2 empty bars (spaces) to draw
	SUBB	UNIT_HEALTH		Subtract players actual health
	LSRB				# of full spaces to print
DPH03A:
	BEQ	DPH05			No spaces to print, exit
DPH04	STD	TEMP_X			Save space char & # spaces we have left to print
	BSR	BITMAP_PLOTTER  	Print a space
	LDD	TEMP_X			Get space char & # of spaces left to print
	DECB				Drop # spaces left to print
	BNE	DPH04			More to do, keep going until done
DPH05	RTS

; Cycle to next item in players inventory.
; ENTRY: SELECTED_ITEM = item # currently selected
; EXIT:  SELECTED_ITEM = new item # currently selected (also in A?)
CYCLE_ITEM:
;LDA	#13		;CHANGE-ITEM-SOUND
;JSR	PLAY_SOUND	;SOUND PLAY
	LDA	SELECT_TIMEOUT		Select timeout finished?
	BEQ	CYIT0			Yes, let player select a different item
	RTS				No, return until enough VSYNC IRQ's have passed

CYIT0:	
	LDD	#3*256+20		;RESET THE TIMEOUT to 3 ticks, and KEYTIMER to 20 ticks
	STA	SELECT_TIMEOUT
	STB	KEYTIMER
	INC	SELECTED_ITEM		Inc currently selected item #
	LDA	SELECTED_ITEM		Get new value
	CMPA	#5			Time to wrap around?
	BNE	DISPLAY_ITEM		No, display newly selected item
CYIT1:	
	CLR	SELECTED_ITEM		Yes, selected item=0
	
DISPLAY_ITEM:
	BSR	PRESELECT_ITEM		Note: This returns SELECTED_ITEM in A
DSIT00:	
	LDA	SELECTED_ITEM		Get currently selected item
	BNE	DSIT01			There is one, display it
	RTS				None, leave blank (SELECTED_ITEM=0)

DSIT01:	
	CMPA	#5			item # out of range of (0-4)?
	BNE	DSIT0A			No, figure out if it is one the player has
	CLRA				Yes, wrap to 0 & return
	STA	SELECTED_ITEM
	RTS

DSIT0A:	
	DECA				#1 (bomb)?
	BNE	DSIT03			No, check next
	LDA	INV_BOMBS		Yes, get # bombs left in player inventory
	BNE	DISPLAY_TIMEBOMB	Yes, still have some, display the Time Bomb graphic/count & return from there
	INC	SELECTED_ITEM		No, player is out, bump to next item # and see if player has those
	BRA	DSIT00

DSIT03:
	DECA				#2 (EMP)?
	BNE	DSIT05			No, check next
	LDA	INV_EMP			Yes, get # of EMP charges left in player inventory
	BNE	DISPLAY_EMP		Yes, still have some, display the EMP graphic/count & return from there
	INC	SELECTED_ITEM		No, player is out, bump to next item # and see if player has those
	BRA	DSIT00

DSIT05:	
	DECA				#3 (Medkit)?
	BNE	DSIT07			No, check next
	LDA	INV_MEDKIT		Get # of medkit health points player has
	BNE	DISPLAY_MEDKIT		Have some, display the Medkit graphic/count & return from there
	INC	SELECTED_ITEM		No, player is out, bump to next item # and see if player has those
	BRA	DSIT00

DSIT07:	
	DECA				#4 (magnet)?
	BNE	DSIT09			No, player has no items left. set item # to 0 and blank the item area on screen
	LDA	INV_MAGNET		Yes, get # of magnets player has
	BNE	DISPLAY_MAGNET		Have some, display the magnet graphic/count & return from there
DSIT09:	
	CLRA				Player out of items, set selected item to 0
	STA	SELECTED_ITEM
	BSR	PRESELECT_ITEM
	BRA	DISPLAY_ITEM		And display blank in the item area

;This routine checks to see if currently selected
;item is zero.  And if it is, then it checks inventories
;of other items to decide which item to automatically
;select for the user.
PRESELECT_ITEM:
	LDA	SELECTED_ITEM		If player has item already selected, return
	BEQ	PRSI01			Doesn't have one, see if the player has one we can switch to
	RTS	

PRSI01:	
	LDA	INV_BOMBS		Does player have any bombs?
	BEQ	PRSI02			No, check next
	LDA	#1			Yes, select BOMB item
	STA	SELECTED_ITEM
	RTS

PRSI02:	
	LDA	INV_EMP			Does player have any EMP charges?
	BEQ	PRSI03			No, check next
	LDA	#2			Yes, select EMP
	STA	SELECTED_ITEM
	RTS

PRSI03:	
	LDA	INV_MEDKIT		Does player have any Medkit health points
	BEQ	PRSI04			No, check next
	LDA	#3			Yes, select MEDKIT
	STA	SELECTED_ITEM
	RTS

PRSI04:
	LDA	INV_MAGNET		Get # of magnets player has
	BEQ	PRSI05			None, blank item area out
	LDA	#4			Set selected item to magnet & return	
	STA	SELECTED_ITEM
DSP_OBJECT_END:
	RTS

;Nothing found in inventory at this point, so set
;selected-item to zero.
PRSI05:	
	CLR	SELECTED_ITEM		No items in inventory, clear selected item
	BRA	DISPLAY_BLANK_ITEM	And blank out the item area, returning from there

; Display Timebomb in PETSCII (6x4 text chars). 
DISPLAY_TIMEBOMB:
	LDY	#TBOMB1A		Get ptr to PETSCII 6x4 grid of chars for Time Bomb
	LDX	#SCREEN+(8*CHAR_ROWSIZE)+(34*CHAR_WIDTH)	Where to draw timebomb on screen
	BSR	DISPLAY_OBJECT		Go draw 6x4 image
* Unique to each object, so each routine will have it's own version of this
	LDA	INV_BOMBS		Get # of bombs in inventory
	STA	DECNUM			Save for subroutine
DISPLAY_ITEM_COUNT:
	LDD	#SCREEN+(12*CHAR_ROWSIZE)+(37*CHAR_WIDTH)	$BC94
DISPLAY_ITEM_COUNT2:
	STD	$FD			Save where to draw for subroutine
	JMP	DECWRITE		Go draw 3 digits and return from there

DISPLAY_EMP:
	LDY	#EMP1A			Get ptr to PETSCII 6x4 grid of chars for EMP
	LDX	#SCREEN+(8*CHAR_ROWSIZE)+(34*CHAR_WIDTH)	($A888) Where to draw EMP on screen
	BSR	DISPLAY_OBJECT		Go draw 6x4 image
	LDA	INV_EMP			Get # of EMP's in inventory
	STA	DECNUM			Save for subroutine
	BRA	DISPLAY_ITEM_COUNT	Draw on screen, return from there
	
DISPLAY_MEDKIT:
	LDY	#MED1A			Get ptr to PETSCII 6x4 grid of chars for MedKit
	LDX	#SCREEN+(8*CHAR_ROWSIZE)+(34*CHAR_WIDTH)	($A888) Where to draw Medkit on screen
	BSR	DISPLAY_OBJECT		Go draw 6x4 image
	LDA	INV_MEDKIT		Get # of Medkits in inventory
	STA	DECNUM			Save for subroutine
	BRA	DISPLAY_ITEM_COUNT	Draw on screen, return from ther
	
DISPLAY_MAGNET:
	LDY	#MAG1A			Get ptr to PETSCII 6x4 grid of chars for Magnet
	LDX	#SCREEN+(8*CHAR_ROWSIZE)+(34*CHAR_WIDTH)	($A888) Where to draw Magnet on screen
	BSR	DISPLAY_OBJECT		Go draw 6x4 image
	LDA	INV_MAGNET		Get # of magnets in inventory
	STA	DECNUM			Save for subroutine
	BRA	DISPLAY_ITEM_COUNT	Draw on screen, return from there
		
DISPLAY_BLANK_ITEM:
	LDY	#BLANK1A		Get ptr to PETSCII 6x4 grid of chars for Blank (shares last 6 bytes of PISTOL)
	LDX	#SCREEN+(8*CHAR_ROWSIZE)+(34*CHAR_WIDTH)	($A888) Where to draw blank on screen
	BSR	DISPLAY_OBJECT		Draw 6x4 blank image
	LDX	#SCREEN+(12*CHAR_ROWSIZE)+(34*CHAR_WIDTH)	Where to blank out digits on screen
	BRA	BLANK2

; Patch to DISPLAY_OBJECT routine to allow <4 lines per object draw
; Draw 6x4 object
; Entry: X = ptr to upper left corner on screen to draw object at
;        Y = ptr to 6x4 PETSCII chars to draw
DISPLAY_OBJECT:
	LDB	#4			# lines to draw
; If entered here, same entry as above with this added:
; Entry: B = # of lines to draw
DISPLAY_OBJECT2:
	STB	<LINE_COUNTER		Save # lines to draw
DSP_NEXTLINE:
	STX	<SCRN_ADDRESS		Save to change lines quickly
	STX	<$FD			Save current char position on screen for subroutine
	LDB	#6			6 PETSCII chars per line
DSP_NEXTCHAR:
	LDA	,Y+			Get char
	PSHS	B,Y			Save ctr & object address
	JSR	BITMAP_PLOTTER		Draw char (autoinc's dest char position)
	PULS	B,Y			Get ctr & object address back
	DECB				Dec # chars left in current line
	BNE	DSP_NEXTCHAR		Still more, keep drawing
	DEC	<LINE_COUNTER		Dec # lines left to draw
	BEQ	DSP_OBJECT_END		done, exit
	LDX	<SCRN_ADDRESS		Get start of previous line
	LEAX	CHAR_ROWSIZE,X		Bump to start of next row down
	BRA	DSP_NEXTLINE

DISPLAY_PLASMA_GUN:
	LDY	#WEAPON1A		Get ptr to PETSCII 6x4 grid of chars for Plasma Gun
	LDX	#SCREEN+(1*CHAR_ROWSIZE)+(34*CHAR_WIDTH)	($8588) Where to draw Plasma Gun on screen
	BSR	DISPLAY_OBJECT		Go draw 6x4 image
	LDA	AMMO_PLASMA		Get # shots left for plasma gun
	STA	DECNUM			Save for subroutine
	LDD	#SCREEN+(5*CHAR_ROWSIZE)+(37*CHAR_WIDTH)	$9994 Where to put digits on screen
	BRA	DISPLAY_ITEM_COUNT2	Put # on screen, return from there
	
DISPLAY_PISTOL:
	LDY	#PISTOL1A		Get ptr to PETSCII 6x4 grid of chars for Pistol
	LDX	#SCREEN+(1*CHAR_ROWSIZE)+(34*CHAR_WIDTH)	($8588) Where to draw Pistol on screen
	BSR	DISPLAY_OBJECT		Go draw 6x4 image
	LDA	AMMO_PISTOL		Get # shots left for pistol
	STA	DECNUM			Save for subroutine
	LDD	#SCREEN+(5*CHAR_ROWSIZE)+(37*CHAR_WIDTH)	$9994 Where to put digits on screen
	JMP	DISPLAY_ITEM_COUNT2	Put # on screen, return from there
		
; Bug fix - originally my code blanked the weapon, but not the ammo count
DISPLAY_BLANK_WEAPON:
	LDY	#BLANK1A		Get ptr to PETSCII 6x4 grid of chars for Blank (shares last 6 bytes of PISTOL)
	LDX	#SCREEN+(1*CHAR_ROWSIZE)+(34*CHAR_WIDTH)	($8588) Where to draw Pistol on screen
	BSR	DISPLAY_OBJECT		Draw 6x4 blank image and return from there
	LDX	#SCREEN+(5*CHAR_ROWSIZE)+(34*CHAR_WIDTH)	($8588) Where to draw ammo count on screen
BLANK2:	LDB	#1			1 more line to blank (digits on screen)
	LDY	#BLANK1A		Get ptr to PETSCII row of 6 blanks
	BRA	DISPLAY_OBJECT2		Blank out ammo count & return from there

; Display current weapon on screen. If none selected, pick first one with
; ammo. If no weapons with ammo, blank out the weapon.
DISPLAY_WEAPON:
	LDA	SELECTED_WEAPON		Get currently selected weapon
	BEQ	FIND_WEAPON		None, see if we have one to make active
	DECA				Pistol?
	BNE	PRSW01			No, check plasma
	LDB	AMMO_PISTOL		Does player have ammo for pistol?
	BNE	DISPLAY_PISTOL		Yes, draw pistol & return from there
PRSW01:
	LDB	AMMO_PLASMA		Does player have ammo for plasma?
	BEQ	PRSW02			No, check for different weapon
	LDA	#2			Yes, set selected weapon to plasma
	STA	SELECTED_WEAPON
	BRA	DISPLAY_PLASMA_GUN	Yes, display plasma & return from there

PRSW02:	CLRA				Reset A for checking for another weapon
; No weapon currently selected; see if we can find one with ammo
FIND_WEAPON:
	INCA				Bump up to pistol type (1)
	LDB	AMMO_PISTOL		Player have any ammo for pistol?
	BEQ	PRSW03			No, see if they have any for Plasma gun
	STA	SELECTED_WEAPON		Yes, Draw Pistol (1) & return from there
	BRA	DISPLAY_PISTOL

PRSW03:	
	INCA				Plasma type (2)
	LDB	AMMO_PLASMA		Player have any ammo for plasma?
	BEQ	PRSW04			No, set weapon to blank
	STA	SELECTED_WEAPON		Yes, draw Plasma (2) & return from there
	BRA	DISPLAY_PLASMA_GUN

PRSW04:
	CLRA				Player has no ammo, set selected weapon to 0 (blank)
	STA	SELECTED_WEAPON
	BRA	DISPLAY_BLANK_WEAPON	Blank out weapon & return from there


CYCLE_WEAPON:
;LDA	#12		;CHANGE WEAPON-SOUND
;JSR	PLAY_SOUND	;SOUND PLAY
	LDA	SELECT_TIMEOUT		Are we still delaying before next weapons select can be done?
	BEQ	CYWE0			No, go cycle through next weapon
	RTS				Yes, ignore request and return

CYWE0:	
	LDA	#3
	STA	SELECT_TIMEOUT		RESET THE TIMEOUT to 3 ticks
	LDA	#20			And keytimer to 20
	STA	KEYTIMER
	INC	SELECTED_WEAPON		Bump to next weapon
	LDA	SELECTED_WEAPON		Get weapon #
	CMPA	#2			Now at Plasma?
	BNE	CYWE1			No, we are now past that, so wrap back to 0
	BRA	DISPLAY_WEAPON		Yes, display weapon

CYWE1:	
	CLR	SELECTED_WEAPON		Clear weapon selected
	BRA	DISPLAY_WEAPON		Find next weapon in inventory, display it & return from there

;This is the routine that allows a person to select
;a level and highlights the selection in the information
;display. It is unique to each computer since it writes
;to the screen directly.
ELEVATOR_SELECT:
	JSR	DRAW_MAP_WINDOW		Redraw the viewable window first
	CLRA				X=unit # for elevator
	LDB	UNIT
	TFR	D,X
	LDB	UNIT_D,X		get max levels this elevator handles (base 1)
	STB	ELEVATOR_MAX_FLOOR	Save it for other routine
;Now draw available levels on screen
	LDA	#$31			A=ASCII '1'
	LDU	#SCREEN+(24*CHAR_ROWSIZE)+(6*CHAR_WIDTH)	($F818)	Start position to print at 6,24
	STU	<$FD  			Save for BITMAP_PLOTTER
ELS1:	
	PSHS	X,D			Save regs we need to preserve
	JSR	BITMAP_PLOTTER		Draw the level # on screen (automatically moves to next char position)
	PULS	D,X			Get regs back
	INCA				Bump ASCII digit up
	DECB				Dec # of level #'s we are printing
	BNE	ELS1			Keep print level #'s until they are all done
	LDA	UNIT_C,X		Get level # we are on now
	STA	ELEVATOR_CURRENT_FLOOR	Save as current
	BSR	ELEVATOR_INVERT		Now highlight current level
;Now get user input
; LDA	CONTROL	
; CMPA	#2
; BNE	ELS5
;JMP	SELS5

; KEYBOARD INPUT - select elevator level or exit elevator
ELS5:
	LDA	CURRENT_KEY		Get keypress (generated from VSYNC IRQ routine)
	BEQ	ELS5			until we actually get one
	CMPA	KEY_MOVE_LEFT		Move Left key (Down a level)?
	BNE	ELS6			No, check next option
	BSR	ELEVATOR_DEC		Yes, move player selection to previous level
ELS5A:	CLR	CURRENT_KEY		Clear out key press
	BRA	ELS5			And go wait for next keypress

ELS6:	
	CMPA	KEY_MOVE_RIGHT		Move Right key (Up a level)?
	BNE	ELS10			No, check next option
	BSR	ELEVATOR_INC		Yes, move player selection to next level
	BRA	ELS5A			Go wait for next keypress

ELS10:	
	CMPA	KEY_MOVE_DOWN		Move Down key (open door)?
	BNE	ELS5			No, ignore keypress and get another one
	CLR	CURRENT_KEY		Yes, clear the key buffer
	JSR	CLEARALL		Clear the text window at bottom
	JMP	CLEAR_KEY_BUFFER	Clear key buffer & reset keyboard repeat start timer

; Invert current floor # selection
; Entry: ELEVATOR_CURRENT_FLOOR is our current floor #
;        ELEVATOR_MAX_FLOOR is maximum floor # for this elevator
ELEVATOR_INVERT:
	LDB	ELEVATOR_CURRENT_FLOOR	Get current floor #
	LSLB				4 bytes (8 pixels) per character
	LSLB
	LDU	#SCREEN+(24*CHAR_ROWSIZE)+(5*CHAR_WIDTH)	($F814)	Start position-1 first level # on screen (5,24)
	LEAU	B,U			Point to level # on screen that we are currently on
	LDX	#8			# of scanlines to invert
RM0A:	LDD	,U			Get left half
	COMA				invert them
	COMB
	STD	,U			Save them back
	LDD	2,U			Get right half
	COMA				invert them
	COMB
	STD	2,U			Save them back
	LEAU	PIXEL_ROWSIZE,U		Move to next line down
	LEAX	-1,X			Dec # of scanlines left
	BNE	RM0A			Do until whole char inverted
;CLR CURRENT_KEY		?Might still need this?
	RTS

ELEVATOR_INC:
	LDA	ELEVATOR_CURRENT_FLOOR	Get current floor #
	CMPA	ELEVATOR_MAX_FLOOR	Already @ maximum floor #?
	BNE	ELVIN1			No, move select to next floor #
	RTS				Yes, leave cursor where it is & return

ELVIN1:	
	BSR	ELEVATOR_INVERT		First change previous selection back to normal
	INC	ELEVATOR_CURRENT_FLOOR	Increase floor number selected
	BSR	ELEVATOR_INVERT		Invert that one
	BRA	ELEVATOR_FIND_XY	... & return from there

ELEVATOR_DEC:
	LDA	ELEVATOR_CURRENT_FLOOR	Get currently selected level
	CMPA	#1			Already at lowest?
	BNE	ELVDE1			No, go change to previous level
	RTS				Yes, leave cursor where it is & return

ELVDE1:	
	BSR	ELEVATOR_INVERT		First change previous selection back to normal
	DEC	ELEVATOR_CURRENT_FLOOR  Decrease floor number selected
	BSR	ELEVATOR_INVERT		Invert that one
; Search through Door objects (32-47) for elevator door specifically
ELEVATOR_FIND_XY:
	LDB	#47			Last door object
	LDX	#UNIT_TYPE		Point to Unit_Type table (will tell which kind of door)
ELXY1:	LDA	B,X			Get door type (each loop is 17 cycles if not found)
	CMPA	#19			Elevator type?
	BEQ	ELXY2			Yes, go check floor #
ELXY3:	DECB				No, next door in list
	CMPB	#32			Finished checking all doors?
	BHS	ELXY1			No, keep checking 
	RTS				Yes, return

ELXY2:	CLRA				Found elevator, move unit # to Y
	TFR	D,Y			
	LDA	UNIT_C,Y		Get floor # this elevator is on
	CMPA	ELEVATOR_CURRENT_FLOOR	Same as floor now selected?
	BNE	ELXY3			No, keep checking for another elevator
ELXY10:	LDA	UNIT_LOC_X,Y		Get new elevators X location
	LDB	UNIT_LOC_Y,Y		Get new elevators Y location
	STA	UNIT_LOC_X		Make that Players X location
	SUBB	#$01			Players Y location 1 up from elevator's
	STB	UNIT_LOC_Y		Make that Players Y location
	SUBD	#$0503			subtract 5 horizontal & another 3 vertical to center in view window  
	STD	MAP_WINDOW_X		Save view window's upper left start X,Y
	ADDD	#10*256+6		Calc lower right coords
	STD	MAP_WINDOW_XMAX		Save for faster access in various routines
	JMP	DRAW_MAP_WINDOW		Redraw window from new perspective & return from there

; Calling routine resets Y after this (when it calls DECOMPRESS_SCREEN), I don't think
;  it needs to preserve X (but we could pshs/puls X if needed)
; Speed not required; go for smaller code here
SET_CONTROLS:	;load standard values for key controls
	LDB	#14
	LEAY	<STANDARD_CONTROLS,PCR
	LDX	#KEY_MOVE_UP
SETC2:	
	LDA	,Y+
	STA	,X+
	DECB
	BNE	SETC2
	RTS

STANDARD_CONTROLS:
	.BYTE	87			MOVE UP W
	.BYTE	83			MOVE DOWN S
	.BYTE	65			MOVE LEFT A
	.BYTE	68			MOVE RIGHT D
	.BYTE	94			FIRE UP up arrow
	.BYTE	10			FIRE DOWN down arrow
	.BYTE	8			FIRE LEFT left arrow
	.BYTE	9			FIRE RIGHT right arrow	
	.BYTE	49			CYCLE WEAPONS 1
	.BYTE	50			CYCLE ITEMS 2
	.BYTE	32			USE ITEM spacebar
	.BYTE	90			SEARCH OBJECT Z
	.BYTE	77			MOVE OBJECT M
  .BYTE 88      DISPLAY MAP

; Entry: <DECNUM = byte value we want to print in decimal ASCII format
;        <$FD    = Ptr to where on screen to print (updates to next character cell to right) 
; Uses:  A,B,X,U (all modified on exit)
; Calls: BITMAP_PLOTTER (Enters with A=char, <INVERSE flag set/cleared).
; Uses D,X,Y,U all modified on exit. <$FB updated on exit
; Always prints 3 digits: 000-255
;==========
;New code (remove PRINT: routine entirely):
DIGITSTBL:
	fcb	100,10,1

DECWRITE:
	LDX	#DIGITSTBL		Point to digits table
	LDA	#3			3 digits to do
	PSHS	A			Save counter
	LDB	DECNUM			Get byte value we will print
DEC1:	CLRA				Init digit to 0
DEC2:	INCA				Bump up digit
	SUBB	,X			Subtract current digit value
	BHS	DEC2			Haven't underflowed yet, keep going
	DECA				Drop digit back
	ADDB	,X+			And add current digit value (and bump to next value in table)
	PSHS	X,B			Save src ptr & count
	ADDA	#$30			Make ASCII
	JSR	BITMAP_PLOTTER		Print digit in A to screen, advance to next char position
	PULS	X,B			Restore src ptr & count
	DEC	,S			Dec digit position counter
	BNE	DEC1			Still more, continue
	PULS	A,PC			Eat temp stack & return

COCO_SCREEN_SHAKE:
	LDA	BGTIMER1		Always 0 or 1; 0=AI routines done work for this cycle?
	BNE	PSS4			AI not done, skip ahead
	RTS				AI is done, just return
PSS4:
	LDA	SELECT_TIMEOUT		Get time delay before Select allowed again (shoehorned this into the screenshake routine)
	BEQ	PSS4A			No delay, skip ahead (this is to prevent accidental double-taps on cycle weapons or items). 
	DEC	SELECT_TIMEOUT		Dec delay
PSS4A:  
  LDA	SCREEN_SHAKE		Are we supposed to shake the screen?
	BNE	PSS0		Yes, go do that
  RTS			No, return
; Shake screen
PSS0:    
    LDA    #32            ??? set border register palette to 100 (0-63 normally)
    STA    $FF9A
  
    LDA    #$F0            Small delay timer init value
    STA    FLASH_DELAY        Save for subroutine
    JSR    GENERATE_RANDOM_NUMBER    Generate a random number
    LDA    RANDOM            Get the number
    ANDA    #7            limit it's range
    STA    $FF9F            Save in horizontal offset register
    BSR    PSS1            Small time delay
    CLR    $FF9F            Reset horizontal offset register to normal
  
    LDA    #1
    STA    REDRAW_WINDOW
    CLR    $FF9A
    RTS
PSS1:
;  LDA FLASH_DELAY
    CLRA
    LDB    FLASH_DELAY
    LSLB
    ROLA
    LSLB
    ROLA
    LSLB
    ROLA
    TFR    D,X
PSS2:
    NOP 
;  DECA
    LEAX    -1000,X
    LEAX    1000,X
    LEAX    -1000,X
    LEAX    -1000,X
    LEAX    1000,X
    LEAX    -1000,X
    LEAX    -1000,X
    LEAX    1000,X
    LEAX    -1000,X
    LEAX    -1000,X
    LEAX    1000,X
    LEAX    -1000,X
    LEAX    -1000,X
    LEAX    1000,X
    LEAX    -1000,X
    LEAX    -1000,X
    LEAX    1000,X
    LEAX    -1000,X
    LEAX    -1000,X
    LEAX    1000,X
    LEAX    -1000,X
    BNE PSS2
    RTS

; ; Shake screen
; PSS0:	
;   ; LDA	#5			??? set border register palette to 100 (0-63 normally)
; 	; STA	$FF9A
  
;   LDA #$F0
;   STA FLASH_DELAY
;   ldd #$F001
;   std $FF9D	MSB = ($70000 + addr) / 2048, LSB = (addr / 8) AND $
;   BSR PSS1

;   ldd #$F000
;   std $FF9D	MSB = ($70000 + addr) / 2048, LSB = (addr / 8) AND $F
;   ; * Turn off border (DEBUG)
;   ; CLR	$FF9A			Change border color to black
  
;   LDA	#1
;   STA	REDRAW_WINDOW
; 	RTS

; PSS1:
;   LDA FLASH_DELAY
; PSS2:
;   NOP 
;   DECA
;   BNE PSS2
;   RTS


;So, it doesn't really flash the PET border, instead it flashes the word "OUCH" in a white box
; overtop the HEALTH area on the lower right.
; On Coco 3 - just change the GIME border color register (red, maybe?)
; On Coco 1/2 - just change Colorset bit on VDG @ $FF22

;This is actually part of a background routine, but it has to be in the main
;source because the screen effects used are unique on each system.
; This is used to start the Transport process. LCB NOTE: I *think* this cycles through
; the B_TIMER from 0 to 15, using the 1st and 4th bits to help trigger which of 3 tiles
; it draws at different times.
DEMATERIALIZE:
	LDX	UNITPRE			Get 16 bit unit #
	LDB	UNIT_TIMER_B,X		Get timer
	ANDB	#%00000001		Keep only least sig bit 0 or 1
	ADDB	#160			dematerialize tile (160 or 161)
	STB	UNIT_TILE		Save as unit tile #
	LDB	UNIT_TIMER_B,X		Get full timer value back
	ANDB	#%00001000		Keep only bit 3
	LSRB				Shift that to bit 0 (so 0 or 1 again)
	LSRB
	LSRB
	ADDB	UNIT_TILE		Add that to tile we updated before (now 160,161 or 162)
	STB	UNIT_TILE		Save updated tile #
	INC	UNIT_TIMER_B,X		Add 1 to B timer
	LDA	UNIT_TIMER_B,X		Get new B timer value
	CMPA	#%00010000		Is it 16?
	BEQ	DEMA1			Yes, transport is complete, so skip ahead
	LDA	#1			Not yet, set TIMER_A to 1 & flag to redraw window
	STA	UNIT_TIMER_A,X
	STA	REDRAW_WINDOW
	JMP	AILP			Back to AI processing loop

;TRANSPORT COMPLETE
DEMA1:
	LDA	UNIT_B,X		Get type of transporter (0=completes level, 1=send to coordinates)
	BNE	DEMA2			Send elsewhere on current level, go handle that
; transporter that ends current level
	LDD	#2*256+7		A=Game over condition, B=normal transported pad
	STA	UNIT_TYPE		player type to game over condition
	STB	UNIT_TYPE,X		Set transporter pad type to "normal"
	JMP	AILP			Back to AI processing loop

; Transporter that teleports player
DEMA2:	
	LDA	UNIT_C,X		Copy target X,Y coordinates from transporter to players coordinates
	STA	UNIT_LOC_X
	LDA	UNIT_D,X
	STA	UNIT_LOC_Y
	LDD	#97*256+7		A=Player animation 2nd frame, B="Normal" transporter pad type
	STA	UNIT_TILE
	STB	UNIT_TYPE,X
	JSR	CALCULATE_AND_REDRAW	Update MAP_WINDOW_X,MAP_WINDOW_Y to new player location, flag for redraw
	JMP	AILP			Back to AI processing loop

ANIMATE_PLAYER:
ANP1:    
; 14 bytes. Original was 19
	LDA	UNIT_TILE		Get current tile # for player
	CMPA	#97			Current player animation frame #2?
	BNE	ANP2			No, must be 96 so go bump up by 1
	DECA				Yes, bump down to 96
	FCB	$21			BRN opcode (skip next byte)
ANP2:    
	INCA
	STA	UNIT_TILE		Save new player animation tile # & return
	RTS

; Now that these variables are in DP, and they are contiguous, make a clear loop (smaller). 
;NOTE: the only place this gets called from calls DISPLAY_GAME_SCREEN immediately after
; which immediately changes the X register, so we don't need to save
; it here.
; NOTE 2: Either SPACE or ENTER can be used to do select a menu option. However, the original
;  PET code will beep if ENTER was hit, but not for SPACE. Not sure why.

RESET_KEYS_AMMO:
	LDD	#HOURS-KEYS		A=0 (for clearing, B=# of bytes to clear)
	LDX	#KEYS			Point to start of vars we are clearing
; note: Any other routines that need to clear 1 to 255 bytes with the same
; value can LDD and LDX their needed values, and then call this routine here:
RST_LOOP:
	STA	,X+			Clear a byte
	DECB				Dec # bytes left
	BNE	RST_LOOP
	RTS

INTRO_SCREEN:
	LDY	#INTRO_TEXT		Point to RLE compressed intro screen
	JSR	DECOMPRESS_SCREEN	Draw it
	JSR	DISPLAY_MAP_NAME	Display currently selected map name
	JSR	CHANGE_DIFFICULTY_LEVEL	Draw part of robot face based on difficulty level (eyebrows)
;JSR	START_INTRO_MUSIC
	CLR	MENUY			Set menu # to 0
	JSR	REVERSE_MENU_OPTION	Invert it to show that it is selected
	LDD	#20*256+12		20 ticks for start of repeat, 12 ticks between subsequent key repeats
	STD	KEYTIMER_STARTDELAY	Save both as reset default values
	STA	KEYTIMER		And initial delay
ISLOOP	
	LDA	CURRENT_KEY		Get key from keyboard buffer
	BEQ	ISLOOP			None, loop back and wait for player to hit one during VSYNC IRQ
	CMPA	#10			CURSOR DOWN key? (default=down arrow)
	BNE	IS001			No, try next
; Move down in menu
IS001A:	
	LDA	MENUY			Get current menu selection
	CMPA	#3			Already at 3 (bottom)?
	BEQ	ISLOOP			Yes, can't go down any further, go read another key
	JSR	REVERSE_MENU_OPTION	Un-invert the current selection
	INC	MENUY			Move selection down 1
	JSR	REVERSE_MENU_OPTION	Invert it on screen
;LDA	#15	;menu beep
;JSR	PLAY_SOUND
	BRA	ISLOOP			And back to the key read loop

IS001:	
	CMPA	#94			CURSOR UP key? (default=up arrow)
	BNE	IS002			No, try next
IS002A:	
	LDA	MENUY			Get current menu selection
	BEQ	ISLOOP			Already at 0 (top), can't go up any further, go read another key
	JSR	REVERSE_MENU_OPTION	Un-invert the current selection
	DEC	MENUY			Move selection up 1
	JSR	REVERSE_MENU_OPTION	Invert it on screen
;LDA	#15	;menu beep
;JSR	PLAY_SOUND
	BRA	ISLOOP			And back to the read key loop

IS002:	
	CMPA	#32			SPACE key? (to select)
	BEQ	EXEC_COMMAND		Yes, execute current menu selection without beeping
IS003:	
	CMPA	KEY_MOVE_UP		MOVE UP key? (default='W')
	BEQ	IS002A			Yes, move up
IS004:	
	CMPA	KEY_MOVE_DOWN		MOVE DOWN key? (default='S')
	BEQ	IS001A			Yes, move down
IS005:	
	CMPA	#13			ENTER key?
	BNE	ISLOOP			No, not an allowed key, go back to key read loop
;LDA	#15 		;menu beep
;JSR	PLAY_SOUND	;SOUND PLAY
	BRA	EXEC_COMMAND		Execute current menu selection with a beep

; ; START_INTRO_MUSIC:
; ; 	CLRA
; ; 	STA	DATA_LINE
; ; 	LDA	#$FF
; ; 	STA	SOUND_EFFECT
; ; 	LDA	#<INTRO_MUSIC
; ; 	STA	CUR_PATTERN_L
; ; 	LDA	#>INTRO_MUSIC
; ; 	STA	CUR_PATTERN_H
; ; 	LDA	#1
; ; 	STA	MUSIC_ON
; ; 	RTS

EXEC_COMMAND:
	LDA	MENUY			Get which menu option user chose
;START GAME
	BNE	EXEC1			Not menu #0 (START GAME), try next
;CLRA
;STA	MUSIC_ON
;STA	$E848	;turn off sound
;STA	$E84A	;turn off sound
	JMP	INIT_GAME		Was menu #0 (START GAME), go start the game

EXEC1:	
	CMPA	#2			Menu #2 (DIFFICULTY)??
	BNE	EXEC05			no, try next
	INC	DIFF_LEVEL		Yes, bump up difficulty level
	LDA	DIFF_LEVEL		Get new difficulty
	CMPA	#3			Time to wrap? (only 0-2 allowed)
	BNE	EXEC02			No, update robot graphics to show difficulty has changed?
	CLR	DIFF_LEVEL		Yes, change to difficulty 0
EXEC02:	
	JSR	CHANGE_DIFFICULTY_LEVEL	Update robot graphics to reflect difficulty change
;LDA	#15	;menu beep
;JSR	PLAY_SOUND
	CLR	CURRENT_KEY		Clear key buffer
	BRA	ISLOOP			And wait for user again

EXEC05:	
	CMPA	#1			Menu #1 (cycle through maps)?
	BNE	EXEC06			No, check next
; LDA	#15	;menu beep
;JSR	PLAY_SOUND
	BSR	CYCLE_MAP		Cycle to next map (and wrap around if needed)
	CLR	CURRENT_KEY		Clear key buffer
	BRA	ISLOOP			And wait for user again

EXEC06:	
	CMPA	#3			Menu #3 (change default key controls)?
	BNE	EXEC07			No, clear key buffer & wait for user again
;JSR	CYCLE_CONTROLS			Bring up Key assignment screen, and get new keys from user
;LDA	#15	;menu beep
;JSR	PLAY_SOUND
EXEC07:	
	CLR	CURRENT_KEY		Clear key buffer
	BRA	ISLOOP			And wait for user again

CYCLE_MAP:
	INC	SELECTED_MAP		Bump to next map
	LDA	SELECTED_MAP		Get map # selected
	CMPA	#10			Maximum number of maps reached?
	BNE	CYM1			No, display new map name on screen
	CLR	SELECTED_MAP		Yes, wrap to map 0 first
CYM1:	
	BRA	DISPLAY_MAP_NAME	And display new map name on screen
	
; Displays the 16 char max map name at fixed spot on screen (0 based is 2,10). This NEVER wraps lines
; and since BITMAP_PLOTTER now advances $FD to the right automatically, we shouldn't need to call
; INC_DEST at all anymore.
DISPLAY_MAP_NAME:
	LDY	#SCREEN+(9*160*8)+(2*4)	($AD08) 9 text lines down, 3rd char from left ($AD08)
; Alternate entry point from DISPLAY_ENDGAME_SCREEN
PRINT_MAP_NAME:
	STY	$FD			Save dest ptr
	BSR	CALC_MAP_NAME		Get ptr to map name we want to print, and store it in $FB (and in X)
	LDB	#16			Map names are always 16 chars (including space padding)
DMN1:
	LDA	,X+			Get char
	CMPA	#$60			Do we need to adjust down by $60?
	BLT	LESS			No, use as is
	SUBA	#$60			Yes, adjust character code first
LESS:
	PSHS	B,X			Save src ptr & ctr
	JSR	BITMAP_PLOTTER		Draw character (NOTE: Updates $FD to next char to right)
	PULS	B,X  			Get src ptr & ctr back
	DECB				Done all 16?
	BNE	DMN1			No, keep going until done
;now set the mapname for the filesystem load
	LDA	SELECTED_MAP		Done printing, get map # player selected again
	ADDA	#65			convert to ASCII letter (A to J for 10 maps)
	STA	MAP_FILENAME+5		Save as part of filename to load map in from
	RTS

; ONLY called from DISPLAY_MAP_NAME and DISPLAY_ENDGAME_SCREEN
CALC_MAP_NAME:
;FIND MAP NAME based on map # (0-9, I think)
; Uses: D,X
; Exit: $FB and X contain the pointer to the 16 character map name
	LDB	SELECTED_MAP		Get map #
	LSLB				16 bytes per entry for map # & name in ASCII
	LSLB
	LSLB
	LSLB
	LDX	#MAP_NAMES		Point to start of map names table
	ABX				Add offset to map names table, so we now point at the specific entry we want
	STX	$FB			Save for calling subs (once we change DISPLAY_ENDGAME_SCREEN, probably can remove-LCB)
	RTS

; Entry: MENUY = menu Y position (0-3)
; Uses: A,B,X,Y,U, preserves none of them
; Exit: $FB has updated graphics position to draw from next
REVERSE_MENU_OPTION:
	LDB	MENUY			Get menu # (0-3)
	LSLB				* 2 bytes per entry
	LDU	#MENU_CHART		Point to table of start addresses for menu lines
	LDU	B,U			Point to menu line on screen we are to inverse
	LDY	#8			# of scanlines to invert
RM00:
	LDX	#2*10			# of 2 byte pairs wide to invert
RM01:
	LDD	,U			Get 2 bytes (4 pixels)
	COMA				Invert them
	COMB
	STD	,U++			Save inverted ones back
	LEAX	-1,X			Dec # of bytes left to invert on current line
	BNE	RM01			Do all 40 bytes (20 words)
	LEAU	PIXEL_ROWSIZE-40,U	Skip to start of next line
	LEAY	-1,Y			Dec line ctr
	BNE	RM00			More lines, keep going
	CLR	CURRENT_KEY		Clear key buffer & return
	RTS

MENU_CHART:
;Ptrs to where to start inverting for each of 4 selections (Screen starts @ $8000)
;So all start $10 bytes (32 pixels) in from left. In order:
;16 pixel lines down (3rd text line)
;24 pixel lines down (4th text line)
;32 pixel lines down (5th text line)
;40 pixel lines down (6th text line)
    .WORD $8A10,$8F10,$9410,$9910

; Update robot face based on difficulty level. Once my BITMAP_PLOTTER updates work fully, this
; can be shrunk by not having to reload X each time (a few will still need to, but not all)
CHANGE_DIFFICULTY_LEVEL:
	LDY	#ROBOT_FACE		Point to table of 8 chars for each robot face/difficulty level
	LDB	DIFF_LEVEL		Get current difficulty level into Y
	LSLB				8 bytes/entry
	LSLB
	LSLB
	LEAY	B,Y			Point to start of specific 8 byte face sequence
;DO CHARACTERS FIRST
	LDA	,Y+			Get first of 8 chars for robot face
	LDX	#SCREEN+(CHAR_ROWSIZE*5)+(CHAR_WIDTH*21)	$9954 Where on screen to print it
	STX	$FD			Save for sub
	PSHS	Y			Save offset
	JSR	BITMAP_PLOTTER		Draw character
	PULS	Y			Get source ptr back
	LDA	,Y+			Do 2nd char of 8
	PSHS	Y
	JSR	BITMAP_PLOTTER
	PULS	Y
	LDA	,Y+			Do 3rd char of 8
	PSHS	Y
	JSR	BITMAP_PLOTTER
	PULS	Y
	LDA	,Y+			Do 4th char of 8
	LDX	#SCREEN+(CHAR_ROWSIZE*5)+(CHAR_WIDTH*25)	$9964
	STX	$FD
	PSHS	Y
	JSR	BITMAP_PLOTTER
	PULS	Y
	LDA	,Y+			Do 5th char of 8
	PSHS	Y
	JSR	BITMAP_PLOTTER
	PULS	Y
	LDA	,Y+			Do 6th char of 8
	PSHS	Y
	JSR	BITMAP_PLOTTER
	PULS	Y
	LDA	,Y+			Do 7th char of 8
	LDX	#SCREEN+(CHAR_ROWSIZE*6)+(CHAR_WIDTH*23)	$9E5C
	STX	$FD
	PSHS	Y
	JSR	BITMAP_PLOTTER
	PULS	Y
	LDA	,Y+			Do 8th char of 8
	LDX	#SCREEN+(CHAR_ROWSIZE*6)+(CHAR_WIDTH*25)	$9E64
	STX	$FD
	JMP	BITMAP_PLOTTER

DIFF_LEVEL	.BYTE 01	;default medium

ROBOT_FACE:
	.BYTE	$3A,$43,$49,$55,$43,$3A,$49,$55	;EASY LEVEL
	.BYTE	$40,$40,$6E,$70,$40,$40,$49,$55	;MEDIUM LEVEL
	.BYTE	$3A,$4D,$3A,$3A,$4E,$3A,$4D,$4E	;HARD LEVEL

; This routine is run after the map is loaded, but before the
; game starts.  If the difficulty is set to normal, nothing 
; actually happens.  But if it is set to easy or hard, then
; some changes occur accordingly.
SET_DIFF_LEVEL:
	LDA	DIFF_LEVEL		Get difficulty level 0-2
	BEQ	SET_DIFF_EASY		0=Easy, do easy settings
SDLE1:	
	DECA				1 (Normal)?
	BNE	SET_DIFF_HARD		No, must be 2 (hard), go do 
	RTS				Setting 1 is normal, no mods needed, so return

SET_DIFF_EASY:
;Find all hidden items and double the quantity.
	LDX	#48			Point to start of hidden items (48-63)
SDE1:	
	LDA	UNIT_TYPE,X		Get unit type
	BEQ	SDE2			None, go onto next one
	CMPA	#128			Found one, is it a key?
	BEQ	SDE2			Yes, leave that alone
	ASL	UNIT_A,X		No, double the quantity of all other hidden items
SDE2:	
	LEAX 	1,X			Go onto next item
	CMPX	#64			Done all hidden items?
	BNE	SDE1			No, keep going until done
	RTS				Yes, return

SET_DIFF_HARD:
; Find all hoverbots and change AI to attack mode
	LDX	#UNIT_TYPE		Point to unit type table
	LDB	#28			Start on last allowable unit (28)
SDH1:	LDA	B,X			Get unit type
	CMPA	#2			hoverbot left/right (2) or up/down (3)
	BLO	SDH2			Not a hoverbot, onto next
	CMPA	#3
	BHI	SDH2			Not a hoverbot, onto next
	LDA	#4			change hoverbot to attack mode
	STA	B,X
SDH2:	DECB 				neither, go onto previous unit
	BNE	SDH1			Keep going until 28 are done
	RTS


; Inverts the map area of the screen (11x7 or 33x21 8x8 text char cells) on Commodore PET
; We need to invert 264 pixels wide x 168 lines (132 bytes x 168 bytes)
; ALTERNATIVE FOR SPEED - just change palettes instead? Then have to change it back after the EMP sound
; at USE_EMP (NOTE: This will change all colors on screen instead of just map area!). The other option is what
; some other ports have done, which is flash the border color. This would be the smallest/easiest for sure.
EMP_FLASH:
	BSR	EMP_FLASH2		Invert screen (falls through to invert it back)
EMP_FLASH2:
	LDU	#SCREEN			(3 cyc) Point to upper left corner of graphics screen
	LDY	#7*(3*8)		(4 cyc) # of pixel lines (7 tile heights which are 24 pixels each)= 168 lines
EMPF1:
	LDX	#33			(3 cyc) # 4 byte pairs to invert. takes around 235040 CPU cycles total (~1/6th second)
EMPF2:
; could unroll this somewhat to speed it up at the cost of size
	PULU	D			(7 cyc) Get 4 pixels . Currently 1386 cycles for inner loop (1 line)
	COMA				(2 cyc) invert them
	COMB				(2 cyc)
	STD	-2,U			(6 cyc) save back & advance screen ptr
	PULU	D			(7 cyc) Get 4 pixels.
	COMA				(2 cyc) invert them
	COMB				(2 cyc)
	STD	-2,U			(6 cyc) save back & advance screen ptr
	LEAX	-1,X			(5 cyc) drop double byte counter
	BNE	EMPF2			(3 cyc) finish current line
	LEAU    PIXEL_ROWSIZE-132,U	(5 cyc) Skip ptr to start of next line
	LEAY	-1,Y			(5 cyc)
	BNE	EMPF1			(3 cyc) And do next line
	RTS				(5 cyc) return

DISPLAY_GAME_SCREEN:
	LDY	#SCR_TEXT		Point to screen text (RLE encoded)
	JMP	DECOMPRESS_SCREEN	Display it & return from there
	
; Update keys - blanks all 3 out, and then draws the ones the player has. May want to change to skip
; blanking them out all at once, and only blank/draw by individual (if player has all 3 keys, will cut drawing
; time in half). This is still smaller/faster than original, though.
DISPLAY_KEYS:
	LDY	#BLANK1A		Get ptr to PETSCII 6x2 grid of chars for Blank (shares last 6 bytes of pistol)
	LDX	#SCREEN+(15*CHAR_ROWSIZE)+(34*CHAR_WIDTH)	$CB88 ;ERASE ALL 3 KEY SPOTS
	LDB	#2			Only 2 lines to clear
	JSR	DISPLAY_OBJECT2		Go clear them (THIS MAY NEED TO BE A JSR IF TOO FAR)
	LDA	KEYS			Get key flags (Get KEY bit flags (bit0=Spade, bit1=Heart, bit2=Star)
	ANDA	#%00000001		Player has Spade key?
;Spade key top 2 chars
	BEQ	DKS1			No, check next key type
	LDA	#$63			Horizontal line on top character
	LDX	#SCREEN+(15*CHAR_ROWSIZE)+(34*CHAR_WIDTH)
	STX	$FD			Save for subroutine
	JSR	BITMAP_PLOTTER  	Draw it
	LDA	#$4D			Diagonal line on right character
	JSR	BITMAP_PLOTTER		Draw it
; Spade key bottom 2 chars
	LDA	#$41			SPADE character
	LDX	#SCREEN+(16*CHAR_ROWSIZE)+(34*CHAR_WIDTH)
	STX	$FD			Save for subroutine
	JSR	BITMAP_PLOTTER		Draw it
	LDA	#$67			Vertical line on right character
	JSR	BITMAP_PLOTTER		Draw it
DKS1:	
	LDA	KEYS			Get key flags (Get KEY bit flags (bit0=Spade, bit1=Heart, bit2=Star)
	ANDA	#%00000010		Player has Heart key?
	BEQ	DKS2			No, go check for Star key
	LDA	#$63			Horizontal line on top character
	LDX	#SCREEN+(15*CHAR_ROWSIZE)+(36*CHAR_WIDTH)
	STX	$FD			Save for subroutine
	JSR	BITMAP_PLOTTER  	Draw it
	LDA	#$4D			Diagonal line on right character
	JSR	BITMAP_PLOTTER		Draw it
	LDA	#$53			HEART character
	LDX	#SCREEN+(16*CHAR_ROWSIZE)+(36*CHAR_WIDTH)
	STX	$FD			Save for subroutine
	JSR	BITMAP_PLOTTER		Draw it
	LDA	#$67			Vertical line on right character
	JSR	BITMAP_PLOTTER		Draw it
DKS2:	  
	LDA	KEYS			Get key flags (Get KEY bit flags (bit0=Spade, bit1=Heart, bit2=Star)
	ANDA	#%00000100		Player has Star key?
;star key
	BEQ	DKS3			No, done key draw routine
	LDA	#$63			Horizontal line on top character
	LDX	#SCREEN+(15*CHAR_ROWSIZE)+(38*CHAR_WIDTH)
	STX	$FD			Save for subroutine
	JSR	BITMAP_PLOTTER  	Draw it
	LDA	#$4D			Diagonal line on right character
	JSR	BITMAP_PLOTTER		Draw it
	LDA	#$2A			STAR character
	LDX	#SCREEN+(16*CHAR_ROWSIZE)+(38*CHAR_WIDTH)
	STX	$FD			Save for subroutine
	JSR	BITMAP_PLOTTER		Draw it
	LDA	#$67			Vertical line on right character
	JMP	BITMAP_PLOTTER		Draw & return from there

DKS3:
	RTS

GAME_OVER:
;stop game clock
	CLR	CLOCK_ACTIVE		Flag clock as inactive
;disable music
;CLRA
;STA	MUSIC_ON
;STA	$E848	;turn off sound
;STA	$E84A	;turn off sound
;Did player die or win?
	LDA	UNIT_TYPE		Get players status
	BNE	GOM0			Still alive, skip ahead
	LDA	#111			dead player tile
	STA	UNIT_TILE		Save for routines
	LDA	#100			100 tick pause before keys accepted
	STA	KEYTIMER
GOM0:	
	JSR	COCO_SCREEN_SHAKE	Shake screen (not implemented yet)
	JSR	BACKGROUND_TASKS	Update background tasks (moving robots, finishing explosions, etc.)
	LDA	KEYTIMER		Get timer
	BNE	GOM0			Keep doing background tasks until KEYTIMER drops to 0 (100 ticks)
GOM1:	
	LDX	#SCREEN+(8*CHAR_ROWSIZE)+(11*CHAR_WIDTH)	$A82C Draw top line
	STX	$FD			Save dest ptr
	LDX	#GAMEOVER1
	BSR	GOM3A			Print 11 char line to screen
	LDX	#SCREEN+(9*CHAR_ROWSIZE)+(11*CHAR_WIDTH)	$AD2C Print "GAME OVER"
	STX	$FD			Save dest ptr
	LDX	#GAMEOVER2
	BSR	GOM3A			Print 11 char line to screen
	LDX	#SCREEN+(10*CHAR_ROWSIZE)+(11*CHAR_WIDTH)	$B22C Draw bottom line
	STX	$FD			Save dest ptr
	LDX	#GAMEOVER3
	BSR	GOM3A			Print 11 char line to screen
	LDA	#100			Reset timer to 100 ticks (to hold GAME OVER on screen for 1&2/3 seconds)
	STA	KEYTIMER
GOM22:	LDA	KEYTIMER		loop until 100 ticks have passed
	BNE	GOM22
GOM4:	
; CLRA
;STA	MUSIC_ON
	JSR	DISPLAY_ENDGAME_SCREEN	Display game end summary screen fixed text (RLE encoded) & stats of players game
	BSR	DISPLAY_WIN_LOSE	Display whether player won or lost game
GOM5:	
	LDA	CURRENT_KEY		Keep on screen until keypress received
	BEQ	GOM5	
GOM6:
	CLR	CURRENT_KEY		Key press found; clear key buffer (may need key_timer here if player holds key down too long)
;	JMP	INTRO_SCREEN		and restart game (change back to this once level loading working - LCB)
	JMP	RESTART_GAME		And restart game


; Write 11 char message to screen at location stored in $FD
; Entry: $FD = ptr to screen address to start printing at
;        X=Ptr to text to print
GOM3A:	STX	$FB			Save source ptr
	LDB	#11			11 bytes to write
DMN2:
	LDA	,X+			Get char
	CMPA	#$7F			Do we need to adjust down by $60?
	BLT	LESS3			No, use as is
	SUBA	#$7F			Yes, adjust character code first
LESS3:
	PSHS	B,X			Save counter & src ptr
	JSR	BITMAP_PLOTTER		Draw character (NOTE: Updates $FD to next char to right)
	PULS	B,X  			Get counter & src ptr back
	DECB				Done all 11 chars?
	BNE	DMN2			No, keep going until done
	RTS

; GAME OVER window with border
GAMEOVER1:	.BYTE	$70,$40,$40,$40,$40,$40,$40,$40,$40,$40,$6e	; top border
GAMEOVER2:	.BYTE	$5d,$07,$01,$0d,$05,$20,$0f,$16,$05,$12,$5d	; GAME OVER
GAMEOVER3:	.BYTE	$6d,$40,$40,$40,$40,$40,$40,$40,$40,$40,$7d	; bottom border

; Changing this to use NUL's to end strings, since they are already in the text messages anyways.
DISPLAY_WIN_LOSE:
;JSR	STOP_SONG
	LDX 	#SCREEN+(2*CHAR_ROWSIZE)+(16*CHAR_WIDTH)	$8A40
	STX	$FD			Save where on screen to print
	LDA	UNIT_TYPE		Get player status
	BEQ	DWL5			Dead, go print the lose message
;WIN MESSAGE
DWL1:
	LDX	#WIN_MSG		Save ptr to message to print for subroutine
;LDA	#18	;win music
;JSR	PLAY_SOUND
	BRA	DMN3

DWL5:	;LOSE MESSAGE
	LDX	#LOS_MSG		Save ptr to message to print for subroutine
;LDA	#19	;LOSE music
;JSR	PLAY_SOUND  
; If entered here (like from printing difficulty level), <$FD needs to bet the start address on the screen to print at
; X=PTR to source string to print (NUL terminated)
DMN3:
	LDA	,X+			Get char
	BEQ	DONE_DNM		NUL, we are done
	CMPA	#$60			Do we need to adjust down by $60?
	BLT	LESS4			No, use as is
	SUBA	#$60			Yes, adjust character code first
LESS4:
	PSHS	X			Save srs ptr & ctr
	JSR	BITMAP_PLOTTER		Draw character in A (NOTE: Updates $FD to next char to right)
	PULS	X  			Get src ptr & ctr back
	BRA	DMN3			Keep going until done	

DONE_DNM:
	RTS

WIN_MSG:	
	.STR	"you win!"
	.BYTE	0
LOS_MSG:	
	.STR	"you lose!"
	.BYTE 0


PRINT_INTRO_MESSAGE:
	LDY	#INTRO_MESSAGE		Point to intro screen (RLE encoded)

;This routine will print something to the "information" window
;at the bottom left of the screen.  You must first define the 
;source of the text in $FB. The text should terminate with
;a null character.
* Entry: Y=Ptr to text string to print
* Exit: String printed (including screen scrolling if necessary)
*       <$FD=screen address of next "text position" to write to.
*       D,X,Y,U registers all modified.
PRINT_INFO:
	BSR	ADD_LINE		Make room for new line
PI01:
	LDA	,Y+			Get char from source
	BNE	PI02			Still more, go print
	RTS				NUL, done so exit

PI02:	CMPA	#255			Special forced CRLF char?
	BEQ	PI03			Yes, force scroll
; Normal char to print
	CMPA 	#$60			No, do we need to adjust character?
	BLT 	LESS2 			No, skip ahead
	SUBA 	#$60			Yes, adjust char codes $60-$7F to $00-$1F
LESS2:
	PSHS	B,Y			Save # chars left & source ptr
	JSR	BITMAP_PLOTTER		Draw the character (note: uses/modifies <$FD, x,y,u,d & <INVERSE)
	PULS	B,Y			Get chars left & source ptr back
	DECB				Dec # chars left to print on current line
	BNE	PI01			Still more left, onto the next char (or fall through to forced scroll if line full)
PI03:	
	BSR	ADD_LINE		Scroll window up and set up for next line
	DEC	BYTECOUNT		Dec # chars left on line
	BNE	PI01			Still more, continue
	BRA	PRINT_INFO		Force new line and continue

; Scroll text window to insert line at bottom, reset ptrs & counter for new line
ADD_LINE:
	PSHS	Y			Save src ptr
	BSR	SCROLL_INFO		New text always causes a scroll - scrolls up the 4 lines in the text window 
	LDX	#SCREEN+(24*CHAR_ROWSIZE)	($F800) Point to the last "text" line on the screen (left side, 8 dot rows up from bottom)
	STX 	$FD			Save version for drawing subroutine
	LDB	#33			Max 33 chars/line for text window (original was 40, but that would go over health)
	PULS    Y,PC			Restore src ptr & return

;This routine scrolls the info screen by one row, clearing
;a new row at the bottom. (3 line text window on lines 23-25)
; changed so one scroll loop, 1 clear with mini-stackblasting
; NOTE: only the left 128 bytes are scrolled up and cleared
; Original used D,X,Y & preserved none of them. Does NOT affect $FD-$FE.
; New version uses D,X,Y,U & preserves none of them. No longer uses extra RAM variables either.
SCROLL_INFO:
	LDY	#$EE00			(Dest) Address of top left corner of text window (line 23) scanline 176
	LDU	#$F300  		(Src) Address of top left corner of text window (line 24) scanline 184
	LDD	#$1020  		A=# lines to copy, B=# of 4 byte blocks to copy (32 * 4 so 128 bytes)
	STD	<SCRATCH 		Save # of lines left & # 4 byte blocks left on current line
SCROLL1:
	PULU	D,X			Get 4 bytes
	STD	,Y++			Copy up one text row
	STX	,Y++
	DEC	<SCRATCH+1		Dec # of 4 byte blocks left to copy on current line
	BNE	SCROLL1
	DEC	<SCRATCH		Dec # lines left
	BEQ	CLEAR3			Done, go clear 25th text line
	LDA	#$20			Reset 4 bytes/block counter
	STA	<SCRATCH+1
	LEAU	32,U			Bump src/dest ptrs to start of next line
	LEAY	32,Y
	BRA	SCROLL1

CLEARALL:	LDA	#24		# of lines to clear
	FCB	$8C			Skip 2 bytes (CMPX # opcode)
CLEAR3:
	LDA	#8			# of lines to clear
	LDX	#0			4 empty pixels
	LEAY	,X			Ditto for Y
	LDU	#$FD00-32		Point to end of text area on last scanline (199)
CLEAR4:
	LDB	#32			# of 4 byte blocks to clear per line
CLEAR5:
	PSHU	X,Y			Clear 4 bytes
	DECB				Drop 4 byte counter
	BNE	CLEAR5			Do until current line done
	DECA				Drop line counter
	BEQ	END2			Done, exit
	LEAU	-32,U			Bump up to end of previous scanline
	BRA	CLEAR4			Go clear that line
  
; Update upper left and lower right coords of viewable map window based on new player position
CALCULATE_AND_REDRAW:
	LDA	UNIT_LOC_X		Get player X location (no index needed since it's player unit)
	LDB	UNIT_LOC_Y		Get player Y location (no index needed since it's player unit)
	SUBD	#5*256+3		Map starts 5 left, 3 above player X,Y location
	STD	MAP_WINDOW_X		Save viewable map upper left corner start position
	ADDD	#10*256+6		Calc lower right coords
	STD	MAP_WINDOW_XMAX		Save for faster access in various routines
	LDA	#1			Flag that map window needs redrawn & return
	STA	REDRAW_WINDOW
END2:	RTS			

;This routine checks all units from 0 to 31 and figures out if it should be displayed
;on screen, and then grabs that unit's tile and stores it in the MAP_PRECALC array
;so that when the window is drawn, it does not have to search for units during the
;draw, speeding up the display routine. This does the player, robots & active weapons
;1st, clear old buffer
MAP_PRE_CALCULATE:
	CLRA     			Init A,X,Y to 0's
	LDX	#0
	LEAY	,X
	LDU	#MAP_PRECALC+75		Point to end of table-2
	STX	,U			Init last 2 bytes to 0
	LDB	#15			(# of 5 byte chunks to clear)
PREC0:
	PSHU	A,X,Y			Clear 5 bytes
	DECB				Do 15 times (75 bytes)
	BNE	PREC0
; U should be pointing to start of MAP_PRECALC NOW
	BRA	PREC2			skip the player (always exists)

;check that unit exists (note: we skip player unit 0; that always exists)
PREC1:
	LDA	UNIT_TYPE,X		Get robot type
	BEQ	PREC5			Dead, skip to next
;CHECK HORIZONTAL POSITION
	LDA	UNIT_LOC_X,X		Get unit's X location
	CMPA	MAP_WINDOW_X		Unit past left edge of viewable window?
	BLO	PREC5			Yes, skip to next
	CMPA	MAP_WINDOW_XMAX		Unit past right edge of viewable window?
	BHI	PREC5			Yes, skip to next
;NOW CHECK VERTICAL
	LDA	UNIT_LOC_Y,X		Get unit's Y location
	CMPA	MAP_WINDOW_Y		Unit above top edge of viewable window?
	BLO	PREC5			Yes, skip to next
	CMPA	MAP_WINDOW_YMAX		Unit past lower edge of viewable window?
	BHI	PREC5			Yes, skip to next
;Unit found in map window, now add that unit's tile to the precalc map.
PREC2:    
	LDA	#11			Width of a viewable map row
	LDB	UNIT_LOC_Y,X		Get unit's Y location
	SUBB	MAP_WINDOW_Y		Subtract start Y of viewable map
	MUL				Calculate row offset in our pre-calc buffer
	ADDB	UNIT_LOC_X,X		Get unit's X location
	SUBB	MAP_WINDOW_X		Subtract start X of viewable map to get X offset into pre-calc buffer
	LDA	UNIT_TILE,X		Get tile sub-type of robot
	CMPA	#130			is it a bomb?
 	BEQ	PREC6			Yes, special handling
	CMPA	#134			Is it a magnet?
	BEQ	PREC6			Yes, special handling
PREC4:	
	STA	B,U			Anything else, save sub-type tile # in pre-calc map
;continue search
PREC5:
	LEAX	1,X			Point to next robot/bullet unit
	CMPX	#32			Done through all of them?
	BNE	PREC1			No, keep going until done
	RTS				Yes, done all units, return

;What to do in case of bomb or magnet that should go underneath the unit or robot.
PREC6:	
	TST	B,U			Get the existing tile from the pre-calc map
	BNE	PREC5			Something already there, leave it alone and go on to next unit
	BRA	PREC4			Save sub-tile type in pre-calc map instead of "raw" tile #

;This chart contains the left-most starting position for each
;row of tiles on the map-editor. 7 Rows.
;*** NOTE: SINCE THESE ALWAYS START AT $XX00, WE COULD MAKE THESE 8 BIT AND ADD TO THE HIGH BYTE OF
;*** THE SCREEN ADDRESS. DEPENDS ON WHAT REGISTERS ARE BEING USED, THOUGH. Also expanded chart to
;*** make Coco 1/2 version easier in the future.
MAP_CHART:
	.WORD				SCREEN+(0*CHAR_ROWSIZE) $8000
	.WORD				SCREEN+(3*CHAR_ROWSIZE) $8F00
	.WORD				SCREEN+(6*CHAR_ROWSIZE) $9E00
	.WORD				SCREEN+(9*CHAR_ROWSIZE) $AD00
	.WORD				SCREEN+(12*CHAR_ROWSIZE) $BC00
	.WORD				SCREEN+(15*CHAR_ROWSIZE) $CB00
	.WORD				SCREEN+(18*CHAR_ROWSIZE) $DA00

;This routine is where the MAP is displayed on the screen
;This is a temporary routine, taken from the map editor.
; MAP is 128x64 tiles. Each tile is 24 pixels x 24 pixels (each tile is 3x3 graphic characters, each
;   of which is 8x8 pixels)
; LCB - CHANGED THIS TO RUN FROM BOTTOM RIGHT TO TOP LEFT INSTEAD OF TOP LEFT TO BOTTOM RIGHT. CAN THEN 
; DEC TEMP_X / TEMP_Y / PRECALC_COUNT AND NOT NEED CMPA #1 / CMPA #7 IN LOOPS

; LCB NOTE: MAY ALSO WANT TO SET UP TO GET PRECALC TILE # BEFORE DRAWING. THAT WAY IT CAN GET EACH OF THE 9
; CHARS FOR A FLOOR TILE, AND IF THAT PARTICULAR CHARACTER IS A ':', THEN IMMEDIATELY GET THE CORRESPONDING
; SPRITE TILE CHAR AT THE SAME 3X3 POSITION AND DRAW IT INSTEAD (rather than the current draw it twice, once
; from the floor tile then again from the sprite tile)
; Also this routine should copy each end result tile to a second 77 byte table (dirty tile table). It will
; use that to check each tile to see if it has changed from the previous screen redraw. If not, skip drawing
; the 3x3 char tile entirely.

DRAW_MAP_WINDOW:
	BSR	MAP_PRE_CALCULATE	Pre-calc 11x7 grid of object data that will appear on current MAP_WINDOW
	CLR	REDRAW_WINDOW
	LDD	#10*256+6		Init start tile # on window to 10,6 (lower right corner)
	STD	TEMP_X			Save counters
	LDA	#76			And MAP_PRECALC buffer position
	STA	PRECALC_COUNT
; FIRST CALCULATE WHERE THE BYTE IS STORED IN THE MAP. Save X position (0-10) in TEMPX &
;   Y position (0-6) in TEMPY
; Entry:
;   MAP_WINDOW_X IS THE X tile position (0-127) from the full map that our viewable window starts at
;   MAP_WINDOW_Y IS THE Y tile position (0-63) from the full map that our viewable window starts at
; Using same hack to speed up offset calc we used elsewhere yesterday
; Tweaked version to use "quick & dirty multiply by 128". 1 byte shorter, 9 cycles faster if it works.

;;;;;;;;;; TEMPORARY TEST ;;;;;;;;;;;;
; Shut off IRQ's so timers don't count down during the multiple VSYNC's it takes to currently draw a screen
	ORCC	#$50
;;;;;;;;;; TEMPORARY TEST ;;;;;;;;;;;;


DM01:
	CLRB				Point to start of full map (128x64)
	LDA	TEMP_Y			Get Y tile row on window that we are drawing (0-6)
	ADDA	MAP_WINDOW_Y		Add to Y tile row that viewable window starts at (0-63)
	LSRA				Quick & Dirty * 128
	RORB
	ADDD	#MAP			Add base ptr to map to point to specific tile
	TFR	D,X			Move to index register
	LDB	TEMP_X			Get X tile column on screen that we are drawing (0-10)
	ADDB	MAP_WINDOW_X		Add to X tile column that viewable window starts at (0-63)
	LDA	B,X			Get tile from map
	STA	TILE			save for drawing routine
;NOW FIGURE OUT WHERE TO PLACE IT ON SCREEN.
	LDD	TEMP_X			A=X position, B=Y position (within viewable window for both)
	LSLB				*2 bytes / entry
	LDX	#MAP_CHART		Point to chart of start addresses for each row of tiles
	LDX	B,X			Get start address for row
	LDB	#12			each tile is 12 bytes wide
	MUL				Calculate X byte offset to draw at
	ABX				Add to address
	STX	$FD    			Save for sub
	BSR	PLOT_TILE		Draw the tile
;now check for sprites in this location
	LDX	#MAP_PRECALC		Point to Precalc table
	LDB	PRECALC_COUNT		Get current position in PRECALC buffer
	LDA	B,X			Get sprite tile # from PRECALC buffer
	BEQ	DM02			None, skip to next	
	STA	TILE			Save sprite tile # to draw
;NOW FIGURE OUT WHERE TO PLACE IT ON SCREEN.
	LDD	TEMP_X			A=X position, B=Y position (within viewable window for both)
	LSLB				*2 bytes / entry
	LDX	#MAP_CHART		Point to chart of start addresses for each row of tiles
	LDX	B,X			Get start address for row
	LDB	#12			each tile is 12 bytes wide
	MUL				Calculate X byte offset to draw at
	ABX				Add to address
	STX	$FD    			Save for sub
	BSR	PLOT_TRANSPARENT_TILE	Draw transparent tile overtop original floor tile on screen
DM02:	
	DEC	PRECALC_COUNT		Move 1 position earlier in sprite active on viewable window table
	DEC	TEMP_X			Drop X position on window by one
	BPL	DM01			More on current row, go do
	LDA	#10			Reset display window X position to end of row
	STA	TEMP_X
	DEC	TEMP_Y			Dec display Y position
	BPL	DM01			More rows, keep drawing


;;;;;;;;;; TEMPORARY TEST ;;;;;;;;;;;;
; Shut off IRQ's so timers don't count down during the multiple VSYNC's it takes to currently draw a screen
	ANDCC	#$AF			Turn IRQ's back on
;;;;;;;;;; TEMPORARY TEST ;;;;;;;;;;;;


;CHECK FOR CURSOR (to invert it)
	LDA	CURSOR_ON		Done main draw, is cursor turned on?
	BEQ	DM04			No, skip cursor
	JMP	REVERSE_TILE		Yes, Invert the tile (24x24 pixels) at CURSOR_X,CURSOR_Y & return from there

DM04:	
	RTS				Yes, done view window, return


;This routine plots a 3x3 tile from the tile database anywhere
;on screen.  But first you must define the tile number in the
;TILE variable, as well as the starting screen address must
;be defined in $FD.
PLOT_TILE:
	LDX	TILEPRE			Get 16 bit tile #
;DRAW THE TOP 3 CHARACTERS
	LDA	TILE_DATA_TL,X		Top left sub-tile
	JSR	BITMAP_PLOTTER		Draw tile @ [$FD], then move [$FD] to next text cel to right
	LDX	TILEPRE			Get tile # back
	LDA	TILE_DATA_TM,X		Top middle sub-tile
	JSR	BITMAP_PLOTTER		Draw tile @ [$FD], then move [$FD] to next text cel to right
	LDX	TILEPRE			Get tile # back
	LDA	TILE_DATA_TR,X		Top right sub-tile
	JSR	BITMAP_PLOTTER		Draw tile @ [$FD], then move [$FD] to next text cel to right
	LDX	TILEPRE			Get tile # back
;DRAW THE MIDDLE 3 CHARACTERS
	LDD 	$FD			Get screen draw ptr
	ADDD	#(CHAR_ROWSIZE)-(CHAR_WIDTH*3)	Move down 1 text line and left 3 characters
	STD	$FD			Save new screen draw ptr
	LDA	TILE_DATA_ML,X		Middle Left sub-tile
	JSR	BITMAP_PLOTTER		Draw tile @ [$FD], then move [$FD] to next text cel to right
	LDX	TILEPRE			Get tile # back
	LDA	TILE_DATA_MM,X		Middle middle sub-tile
	JSR	BITMAP_PLOTTER		Draw tile @ [$FD], then move [$FD] to next text cel to right
	LDX	TILEPRE			Get tile # back
	LDA	TILE_DATA_MR,X  	Middle right sub-tile
	JSR	BITMAP_PLOTTER		Draw tile @ [$FD], then move [$FD] to next text cel to right
	LDX	TILEPRE			Get tile # back
;DRAW THE BOTTOM 3 CHARACTERS
	LDD 	$FD			Get screen draw ptr
	ADDD	#(CHAR_ROWSIZE)-(CHAR_WIDTH*3)	Move down 1 text line and left 3 characters
	STD	$FD			Save new screen draw ptr
	LDA	TILE_DATA_BL,X  	Bottom left sub-tile
	JSR	BITMAP_PLOTTER  	Draw tile @ [$FD], then move [$FD] to next text cel to right
	LDX	TILEPRE			Get tile # back
	LDA	TILE_DATA_BM,X  	Bottom middle sub-tile
	JSR	BITMAP_PLOTTER  	Draw tile @ [$FD], then move [$FD] to next text cel to right
	LDX	TILEPRE			Get tile # back
	LDA	TILE_DATA_BR,X  	Bottom right sub-tile
	JMP	BITMAP_PLOTTER		Draw tile @ [$FD], then move [$FD] to next text cel to right, and return from there

;This routine plots a transparent tile from the tile database
;anywhere on screen.  But first you must define the tile number
;in the TILE variable, as well as the starting screen address must
;be defined in $FD.  Also, this routine is slower than the usual
;tile routine, so is only used for sprites.  The ":" character ($3A)
;is not drawn. I have optimized this for size, and a little for speed (LCB)
; This routine I think should be changed (see my notes in DRAW_MAP_WINDOW) to
; intelligently check both the floor tile and the sprite tile character by
; character and only draw one or the other (rather than draw both fully overtop
; of each other)
PLOT_TRANSPARENT_TILE:
	LDX	TILEPRE			Get 16 bit tile #
;DRAW THE TOP 3 CHARACTERS
	LDA	TILE_DATA_TL,X		Top left sub-tile
	CMPA	#$3A			':' char?
	BNE	PTT1A			No, draw character
	JSR	PTMOVE_RIGHT		Yes, just move ptr to right
	BRA	PTT01			Next subtile

PTT1A:
	JSR	BITMAP_PLOTTER		Draw tile @ [$FD] & move [$FD] to right 1 char
	LDX	TILEPRE			Get tile # back
PTT01:
	LDA	TILE_DATA_TM,X		Top middle sub-tile
	CMPA	#$3A			':' char?
	BNE	PTT2A			No, draw character
	JSR	PTMOVE_RIGHT		Yes, just move ptr to right
	BRA	PTT02			Next subtile

PTT2A:
	JSR	BITMAP_PLOTTER		Draw tile @ [$FD] & move [$FD] to right 1 char
	LDX	TILEPRE			Get tile # back
PTT02:
	LDA	TILE_DATA_TR,X		Top right sub-tile
	CMPA	#$3A			':' char?
	BNE	PTT3A			No, draw character
	BSR	PTMOVE_RIGHT		Yes, just move ptr to right
	BRA	PTT03			Next subtile

PTT3A:
	JSR	BITMAP_PLOTTER  Draw tile @ [$FD] & move [$FD] to right 1 char
	LDX	TILEPRE			Get tile # back
; DRAW MIDDLE 3 CHARACTERS
PTT03:
	LDD	$FD			First, get screen draw ptr
	ADDD	#(160*8)-(4*3)		Move down 1 text line and left 3 characters
	STD	$FD			Save new screen draw ptr
	LDA	TILE_DATA_ML,X		Middle left sub-tile
	CMPA	#$3A			':' char?
	BNE	PTT4A			No, draw character
	BSR	PTMOVE_RIGHT		Yes, just move ptr to right
	BRA	PTT04			Next subtile

PTT4A:
	JSR	BITMAP_PLOTTER  	Draw tile @ [$FD] & move [$FD] to right 1 char
	LDX	TILEPRE			Get tile # back
PTT04:	
	LDA	TILE_DATA_MM,X		Middle middle sub-tile
	CMPA	#$3A			':' char?
	BNE	PTT5A			No, draw character
	BSR	PTMOVE_RIGHT		Yes, just move ptr to right
	BRA	PTT05			Next subtile

PTT5A:
	JSR	BITMAP_PLOTTER  	Draw tile @ [$FD] & move [$FD] to right 1 char
	LDX	TILEPRE			Get tile # back
PTT05:
	LDA	TILE_DATA_MR,X		Middle right sub-tile
	CMPA	#$3A			':' char?
	BNE	PTT6A			No, draw character
	BSR	PTMOVE_RIGHT		Yes, just move ptr to right
	BRA	PTT06			Next subtile

PTT6A:
	JSR	BITMAP_PLOTTER  	Draw tile @ [$FD] & move [$FD] to right 1 char
	LDX	TILEPRE			Get tile # back
; DRAW BOTTOM 3 CHARACTERS
PTT06:
	LDD	$FD			First, get screen draw ptr
	ADDD	#(160*8)-(4*3)		Move down 1 text line and left 3 characters
	STD	$FD			Save new screen draw ptr
	LDA	TILE_DATA_BL,X		Bottom left sub-tile
	CMPA	#$3A			':' char?
	BNE	PTT7A			No, draw character
	BSR	PTMOVE_RIGHT		Yes, just move ptr to right
	BRA	PTT07			Next subtile

PTT7A:
	JSR	BITMAP_PLOTTER  	Draw tile @ [$FD] & move [$FD] to right 1 char
	LDX	TILEPRE			Get tile # back
PTT07:
	LDA	TILE_DATA_BM,X		Bottom middle sub-tile
	CMPA	#$3A			':' char?
	BNE	PTT8A			No, draw character
	BSR	PTMOVE_RIGHT		Yes, just move ptr to right
	BRA	PTT08			Next subtile

PTT8A:
	JSR	BITMAP_PLOTTER  	Draw tile @ [$FD] & move [$FD] to right 1 char
	LDX	TILEPRE			Get tile # back
PTT08:
	LDA	TILE_DATA_BR,X		Bottom right sub-tile
	CMPA	#$3A			':' char?
	BNE	PTT9A			No, draw character
	BRA	PTMOVE_RIGHT		Yes, just move ptr to right
	
PTT9A:
	JMP	BITMAP_PLOTTER  	Draw tile @ [$FD] & move [$FD] to right 1 char

; Subroutine to move screen pointer right 1 character (8 pixels)
PTMOVE_RIGHT:
	LDD	$FD			Move screen ptr to right 1 char
	ADDD	#4
	STD	$FD
	RTS

; Entry: CURSOR_X = X position on screen (in tile size, so 12 byte chunks)
; CURSOR_Y = U position (in tile size, so 24 line chunks)
; Uses: D,U,X
; Exit: $FD-$FE screen address of last byte of tile
; Inverts map tile (3x3 sub-tiles, so 12 x 24 bytes (24 x 24 pixels) get inverted
REVERSE_TILE:
; First calc where to start inversing on screen
	LDD	CURSOR_X		A=X Position, B=Y position
	LSLB				* 2 bytes/entry for Y start address table
	LDU	#MAP_CHART		Point to start line of Y tile chart
	LDU	B,U			Get ptr to start line
	LDB	#12			12 bytes/X position (24 pixels)
	MUL				Calc X offset
	LEAU	B,U			Add to screen address
	LDX	#24			24 lines to invert
RT01:
	LDD	,U			Invert pixels 1-4
	COMA
	COMB
	STD	,U
	LDD	2,U			Invert pixels 5-8
	COMA
	COMB
	STD	2,U
	LDD	4,U			Invert pixels 9-12
	COMA
	COMB
	STD	4,U
	LDD	6,U			Invert pixels 13-16
	COMA
	COMB
	STD	6,U
	LDD	8,U			Invert pixels 17-20
	COMA
	COMB
	STD	8,U
	LDD	10,U			Invert pixels 21-24
	COMA
	COMB
	STD	10,U
	LEAU	160,U			Point U to start of next line
	LEAX	-1,X			Drop # of lines left to invert
	BNE	RT01			Still more, keep going
	RTS

;This routine checks to see if a UNIT is occupying any space
;that is currently visible in the window.  If so, the
;flag for redrawing the window will be set.
; LCB NOTE: However, it doesn't know if a UNIT has just moved off the screen
; (a robot) - so once it does it leaves the previous robot tile still on the
; the edge of he screen (until it comes back, the player moves, or something
; else like a shot forces a screen update).
CHECK_FOR_WINDOW_REDRAW:
	LDX	UNITPRE			Get Unit # into X
;FIRST CHECK HORIZONTAL
	LDA	UNIT_LOC_X,X		Get Unit's X location
	CMPA	MAP_WINDOW_X		Left of viewable area?
	BLO	CFR1			Yes, return
	CMPA	MAP_WINDOW_XMAX		Right of viewable area?
	BHI	CFR1			Yes, return
;NOW CHECK VERTICAL
	LDA	UNIT_LOC_Y,X		Get Unit's Y location
	CMPA	MAP_WINDOW_Y		Above viewable area?
	BLO	CFR1			Yes, return
	CMPA	MAP_WINDOW_YMAX		Below viewable area?
	BHI	CFR1			Yes, return
	LDA	#1			Unit is within viewable window, flag screen redraw
	STA	REDRAW_WINDOW
CFR1:
	RTS

;This routine animates the tile #204 (water) 
;and also tile 148 (trash compactor), and Cinema, and HVAC, and server lights
; LCB NOTE: change to load WATER_TIMER with 20, then DEC it instead (saves a CMPA each time) 
ANIMATE_WATER:
	LDA	#1
;	LDA	ANIMATE			Flag to animate turned on? (we currently wipe DP so setting getting cleared)
	BNE	AW00			Yes, go do extra animations
	RTS

AW00:	
;	INC	WATER_TIMER
	DEC	WATER_TIMER		Dec timer until next set of animations
;	LDA	WATER_TIMER
;	CMPA	#20
	BEQ	AW01
	RTS

; These animations are done by redefining the characters that make up the the tiles themselves, not the tile #'s in the map.
; Thus, a redraw automatically updates the tile. HOWEVER - since it redefines the tile - not swapping tiles - dirty tiles will
; not animate properly, as it will think the tile is unchanged. Options: 1) Palette animation, 2) swap the tile
; #'s themselves, not the characters defining the tiles. 3) Force the viewable map drawing routine to treat each of these
; tiles special - and physically draw them ALL the time if they are on screen. 4) Change dirty tiles to keep track of each
; char on the map part of the screen (so 33x21 chars or 693 bytes), and have it call BITMAP_PLOTTER only when the char itself
; has changed. This might speed up general drawing, actually, but takes way more RAM than a "previous frames tiles" which would
; only be 77 bytes.
AW01:	
	LDA	#20			Reset animation timer to 20 ticks (1/3 second)
;	LDA	#0
	STA	WATER_TIMER
	LDA	TILE_DATA_BR+204	Get current animation character for tile #204, bottom right
	STA	WATER_TEMP1		Save temp copy
	LDA	TILE_DATA_MM+204	Get current animation character for tile #204, middle middle
	STA	TILE_DATA_BR+204	Save it onto bottom right of tile #204
	STA	TILE_DATA_BR+221
	LDA	TILE_DATA_TL+204
	STA	TILE_DATA_MM+204
	LDA	WATER_TEMP1
	STA	TILE_DATA_TL+204

	LDA	TILE_DATA_BL+204
	STA	WATER_TEMP1
	LDA	TILE_DATA_MR+204
	STA	TILE_DATA_BL+204
	STA	TILE_DATA_BL+221
	LDA	TILE_DATA_TM+204
	STA	TILE_DATA_MR+204
	LDA	WATER_TEMP1
	STA	TILE_DATA_TM+204
	STA	TILE_DATA_TM+221

	LDA	TILE_DATA_BM+204
	STA	WATER_TEMP1
	LDA	TILE_DATA_ML+204
	STA	TILE_DATA_BM+204
	STA	TILE_DATA_BM+221
	LDA	TILE_DATA_TR+204
	STA	TILE_DATA_ML+204
	LDA	WATER_TEMP1
	STA	TILE_DATA_TR+204
	STA	TILE_DATA_TR+221

;now do trash compactor
	LDA	TILE_DATA_TR+148
	STA	WATER_TEMP1
	LDA	TILE_DATA_TM+148
	STA	TILE_DATA_TR+148
	LDA	TILE_DATA_TL+148
	STA	TILE_DATA_TM+148
	LDA	WATER_TEMP1
	STA	TILE_DATA_TL+148

	LDA	TILE_DATA_MR+148
	STA	WATER_TEMP1
	LDA	TILE_DATA_MM+148
	STA	TILE_DATA_MR+148
	LDA	TILE_DATA_ML+148
	STA	TILE_DATA_MM+148
	LDA	WATER_TEMP1
	STA	TILE_DATA_ML+148

	LDA	TILE_DATA_BR+148
	STA	WATER_TEMP1
	LDA	TILE_DATA_BM+148
	STA	TILE_DATA_BR+148
	LDA	TILE_DATA_BL+148
	STA	TILE_DATA_BM+148
	LDA	WATER_TEMP1
	STA	TILE_DATA_BL+148
;Now do HVAC fan
	LDA	HVAC_STATE
;	CMPA	#0
	BEQ	HVAC1
	LDA	#$CD
	STA	TILE_DATA_MM+196
	STA	TILE_DATA_TL+201
	LDA	#$CE
	STA	TILE_DATA_ML+197
	STA	TILE_DATA_TM+200
	LDA	#$A0
	STA	TILE_DATA_MR+196	
	STA	TILE_DATA_BM+196	
	STA	TILE_DATA_BL+197
	STA	TILE_DATA_TR+200
;	LDA	#0
;	STA	HVAC_STATE
	CLR	HVAC_STATE
	BRA	HVAC2

HVAC1:
	LDA	#$A0
	STA	TILE_DATA_MM+196
	STA	TILE_DATA_TL+201
	STA	TILE_DATA_ML+197
	STA	TILE_DATA_TM+200
	LDA	#$C2
	STA	TILE_DATA_MR+196
	STA	TILE_DATA_TR+200
	LDA	#$C0
	STA	TILE_DATA_BM+196	
	STA	TILE_DATA_BL+197
	LDA	#1
	STA	HVAC_STATE
HVAC2:	;now do cinema screen tiles
;FIRST COPY OLD LETTERS TO THE LEFT. This part is working
	LDA	TILE_DATA_MR+20	;#2
	STA	TILE_DATA_MM+20	;#1
	LDA	TILE_DATA_ML+21	;#3
	STA	TILE_DATA_MR+20	;#2
	LDA	TILE_DATA_MM+21	;#4
	STA	TILE_DATA_ML+21	;#3
	LDA	TILE_DATA_MR+21	;#5
	STA	TILE_DATA_MM+21	;#4
	LDA	TILE_DATA_ML+22	;#6
	STA	TILE_DATA_MR+21	;#5
;now insert new character.
	LDX	CINEMA_STATE			Get current offset into cinema messages
	LDA	CINEMA_MESSAGE,X		Get current char
	CMPA	#$60				Need to adjust?
	BLT	NO_ADJ_CIN			No, print as is
	SUBA	#$60				Yes, adjust for ASCII vs. PETSCII font
NO_ADJ_CIN:
	STA	TILE_DATA_ML+22			Save as character 6 on cinema screen
	INC	CINEMA_STATE+1			Bump to next char
	LDA	CINEMA_STATE+1			Get new offset
	CMPA	#223				Hit end?
	BLO	CINE2				No, go do server computer lights
	CLR	CINEMA_STATE+1			Yes, reset offset to 0
;Now animate light on server computers
CINE2:
	LDA	TILE_DATA_MR+143
	CMPA	#$D7
	BNE	CINE3
	LDA	#$D1
	BRA	CINE4

CINE3:	
	LDA	#$D7
CINE4:	
	STA	TILE_DATA_MR+143
	LDA	#1				Flag that we need window redrawn (maybe add 3rd option to redraw animation tiles? Once dirty tile routines are in?)
	STA	REDRAW_WINDOW
	RTS

; LCB - probably move these to DP as well (shorter/faster)


 INCLUDE utils.asm
 INCLUDE graphics.asm
 INCLUDE BACKGROUND_TASKS_6809.ASM


INTRO_TEXT:
	.BYTE	$60,$20,$02,$4e,$60,$63,$0a,$4e,$65,$60,$20,$05,$e9,$ce,$20,$20,$e9,$ce,$60,$20
	.BYTE	$0d,$cd,$60,$a0,$09,$ce,$20,$65,$60,$20,$05,$66,$a0,$20,$20,$66,$a0,$60,$20,$0d
	.BYTE	$a0,$13,$14,$01,$12,$14,$20,$07,$01,$0d,$05,$a0,$20,$65,$60,$20,$04,$e9,$66,$ce
	.BYTE	$a0,$a0,$66,$ce,$ce,$60,$20,$0c,$a0,$13,$05,$0c,$05,$03,$14,$20,$0d,$01,$10,$a0
	.BYTE	$20,$65,$60,$20,$03,$e9,$a0,$e3,$60,$a0,$02,$e3,$60,$ce,$02,$60,$20,$0b,$a0,$04
	.BYTE	$09,$06,$06,$09,$03,$15,$0c,$14,$19,$a0,$20,$65,$60,$20,$02,$e9,$60,$66,$06,$ce
	.BYTE	$ce,$a0,$60,$20,$0b,$a0,$03,$0f,$0e,$14,$12,$0f,$0c,$13,$20,$20,$a0,$20,$65,$60
	.BYTE	$20,$02,$66,$3a,$4d,$60,$3a,$02,$4e,$3a,$66,$a0,$a0,$60,$20,$02,$e9,$ce,$20,$20
	.BYTE	$e9,$ce,$60,$20,$02,$ce,$60,$a0,$09,$cd,$4e,$60,$20,$03,$66,$55,$43,$4d,$3a,$4e
	.BYTE	$43,$49,$66,$a0,$a0,$60,$20,$02,$66,$a0,$20,$20,$66,$a0,$60,$20,$13,$66,$42,$51
	.BYTE	$48,$3a,$42,$51,$48,$66,$a0,$69,$60,$20,$02,$66,$a0,$20,$20,$66,$a0,$60,$20,$02
	.BYTE	$70,$60,$40,$02,$73,$0d,$01,$10,$6b,$60,$40,$02,$6e,$60,$20,$03,$66,$4a,$46,$4b
	.BYTE	$3a,$4a,$46,$4b,$66,$ce,$60,$20,$03,$66,$ce,$a0,$a0,$66,$a0,$20,$20,$0b,$09,$0c
	.BYTE	$0c,$20,$01,$0c,$0c,$20,$08,$15,$0d,$01,$0e,$13,$60,$20,$03,$60,$66,$06,$a0,$a0
	.BYTE	$60,$20,$03,$60,$66,$04,$69,$60,$20,$14,$66,$60,$d0,$04,$66,$a0,$a0,$60,$20,$05
	.BYTE	$66,$a0,$20,$20,$60,$43,$14,$66,$60,$d0,$04,$66,$a0,$69,$60,$43,$05,$66,$a0,$43
	.BYTE	$43,$60,$3a,$14,$60,$66,$06,$ce,$a0,$a0,$ce,$60,$3a,$03,$66,$a0,$60,$3a,$16,$e9
	.BYTE	$a0,$a0,$e7,$d0,$ce,$60,$a0,$02,$ce,$a0,$60,$3a,$03,$66,$a0,$60,$3a,$15,$e9,$60
	.BYTE	$a0,$03,$e3,$60,$a0,$02,$ce,$a0,$a0,$60,$3a,$03,$66,$a0,$60,$3a,$0b,$e9,$ce,$df
	.BYTE	$60,$3a,$06,$60,$66,$08,$d5,$c0,$c9,$60,$3a,$03,$66,$ce,$df,$60,$3a,$09,$e9,$e3
	.BYTE	$cd,$ce,$60,$a0,$06,$66,$51,$60,$66,$04,$51,$66,$dd,$ce,$e3,$60,$a0,$02,$ce,$a0
	.BYTE	$cd,$ce,$60,$3a,$09,$a0,$d1,$e7,$60,$66,$10,$dd,$60,$66,$04,$a0,$d1,$e7,$69,$60
	.BYTE	$3a,$09,$5f,$a0,$ce,$60,$3a,$07,$60,$66,$08,$ca,$c0,$cb,$60,$3a,$02,$5f,$e4,$69
	.BYTE	$60,$3a,$0b,$66,$a0,$3a,$e9,$a0,$a0,$ce,$3a,$e9,$a0,$a0,$ce,$e9,$a0,$a0,$ce,$66
	.BYTE	$e9,$a0,$a0,$ce,$e9,$a0,$a0,$ce,$e9,$a0,$a0,$ce,$60,$3a,$0a,$66,$a0,$3a,$60,$66
	.BYTE	$02,$ce,$ce,$60,$66,$02,$a0,$60,$66,$02,$ce,$ce,$60,$66,$02,$a0,$60,$66,$02,$69
	.BYTE	$60,$66,$02,$69,$60,$3a,$0a,$66,$a0,$3a,$66,$ce,$a0,$66,$ce,$66,$a0,$66,$a0,$66
	.BYTE	$ce,$a0,$66,$ce,$66,$a0,$66,$a0,$3a,$66,$a0,$3a,$66,$ce,$a0,$ce,$60,$3a,$0a,$66
	.BYTE	$a0,$3a,$60,$66,$02,$ce,$ce,$66,$a0,$66,$a0,$60,$66,$02,$ce,$ce,$66,$a0,$66,$a0
	.BYTE	$3a,$66,$a0,$3a,$60,$66,$02,$a0,$60,$3a,$0a,$66,$a0,$3a,$66,$a0,$3a,$66,$a0,$66
	.BYTE	$ce,$66,$a0,$66,$ce,$a0,$66,$69,$66,$ce,$66,$a0,$3a,$66,$a0,$3a,$e9,$a0,$66,$a0
	.BYTE	$60,$3a,$0a,$66,$a0,$3a,$66,$69,$3a,$66,$69,$60,$66,$02,$69,$60,$66,$02,$69,$3a
	.BYTE	$60,$66,$02,$69,$3a,$66,$69,$3a,$60,$66,$02,$69,$3a

SCR_TEXT:
	.BYTE	$60,$20,$20,$5d,$17,$05,$01,$10,$0f,$0e,$60,$20,$20,$5d,$60,$20,$26,$5d,$60,$20
	.BYTE	$26,$5d,$60,$20,$26,$5d,$60,$20,$26,$5d,$60,$20,$26,$6b,$60,$40,$05,$60,$20,$20
	.BYTE	$5d,$20,$09,$14,$05,$0d,$60,$20,$21,$5d,$60,$20,$26,$5d,$60,$20,$26,$5d,$60,$20
	.BYTE	$26,$5d,$60,$20,$26,$5d,$60,$20,$26,$6b,$60,$40,$05,$60,$20,$20,$5d,$20,$0b,$05
	.BYTE	$19,$13,$60,$20,$21,$5d,$60,$20,$26,$5d,$60,$20,$26,$6b,$60,$40,$05,$60,$20,$20
	.BYTE	$5d,$60,$20,$26,$5d,$60,$20,$26,$5d,$60,$20,$05,$73,$09,$0e,$06,$0f,$12,$0d,$01
	.BYTE	$14,$09,$0f,$0e,$6b,$60,$40,$13,$5b,$60,$40,$05,$60,$20,$20,$5d,$08,$05,$01,$0c
	.BYTE	$14,$08,$60,$20,$20,$5d,$60,$20,$26,$5d,$60,$71,$05

SCR_ENDGAME:
	.BYTE	$55,$60,$40,$03,$73,$01,$14,$14,$01,$03,$0B,$20,$0F,$06,$20
	.BYTE	$14,$08,$05,$20,$10,$05,$14,$13,$03,$09,$09,$20,$12,$0F,$02
	.BYTE	$0F,$14,$13,$6B,$60,$40,$03,$49,$5D,$60,$20,$25,$5D,$5D,$60
	.BYTE	$20,$25,$5D,$5D,$60,$20,$25,$5D,$5D,$60,$20,$25,$5D,$5D,$60
	.BYTE	$20,$25,$5D,$5D,$60,$20,$25,$5D,$5D,$60,$20,$0A,$13,$03,$05
	.BYTE	$0E,$01,$12,$09,$0F,$3A,$60,$20,$11,$5D,$5D,$60,$20,$25,$5D
	.BYTE	$5D,$60,$20,$06,$05,$0C,$01,$10,$13,$05,$04,$20,$14,$09,$0D
	.BYTE	$05,$3A,$60,$20,$11,$5D,$5D,$60,$20,$25,$5D,$5D,$60,$20,$02
	.BYTE	$12,$0F,$02,$0F,$14,$13,$20,$12,$05,$0D,$01,$09,$0E,$09,$0E
	.BYTE	$07,$3A,$60,$20,$11,$5D,$5D,$60,$20,$25,$5D,$5D,$20,$20,$13
	.BYTE	$05,$03,$12,$05,$14,$13,$20,$12,$05,$0D,$01,$09,$0E,$09,$0E
	.BYTE	$07,$3A,$60,$20,$11,$5D,$5D,$60,$20,$25,$5D,$5D,$60,$20,$08
	.BYTE	$04,$09,$06,$06,$09,$03,$15,$0C,$14,$19,$3A,$60,$20,$11,$5D
	.BYTE	$5D,$60,$20,$25,$5D,$5D,$60,$20,$25,$5D,$5D,$60,$20,$25,$5D
	.BYTE	$5D,$60,$20,$25,$5D,$5D,$60,$20,$25,$5D,$5D,$60,$20,$25,$5D
	.BYTE	$5D,$60,$20,$25,$5D,$5D,$60,$20,$25,$5D,$4A,$60,$40,$25,$4B
  
  ;Medkit	(PET / C64)
MED1A	.BYTE	$20,$55,$43,$43,$49,$20
MED1B	.BYTE	$20,$A0,$A0,$A0,$A0,$20
MED1C	.BYTE	$20,$A0,$EB,$F3,$A0,$20
MED1D	.BYTE	$20,$E4,$E4,$E4,$E4,$20


 INCLUDE PETSCII_COCO.asm
zprog

  END START