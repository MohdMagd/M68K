**********************************************************************************************************
* CSTART.ASM  -  C startup-code
*
*          Initialises the system prior to running the users main() program
*
*          1) Sets up the user program stack pointer
*          2) Switches to User mode in the 68000
*          3) Enables All Interrupts 1-7 on 68000
*          4) Copies all initialised C program variables from Rom to Ram prior to running main()
*
**********************************************************************************************************
                section CODE
                align


**********************************************************************************************************
* The Following ORG Statement marks the address of the start of the this CStart Program
*
* The debug Monitor and Flash Load and Program routines assume your program lives here
**********************************************************************************************************
                org       $08000000
start:          move.w    #$2000,SR             clear interrupts to enable all, move to supervisor mode

******************************************************************************************
* Set unitialised global variables to 0 at startup
******************************************************************************************
mainloop        movea.l   #BssStart,a0          point a0 to the start of the initialised data section held in ROM
                move.l    #BssLength,d0         figure out how many bytes of C program variables data to copy
                beq       go_main               if no data to copy go straight to program
Zeroinit        move.b    #0,(a0)+              copy the C program initialise variables from rom to ram
                subq.l    #1,d0
                bne       Zeroinit

*******************************************************************************************
* last minute initialisation before calling main
*******************************************************************************************

                move.l    #-1,__ungetbuf         required for use of scanf() etc in C programs
                clr.l     __allocp               used by malloc() in C
                move.l    #heap,__heap           pointer to free memory
go_main         jsr       _main
                bra       start

                section const                    compiler puts implicit and explicit constants here e.g. the string in printf("Hello world"); string, is part of code section as it can be put into ROM
                align


                section   data                  for global variables with explicit initialisation e.g. int i = 5
                align

*********************************************************************************************************************************************************
* Section for Initialised Data (in theory should be copied to Ram at startup) but is part of program code as we copy whole program to ram at startup
********************************************************************************************************************************************************

DataStart       equ       *
__ungetbuf:     ds.l      1                    ungetbuffer for stdio functions
__allocp:       ds.l      1                    start of free memory block list
__heap:         ds.l      1                    begin of free memory


                section   bss                  for uninitialised data set to zero e.g. static int i etc
                align

DataEnd         equ       *                    this label will equate to the address of the last byte of global variable in it
DataLength      equ       DataEnd-DataStart    length of data needed to copy to Ram on bootup

*********************************************************************************************************
* Section for uninitialised Data which is set to zero, i.e. we should set this space to zero at starup
*********************************************************************************************************
BssStart       equ       *

               section   heap                  area for dynamic memory allocation e.g. malloc() etc
               align

BssEnd         equ       *
BssLength      equ       BssEnd-BssStart       length of zeroed data needed to copy to Ram on bootup

*********************************************************************************************************
* Section for Heap
*********************************************************************************************************

heap           equ       *
               align
