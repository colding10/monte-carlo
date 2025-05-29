.section .data
    prompt_degree:   .string "Enter polynomial degree: "
    prompt_coeff:    .string "Enter coefficient for x^%d: "
    prompt_bounds:   .string "Enter integration bounds (a b): "
    prompt_samples:  .string "Enter number of samples: "
    result_msg:      .string "Integral result: %.6f\n"
    scanf_int:       .string "%d"
    scanf_double:    .string "%lf"
    scanf_two_double: .string "%lf %lf"
    
    # Floating point constants
    .align 8
    fp_one:          .quad 0x3FF0000000000000    # 1.0 in IEEE 754
    fp_rand_max:     .quad 0x41DFFFFFFFC00000    # 2147483647.0

.section .bss
    .align 8
    coefficients:    .space 800    # Space for up to 100 coefficients
    degree:          .space 4
    num_samples:     .space 4
    lower_bound:     .space 8
    upper_bound:     .space 8
    temp_coeff:      .space 8

.section .text
.global main

main:
    push %rbp
    mov %rsp, %rbp
    
    # Get polynomial degree
    mov $prompt_degree, %rdi
    xor %rax, %rax
    call printf
    
    mov $scanf_int, %rdi
    mov $degree, %rsi
    xor %rax, %rax
    call scanf
    
    # Read coefficients
    xor %r12, %r12                  # counter for coefficients
    
read_coefficients:
    mov degree(%rip), %eax
    cmp %eax, %r12d
    jg bounds_input
    
    mov $prompt_coeff, %rdi
    mov %r12d, %esi
    xor %rax, %rax
    call printf
    
    mov $scanf_double, %rdi
    mov $temp_coeff, %rsi
    xor %rax, %rax
    call scanf
    
    # Store coefficient in array
    mov %r12, %rax
    shl $3, %rax                    # multiply by 8 (size of double)
    movsd temp_coeff(%rip), %xmm0
    movsd %xmm0, coefficients(%rax)
    
    inc %r12d
    jmp read_coefficients

bounds_input:
    # Get integration bounds
    mov $prompt_bounds, %rdi
    xor %rax, %rax
    call printf
    
    mov $scanf_two_double, %rdi
    mov $lower_bound, %rsi
    mov $upper_bound, %rdx
    xor %rax, %rax
    call scanf
    
    # Get number of samples
    mov $prompt_samples, %rdi
    xor %rax, %rax
    call printf
    
    mov $scanf_int, %rdi
    mov $num_samples, %rsi
    xor %rax, %rax
    call scanf
    
    # Initialize random seed
    xor %rdi, %rdi
    call time
    mov %rax, %rdi
    call srand
    
    # Perform Monte Carlo integration
    call monte_carlo_integrate
    
    # Print result (result is in xmm0)
    mov $result_msg, %rdi
    mov $1, %rax                    # 1 XMM register used
    call printf
    
    # Return 0
    xor %rax, %rax
    pop %rbp
    ret

# Monte Carlo integration function
monte_carlo_integrate:
    push %rbp
    mov %rsp, %rbp
    
    pxor %xmm0, %xmm0              # sum = 0.0
    xor %r13, %r13                  # sample counter
    
    # Calculate range = upper_bound - lower_bound
    movsd upper_bound(%rip), %xmm1
    movsd lower_bound(%rip), %xmm2
    subsd %xmm2, %xmm1             # xmm1 = range
    
monte_carlo_loop:
    mov num_samples(%rip), %eax
    cmp %eax, %r13d
    jge monte_carlo_done
    
    # Generate random x in [lower_bound, upper_bound]
    call rand
    cvtsi2sd %eax, %xmm3           # convert to double
    movsd fp_rand_max(%rip), %xmm4 # load RAND_MAX as double
    divsd %xmm4, %xmm3             # normalize to [0,1]
    mulsd %xmm1, %xmm3             # scale to range
    addsd %xmm2, %xmm3             # add lower_bound
    
    # Evaluate polynomial at x
    call evaluate_polynomial        # result in xmm5
    
    # Add to sum
    addsd %xmm5, %xmm0
    
    inc %r13d
    jmp monte_carlo_loop

monte_carlo_done:
    # Calculate final result: sum * range / num_samples
    mulsd %xmm1, %xmm0             # multiply by range
    cvtsi2sd num_samples(%rip), %xmm6
    divsd %xmm6, %xmm0             # divide by number of samples
    
    pop %rbp
    ret

# Evaluate polynomial at x (x in xmm3, result in xmm5)
evaluate_polynomial:
    push %rbp
    mov %rsp, %rbp
    
    pxor %xmm5, %xmm5              # result = 0.0
    movsd fp_one(%rip), %xmm7      # x_power = 1.0
    xor %r15, %r15                  # degree counter
    
eval_loop:
    mov degree(%rip), %eax
    cmp %eax, %r15d
    jg eval_done
    
    # Get coefficient
    mov %r15, %rax
    shl $3, %rax
    movsd coefficients(%rax), %xmm6
    
    # Add coefficient * x_power to result
    mulsd %xmm7, %xmm6
    addsd %xmm6, %xmm5
    
    # Update x_power *= x
    mulsd %xmm3, %xmm7
    
    inc %r15d
    jmp eval_loop
    
eval_done:
    pop %rbp
    ret

# External C library functions
.extern printf
.extern scanf
.extern rand
.extern srand
.extern time
