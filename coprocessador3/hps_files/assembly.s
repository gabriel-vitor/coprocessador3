.equ DELAY_CYCLES, 10               @ Número de ciclos de espera entre pulsos (reset/start)

.section .data
devmem_path: .asciz "/dev/mem"     @ Caminho para o dispositivo de memória física
LW_BRIDGE_BASE: .word 0xff200000      @ Endereço base da região leve do barramento (LW)
LW_BRIDGE_SPAN: .word 0x1000       @ Tamanho do espaço mapeado (4 KB)

.global data_in_ptr
data_in_ptr: .word 0               @ Armazena ponteiro para registrador de entrada da FPGA

.global data_out_ptr
data_out_ptr: .word 0              @ Armazena ponteiro para registrador de saída da FPGA

.global fd_mem
fd_mem: .space 4                   @ Armazena o descritor de arquivo de /dev/mem

.section .text

.global begin_hw
.global end_hw
.global send_data
.global read_results

.type begin_hw, %function
.type end_hw, %function
.type send_data, %function
.type read_results, %function

@ ===============================
@ Função: begin_hw
@ Inicializa o acesso à FPGA:
@ - Abre /dev/mem
@ - Faz mapeamento de memória
@ - Define ponteiros para os registradores da FPGA
@ ===============================
begin_hw:
    PUSH {r1-r7, lr}                   @ Salva registradores usados

    @ --- Abrir /dev/mem ---
    MOV r7, #5                         @ syscall open
    LDR r0, =devmem_path               @ ponteiro para "/dev/mem"
    MOV r1, #2                         @ flags O_RDWR
    MOV r2, #0                         @ mode (não usado)
    SVC 0                             @ chamada de sistema

    CMP r0, #0
    BLT fail_open                     @ erro ao abrir /dev/mem?

    MOV r4, r0                        @ salva fd em r4 (usado no mmap)
    LDR r1, =fd_mem
    STR r0, [r1]                     @ salva fd_mem = fd

    @ --- mmap2 para mapear memória ---
    MOV r7, #192                     @ syscall mmap2
    MOV r0, #0                      @ addr NULL (deixa SO escolher)
    LDR r1, =LW_BRIDGE_SPAN
    LDR r1, [r1]                    @ tamanho da região a mapear
    MOV r2, #3                      @ prot = PROT_READ | PROT_WRITE
    MOV r3, #1                      @ flags = MAP_SHARED
    MOV r4, r4                      @ fd (salvo após open)
    LDR r5, =LW_BRIDGE_BASE
    LDR r5, [r5]                    @ offset físico
    LSR r5, r5, #12                 @ offset >> 12 (em páginas de 4k)
    SVC 0                           @ syscall mmap2

    CMP r0, #-1
    BEQ fail_mmap                   @ falha no mmap

    @ --- Salva ponteiros para registradores de entrada e saída ---
    LDR r1, =data_in_ptr
    STR r0, [r1]                   @ data_in_ptr = endereço mapeado

    ADD r1, r0, #0x10              @ data_out está 16 bytes à frente
    LDR r2, =data_out_ptr
    STR r1, [r2]

    MOV r0, #0                     @ sucesso
    B end_init

fail_open:
    MOV r7, #1
    MOV r0, #1                     @ código de erro: falha ao abrir
    SVC 0
    B end_init

fail_mmap:
    MOV r7, #1
    MOV r0, #2                     @ código de erro: falha no mmap
    SVC 0

end_init:
    POP {r1-r7, lr}
    BX lr

@ ===============================
@ Função: end_hw
@ Encerra acesso à FPGA:
@ - Desfaz mapeamento de memória
@ - Fecha descritor de arquivo
@ ===============================
end_hw:
    PUSH {r4-r7, lr}

    @ Verifica se memória foi mapeada
    LDR r0, =data_in_ptr
    LDR r0, [r0]
    CMP r0, #0
    BEQ skip_munmap                   @ Se não mapeado, pula

    @ Desfaz mapeamento com munmap
    MOV r7, #91                       @ Código da syscall munmap
    LDR r1, =LW_BRIDGE_SPAN
    LDR r1, [r1]
    SVC 0

    @ Limpa os ponteiros
    MOV r4, #0
    LDR r5, =data_in_ptr
    STR r4, [r5]
    LDR r5, =data_out_ptr
    STR r4, [r5]

skip_munmap:
    @ Fecha /dev/mem se foi aberto
    LDR r0, =fd_mem
    LDR r0, [r0]
    CMP r0, #0
    BLE skip_close

    MOV r7, #6                       @ Código da syscall close
    SVC 0

    MOV r4, #-1                      @ Marca como fechado
    LDR r5, =fd_mem
    STR r4, [r5]

skip_close:
    MOV r0, #0                       @ Sucesso
    POP {r4-r7, lr}
    BX lr

@ ===============================
@ Função: send_data
@ Envia dados para a FPGA
@ Parâmetros: struct com a, b, opcode, size, scalar
@ ===============================
send_data:
    PUSH {r4-r11, lr}

    @ Carrega parâmetros da struct passada em R0
    LDR r4, [r0]         @ vetor a
    LDR r5, [r0, #4]     @ vetor b
    LDR r6, [r0, #8]     @ opcode
    LDR r7, [r0, #12]    @ size
    LDR r8, [r0, #16]    @ scalar

    @ Reset do módulo da FPGA
    LDR r2, =data_in_ptr
    LDR r2, [r2]
    MOV r9, #(1 << 29)
    STR r9, [r2]         @ Ativa reset
    MOV r0, #0
    STR r0, [r2]         @ Desativa (pulso)

    MOV r11, #DELAY_CYCLES
    BL delay_loop        @ Espera entre reset e start

    @ Sinal de start
    MOV r9, #(1 << 30)
    STR r9, [r2]
    MOV r0, #0
    STR r0, [r2]

    @ Envio de cada par de elementos (a[i], b[i]) com metadados
    MOV r9, #25          @ Total de elementos (5x5)
    MOV r10, #0          @ Índice

loop_send:
    CMP r10, r9
    BGE end_send

    LDRSB r0, [r4, r10]  @ a[i]
    LDRSB r1, [r5, r10]  @ b[i]
    LSL r1, r1, #8
    ORR r0, r0, r1       @ Combina A e B

    ORR r0, r0, r6, LSL #16
    ORR r0, r0, r7, LSL #19
    ORR r0, r0, r8, LSL #21

    PUSH {r0}
    MOV r1, #1
    BL sync_send
    POP {r0}

    ADD r10, r10, #1
    B loop_send

end_send:
    MOV r0, #0
    POP {r4-r11, lr}
    BX lr

@ ===============================
@ delay_loop: Pequeno atraso baseado em contagem
@ ===============================
delay_loop:
    SUBS r11, r11, #1
    BNE delay_loop
    BX lr

@ ===============================
@ Função: read_results
@ Lê os dados processados pela FPGA
@ Parâmetros:
@   r0 = ponteiro para resultado
@   r1 = ponteiro para overflow flag
@ ===============================
read_results:
    PUSH {r4-r7, lr}
    MOV r4, r0
    MOV r5, r1
    MOV r6, #25
    MOV r7, #0

.loop_recv:
    CMP r7, r6
    BGE .done

    MOV r0, r4
    ADD r0, r0, r7
    MOV r1, r5
    BL sync_receive

    CMP r0, #0
    BNE .error

    ADD r7, r7, #1
    B .loop_recv

.error:
    MOV r0, #1
    B .exit

.done:
    MOV r0, #0

.exit:
    POP {r4-r7, lr}
    BX lr

@ ===============================
@ Função: sync_send
@ Envia um valor para a FPGA
@ ===============================
sync_send:
    PUSH {r1-r4, lr}
    LDR r1, =data_in_ptr
    LDR r1, [r1]
    LDR r2, =data_out_ptr
    LDR r2, [r2]

    ORR r3, r0, #(1 << 31)
    STR r3, [r1]

.wait_ack_high_send:
    LDR r4, [r2]
    TST r4, #(1 << 31)
    BEQ .wait_ack_high_send

    MOV r3, #0
    STR r3, [r1]

.wait_ack_low_send:
    LDR r4, [r2]
    TST r4, #(1 << 31)
    BNE .wait_ack_low_send

    POP {r1-r4, lr}
    BX lr

@ ===============================
@ Função: sync_receive
@ Recebe um valor da FPGA 
@ ===============================
sync_receive:
    PUSH {r2-r5, lr}
    LDR r2, =data_in_ptr
    LDR r2, [r2]
    LDR r3, =data_out_ptr
    LDR r3, [r3]

    CMP r2, #0
    BEQ .sync_error
    CMP r3, #0
    BEQ .sync_error

    MOV r4, #(1 << 31)
    STR r4, [r2]

.wait_ack_high_recei:
    LDR r5, [r3]
    TST r5, #(1 << 31)
    BEQ .wait_ack_high_recei

    AND r4, r5, #0xFF
    STRB r4, [r0]

    LSR r4, r5, #30
    AND r4, r4, #1
    STRB r4, [r1]

    MOV r4, #0
    STR r4, [r2]

.wait_ack_low_recei:
    LDR r5, [r3]
    TST r5, #(1 << 31)
    BNE .wait_ack_low_recei

    MOV r0, #0
    B .sync_exit

.sync_error:
    MOV r0, #1

.sync_exit:
    POP {r2-r5, lr}
    BX lr
