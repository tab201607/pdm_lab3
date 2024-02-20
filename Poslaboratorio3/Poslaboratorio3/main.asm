;******************************************************************************
; Universidad del Valle de Guatemala 
; 1E2023: Programacion de Microcontroladores 
; main.asm 
; Autor: Jacob Tabush 
; Proyecto: Posaboratorio 3
; Hardware: ATMEGA328P 
; Creado: 18/02/2024 
; Ultima modificacion: 20/02/2024 
;*******************************************************************************

.include "M328PDEF.inc"

.def counter=R18 ; reservamos un register para el contador de los botones
.def outerloop=R22 ; reservamos un register para el loop externo
.def countersegundos=R20; reservamos un register para el contador de los segundos
.def counterdecenas=R21;  reservamos un register para el contador de los decenas
.def muxshow=R23 ; reservamos un register para determinar que mostrar en el mux
.def debounceactive=R24
.def debouncetimer=R25

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

; Utilizamos B para los pushbuttons y para mux de los displays
LDI R16, 0b0000_1100
OUT DDRB, R16 ; Ponemos a PB0 y PB1 como entradas y PB2 y PB3 como salidas
LDI R16, 0b0000_0011
OUT PORTB, R16 ; hablitamos pullups en PB0 y PB1

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
LDI countersegundos, 0x00
LDI counterdecenas, 0x00
LDI muxshow, 0x10 ; Este nos permitira utilizar el comando swap para negar y denegar el primer bit
SEI ; habilitamos interrupts 

; ////////////////////////////////////////////////////////////////////

 
 ; //////////////////////////////////////////////
 ; Loop prmario
 ; //////////////////////////////////////////////

 Loop:

OUT PORTC, counter

LDI ZL, LOW(tabla7seg << 1) ; Seleccionamos el ZL para encontrar al bit bajo en el flash
LDI ZH, HIGH(tabla7seg << 1) ; Seleccionamos el ZH para ecnontar al bit alto en el flash

SBRC muxshow, 0 ; revisamos el valor del primer bit en muxshow pare determinar si desplegamos segundos o decenas
RJMP dispsegundos

ADD ZL, countersegundos ; Le agreagamos el valor del countersegundos, para ir al valor especifico de la tabla
LPM R16, Z ; Cargamos el valor del tabla a R16

SBI PORTB, 2 ; Activamos el bit de mux apropiado
CBI PORTB, 3

OUT PORTD, R16 ; Cargar el valor a PORTD

RJMP Loop 

dispsegundos: 
ADD ZL, counterdecenas ; Le agreagamos el valor del counterdecenas, para ir al valor especifico de la tabla
LPM R16, Z ; Cargamos el valor del tabla a R16

SBI PORTB, 3 ; Activamos el bit de mux apropiado
CBI PORTB, 2

OUT PORTD, R16 ; Cargar el valor a PORTD

RJMP Loop 



; ///////////////////////////////
; Modulos para iniciar el timer
; //////////////////////////////

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

; debounce

SBRC debounceactive, 0 ; revisamos si el debounce es activo, en caso que si no realizamos todo lo demas
RETI

incremento:
LDI debounceactive, 0x01 ; activamos el debouncer
LDI debouncetimer, 20 ; le colocamos 100ms al debouncetimer

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

SWAP muxshow ; niega el primer bit de muxshow

LDI R16, 235 ; Cargamos 235 al contador = aproximadamente 10ms
OUT TCNT0, R16

SBI TIFR0, 0 ; Colocamos un 0 TV0 para reiniciar el timer
SBRS debounceactive, 0 ; revisamos si el debounce esta activo
RJMP outerloopdecrease

DEC debouncetimer ; decrementamos el debounce timer cada 10ms
BRNE outerloopdecrease
LDI debounceactive, 0 ; desactivamos el protocolo de debounce

outerloopdecrease:
DEC outerloop
BRNE endtimr0

LDI outerloop, 100 ; le cargamos 100 al segundo loop 

INC countersegundos ; Incrementamos el contador de segundos
LDI R16, 10
CPSE countersegundos, R16 ; revisamos que no haya superado 10
RETI ; Si no ha superado los 10 terminamos la interrupcion


LDI countersegundos, 0x00 ; colocamos a contador de segundos en 0
INC counterdecenas ; incrementamos el contador de decenas
LDI R16, 6 
CPSE counterdecenas, R16 ; revisamos que no haya superado 60
RETI ; Si no ha superado los 60 terminamos la interrupcion

LDI counterdecenas, 0x00 ; colocamos el contador de decenas en 0

endtimr0:
RETI