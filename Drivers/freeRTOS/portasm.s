%if %Compiler == "GNUC"
/* file is intentionally empty as not needed for this FreeRTOS port*/
%else
%if (CPUfamily = "ColdFireV1") | (CPUfamily = "MCF") | (CPUfamily = "Kinetis")
/*
    FreeRTOS V7.2.0 - Copyright (C) 2012 Real Time Engineers Ltd.

    ***************************************************************************
    *                                                                         *
    * If you are:                                                             *
    *                                                                         *
    *    + New to FreeRTOS,                                                   *
    *    + Wanting to learn FreeRTOS or multitasking in general quickly       *
    *    + Looking for basic training,                                        *
    *    + Wanting to improve your FreeRTOS skills and productivity           *
    *                                                                         *
    * then take a look at the FreeRTOS eBook                                  *
    *                                                                         *
    *        "Using the FreeRTOS Real Time Kernel - a Practical Guide"        *
    *                  http://www.FreeRTOS.org/Documentation                  *
    *                                                                         *
    * A pdf reference manual is also available.  Both are usually delivered   *
    * to your inbox within 20 minutes to two hours when purchased between 8am *
    * and 8pm GMT (although please allow up to 24 hours in case of            *
    * exceptional circumstances).  Thank you for your support!                *
    *                                                                         *
    ***************************************************************************

    This file is part of the FreeRTOS distribution.

    FreeRTOS is free software; you can redistribute it and/or modify it under
    the terms of the GNU General Public License (version 2) as published by the
    Free Software Foundation AND MODIFIED BY the FreeRTOS exception.
    ***NOTE*** The exception to the GPL is included to allow you to distribute
    a combined work that includes FreeRTOS without being obliged to provide the
    source code for proprietary components outside of the FreeRTOS kernel.
    FreeRTOS is distributed in the hope that it will be useful, but WITHOUT
    ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
    FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
    more details. You should have received a copy of the GNU General Public
    License and the FreeRTOS license exception along with FreeRTOS; if not it
    can be viewed here: http://www.freertos.org/a00114.html and also obtained
    by writing to Richard Barry, contact details for whom are available on the
    FreeRTOS WEB site.

    1 tab == 4 spaces!

    http://www.FreeRTOS.org - Documentation, latest information, license and
    contact details.

    http://www.SafeRTOS.com - A version that is certified for use in safety
    critical systems.

    http://www.OpenRTOS.com - Commercial support, development, porting,
    licensing and training services.
*/
%endif
%if (CPUfamily = "ColdFireV1") | (CPUfamily = "MCF")
/*
 * Purpose: Lowest level routines for all ColdFire processors.
 *
 * Notes:
 *
 * ulPortSetIPL() and mcf5xxx_wr_cacr() copied with permission from FreeScale
 * supplied source files.
 */

    .global ulPortSetIPL
    .global _ulPortSetIPL
    .global mcf5xxx_wr_cacrx
    .global _mcf5xxx_wr_cacrx
    .global vPortYieldISR
    .global _vPortYieldISR
    .global vPortStartFirstTask
    .global _vPortStartFirstTask
    .extern _pxCurrentTCB
    .extern _vPortYieldHandler

    .text

.macro portSAVE_CONTEXT
  lea.l                (-60, sp), sp
  movem.l              d0-a6, (sp)
  move.l               _pxCurrentTCB, a0
  move.l               sp, (a0)
  .endm

.macro portRESTORE_CONTEXT
  move.l               _pxCurrentTCB, a0
  move.l               (a0), sp
  movem.l              (sp), d0-a6
  lea.l                (60, sp), sp
  rte
  .endm
/********************************************************************/
/*
 * This routines changes the IPL to the value passed into the routine.
 * It also returns the old IPL value back.
 * Calling convention from C:
 *   old_ipl = asm_set_ipl(new_ipl);
 */
ulPortSetIPL:
_ulPortSetIPL:
  link    A6,#-8
  movem.l D6-D7,(SP)

  move.w  SR,D7           /* current sr    */

  move.l  D7,D6           /* prepare return value  */
  andi.l  #0x0700,D6      /* mask out IPL  */
  lsr.l   #8,D6           /* IPL   */

  andi.l  #0x07,D0        /* least significant three bits  */
  lsl.l   #8,D0           /* move over to make mask    */

  andi.l  #0x0000F8FF,D7  /* zero out current IPL  */
  or.l    D0,D7           /* place new IPL in sr   */
  move.w  D7,SR

  move.l  D6, D0          /* Return value in D0 */
  movem.l (SP),D6-D7
  lea     8(SP),SP
  unlk    A6
  rts
/********************************************************************/
mcf5xxx_wr_cacrx:
_mcf5xxx_wr_cacrx:
  move.l  4(sp),d0
  .long   0x4e7b0002  /* movec d0,cacr   */
  nop
  rts
/********************************************************************/
/* Yield interrupt. */
_vPortYieldISR:
vPortYieldISR:
  portSAVE_CONTEXT
  jsr _vPortYieldHandler
  portRESTORE_CONTEXT
/********************************************************************/
vPortStartFirstTask:
_vPortStartFirstTask:
  portRESTORE_CONTEXT
  .end
%-*****************************************************************************************************
%elif (CPUfamily = "Kinetis")
#include "FreeRTOSConfig.h"

/* For backward compatibility, ensure configKERNEL_INTERRUPT_PRIORITY is
   defined.  The value zero should also ensure backward compatibility.
   FreeRTOS.org versions prior to V4.3.0 did not include this definition. */
#ifndef configKERNEL_INTERRUPT_PRIORITY
  #define configKERNEL_INTERRUPT_PRIORITY 0
#endif

#define VECTOR_TABLE_OFFSET_REG     0xE000ED08 /* Vector Table Offset Register (VTOR) */
%if %M4FFloatingPointSupport='yes'
#define COPROCESSOR_ACCESS_REGISTER 0xE000ED88 /* Coprocessor Access Register (CPACR) */
%endif

  .text, code

  .extern vPortYieldFromISR
  .extern pxCurrentTCB
  .extern vTaskSwitchContext
  .extern vOnCounterRestart
  .extern vTaskIncrementTick

  .global vOnCounterRestart
  .global vSetMSP
  .global vPortPendSVHandler
  .global vPortSetInterruptMask
  .global vPortClearInterruptMask
  .global vPortSVCHandler
  .global vPortStartFirstTask
%if %M4FFloatingPointSupport='yes'
  .global vPortEnableVFP
%endif
/*-----------------------------------------------------------*/
vOnCounterRestart:
%if %CompilerOptimizationLevel='0'
  /* Compiler optimization level 0 */
  pop {lr,r3} /* remove stacked registers from the caller routine */
%else
  /* Compiler optimization level 1, 2, 3 or 4 */
  push {lr} /* need to save link register, it will be overwritten below */
%endif
%if %UsePreemption='yes'
  /* If using preemption, also force a context switch. */
  bl vPortYieldFromISR
%endif
  bl vPortSetInterruptMask /* disable interrupts */
  bl vTaskIncrementTick    /* increment tick count, might schedule a task */
  bl vPortClearInterruptMask /* enable interrupts again */
%if %CompilerOptimizationLevel='0'
  /* Compiler optimization level 0 */
  pop {lr,r4} /* start exit sequence from interrupt: r4 and lr where pushed in the ISR */
%else
  /* Compiler optimization level 1, 2, 3 or 4 */
  pop {lr}    /* restore pushed lr register */
%endif
  bx lr
  nop
/*-----------------------------------------------------------*/
vSetMSP:
  msr msp, r0
  bx lr
  nop
/*-----------------------------------------------------------*/
vPortPendSVHandler:
%if (defined(PEversionDecimal) && (PEversionDecimal >=0 '1282')) %- this is only supported with MCU 10.3
%else %- up to MCU10.2
%if %CompilerOptimizationLevel='0'
  /* Compiler optimization level 0 */
  pop {lr,r3}  /* remove stack frame for the call from Cpu.c to Events.c */
  pop {lr,r3}  /* remove stack frame for the call from Events.c to here */
%else
  /* Compiler optimization level 1, 2, 3 or 4: nothing special to do */
%endif
%endif %- MCU10.3
  mrs r0, psp

  /* Get the location of the current TCB */
  ldr r3, =pxCurrentTCB
  ldr r2, [r3] /* r2 points now to top-of-stack of the current task */

  /* Save the core registers */
%if %M4FFloatingPointSupport='yes'
  /* Is the task using the FPU context?  If so, push high vfp registers. */
  tst r14, #0x10
  it eq
  vstmdbeq r0!, {s16-s31}

  stmdb r0!, {r4-r11, r14} /* save remaining core registers */
%else
  stmdb r0!, {r4-r11} /* save remaining core registers */
%endif

  /* Save the new top of stack into the first member of the TCB */
  str r0, [r2]

  stmdb sp!, {r3, r14}
  mov r0, #configMAX_SYSCALL_INTERRUPT_PRIORITY
  msr basepri, r0
  bl vTaskSwitchContext
  mov r0, #0
  msr basepri, r0
  ldmia sp!, {r3, r14}

  /* The first item in pxCurrentTCB is the task top of stack. */
  ldr r1, [r3]
  ldr r0, [r1] /* r0 points now to the top-of-stack of the new task */

  /* Pop the registers. */
%if %M4FFloatingPointSupport='yes'
  ldmia r0!, {r4-r11, r14} /* Pop the core registers */
  /* Is the task using the FPU context?  If so, pop the high vfp registers too. */
  tst r14, #0x10
  it eq
  vldmiaeq r0!, {s16-s31}
%else
  ldmia r0!, {r4-r11} /* Pop the core registers */
%endif

  msr psp, r0
  bx r14
  nop
/*-----------------------------------------------------------*/
vPortSetInterruptMask:
  push {r0}
  mov r0, #configMAX_SYSCALL_INTERRUPT_PRIORITY
  msr BASEPRI, r0
  pop {r0}
  bx r14
  nop
/*-----------------------------------------------------------*/
vPortClearInterruptMask:
  push {r0}
  mov r0, #0
  msr BASEPRI, R0
  pop {r0}
  bx r14
  nop
/*-----------------------------------------------------------*/
vPortSVCHandler:
%if (defined(PEversionDecimal) && (PEversionDecimal >=0 '1282')) %- this is only supported with MCU 10.3
%else %- up to MCU10.2
%if %CompilerOptimizationLevel='0'
  /* compiler optimization level 0 */
  pop {lr,r3}  /* remove stack frame for the call from Cpu.c to Events.c */
  pop {lr,r3}  /* remove stack frame for the call from Events.c to here */
%else
  /* Compiler optimization level 1, 2, 3 or 4: nothing special to do */
%endif
%endif %- MCU10.3
  ldr r3, =pxCurrentTCB
  ldr r1, [r3]
  ldr r0, [r1] /* r0 points now to top-of-stack of the new task */

  /* pop the core registers */
%if %M4FFloatingPointSupport='yes'
  ldmia r0!, {r4-r11, r14}
%else
  ldmia r0!, {r4-r11}
%endif
  msr psp, r0
  mov r0, #0
  msr basepri, r0
%if %M4FFloatingPointSupport='no'
  orr r14, r14, #13
%endif
  bx r14
  nop
/*-----------------------------------------------------------*/
vPortStartFirstTask:
  /* Use the Vector Table Offset Register to locate the stack. */
  ldr r0, =VECTOR_TABLE_OFFSET_REG  /* (VTOR) 0xE000ED08 */
  ldr r0, [r0]
  ldr r0, [r0]
  /* Set the msp back to the start of the stack. */
  msr msp, r0
  /* Call SVC to start the first task. */
  svc 0
  nop
/*-----------------------------------------------------------*/
%if %M4FFloatingPointSupport='yes'
vPortEnableVFP:
  /* The FPU enable bits are in the CPACR. */
  ldr.w r0, =COPROCESSOR_ACCESS_REGISTER /* CAPCR, 0xE000ED88 */
  ldr r1, [r0]  /* read CAPR */

  /* Enable CP10 and CP11 coprocessors, then save back. */
  orr r1, r1, #(0xf<<20)
  str r1, [r0]   /* wait for store to complete */

  bx  r14
  nop
/*-----------------------------------------------------------*/
%endif
%else
; file is intentionally empty as not needed for this FreeRTOS port
%endif
%endif %- %Compiler = "GNUC"

