;******************************************************************************
; Universidad del Valle de Guatemala 
; 1E2023: Programacion de Microcontroladores 
; main.asm 
; Autor: Jacob Tabush 
; Proyecto: Laboratorio 3
; Hardware: ATMEGA328P 
; Creado: 14/02/2024 
; Ultima modificacion: 14/02/2024 
;*******************************************************************************

.include "M328PDEF.inc"

.def counter=R18 ; reservamos un register para el contador de los botones
.def outerloop=R22 ; reservamos un register para el loop externo
.def countertimer=R20; reservamos un register para el contador del timer

.cseg
.org 0x00
JMP MAIN ; vector reset

.org 0x0006 ; Vector de ISR: PCINT0
	JMP ISR_PCINT0

	.org 0x0020 ; Vector de ISR: Timer 0 overflow
	JMP ISR_TIMR0


MAIN:
; STACK POINTER

LDI R16, LOW(RAMEND)
OUT SPL, R16
LDI R17, HIGH(RAMEND)
OUT SPH, R17

; nuestra tabla de valores del 7 seg, con pin0 = a, pin1 = b...
tabla7seg: .DB  0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x67, 0x77, 0x7C, 0x58, 0x5E, 0x79, 0x71

; ///////////////////////////////////////////////////////
; Configuracion
; ///////////////////////////////////////////////////////

Setup:

;  prescaler

LDI R16, 0b1000_0000
STS CLKPR, R16

LDI R16, 0b0000_0011 ;1 MHz
STS CLKPR, R16 

; utilizamos D para controlar el disp de 7 segmentos
LDI R16, 0xFF
OUT DDRD, R16 ;Ponemos a todo D como salidas
LDI R16, 0x00
OUT PORTD, R16 ; Apagamos todas las salidas

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

; Habilitamos un interrupt en timr0 overflow
LDI R16, 0x01
STS TIMSK0, R16

LDI R16, 0x00
STS UCSR0B, R16 ; deshablitamos el serial en pd0 y pd1

CALL timerinit

LDI counter, 0x00
SEI ; habilitamos interrupts 

; ////////////////////////////////////////////////////////////////////

 
 ; //////////////////////////////////////////////
 ; Loop prmario
 ; //////////////////////////////////////////////

 Loop:

OUT PORTC, counter

LDI ZL, LOW(tabla7seg << 1) ; Seleccionamos el ZL para encontrar al bit bajo en el flash
LDI ZH, HIGH(tabla7seg << 1) ; Seleccionamos el ZH para ecnontar al bit alto en el flash

ADD ZL, countertimer ; Le agreagamos el valor del counter1, para ir al valor especifico de la tabla
LPM R16, Z ; Cargamos el valor del tabla a R16

OUT PORTD, R16 ; Cargar el valor a PORTD

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

timerinit: 

LDI R16, (1 << CS02) | (1 << CS00)
OUT TCCR0B, R16 ; prescaler de 1024

LDI R16, 235 ; Cargamos 235 al contador = aproximadamente 10ms
OUT TCNT0, R16

RET



; ////////////////////////////////////////////////////
; Subrutinas de interrupcion
; ////////////////////////////////////////////////////

ISR_PCINT0: ; Para el cambio de pines

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

ISR_TIMR0: ; Para el cambio de timer0
LDI R16, 235 ; Cargamos 235 al contador = aproximadamente 10ms
OUT TCNT0, R16

SBI TIFR0, 0 ; Colocamos un 0 TV0 para reiniciar el timer
DEC outerloop
BRNE endtimr0

INC countertimer ; Incrementamos el contador
SBRC countertimer, 4
LDI countertimer, 0x00 ; Aseguramos que no haya pasado de los 4 bits
LDI outerloop, 100

endtimr0:
RETI