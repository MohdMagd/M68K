; C:\IDE68K\OS EXAMPLES\EXAMPLE_1.C - Compiled by CC68K  Version 5.00 (c) 1991-2005  Peter J. Fondse
; /*
; * EXAMPLE_1.C
; *
; * This is a minimal program to verify multitasking.
; *
; * Two tasks are created, Task #1 prints "This is task 1", task #2 prints "This is task 2".
; *
; * However, simple and small as it is, there is a serious flaw in the program. The device
; * to print on is a shared resource! The error can be observed as sometimes printing of
; * task #2 is interrupted and the higher priority task #1 prints "This is task #1" in the
; * middle of "This is task #2". A mutex or semaphore would be required to synchronize both tasks.
; *
; */
; #include <ucos_ii.h>
; #include <stdio.h>
; #define STACKSIZE  256
; /* Stacks */
; OS_STK Task1Stk[STACKSIZE];
; OS_STK Task2Stk[STACKSIZE];
; /* Prototypes */
; void Task1(void *);
; void Task2(void *);
; void main(void)
; {
       section   code
       xdef      _main
_main:
; OSInit();
       jsr       _OSInit
; OSTaskCreate(Task1, OS_NULL, &Task1Stk[STACKSIZE], 10);
       pea       10
       lea       _Task1Stk.L,A0
       add.w     #512,A0
       move.l    A0,-(A7)
       clr.l     -(A7)
       pea       _Task1.L
       jsr       _OSTaskCreate
       add.w     #16,A7
; OSTaskCreate(Task2, OS_NULL, &Task2Stk[STACKSIZE], 11);
       pea       11
       lea       _Task2Stk.L,A0
       add.w     #512,A0
       move.l    A0,-(A7)
       clr.l     -(A7)
       pea       _Task2.L
       jsr       _OSTaskCreate
       add.w     #16,A7
; OSStart();
       jsr       _OSStart
       rts
; }
; void Task1(void *pdata)
; {
       xdef      _Task1
_Task1:
       link      A6,#0
; for (;;) {
Task1_1:
; printf("  This is Task #1\n");
       pea       @exampl~1_1.L
       jsr       _printf
       addq.w    #4,A7
; OSTimeDlyHMSM(0, 0, 1, 0);
       clr.l     -(A7)
       pea       1
       clr.l     -(A7)
       clr.l     -(A7)
       jsr       _OSTimeDlyHMSM
       add.w     #16,A7
       bra       Task1_1
; }
; }
; void Task2(void *pdata)
; {
       xdef      _Task2
_Task2:
       link      A6,#0
; for (;;) {
Task2_1:
; printf("    This is Task #2\n");
       pea       @exampl~1_2.L
       jsr       _printf
       addq.w    #4,A7
; OSTimeDlyHMSM(0, 0, 3, 0);
       clr.l     -(A7)
       pea       3
       clr.l     -(A7)
       clr.l     -(A7)
       jsr       _OSTimeDlyHMSM
       add.w     #16,A7
       bra       Task2_1
; }
; }
       section   const
@exampl~1_1:
       dc.b      32,32,84,104,105,115,32,105,115,32,84,97,115
       dc.b      107,32,35,49,10,0
@exampl~1_2:
       dc.b      32,32,32,32,84,104,105,115,32,105,115,32,84
       dc.b      97,115,107,32,35,50,10,0
       section   bss
       xdef      _Task1Stk
_Task1Stk:
       ds.b      512
       xdef      _Task2Stk
_Task2Stk:
       ds.b      512
       xref      _OSTimeDlyHMSM
       xref      _OSInit
       xref      _OSStart
       xref      _OSTaskCreate
       xref      _printf
