; C:\M68K\PROGRAMS\DEBUGMONITORCODE\IIC EEPROM PROGRAM FILES\M68KUSERPROGRAM (DE1).C - Compiled by CC68K  Version 5.00 (c) 1991-2005  Peter J. Fondse
; #include <stdio.h>
; /*********************************************************************************************
; **  RS232 port addresses
; *********************************************************************************************/
; #define RS232_Control     *(volatile unsigned char *)(0x00400040)
; #define RS232_Status      *(volatile unsigned char *)(0x00400040)
; #define RS232_TxData      *(volatile unsigned char *)(0x00400042)
; #define RS232_RxData      *(volatile unsigned char *)(0x00400042)
; #define RS232_Baud        *(volatile unsigned char *)(0x00400044)
; /*********************************************************************************************
; **  IIC registers
; *********************************************************************************************/
; #define PRERlo *(volatile unsigned char *)(0x00408000) // Clock Prescale register lo-byte
; #define PRERhi *(volatile unsigned char *)(0x00408002) // Clock Prescale register hi-byte
; #define CTR *(volatile unsigned char *)(0x00408004) // Control Register
; #define TXR *(volatile unsigned char *)(0x00408006) // Transmit Register
; #define RXR *(volatile unsigned char *)(0x00408006) // Receive Register
; #define CR *(volatile unsigned char *)(0x00408008) // Command Register
; #define SR *(volatile unsigned char *)(0x00408008) // Status Register
; #define startWrite  0x90
; #define startRead   0xA8
; #define stop        0x41
; /*********************************************************************************************
; **  Function protoTypes
; *********************************************************************************************/
; void writeByteToChip(char c);
; char readByteFromChip(void);
; void waitForTXByte(void);
; void waitForReceivedByte(void);
; int checkForACK(void);
; void IIC_Init(void);
; int _getch( void )
; {
       section   code
       xdef      __getch
__getch:
       link      A6,#-4
; char c ;
; while((RS232_Status & (char)(0x01)) != (char)(0x01))    // wait for Rx bit in 6850 serial comms chip status register to be '1'
_getch_1:
       move.b    4194368,D0
       and.b     #1,D0
       cmp.b     #1,D0
       beq.s     _getch_3
       bra       _getch_1
_getch_3:
; ;
; return (RS232_RxData & (char)(0x7f));                   // read received character, mask off top bit and return as 7 bit ASCII character
       move.b    4194370,D0
       and.l     #255,D0
       and.l     #127,D0
       unlk      A6
       rts
; }
; int _putch( int c)
; {
       xdef      __putch
__putch:
       link      A6,#0
; while((RS232_Status & (char)(0x02)) != (char)(0x02))    // wait for Tx bit in status register or 6850 serial comms chip to be '1'
_putch_1:
       move.b    4194368,D0
       and.b     #2,D0
       cmp.b     #2,D0
       beq.s     _putch_3
       bra       _putch_1
_putch_3:
; ;
; RS232_TxData = (c & (char)(0x7f));                      // write to the data register to output the character (mask off bit 8 to keep it 7 bit ASCII)
       move.l    8(A6),D0
       and.l     #127,D0
       move.b    D0,4194370
; return c ;                                              // putchar() expects the character to be returned
       move.l    8(A6),D0
       unlk      A6
       rts
; }
; /*********************************************************************************************
; **  Write Byte to EEPROM Chip
; *********************************************************************************************/
; void writeByteToChip(char c){
       xdef      _writeByteToChip
_writeByteToChip:
       link      A6,#0
       movem.l   D2/A2/A3,-(A7)
       lea       _waitForTXByte.L,A2
       lea       _checkForACK.L,A3
; int checkACKFlag = 0;
       clr.l     D2
; waitForTXByte();
       jsr       (A2)
; while(checkACKFlag != 1){
writeByteToChip_1:
       cmp.l     #1,D2
       beq.s     writeByteToChip_3
; TXR = 0xA0; // Write Control Byte
       move.b    #160,4227078
; CR = startWrite;
       move.b    #144,4227080
; waitForTXByte();
       jsr       (A2)
; checkACKFlag = checkForACK();
       jsr       (A3)
       move.l    D0,D2
       bra       writeByteToChip_1
writeByteToChip_3:
; }
; checkACKFlag = 0;
       clr.l     D2
; while(checkACKFlag != 1){
writeByteToChip_4:
       cmp.l     #1,D2
       beq.s     writeByteToChip_6
; TXR = 0x00; // Address Byte 1
       clr.b     4227078
; waitForTXByte();
       jsr       (A2)
; checkACKFlag = checkForACK();
       jsr       (A3)
       move.l    D0,D2
       bra       writeByteToChip_4
writeByteToChip_6:
; }
; checkACKFlag = 0;
       clr.l     D2
; while(checkACKFlag != 1){
writeByteToChip_7:
       cmp.l     #1,D2
       beq.s     writeByteToChip_9
; TXR = 0x00; // Address Byte 2
       clr.b     4227078
; waitForTXByte();
       jsr       (A2)
; checkACKFlag = checkForACK();
       jsr       (A3)
       move.l    D0,D2
       bra       writeByteToChip_7
writeByteToChip_9:
; }
; checkACKFlag = 0;
       clr.l     D2
; while(checkACKFlag != 1){
writeByteToChip_10:
       cmp.l     #1,D2
       beq.s     writeByteToChip_12
; TXR = c;    // send 1 byte of data
       move.b    11(A6),4227078
; waitForTXByte();
       jsr       (A2)
; checkACKFlag = checkForACK();
       jsr       (A3)
       move.l    D0,D2
       bra       writeByteToChip_10
writeByteToChip_12:
; }
; CR = stop;
       move.b    #65,4227080
       movem.l   (A7)+,D2/A2/A3
       unlk      A6
       rts
; }
; /*********************************************************************************************
; **  Read Byte from EEPROM flash
; *********************************************************************************************/
; char readByteFromChip(void){
       xdef      _readByteFromChip
_readByteFromChip:
       link      A6,#-4
       movem.l   D2/A2/A3,-(A7)
       lea       _checkForACK.L,A2
       lea       _waitForTXByte.L,A3
; int checkACKFlag = 0;
       clr.l     D2
; char receivedByte;
; while(checkACKFlag != 1){
readByteFromChip_1:
       cmp.l     #1,D2
       beq.s     readByteFromChip_3
; TXR = 0xA0; // Write Control Byte
       move.b    #160,4227078
; CR = startWrite;
       move.b    #144,4227080
; waitForTXByte();
       jsr       (A3)
; checkACKFlag = checkForACK();
       jsr       (A2)
       move.l    D0,D2
       bra       readByteFromChip_1
readByteFromChip_3:
; }
; checkACKFlag = 0;
       clr.l     D2
; while(checkACKFlag != 1){
readByteFromChip_4:
       cmp.l     #1,D2
       beq.s     readByteFromChip_6
; TXR = 0x00; // Address Byte 1
       clr.b     4227078
; waitForTXByte();
       jsr       (A3)
; checkACKFlag = checkForACK();
       jsr       (A2)
       move.l    D0,D2
       bra       readByteFromChip_4
readByteFromChip_6:
; }
; checkACKFlag = 0;
       clr.l     D2
; while(checkACKFlag != 1){
readByteFromChip_7:
       cmp.l     #1,D2
       beq.s     readByteFromChip_9
; TXR = 0x00; // Address Byte 2
       clr.b     4227078
; waitForTXByte();
       jsr       (A3)
; checkACKFlag = checkForACK();
       jsr       (A2)
       move.l    D0,D2
       bra       readByteFromChip_7
readByteFromChip_9:
; }
; while(checkACKFlag != 1){
readByteFromChip_10:
       cmp.l     #1,D2
       beq.s     readByteFromChip_12
; TXR = 0xA1; // Read Control Byte
       move.b    #161,4227078
; CR = startRead;
       move.b    #168,4227080
; waitForTXByte();
       jsr       (A3)
; checkACKFlag = checkForACK();
       jsr       (A2)
       move.l    D0,D2
       bra       readByteFromChip_10
readByteFromChip_12:
; }
; waitForReceivedByte();
       jsr       _waitForReceivedByte
; receivedByte = RXR;
       move.b    4227078,-1(A6)
; CR = stop;
       move.b    #65,4227080
; return receivedByte;
       move.b    -1(A6),D0
       movem.l   (A7)+,D2/A2/A3
       unlk      A6
       rts
; }
; /*********************************************************************************************
; ** Probe SR register to check if TIP bit is clear
; *********************************************************************************************/
; void waitForTXByte(void){
       xdef      _waitForTXByte
_waitForTXByte:
; while ((SR & 0x02) >> 1 == 1);
waitForTXByte_1:
       move.b    4227080,D0
       and.b     #2,D0
       lsr.b     #1,D0
       cmp.b     #1,D0
       bne.s     waitForTXByte_3
       bra       waitForTXByte_1
waitForTXByte_3:
       rts
; }
; /*********************************************************************************************
; ** Probe RX register to check if it has received data from slave
; *********************************************************************************************/
; void waitForReceivedByte(void){
       xdef      _waitForReceivedByte
_waitForReceivedByte:
; while ((SR & 0x01) == 0);
waitForReceivedByte_1:
       move.b    4227080,D0
       and.b     #1,D0
       bne.s     waitForReceivedByte_3
       bra       waitForReceivedByte_1
waitForReceivedByte_3:
       rts
; }
; /*********************************************************************************************
; ** Probe Status Register to check if slave has ACKed
; *********************************************************************************************/
; int checkForACK(void){
       xdef      _checkForACK
_checkForACK:
; if ((SR & 0x80) >> 7)
       move.b    4227080,D0
       and.w     #255,D0
       and.w     #128,D0
       asr.w     #7,D0
       tst.w     D0
       beq.s     checkForACK_1
; return 0;
       clr.l     D0
       bra.s     checkForACK_3
checkForACK_1:
; else return 1;
       moveq     #1,D0
checkForACK_3:
       rts
; }
; /*********************************************************************************************
; ** Initialize IIC Communication
; *********************************************************************************************/
; void IIC_Init(void){
       xdef      _IIC_Init
_IIC_Init:
; // Set Clock Frequency to 100kHz as per page 7 of in IIC controller Document
; CTR = 0x00; // Clear EN bit to set clock value first
       clr.b     4227076
; PRERlo = 0x32;
       move.b    #50,4227072
; PRERhi = 0x00;
       clr.b     4227074
; // Enable EN bit (core is disable) & Disable IEN bit (interrupts disable)
; CTR = 0x80;
       move.b    #128,4227076
       rts
; }
; void main(void)
; {
       xdef      _main
_main:
       link      A6,#-4
       movem.l   D2/A2,-(A7)
       lea       _printf.L,A2
; char sendByte = 's';
       moveq     #115,D2
; char recievedByte;
; scanflush() ;                       // flush any text that may have been typed ahead
       jsr       _scanflush
; printf("\r\nHello CPEN 412 Student\r\nWelcome to Lab3!!!\r\n");
       pea       @m68kus~1_1.L
       jsr       (A2)
       addq.w    #4,A7
; IIC_Init();
       jsr       _IIC_Init
; writeByteToChip(sendByte);
       ext.w     D2
       ext.l     D2
       move.l    D2,-(A7)
       jsr       _writeByteToChip
       addq.w    #4,A7
; recievedByte = readByteFromChip();
       jsr       _readByteFromChip
       move.b    D0,-1(A6)
; printf("This is the sent Byte: %c\r\n", sendByte);
       ext.w     D2
       ext.l     D2
       move.l    D2,-(A7)
       pea       @m68kus~1_2.L
       jsr       (A2)
       addq.w    #8,A7
; printf("This is the received Byte: %c\r\n", recievedByte);
       move.b    -1(A6),D1
       ext.w     D1
       ext.l     D1
       move.l    D1,-(A7)
       pea       @m68kus~1_3.L
       jsr       (A2)
       addq.w    #8,A7
; while(1);
main_1:
       bra       main_1
; // programs should NOT exit as there is nothing to Exit TO !!!!!!
; // There is no OS - just press the reset button to end program and call debug
; }
       section   const
@m68kus~1_1:
       dc.b      13,10,72,101,108,108,111,32,67,80,69,78,32,52
       dc.b      49,50,32,83,116,117,100,101,110,116,13,10,87
       dc.b      101,108,99,111,109,101,32,116,111,32,76,97,98
       dc.b      51,33,33,33,13,10,0
@m68kus~1_2:
       dc.b      84,104,105,115,32,105,115,32,116,104,101,32
       dc.b      115,101,110,116,32,66,121,116,101,58,32,37,99
       dc.b      13,10,0
@m68kus~1_3:
       dc.b      84,104,105,115,32,105,115,32,116,104,101,32
       dc.b      114,101,99,101,105,118,101,100,32,66,121,116
       dc.b      101,58,32,37,99,13,10,0
       xref      _scanflush
       xref      _printf
