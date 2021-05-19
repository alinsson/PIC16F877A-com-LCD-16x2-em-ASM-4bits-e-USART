; ***************************************************************
; *                                                             *
; * Exemlo que escreve em 2 linhas LCD utilizando HD44870	*
; * controlado com modo de interface de 4-bit através do byte   *
; * recebido pela USART.			                *
; *                                                             *
; * PORTC<2:0> = control de sinal:                              *
; *    RC2 = RS, RC1 = RW, RC0 = E                              *
; *                                                             *
; * PORTD<3:0> = usados para dados do LCD                       *
; *                                                             *
; ***************************************************************


list p=16f877
#include <p16f877.inc>

__CONFIG    _CP_OFF & _WDT_OFF & _PWRTE_ON & _XT_OSC & _LVP_OFF

;****************************************************************************

#define E	PORTC,0     ; define ativa lcd
#define RW	PORTC,1     ; define R/W lcd
#define RS	PORTC,2     ; define seleção de registro lcd

;****************************************************************************

CBLOCK		0x20
	temp				; equ 0x20        ; registrador temporário que armazena dados que serão enviados para lcd
	inner   			; equ 0x21        ; cont loop para rotina delay
	cont1
	cont2
	cont3	
ENDC

;****************************************************************************

ORG			0x00       ; inicio programa
	GOTO	MAIN

;****************************************************************************

ORG			0x04		; vetor de interrupção ISR
	RETFIE

;****************************************************************************

MAIN:
	; configuro PORTC e PORTD para LCD
	banksel		TRISD
	clrf		TRISD   ; set PORTD como saída
	movlw		b'10000000'	
	movwf		TRISC   ; set PORTC como saída

	banksel	PORTD
	bsf		E           ; inicializa enable lcd em nível lógico alto
	bcf		RW          ; inicializa RW em nível lógico baixo - write

	call	InitDisp    ; inicial display no modo 4-bit

	movlw	0x28        ; modo de entrada para comando de 4-bit	nas duas linhas do display
	call	LCDCommand

    movlw   0x0E        ; ativar exibição do display
    call    LCDCommand

    movlw   0x06        ; comando para incremento do endereço e deslocamento do cursor para direita
    call    LCDCommand
	
	call 	MeuNome		; mostra meu nome

	; limpa display
	call	Delay_1S
	call	Delay_1S
	call	Delay_1S
	movlw	0x01        ; limpa display
	call	LCDCommand

	call 	ASCII		; mostra "Caractere ASCII" no lcd
    movlw   0xC0        ; coloca endereço DDRAM em 0x40, ou seja, segunda linha
    call    LCDCommand

	; configura todos os pinos do PORTB como saída para UART
	BANKSEL		TRISB
	CLRF		TRISB
	BANKSEL		PORTB
	CLRF		PORTB

	; configura todos os pinos da PORTA como entrada para UART
	BANKSEL		TRISA
	CLRF		TRISA	; PORTA configurada como entrada em todos os pinos
	BANKSEL		PORTA
	CLRF		PORTA
	BANKSEL		ADCON1		
	MOVLW		0x06    ; todos pinos digitais
	MOVWF		ADCON1

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

Self:
	BANKSEL		PIR1
	BTFSS		PIR1, RCIF		; transmissão mudança de status
	GOTO		$-1

	; recebo valor serial
	BANKSEL		RCREG
	MOVF		RCREG, W
	BANKSEL		PORTB
	MOVWF		PORTB

    movlw   0xC0        ; coloca endereço DDRAM em 0x40, ou seja, segunda linha
    call    LCDCommand
	movf	RCREG, W
	call	LCDData 	; mostra caractere no display lcd
    goto    	Self    	; Loop in place

; ***************************************************
; * Para incializar display enviamos um byte para   *
; * coloca-lo em modo 4-bits.                       *
; ***************************************************
InitDisp:
	BANKSEL	PORTD
	movlw	0x02		; valor para setar interface 4-bit
	movwf	PORTD       ; Move comando para LSB da PORTB
	bcf		RS          ; limpa RS - indicador de comando
	bcf		E           ; ativa lcd
	bsf		E
    call    Delay       ; aguarda comando ser executado
    return              ; sai da sub-rotina

; ***************************************************
; * Para enviar comando para LCD, colocar dado em   *
; * WREG e chamar sub-rotina LCDCommand             *
; ***************************************************
LCDCommand:
    bcf     RS          ; limpa RS para avisar lcd que dado é um comando
    goto    SendToLCD

; ***************************************************
; * Para enviar dado para lcd basta colocar dado em *
; * WREG e cahmar sub-rotina LCDDATA                *
; ***************************************************
LCDData:
    bsf     RS          ; seta RS para avisar lcd que é dado e não um comando

; ***************************************************
; * Sub-rotina para enviar byte em WREG para LCD    *
; ***************************************************
SendToLCD:
	movwf	temp        ; salva dado no registrador temporário
	swapf	temp,W      ; inverte posição bits e salva em WREG
	movwf	PORTD       ; manda nybble LSB para PORTB
 	bcf		E           ; ativa lcd
	bsf		E
	movf	temp,W      ; recupera byte e salva em WREG
	movwf	PORTD       ; manda nybble MB para PORTB
	bcf		E           ; ativa lcd
	bsf		E
    call    Delay       ; Give display time to process command or data
	return              ; return to caller

; *****************************************************
; * Mostra "Caractere ASCII" na primeira linha lcd.   *
; *****************************************************
ASCII:
    movlw   0x80        ; coloca endereço DDRAM em 0x00, ou seja, primeira linha
    call    LCDCommand
    movlw   'C'         ; envia um caractere
    call    LCDData
    movlw   'a'         ; envia um caractere
    call    LCDData
    movlw   'r'         ; envia um caractere
    call    LCDData
    movlw   'a'         ; envia um caractere
    call    LCDData
    movlw   'c'         ; envia um caractere
    call    LCDData
    movlw   't'         ; envia um caractere
    call    LCDData
    movlw   'e'         ; envia um caractere
    call    LCDData
    movlw   'r'         ; envia um caractere
    call    LCDData
    movlw   'e'         ; envia um caractere
    call    LCDData
    movlw   ' '         ; envia um caractere
    call    LCDData
    movlw   'A'         ; envia um caractere
    call    LCDData
    movlw   'S'         ; envia um caractere
    call    LCDData
    movlw   'C'         ; envia um caractere
    call    LCDData
    movlw   'I'         ; envia um caractere
    call    LCDData
    movlw   'I'         ; envia um caractere
	return	

; *****************************************************
; * Mostra meu nome no display de lcd.                *
; *****************************************************
MeuNome:
    movlw   0x80        ; coloca endereço DDRAM em 0x00, ou seja, primeira linha
    call    LCDCommand
    movlw   'A'         ; envia um caractere
    call    LCDData
    movlw   'l'         ; envia um caractere
    call    LCDData
    movlw   'i'         ; envia um caractere
    call    LCDData
    movlw   'n'         ; envia um caractere
    call    LCDData
    movlw   's'         ; envia um caractere
    call    LCDData
    movlw   's'         ; envia um caractere
    call    LCDData
    movlw   's'         ; envia um caractere
    call    LCDData
    movlw   'o'         ; envia um caractere
    call    LCDData
    movlw   'n'         ; envia um caractere
    call    LCDData
    movlw   ' '         ; envia um caractere
    call    LCDData
    movlw   'S'         ; envia um caractere
    call    LCDData
    movlw   'o'         ; envia um caractere
    call    LCDData
    movlw   'u'         ; envia um caractere
    call    LCDData
    movlw   'z'         ; envia um caractere
    call    LCDData
    movlw   'a'         ; envia um caractere
    call    LCDData

    movlw   0xC0        ; coloca endereço DDRAM em 0x40, ou seja, segunda linha
    call    LCDCommand
    movlw   'M'         ; envia um caractere
    call    LCDData
    movlw   'i'         ; envia um caractere
    call    LCDData
    movlw   'c'         ; envia um caractere
    call    LCDData
    movlw   'r'         ; envia um caractere
    call    LCDData
    movlw   'o'         ; envia um caractere
    call    LCDData
    movlw   'p'         ; envia um caractere
    call    LCDData
    movlw   'r'         ; envia um caractere
    call    LCDData
    movlw   'o'         ; envia um caractere
    call    LCDData
    movlw   'c'         ; envia um caractere
    call    LCDData
    movlw   'e'         ; envia um caractere
    call    LCDData
    movlw   's'         ; envia um caractere
    call    LCDData
    movlw   's'         ; envia um caractere
    call    LCDData
    movlw   'a'         ; envia um caractere
    call    LCDData
    movlw   'd'         ; envia um caractere
    call    LCDData
    movlw   'o'         ; envia um caractere
    call    LCDData
    movlw   'r'         ; envia um caractere
    call    LCDData
	return
; *****************************************************
; * Cria um delay para aguardae processamento comando *
; *****************************************************
Delay:
    clrf    inner
DLoop: 
    nop
    nop
    decfsz  inner
    goto    DLoop
    return
    
; *****************************************************
; * Cria um delay 1s								  *
; *****************************************************
Delay_1S						; 10000 cycles
	movlw	0x03			    ; 199 em decimal
	movwf	cont1
	movlw	0x18			
	movwf	cont2
	movlw	0x02			
	movwf	cont3

Delay_Aux						
	decfsz	cont1, f
	goto	$+2
	decfsz	cont2, f
	goto	$+2
	decfsz	cont3, f
	goto	Delay_Aux 			
	goto	$+1
	goto	$+1
	goto	$+1
	return
end

