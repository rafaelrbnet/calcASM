# Calculadora de Ponto Flutuante em Assembly x86-64

Projeto da disciplina __________ do IFSP – **Assembly NASM + SSE2**  
Autor: _____________________ • Prontuário: ________________

## 🧑‍🔧 Objetivo

Implementar uma calculadora interativa que:

1. Recebe um número `double` inicial  
2. Entra em loop recebendo `operador` (+ - * / | q) e um segundo número  
3. Executa a operação via **instruções SSE/SSE2**  
4. Exibe o resultado com **16 dígitos** e o reutiliza como acumulador  
5. Encerra com `q`  

Todos os requisitos do enunciado anexo foram atendidos :contentReference[oaicite:0]{index=0}&#8203;:contentReference[oaicite:1]{index=1}.

## 🗂️ Estrutura do Repositório

| Arquivo            | Descrição                                                      |
|--------------------|----------------------------------------------------------------|
| `calc.asm`         | Código-fonte principal, totalmente comentado                   |
| `README.md`        | Este guia de uso                                               |
| `fluxo.md`         | Fluxograma (Mermaid) do algoritmo                              |
| `relatorio_final.md` | Relato técnico: decisões, bugs encontrados, resultados       |

## ⚙️ Compilação e Execução

```bash
# Montagem (gera objeto ELF64 com debug)
nasm -f elf64 -g -F dwarf calc.asm -o calc.o

# Linkagem contra libc (+símbolos, sem PIE)
gcc -g -no-pie calc.o -o calc

# Execução
./calc
```
Para depurar com GDB:

```bash
gdb ./calc
(gdb) display $xmm0.v2_double   # mostra conteúdo do registrador XMM0
(gdb) run
```
Importante: Todas as chamadas variádicas (printf/scanf) recebem pilha alinhada a 16 bytes, conforme a ABI System V AMD64.

## 📋 Requisitos Atendidos
* Arquitetura x86-64, Linux 64 bits  
* Sintaxe NASM  
* Operações: addsd, subsd, mulsd, divsd  
* Precisão IEEE-754 64 bits (SSE2)  
* Interface via scanf/printf (libc)  
* Loop com saída em 'q'  
* Tratamento de divisão por zero  
* Fluxograma entregue em Mermaid  


---

## `fluxo.md` (Mermaid)

<!-- fluxo.md -->

```mermaid
flowchart TD
    A[Start] --> B[Ler primeiro numero]
    B --> C{Operador == q?}
    C -->|Sim| Z[Fim]
    C -->|Nao| D[Ler operador]
    D --> E[Ler segundo numero]
    E --> F{Tipo de operacao}
    F -->|+| G[addsd]
    F -->|-| H[subsd]
    F -->|*| I[mulsd]
    F -->|/| J{Divisor zero?}
    J -->|Sim| K[Erro: divisor zero]
    K --> E
    J -->|Nao| L[divsd]
    G --> M[Guarda em acc]
    H --> M
    I --> M
    L --> M
    M --> N[printf resultado]
    N --> C
```



