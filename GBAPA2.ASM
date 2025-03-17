; =============================================================================
; GBAPA V1.1
; by Jeff Frohwein
;
; first edit: Nov 8th, 1995
; last edit: hell, who knows.
; optimized by Jens Christian Restemeier 21.1.96
; =============================================================================
; I optimized the point-procedure and reformated the source. Hope you like it.
; "Line" was not optimized, it's completely rewritten. Maybe it's not THAT
; fast, but error-free. I could optimize the dx=0,dy=0 and dx=dy cases.
; =============================================================================
; I included a makefile. Try "make -fgbapa2.mak" to compile it.
; =============================================================================

bs	.equ	8
cr	.equ	13

; A small idea: create a var and autodetect the adress !

lorambase	=	0c000h
hirambase	=	0ff80h

#DEFINE LOBYTEVAR(X)  X = lorambase \lorambase  .set (lorambase + 1)
#DEFINE HIBYTEVAR(X)  X = hirambase \hirambase  .set (hirambase + 1)
#DEFINE LOWORDVAR(X)  X = lorambase \lorambase  .set (lorambase + 2)
#DEFINE HIWORDVAR(X)  X = hirambase \hirambase  .set (hirambase + 2)

; Create variables in low-ram
LOBYTEVAR(x1)
LOBYTEVAR(y1)
LOBYTEVAR(x2)
LOBYTEVAR(y2)
LOBYTEVAR(xc)
LOBYTEVAR(yc)

LOBYTEVAR(color)

LOBYTEVAR(i1)
LOBYTEVAR(i2)
LOBYTEVAR(sx)
LOBYTEVAR(sy)
LOWORDVAR(d)

; =============================================================================
.org 0
bitmask:                ; For a simple bitmask-calculation
			; The label isn't neccessary. The table MUST be located
			; at org 0 !
.byte 080h,040h,020h,010h,008h,004h,002h,001h

; Set all irq vectors to do nothing.
.org 40h		; VBlank IRQ
 reti			; Do nothing
.org 46h                ; LCD IRQ
 reti			; Do nothing
.org 48h		; LCDC Status IRQ
 reti			; Do nothing
.org 50h		; Timer Owerflow IRQ
 reti			; Do nothing
.org 58h		; Serial Transfer Completion IRQ
 reti			; Do nothing
.org 60h		; Joypad action (?) IRQ
 reti			; Do nothing
; Irqs done..

; = Gameboy Header ============================================================

; PLEEEEEEAAAAASE excuse me for using this header. I just can't get
; this #!@$ complement check right !

.org 100h
.byte $00,$C3,$50,$01

; Standard Nintendo DO NOT CHANGE...
.byte $CE,$ED,$66,$66,$CC,$0D,$00,$0B,$03,$73,$00,$83
.byte $00,$0C,$00,$0D,$00,$08,$11,$1F,$88,$89,$00,$0E
.byte $DC,$CC,$6E,$E6,$DD,$DD,$D9,$99,$BB,$BB,$67,$63
.byte $6E,$0E,$EC,$CC,$DD,$DC,$99,$9F,$BB,$B9,$33,$3E

.byte "HEROZERO SAMPLE1"	; Cart name   16bytes
.byte 0,0,0			; Not used
.byte 0				; Cart type   ROM Only
.byte 0				; ROM Size    32k
.byte 0				; RAM Size     0k
.byte 0deh,0adh			; Maker ID    $dead=DiESEL Soft
.byte 1				; Version     =1
.byte 0dah			; Complement check (Important)
.byte 0ffh,0ffh			; Cheksum
; =============================================================================

; =============================================================================
; Main procedure
; =============================================================================
start:		di			; This is addr $0150
		ld	sp,0fff4h	; Put the stack into hiram.
		                        ; You may put it to 0cfffh, too

		ld	a,0		; No IRQs at all
		ldh	(0ffh),a

		sub	a		; Misc standard init things..
		ldh	(41h),a		; LCDC Status
		ldh	(42h),a		; Screen scroll Y=0
		ldh	(43h),a		; Screen scroll X=0

		call	waitvbl		; Must be in VBL before turning the screen off.

		ld	a,00010001b	; LCD Controller = Off (No picture on screen)
					; WindowBank = $9800 (Not used)
					; Window = OFF
					; BG Chr = $8000
					; BG Bank= $9800
					; OBJ    = 8x8
					; OBJ    = Off
					; BG     = On
		ldh	(40h),a

		call	nor_col		; Normal palette
		call 	cls		; Move the charset to $8000
		call	init_scr	; Move the text to $9800

		ld	a,10010001b	; LCD Controller = On
		ldh	(40h),a

		ld	a,0
		ld	(y1),a
		ld	a,119
		ld	(y2),a
luper0:		ld	a,3
		ld	(color),a

		ld	b,128
		ld	c,127
luper1:		push	bc
		dec	b
		ld	a,b
		ld	(x1),a
		ld	a,c
		sub	b
		ld	(x2),a
		call	line
		pop	bc
		dec	b
		jr	nz,luper1

		ld	a,0
		ld	(x1),a
		ld	a,127
		ld	(x2),a

		ld	a,2
		ld	(color),a

		ld	b,120
		ld	c,119
luper2:		push	bc
		dec	b
		ld	a,b
		ld	(y2),a
		ld	a,c
		sub	b
		ld	(y1),a

		call	line
		pop	bc
		dec	b
		jr	nz,luper2

		ld	a,0
		ld	(y1),a
		ld	a,119
		ld	(y2),a

		ld	a,3
		ld	(color),a

		ld	b,128
		ld	c,127
luper3:		push	bc
		dec	b
		ld	a,b
		ld	(x1),a
		ld	(x2),a

		call	line
		pop	bc
		dec	b
		jr	nz,luper3

		jp	luper0

; =============================================================================
; Draw a line from (X1),(Y1) to (X2),(Y2) with (color)
; =============================================================================
line:           xor     a
                ld      (d),a
                ld      (d+1),a

		ld	a,(x2)
		ld	b,a
		ld	a,(x1)
                ld      (xc),a
		sub	b
                ld      b,0
                or      a
                jr	z,l_px
		ld	b,0ffh
		bit	7,a
		jr	z,l_px
		neg
		ld	b,01h
l_px:		ld	d,a		; dx sichern
		sla	a
		ld	(i2),a		; i2=dx*2
		ld	a,b
		ld	(sx),a
		ld	a,(y2)
		ld	b,a
		ld	a,(y1)
                ld      (yc),a
		sub	b
                ld      b,0
                jr	z,l_py
		ld	b,0ffh
		bit	7,a
		jr	z,l_py
		neg
		ld	b,01h
l_py:		ld	e,a             ; dy sichern
		sla	a
		ld	(i1),a		; i1=dy*2
		ld	a,b
		ld	(sy),a
		ld	a,d
		cp	e               ; dx<dy ?
		jr	c,dloop2
; dx>dy
dloop:		ld	a,(xc)		; if ((x1==x2)&&(y1==y2)) return;
                ld      b,a
                ld      a,(yc)
                ld      c,a
		call	point
		ld	a,(xc)
                ld      b,a
                ld      a,(x2)
		cp	b
		jr	nz,dnext
		ld	a,(yc)
                ld      b,a
                ld      a,(y2)
		cp	b
		jr	nz,dnext
		ret
dnext:		ld	a,(d)
		ld	e,a
		ld	a,(d+1)
		ld	d,a
		bit	7,d
		jr	nz,xxp
		ld	a,(sy)		; yc+=sy
		ld	b,a
		ld	a,(yc)
		add	a,b
		ld	(yc),a

		ld	a,(i2)		; d-=i2
		ld	b,a
		ld	a,e
		sub	b
		ld	e,a
		jr	nc,jnc1
		dec	d
jnc1:
xxp:		ld	a,(sx)		; xc+=sx
		ld	b,a
		ld	a,(xc)
		add	a,b
		ld	(xc),a

		ld	a,(i1)		; d+=i1
		ld	b,a
		ld	a,e
		add	a,b
		ld	(d),a
		jr	nc,jnc2
		inc	d
jnc2:		ld	a,d
		ld	(d+1),a
		jr	dloop
; dy>dx
dloop2:		ld	a,(xc)		; if ((x1==x2)&&(y1==y2)) return;
                ld      b,a
                ld      a,(yc)
                ld      c,a
		call	point
		ld	a,(xc)
                ld      b,a
                ld      a,(x2)
		cp	b
		jr	nz,dnext2
		ld	a,(yc)
                ld      b,a
                ld      a,(y2)
		cp	b
		jr	nz,dnext2
		ret
dnext2:		ld	a,(d)
		ld	e,a
		ld	a,(d+1)
		ld	d,a
		bit	7,d
		jr	nz,yyp
		ld	a,(sx)		; xc+=sy
		ld	b,a
		ld	a,(xc)
		add	a,b
		ld	(xc),a

		ld	a,(i1)		; d-=i2
		ld	b,a
		ld	a,e
		sub	b
		ld	e,a
		jr	nc,jnc12
		dec	d
jnc12:
yyp:		ld	a,(sy)		; yc+=sy
		ld	b,a
		ld	a,(yc)
		add	a,b
		ld	(yc),a

		ld	a,(i2)		; d+=i1
		ld	b,a
		ld	a,e
		add	a,b
		ld	(d),a
		jr	nc,jnc22
		inc	d
jnc22:		ld	a,d
		ld	(d+1),a
		jr	dloop2

; =============================================================================
; Put a pixel to (b,c) with (color)
; =============================================================================
point:		ld	a,c		; de = 8000h + y*2 + (x/8)*256
		rlc	a
		ld	e,a
		ld	a,b
		srl	a
		srl	a
		srl	a
		add	a,80h
		ld	d,a
		ld	a,b		; b = Bitmask[b & 7]
		and	7
		ld	l,a
		ld	h,0
		ld	a,(HL)
		ld	b,a
point1:		ld	hl,color	; check color
		bit	0,(hl)
		jr	z,point3
point2:		ldh	a,(41h)		; Wait for H/V-Retrace
		bit	1,a
		jp	nz,point2
		ld	a,(de)
		xor	b
		ldi	(de),a
point3:		bit	1,(hl)		; check color
		jr	z,point5
point4:		ldh	a,(41h)		; Wait for H/V-Retrace
		bit	1,a
		jp	nz,point4
		ld	a,(de)
		xor	b
		ld	(de),a
point5:		ret

; =============================================================================
; Wait for VBL
; =============================================================================
waitvbl:	ldh	a,(40h)		; Wait for VBL
		add	a,a
		ret	nc
notyet:		ldh	a,(44h)		; $ff44=LCDC Y-Pos
		cp	90h		; $90 and bigger = in VBL
		jr	nz,notyet	; Loop until it $90
		ret

; =============================================================================
; All colors to transparent
; =============================================================================
white:		xor	a		; a=0
		ldh	(47h),a
		ret

; =============================================================================
; All colors to black
; =============================================================================
black:		ld	a,0ffh
		ldh	(047h),a
		ret

; =============================================================================
; Sets the colors to normal palette
; =============================================================================
nor_col:	ld	a,11100100b	; grey 3=11 (Black)
					; grey 2=10 (Dark grey)
					; grey 1=01 (Light grey)
					; grey 0=00 (Transparent)
		ldh	(47h),a
		ret

; =============================================================================
; Clear screen
; =============================================================================
cls:		ld	hl,8000h
		ld	d,0		; Like move 1024 bytes man
		ld	e,8		; x2=2048
lp1:		xor	a		; A = 0
		ldi	(hl),a
		dec	d
		jp	nz,lp1
		dec	e
		jp	nz,lp1
		ret

; =============================================================================
; Initialize screen
; =============================================================================
init_scr:	ld	hl,9800h	; First clear the screen
		ld	e,4h
cloop1:		ld	d,0h
cloop2:		ld	a,0ffh		; This char (0ffh) isn't used for GFX.
		ldi	(hl),a		; Chars from 0f0h-0ffh may be used for
chole1:		ldh	a,(41h)		; a frame or something...
		and	2
		jp	nz,chole1
		dec	d
		jp	nz,cloop2
		dec	e
		jp	nz,cloop1
		ld	b,0
		ld	hl,9822h	; Now draw the 16*16 matrix
		ld	e,10h
loop1:		ld	d,10h
loop2:		ld	a,b
		swap	a		; The screen must be rotated by 90ø.
		ldi	(hl),a
hole1:		ldh	a,(41h)
		and	2
		jp	nz,hole1
		inc	b
		dec	d
		jp	nz,loop2
		push	de
		ld	d,0
		ld	e,010h
		add	hl,de
		pop	de
		dec	e
		jp	nz,loop1
		ret
; =============================================================================

; Single bank/second bank: check for ROM-overflow
#if ($ > 07FFFh)
		ROM_OVERFLOW_ERROR
#endif

; First bank: check for bank-overflow
;#if ($ > 03FFFh)
;		BANK_OVERFLOW_ERROR
;#endif


; =============================================================================

.end
