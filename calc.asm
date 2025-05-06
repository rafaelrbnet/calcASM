; ============================================================================
;  Calculadora de Ponto Flutuante 64 bits – Assembly x86-64 (NASM + SSE2)
;  Aluno: Rafael Baena Neto
;  Prontuário: GU3066916
;  Disciplina: POS.01178 (C1AOC) - Arquitetura, Organização e Redes de Computadores
;  Calculadora de Ponto Flutuante em Assembly x86-64 com SSE/SSE2
;  Compatível com Linux x86-64, usando printf e scanf (System V AMD64 ABI)
;
; [Fluxograma do desenvolvimento]
; https://www.mermaidchart.com/raw/437babbf-8dd1-4251-afb7-c7c7e59a65d5?theme=light&version=v0.1&format=svg
;
;  → Lê um número inicial.
;  → Loop:  <operador> <número>   |   Operadores: +  -  *  /   |   q → sair
;  → Resultado (%.16lf) vira novo acumulador.
;  → Proteção p/ divisão por zero.
;  → Todas as operações em XMM (addsd, subsd, mulsd, divsd).
;
; ============================================================================
;
;  Objetivos didáticos:
;   • Demonstrar uso de instruções SSE2 (addsd/subsd/mulsd/divsd) para operar
;     em double-precision (64 bits) no registrador XMM.
;   • Expor a convenção de chamada System V AMD64 (registradores RDI, RSI…,
;     XMM0 para argumentos flutuantes e retorno).
;   • Evidenciar a exigência de pilha **alinhada a 16 bytes** antes de CALLs
;     variádicas (`printf`, `scanf`) — causa clássica de SIGSEGV.
;   • Tratar fluxo de controle com saltos (`cmp`/`je`/`jne`) e flags ZF.
;
;  Como compilar/linkar (mantendo símbolos de depuração):
;       nasm -f elf64 -g -F dwarf calc.asm -o calc.o
;       gcc  -g -no-pie calc.o -o calc
;  Execução:
;       ./calc
; ============================================================================

; ---------------- EXPORTAÇÕES E IMPORTAÇÕES ----------------
global  main                 ; ponto de entrada reconhecido pelo linker

extern  printf               ; funções variádicas da libc
extern  scanf
extern  exit                 ; encerramento limpo (exit(int))

; -------------------- SEGMENTO SOMENTE LEITURA --------------------
section .rodata

    ; Formatos de scanf / printf (terminados em NUL)
    fmt_double      db  "%lf",0           ; lê double (scanf)
    fmt_char        db  " %c",0           ; lê char, consumindo espaços/enter
    fmt_out         db  "Resultado: %.15g",10,0  ; saída com 15 dígitos sig.

    ; Mensagens de interface
    msg_banner1     db  10,"*** Calculadora x86-64 (NASM / SSE2) ***",10,0
    msg_banner2     db  "Operadores: +  -  *  /   |   q para sair",10,10,0
    msg_first       db  "Insira o primeiro número: ",0
    msg_nextop      db  "Insira operador (+ - * / ou q): ",0
    msg_second      db  "Insira o próximo número: ",0
    msg_divzero     db  "Erro: divisão por ZERO! Digite outro número.",10,0
    msg_goodbye     db  10,"Calculadora encerrada.",10,0
    msg_badop       db  "Operador inválido! Tente novamente.",10,0

; -------------------- SEGMENTO NÃO INICIALIZADO --------------------
section .bss
    acc      resq 1          ; double acumulador (8 bytes)
    temp     resq 1          ; double do segundo operando
    op       resb 1          ; char do operador

; ===================================================================
;                         CÓDIGO – .text
; ===================================================================
section .text

; ────────────────────────────────────────────────────────────────────
; main:
;   1. Alinha a pilha                    (push rbp / sub rsp,16)
;   2. Mostra banner
;   3. Lê primeiro número (scanf)
;   4. Entra em loop de cálculo          (calc_loop)
; ────────────────────────────────────────────────────────────────────
main:
    ; ---------- PRÓLOGO ----------
    push rbp                 ; salva base pointer anterior
    mov  rbp, rsp            ; estabelece novo frame (opcional, facilita debug)
    sub  rsp, 16             ; reserva 16 bytes (mantém rsp % 16 == 0)

    ; ---------- BANNER ----------
    lea  rdi, [rel msg_banner1] ; 1º arg -> RDI (pointer)
    xor  eax, eax            ; eax = número de vetores SSE passados (0)
    call printf

    lea  rdi, [rel msg_banner2]
    xor  eax, eax
    call printf

; ---------- ENTRADA DO PRIMEIRO NÚMERO ----------
get_first:
    lea  rdi, [rel msg_first]
    xor  eax, eax
    call printf

    ; scanf("%lf", &acc)
    lea  rdi, [rel fmt_double]
    lea  rsi, [rel acc]      ; 2º arg -> RSI
    xor  eax, eax
    call scanf

; ---------- LOOP PRINCIPAL ----------
calc_loop:

; ----- Solicita operador -----
get_op:
    lea  rdi, [rel msg_nextop]
    xor  eax, eax
    call printf

    ; scanf(" %c", &op)
    lea  rdi, [rel fmt_char]
    lea  rsi, [rel op]
    xor  eax, eax
    call scanf

    ; testa se quer sair
    movzx eax, byte [op]
    cmp  al, 'q'
    je   quit_program         ; ZF=1 → jump

    ; garante que seja um dos 4 operadores
    cmp  al, '+'
    je   read_second
    cmp  al, '-'
    je   read_second
    cmp  al, '*'
    je   read_second
    cmp  al, '/'
    je   read_second

invalid_op:                   ; caiu aqui → operador inválido
    lea  rdi, [rel msg_badop]
    xor  eax, eax
    call printf
    jmp  calc_loop

; ----- Solicita segundo número -----
read_second:
    lea  rdi, [rel msg_second]
    xor  eax, eax
    call printf

    ; scanf("%lf", &temp)
    lea  rdi, [rel fmt_double]
    lea  rsi, [rel temp]
    xor  eax, eax
    call scanf

    ; carrega valores nos registradores XMM (SSE2)
    movq xmm0, [acc]          ; acumulador → xmm0
    movq xmm1, [temp]         ; novo operando → xmm1

    ; Decisão de operação
    cmp  byte [op], '+'
    je   do_add
    cmp  byte [op], '-'
    je   do_sub
    cmp  byte [op], '*'
    je   do_mul
    ; resto: divisão

    ; -------- Proteção divisão por zero --------
    movq rax, xmm1            ; copia bits para RAX (mais fácil testar)
    test rax, rax
    jz   div_zero
    jmp  do_div

; ===== INSTRUÇÕES SSE2 DE ALTA PERFORMANCE =====
do_add:  addsd xmm0, xmm1      ; xmm0 = xmm0 + xmm1
        jmp  show_result
do_sub:  subsd xmm0, xmm1      ; xmm0 = xmm0 - xmm1
        jmp  show_result
do_mul:  mulsd xmm0, xmm1      ; xmm0 = xmm0 * xmm1
        jmp  show_result
do_div:  divsd xmm0, xmm1      ; xmm0 = xmm0 / xmm1
        jmp  show_result

; -------- Tratamento de divisão por zero --------
div_zero:
    lea  rdi, [rel msg_divzero]
    xor  eax, eax
    call printf
    jmp  read_second           ; volta a pedir novo divisor

; -------- Exibição do resultado --------
show_result:
    movq [acc], xmm0           ; persiste em memória p/ próximo ciclo

    ; printf("Resultado: %.15g", (double)xmm0);
    lea  rdi, [rel fmt_out]
    mov  eax, 1                ; 1 registro vector passado (xmm0)
    call printf

    jmp  calc_loop             ; reinicia ciclo

; -------- Encerramento gracioso --------
quit_program:
    lea  rdi, [rel msg_goodbye]
    xor  eax, eax
    call printf

    xor  edi, edi              ; exit(0)
    call exit
