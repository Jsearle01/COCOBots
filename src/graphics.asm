* init graphics

gfxinit
	pshs	u,x,d			Save regs

; INITIALIZATION REGISTER 0 $FF90
; 0  Coco 1/2 compatible: NO
; 0  MMU enabled: YES
; 0  GIME IRQ enabled: NO
; 0  GIME FIRQ enabled: NO
; 1  RAM at FExx is constant: YES		 ???
; 0  standard SCS (spare chip select): OFF
; 00 ROM map control: 16k internal, 16K external ???
 ldb #$08
 stb $FF90

; VIDEO MODE REGISTER $FF98
; 1  Graphic mode: YES
; 0  Unused
; 0  Composite color phase invert: NO
; 0  Monochrome on composite video out: NO
; 0  50Hz video: NO
; 00 Lines per row: one line per row		 ???
; VIDEO RESOLUTION REGISTER $FF99
; 0   Unused
; 11  LPF: 225
; 111 HRES: 160 bytes per row
; 01  CRES: 4 colors, 4 pixels per byte
 ldd #$80*256+$3E
 std $FF98

; VERTICAL OFFSET REGISTERS $FF9D - $FF9E set to $8000
 ldd #$F000
 std $FF9D	MSB = ($70000 + addr) / 2048, LSB = (addr / 8) AND $ff
 
; HORIZONTAL OFFSET REGISTER $FF9F
 stb $FF9F
	LDX	#$FFB0			Point to start of palette registers on GIME
	LDU	#PALETTERGB		Point to start of palette values for RGB
	LDB	#16			# of palettes to set
CpyPal:	LDA	,u+			Get value
	STA	,x+			Save to GIME
	DECB				Dec # of palettes left to set
	BNE	CpyPal			Keep going until all are done
; COLOR PALETTE REGISTERS $FFB0 - $FFBF
; stb $ffb0  ;B=0 already, BLACK
; ldd #$3f10 ; WHITE & GREEN ;1 AND 2
; std $ffb1
; LDA #09
; STA $FFB3 ; 3 BLUE
; LDA #07
; STA $FFB4 ; 4 DARK GRAY
; LDA #56 
; STA $FFB5 ; 5 LIGHT GRAY
; LDA #34
; STA $FFB6 ; 6 BROWN
; LDA #11
; STA $FFB7 ; 7 LIGHT BLUE
; LDA #48
; STA $FFB8 ; 8 TANISH
; LDA #38
; STA $FFB9 ; 9 ORANGE
; LDA #55
; STA $FFBA ; 10(A) YELLOW
; LDA #18
; STA $FFBB ; 11(B) LIGHT GREEN
; LDA #52
; STA $FFBC ; 12(C) LIGHT ORANGE
; LDA #32
; STA $FFBD ; 13 RED
; LDA #63
; STA $FFBF ; 15 WHITE  ALSO WILL AFFECT TILES COLOR IN GAME IF CHANGED. SOMETHING TO DO WITH THE INVERSION PROCESS???

	PULS	d,x,u,pc		Restore D & return (we don't really need to preserve D - LCB)

; RGB color palette table. We can make an alternate composite one later, and maybe make it a settable
; option on the main options screen. This code/table can go into the "initialization" block that doesn't
; need to stay mapped in during normal game play.
PALETTERGB:
	fcb	0			0 Black
	fcb	$3f			1 White
	fcb	$10			2 Green
	fcb	9			3 Blue
	fcb	7			4 Dark grey
	fcb	56			5 Light grey
	fcb	34			6 Brown
	fcb	11			7 Light blue
	fcb	48			8 Tanish
	fcb	38			9 Orange
	fcb	55			10 Yellow
	fcb	18			11 Light green
	fcb	52			12 Light orange
	fcb	32			13 Red
	fcb	0			14 NOT DEFINED (black for now)
	fcb	63			15 White ALSO WILL AFFECT TILES COLOR IN GAME IF CHANGED. SOMETHING TO DO WITH THE INVERSION PROCESS???
; Correct. The inversion process inverses all bits of a palette # (ex %0000 becomes %1111)

* clear screen
gfxclear
; 32 bytes, 112,155 cycles
    pshs    d,x,y,u    2 bytes / 13 cyc
    ldu    #SCREEN    3 bytes / 3 cyc    Get screen start address
    leau    160*200,u    4 bytes / 8 cyc    Point to end of screen for stack blasting
    lda    color    3 bytes / 5 cyc
    ldb    color    3 bytes / 5 cyc
    tfr    d,x    2 bytes / 6 cyc    Make X&Y 4 byte/8 pixels of color
    leay    ,x    2 bytes / 4 cyc
    ldd    #$1F40    3 bytes / 3 cyc    31 1K blocks to clear, 64 leftover 4 byte chunks not on 1K boundary
; Pre/post setup is 62 cycles
; Initial inner loop is 896 cycles (64 byte count), Outer loop runs 31 times (with inner 256 times for these, so each outer taking
;   3589 cycles *31 = 111,259 cycles
gfxClrLp    pshu    x,y    2 bytes / 9 cyc    Clear 4 bytes
    decb        1 byte / 2 cyc    Dec "leftover" (<256) 4 byte clock counter
    bne    gfxClrLp    2 bytes / 3 cyc    Keep going until that chunk is done
    deca        1 byte / 2 cyc    Dec 1KByte counter
    bne    gfxClrLp    2 bytes / 3 cyc    Still going (B has been set to 0, so inner loop is 256 now
    puls    d,x,y,u,pc    2 bytes / 15 cyc