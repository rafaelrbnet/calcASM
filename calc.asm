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
;  Como montar e linkar (mantendo símbolos de debug):
;      nasm -f elf64 -g -F dwarf calc.asm -o calc.o
;      gcc  -g -no-pie calc.o -o calc
;  Execução:
;      ./calc
; ============================================================================

global  main
extern  printf
extern  scanf
extern  exit                 ; libc exit(int)

section .rodata
    fmt_double      db  "%lf",0
    fmt_char        db  " %c",0
    fmt_out         db  "Resultado: %.15g",10,0   ; 15 dígitos significativos

    msg_banner1     db  10,"*** Calculadora x86-64 (NASM / SSE2) ***",10,0
    msg_banner2     db  "Operadores: +  -  *  /   |   q para sair",10,10,0

    msg_first       db  "Insira o primeiro número: ",0
    msg_nextop      db  "Insira operador (+ - * / ou q): ",0
    msg_second      db  "Insira o próximo número: ",0
    msg_divzero     db  "Erro: divisão por ZERO! Digite outro número.",10,0
    msg_goodbye     db  10,"Calculadora encerrada.",10,0
    msg_badop       db  "Operador inválido! Tente novamente.",10,0

section .bss
    acc      resq 1          ; acumulador
    temp     resq 1          ; segundo operando
    op       resb 1          ; operador

section .text
main:
    push rbp
    mov  rbp, rsp
    sub  rsp, 16             ; mantém %rsp alinhado a 16 B

; -------- Banner --------
    lea  rdi, [rel msg_banner1]
    xor  eax, eax
    call printf
    lea  rdi, [rel msg_banner2]
    xor  eax, eax
    call printf

; -------- Primeiro número --------
get_first:
    lea  rdi, [rel msg_first]
    xor  eax, eax
    call printf

    lea  rdi, [rel fmt_double]
    lea  rsi, [rel acc]
    xor  eax, eax
    call scanf

; -------- Loop principal --------
calc_loop:
get_op:
    lea  rdi, [rel msg_nextop]
    xor  eax, eax
    call printf

    lea  rdi, [rel fmt_char]
    lea  rsi, [rel op]
    xor  eax, eax
    call scanf

    movzx eax, byte [op]
    cmp  al, 'q'
    je   quit_program

    cmp  al, '+'
    je   read_second
    cmp  al, '-'
    je   read_second
    cmp  al, '*'
    je   read_second
    cmp  al, '/'
    je   read_second

invalid_op:
    lea  rdi, [rel msg_badop]
    xor  eax, eax
    call printf
    jmp  calc_loop

read_second:
    lea  rdi, [rel msg_second]
    xor  eax, eax
    call printf

    lea  rdi, [rel fmt_double]
    lea  rsi, [rel temp]
    xor  eax, eax
    call scanf

    movq xmm0, [acc]
    movq xmm1, [temp]

    cmp  byte [op], '+'
    je   do_add
    cmp  byte [op], '-'
    je   do_sub
    cmp  byte [op], '*'
    je   do_mul

    ; divisão – testa zero
    movq rax, xmm1
    test rax, rax
    jz   div_zero
    jmp  do_div

do_add:  addsd xmm0, xmm1  jmp show_result
do_sub:  subsd xmm0, xmm1  jmp show_result
do_mul:  mulsd xmm0, xmm1  jmp show_result
do_div:  divsd xmm0, xmm1  jmp show_result

div_zero:
    lea  rdi, [rel msg_divzero]
    xor  eax, eax
    call printf
    jmp  read_second

show_result:
    movq [acc], xmm0
    lea  rdi, [rel fmt_out]
    mov  eax, 1
    call printf
    jmp  calc_loop

quit_program:
    lea  rdi, [rel msg_goodbye]
    xor  eax, eax
    call printf

    xor  edi, edi
    call exit
