;********************************************************************** 
; Master - transmissor comunicação serial
list       p=16F877             ; diretiva list para definir o processador 
#include  <p16F877.inc>         ; definições de variáveis do processador 

; ext reset, no code protect, no watchdog, 4Mhz int clock
__CONFIG    _CP_OFF & _WDT_OFF & _PWRTE_ON & _XT_OSC & _LVP_OFF

;********************************************************************** 

CBLOCK 		0x20				; diretiva para bloco de variáveis
	W_TEMP
	STATUS_TEMP
	CONT1
	CONT2
	CONT3
ENDC

;**********************************************************************
ORG     0x00                	; vetor de reset 
	GOTO    	MAIN            ; vai para o inicio do programa 
;**********************************************************************  

;********************************************************************** 
ORG     0x04                	; vetor de interrupção
	RETFIE
	;GOTO 		INTTIMER        ; interrupção por timer	
;********************************************************************** 
 
MAIN:
	; configura a interrupção externa com borda de descida
	CLRF		STATUS

	; configura todos os pinos do PORTB como saída
	BANKSEL		TRISB
	CLRF		TRISB
	BANKSEL		PORTB
	CLRF		PORTB

	; configura todos os pinos da PORTA como entrada
	BANKSEL		TRISA
	MOVLW		0xFF
	MOVWF		TRISA			; PORTA configurada como entrada em todos os pinos
	BANKSEL		PORTA
	CLRF		PORTA

	; configura receptor
	BANKSEL		RCSTA
	CLRF		RCSTA
	BSF			RCSTA, SPEN		; porta serial RX, TX ativadas
	BSF			RCSTA, CREN		; recebimento continuo ativado

	; configura gerador de taxa de transmissão
	BANKSEL		SPBRG
	MOVLW		0x19			; 25 em decimal
	MOVWF		SPBRG

	; registrador TXREG que ativa transmissor
	BANKSEL		TXREG
	CLRF		TXREG

	; configura option_reg
	BANKSEL		OPTION_REG
	CLRF		OPTION_REG
	;BSF			OPTION_REG, RBPU ; Pull-up PORTB desativados
	BSF			OPTION_REG, INTEDG; interrupção por borda de subida em RB0/INT
	BCF			OPTION_REG, T0CS ; utiliza CLKOUT
	BSF			OPTION_REG, T0SE ; TMR0 por borda de descida
	BCF			OPTION_REG, PSA  ; prescaler para timer0
	BCF			OPTION_REG, PS2	 ; prescaler 011 = 1:16
	BSF			OPTION_REG, PS1
	BSF			OPTION_REG, PS0

	; configurar TXSTA (transmit status and control register)
	BANKSEL		TXSTA
	CLRF		TXSTA
	BSF			TXSTA, TXEN		; transferência ativada
	BCF			TXSTA, BRGH		; modo alta velocidade  

	LOOP
	;CALL 		DELAY

	BANKSEL		TXSTA
	BTFSS		TXSTA, TRMT		; transmissão mudança de status
	GOTO		$-1

	BANKSEL		TXREG
	MOVF		PORTB, W
	MOVWF		TXREG
	GOTO		LOOP

PUSHING:
	MOVWF 		W_TEMP
	SWAPF		STATUS, W
	MOVWF		STATUS_TEMP
	RETURN

POPING:
	SWAPF		STATUS_TEMP, W
	MOVWF 		STATUS
	SWAPF		W_TEMP, 1
	SWAPF		W_TEMP, W
	RETURN

; delay de 1s
DELAY							; 10000 cycles
	MOVLW	0x03			    ; 199 em decimal
	MOVWF	CONT1
	MOVLW	0x18			
	MOVWF	CONT2
	MOVLW	0x02			
	MOVWF	CONT3

DELAY_AUX						
	DECFSZ	CONT1, f
	GOTO	$+2
	DECFSZ	CONT2, f
	GOTO	$+2
	DECFSZ	CONT3, f
	GOTO	DELAY_AUX 			
	GOTO	$+1
	GOTO	$+1
	GOTO	$+1
	RETURN

END                    		    ; diretiva de fim de programa 
;**********************************************************************