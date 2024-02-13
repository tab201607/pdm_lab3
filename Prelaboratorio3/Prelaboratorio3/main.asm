;******************************************************************************
; Universidad del Valle de Guatemala 
; 1E2023: Programacion de Microcontroladores 
; main.asm 
; Autor: Jacob Tabush 
; Proyecto: Prelaboratorio 3
; Hardware: ATMEGA328P 
; Creado: 12/02/2024 
; Ultima modificacion: 12/02/2024 
;*******************************************************************************

.include "M328PDEF.inc"

.def counter=R18 ; reservamos un register para el contador del display

.cseg
.org 0x00
JMP MAIN ; vector reset

.org 0x0006 ; Vector de ISR: PCINT0
	JMP ISR_PCINT0

	.org 0x000C

MAIN:
; STACK POINTER

LDI R16, LOW(RAMEND)
OUT SPL, R16
LDI R17, HIGH(RAMEND)
OUT SPH, R17

; ///////////////////////////////////////////////////////
; Configuracion
; ///////////////////////////////////////////////////////

Setup:

;  prescaler

LDI R16, 0b1000_0000
STS CLKPR, R16

LDI R16, 0b0000_0011 ;1 MHz
STS CLKPR, R16 

; Utilizamos C para controlar el contador
LDI R16, 0b0000_1111
OUT DDRC, R16 ; Ponemos a C0-C3 como salidas
LDI R16, 0x00
OUT PORTC, R16 ; Apagamos todas estas

; Utilizamos B para los pushbuttons y para la alarma
LDI R16, 0b0000_0000
OUT DDRB, R16 ; Ponemos a todo B como entradas
LDI R16, 0x0F
OUT PORTB, R16 ; hablitamos pullups en todo B (menos a PB5)

; Habilitamos pin change interrupt en PB0 y PB1
LDI R16, 0x01
STS PCICR, R16
LDI R16, 0x03
STS PCMSK0, R16

LDI counter, 0x00
SEI ; habilitamos interrupts 

; ////////////////////////////////////////////////////////////////////

 
 ; //////////////////////////////////////////////
 ; Loop prmario
 ; //////////////////////////////////////////////

 Loop:

OUT PORTC, counter

RJMP Loop 


; ///////////////////////////////
; Modulos de incremento, decremento y delay
; //////////////////////////////T

delay:
LDI R17, 5 ; loop externo
delayouter:
LDI R16, 250 ; loop interno
delayinner:
	DEC R16
	BRNE delayinner

	DEC R17
	BRNE delayouter

RET

ISR_PCINT0: 

SBIC PINB, PB0 ; analizamos PB0 primero y realizamos el incremento si esta en bajo
RJMP decremento 

INC counter
SBRC counter, 4 ; revisamos que no aumenta mas de los 4 bits
	LDI counter, 0x0F

decremento:
SBIC PINB, PB1 ; analizamos PB1 de segundo y realizamos el decremento si esta en bajo
RETI ; regresamo si ninguno de los pins esta set

DEC counter
SBRC counter, 7 ; revisamos que no hace wraparound para estar de mas de 4 bits
	LDI counter, 0x00


RETI