; C:\M68KV6.0 - 800BY480 - (VERILOG) FOR STUDENTS 2\PROGRAMS\DEBUGMONITORCODE\MEMORY_TEST.C - Compiled by CC68K  Version 5.00 (c) 1991-2005  Peter J. Fondse
; #include <stdio.h>
; #define BaseAddr (unsigned long *) 0x820000
; #define BaseAddr1 (unsigned long *) 0x820000
; int main(void){
       section   code
       xdef      _main
_main:
; *BaseAddr = 5;
       move.l    #5,8519680
; *BaseAddr1 = 8;
       move.l    #8,8519680
; if ((*BaseAddr == 5) && (*BaseAddr1 == 8))
       move.l    8519680,D0
       cmp.l     #5,D0
       bne.s     main_1
       move.l    8519680,D0
       cmp.l     #8,D0
       bne.s     main_1
; {
; printf("\r\n memory w/r successful") ;
       pea       @memory~1_1.L
       jsr       _printf
       addq.w    #4,A7
       bra.s     main_2
main_1:
; } else {
; printf("\r\nmemory w/r failed") ;
       pea       @memory~1_2.L
       jsr       _printf
       addq.w    #4,A7
main_2:
; }
; return 0;
       clr.l     D0
       rts
; }
       section   const
@memory~1_1:
       dc.b      13,10,32,109,101,109,111,114,121,32,119,47,114
       dc.b      32,115,117,99,99,101,115,115,102,117,108,0
@memory~1_2:
       dc.b      13,10,109,101,109,111,114,121,32,119,47,114
       dc.b      32,102,97,105,108,101,100,0
       xref      _printf
