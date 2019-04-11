; *** Register Usage ***
;
; r16: tmp
; Bytes sent to the SR are sent MSB first. For example, if you send 0b10000000,
; QH is going to get be high pin.
; r20: Byte to send to the "data" SR. Wired to D0-D7.
; r21: "high" byte, to send to the "addr" SR. Wired to A8-15
; r22: "low" byte, to send to the "addr" SR. Wired to A0-7
; r23: tmp value to use for sending to the "addr" SR

.include "m328Pdef.inc"

; *** Pins ***
.equ SRCP = PORTD2
.equ SRDS = PORTD3
.equ FLWE = PORTD4
.equ FLCE = PORTD5
.equ SRCP2 = PORTD6
.equ LED = PORTB5

; *** Consts ***
.equ BAUD_PRESCALE = 103	; 9600 bauds at 16mhz

; *** Jump table ***
.org 0x0000
        rjmp    main

; *** Code ***
main:
	ldi	r16, low(RAMEND)
	out	SPL, r16
	ldi	r16, high(RAMEND)
	out	SPH, r16

	sbi	DDRD, SRDS
	sbi	DDRD, SRCP
	sbi	DDRD, FLWE
	sbi	DDRD, FLCE
	sbi	DDRD, SRCP2
	sbi	DDRB, LED

	; We begin with WE disabled (high)
	sbi	PORTD, FLWE

	; We keep CE enabled (low) during writing
	cbi	PORTD, FLCE

	; we keep the LED lit while we "work", that is, while we're not waiting
	; for input.
	sbi	PORTB, LED

	; Setup address counter
	clr	r21
	clr	r22

	; Setup UART
	ldi	R16, low(BAUD_PRESCALE)
	sts	UBRR0L, r16
	ldi	r16, high(BAUD_PRESCALE)
	sts	UBRR0H, r16

	ldi	r16, (1<<RXEN0) | (1<<TXEN0)
	sts	UCSR0B, r16

loop:
	rcall	readchar
	rcall	pushdata
	rjmp	loop

; Waits until a char is read, then put it in R20
readchar:
	cbi	PORTB, LED
	lds	r16, UCSR0A
	sbrs	r16, RXC0	; RXC0 is set? skip rjmp and fetch char.
	rjmp	readchar
	sbi	PORTB, LED
	lds	r20, UDR0
	ret

; push r20 to the rom and increase the memory counter
pushdata:
	; first, set up addr
	mov	r23, r21
	rcall	sendaddr
	mov	r23, r22
	rcall	sendaddr
	inc	r22
	brne	pushdata_0	; no overflow? skip
	inc	r21

pushdata_0:
	; addr is latched on WE falling edge
	cbi	PORTD, FLWE

	; now, lets set up data. Plenty enough instructions to ensure a 100ns
	; minimum delay.
	rcall	senddata

	; data is latched on rising edge
	sbi	PORTD, FLWE

	ret

; send r23 to addr shift register.
; We send highest bits first so that Q7 is the MSB and Q0 is the LSB
sendaddr:
	ldi	r16, 8		; we will loop 8 times
	cbi	PORTD, SRDS
	sbrc	r23, 7		; if latest bit isn't cleared, set SER_DP high
	sbi	PORTD, SRDS
	rcall	togglecp
	lsl	r23		; shift our data left
	dec	r16
	brne	sendaddr+1	; not zero yet? loop! (+1 to avoid reset)
	ret

; toggle SRCP, not waiting between pulses. The CD74AC164 at 5V has a 5.9ns
; CP min pulse width. We can't match that at 16mhz. No need to wait.
togglecp:
	cbi	PORTD, SRCP
	sbi	PORTD, SRCP
	ret

; send r20 to data shift register.
senddata:
	ldi	r16, 8		; we will loop 8 times
	cbi	PORTD, SRDS
	sbrc	r20, 7		; if latest bit isn't cleared, set SER_DP high
	sbi	PORTD, SRDS
	rcall	togglecp2
	lsl	r20		; shift our data left
	dec	r16
	brne	senddata+1	; not zero yet? loop! (+1 to avoid reset)
	ret

togglecp2:
	cbi	PORTD, SRCP2
	sbi	PORTD, SRCP2
	ret
