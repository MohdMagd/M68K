; C:\M68K\PROGRAMS\DEBUGMONITORCODE\IIC EEPROM PROGRAM FILES\M68KUSERPROGRAM (DE1).C - Compiled by CC68K  Version 5.00 (c) 1991-2005  Peter J. Fondse
; #include <stdio.h>
; #include <time.h>
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
; #define PRERlo  (*(volatile unsigned char *)(0x00408000)) // Clock Prescale register lo-byte
; #define PRERhi  (*(volatile unsigned char *)(0x00408002)) // Clock Prescale register hi-byte
; #define CTR     (*(volatile unsigned char *)(0x00408004)) // Control Register
; #define TXR     (*(volatile unsigned char *)(0x00408006)) // Transmit Register
; #define RXR     (*(volatile unsigned char *)(0x00408006)) // Receive Register
; #define CR      (*(volatile unsigned char *)(0x00408008)) // Command Register
; #define SR      (*(volatile unsigned char *)(0x00408008)) // Status Register
; // Sequence Start & Stop Register Commands
; #define start           0x80    // Set STA bit              --> (1000 0000)
; #define stop            0x40    // Set STO bit              --> (0100 0000)
; // Write Command Register Commands
; #define startWrite      0x90    // set STA, WR bit          --> (1001 0000)
; #define Write           0x10    // set WR bit               --> (0001 0000)
; #define read            0x20    // set RD bit               --> (0010 0000)
; #define NACK            0x08    // Set ACK bit              --> (0000 1000)
; #define ReadNACK        0x28    // Set RD, ACK bits         --> (0010 1000)
; #define ReadNACKIACK    0x29    // Set RD, ACK, IACK bits   --> (0010 1001)
; #define stopWrite       0x50    // set STO, WR bit          --> (0101 0000)
; // Read Command Register Commands
; #define startRead       0xA8    // set STA, RD, ACK bit     --> (1010 1000)
; #define stopRead        0x41    // set STO, IACK bit        --> (0100 0001)
; /*********************************************************************************************
; **  Function protoTypes
; *********************************************************************************************/
; void WriteByteToChip(char c);
; char ReadByteFromChip(void);
; void WaitForTXByte(void);
; void WaitForReceivedByte(void);
; int CheckForACK(void);
; void IIC_Init(void);
; void WaitForWriteCycle(void);
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
; void WriteByteToChip(char c){
       xdef      _WriteByteToChip
_WriteByteToChip:
       link      A6,#0
       movem.l   A2/A3/A4,-(A7)
       lea       _WaitForTXByte.L,A2
       lea       _CheckForACK.L,A3
       lea       _printf.L,A4
; // Ensure TX is ready before sending control byte
; WaitForTXByte();
       jsr       (A2)
; TXR = 0xA0;         // Write Control Byte (1010 0000)
       move.b    #160,4227078
; CR = startWrite;    // Set STA bit, set WR bit
       move.b    #144,4227080
; WaitForTXByte();
       jsr       (A2)
; printf("ACK = %d\r\n", CheckForACK());
       move.l    D0,-(A7)
       jsr       (A3)
       move.l    D0,D1
       move.l    (A7)+,D0
       move.l    D1,-(A7)
       pea       @m68kus~1_1.L
       jsr       (A4)
       addq.w    #8,A7
; TXR = 0x20;         // Address Byte 1
       move.b    #32,4227078
; CR = Write;         // Set WR bit
       move.b    #16,4227080
; WaitForTXByte();
       jsr       (A2)
; printf("ACK = %d\r\n", CheckForACK());
       move.l    D0,-(A7)
       jsr       (A3)
       move.l    D0,D1
       move.l    (A7)+,D0
       move.l    D1,-(A7)
       pea       @m68kus~1_1.L
       jsr       (A4)
       addq.w    #8,A7
; TXR = 0x00;         // Address Byte 2
       clr.b     4227078
; CR = Write;         // Set WR bit
       move.b    #16,4227080
; WaitForTXByte();
       jsr       (A2)
; printf("ACK = %d\r\n", CheckForACK());
       move.l    D0,-(A7)
       jsr       (A3)
       move.l    D0,D1
       move.l    (A7)+,D0
       move.l    D1,-(A7)
       pea       @m68kus~1_1.L
       jsr       (A4)
       addq.w    #8,A7
; TXR = c;            // send 1 byte of data
       move.b    11(A6),4227078
; CR = Write;
       move.b    #16,4227080
; WaitForTXByte();
       jsr       (A2)
; printf("ACK = %d\r\n", CheckForACK());
       move.l    D0,-(A7)
       jsr       (A3)
       move.l    D0,D1
       move.l    (A7)+,D0
       move.l    D1,-(A7)
       pea       @m68kus~1_1.L
       jsr       (A4)
       addq.w    #8,A7
; CR = stop;
       move.b    #64,4227080
; WaitForWriteCycle();
       jsr       _WaitForWriteCycle
       movem.l   (A7)+,A2/A3/A4
       unlk      A6
       rts
; }
; /*********************************************************************************************
; ** Wait For EEPROM to complete internal Write Cycle
; *********************************************************************************************/
; void WaitForWriteCycle(void){
       xdef      _WaitForWriteCycle
_WaitForWriteCycle:
; do
; {
WaitForWriteCycle_1:
; TXR = 0xA0; // Write Control Byte (1010 0000)
       move.b    #160,4227078
; CR = start;
       move.b    #128,4227080
; printf("Waiting for Internal Byte Write!\r\n");
       pea       @m68kus~1_2.L
       jsr       _printf
       addq.w    #4,A7
       lea       _CheckForACK.L,A0
       move.l    A0,D0
       beq       WaitForWriteCycle_1
; } while (!CheckForACK);
; printf("Internal Byte Write Complete!\r\n");
       pea       @m68kus~1_3.L
       jsr       _printf
       addq.w    #4,A7
; return;
       rts
; }
; /*********************************************************************************************
; **  Read Byte from EEPROM flash
; *********************************************************************************************/
; char ReadByteFromChip(void){
       xdef      _ReadByteFromChip
_ReadByteFromChip:
       link      A6,#-4
       movem.l   A2/A3/A4,-(A7)
       lea       _WaitForTXByte.L,A2
       lea       _CheckForACK.L,A3
       lea       _printf.L,A4
; char receivedByte;
; // Ensure TX is ready before sending control byte
; WaitForTXByte();
       jsr       (A2)
; TXR = 0xA0;         // Write Control Byte (1010 0000)
       move.b    #160,4227078
; CR = startWrite;    // set STA bit
       move.b    #144,4227080
; WaitForTXByte();
       jsr       (A2)
; printf("ACK = %d\r\n", CheckForACK());
       move.l    D0,-(A7)
       jsr       (A3)
       move.l    D0,D1
       move.l    (A7)+,D0
       move.l    D1,-(A7)
       pea       @m68kus~1_1.L
       jsr       (A4)
       addq.w    #8,A7
; TXR = 0x20;         // Address Byte 1
       move.b    #32,4227078
; CR = Write;         // set WR bit
       move.b    #16,4227080
; WaitForTXByte();
       jsr       (A2)
; printf("ACK = %d\r\n", CheckForACK());
       move.l    D0,-(A7)
       jsr       (A3)
       move.l    D0,D1
       move.l    (A7)+,D0
       move.l    D1,-(A7)
       pea       @m68kus~1_1.L
       jsr       (A4)
       addq.w    #8,A7
; TXR = 0x00;         // Address Byte 2
       clr.b     4227078
; CR = Write;         // set WR bit
       move.b    #16,4227080
; WaitForTXByte();
       jsr       (A2)
; printf("ACK = %d\r\n", CheckForACK());
       move.l    D0,-(A7)
       jsr       (A3)
       move.l    D0,D1
       move.l    (A7)+,D0
       move.l    D1,-(A7)
       pea       @m68kus~1_1.L
       jsr       (A4)
       addq.w    #8,A7
; TXR = 0xA1;         // Read Control Byte (1010 0001)
       move.b    #161,4227078
; CR = startWrite;    // Set STA bit, WR bit
       move.b    #144,4227080
; WaitForTXByte();
       jsr       (A2)
; printf("ACK = %d\r\n", CheckForACK());
       move.l    D0,-(A7)
       jsr       (A3)
       move.l    D0,D1
       move.l    (A7)+,D0
       move.l    D1,-(A7)
       pea       @m68kus~1_1.L
       jsr       (A4)
       addq.w    #8,A7
; CR = ReadNACKIACK;
       move.b    #41,4227080
; WaitForReceivedByte();
       jsr       _WaitForReceivedByte
; receivedByte = RXR;
       move.b    4227078,-1(A6)
; CR = stop;
       move.b    #64,4227080
; return receivedByte;
       move.b    -1(A6),D0
       movem.l   (A7)+,A2/A3/A4
       unlk      A6
       rts
; }
; /*********************************************************************************************
; ** Probe SR register to check if TIP bit is clear
; *********************************************************************************************/
; void WaitForTXByte(void){
       xdef      _WaitForTXByte
_WaitForTXByte:
; while ((SR & 0x02) >> 1 == 1);
WaitForTXByte_1:
       move.b    4227080,D0
       and.b     #2,D0
       lsr.b     #1,D0
       cmp.b     #1,D0
       bne.s     WaitForTXByte_3
       bra       WaitForTXByte_1
WaitForTXByte_3:
       rts
; }
; /*********************************************************************************************
; ** Probe RX register to check if it has received data from slave
; *********************************************************************************************/
; void WaitForReceivedByte(void){
       xdef      _WaitForReceivedByte
_WaitForReceivedByte:
; while ((SR & 0x01) == 0);
WaitForReceivedByte_1:
       move.b    4227080,D0
       and.b     #1,D0
       bne.s     WaitForReceivedByte_3
       bra       WaitForReceivedByte_1
WaitForReceivedByte_3:
       rts
; }
; /*********************************************************************************************
; ** Probe Status Register to check if slave has ACKed
; Returns 0 of not ACKed and 1 if ACKed
; *********************************************************************************************/
; int CheckForACK(void){
       xdef      _CheckForACK
_CheckForACK:
; if ((SR & 0x80)>> 7 == 1)
       move.b    4227080,D0
       and.w     #255,D0
       and.w     #128,D0
       asr.w     #7,D0
       cmp.w     #1,D0
       bne.s     CheckForACK_1
; return 0;
       clr.l     D0
       bra.s     CheckForACK_3
CheckForACK_1:
; else return 1;
       moveq     #1,D0
CheckForACK_3:
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
; PRERlo = 0x31;
       move.b    #49,4227072
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
; char sendByte = 72;
       moveq     #72,D2
; char recievedByte;
; scanflush() ;                       // flush any text that may have been typed ahead
       jsr       _scanflush
; printf("\r\nHello IIC Lab\r\n");
       pea       @m68kus~1_4.L
       jsr       (A2)
       addq.w    #4,A7
; IIC_Init();
       jsr       _IIC_Init
; WriteByteToChip(sendByte);
       ext.w     D2
       ext.l     D2
       move.l    D2,-(A7)
       jsr       _WriteByteToChip
       addq.w    #4,A7
; recievedByte = ReadByteFromChip();
       jsr       _ReadByteFromChip
       move.b    D0,-1(A6)
; printf("This is the sent Byte: %u\r\n", sendByte);
       ext.w     D2
       ext.l     D2
       move.l    D2,-(A7)
       pea       @m68kus~1_5.L
       jsr       (A2)
       addq.w    #8,A7
; printf("This is the received Byte: %u\r\n", recievedByte);
       move.b    -1(A6),D1
       ext.w     D1
       ext.l     D1
       move.l    D1,-(A7)
       pea       @m68kus~1_6.L
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
       dc.b      65,67,75,32,61,32,37,100,13,10,0
@m68kus~1_2:
       dc.b      87,97,105,116,105,110,103,32,102,111,114,32
       dc.b      73,110,116,101,114,110,97,108,32,66,121,116
       dc.b      101,32,87,114,105,116,101,33,13,10,0
@m68kus~1_3:
       dc.b      73,110,116,101,114,110,97,108,32,66,121,116
       dc.b      101,32,87,114,105,116,101,32,67,111,109,112
       dc.b      108,101,116,101,33,13,10,0
@m68kus~1_4:
       dc.b      13,10,72,101,108,108,111,32,73,73,67,32,76,97
       dc.b      98,13,10,0
@m68kus~1_5:
       dc.b      84,104,105,115,32,105,115,32,116,104,101,32
       dc.b      115,101,110,116,32,66,121,116,101,58,32,37,117
       dc.b      13,10,0
@m68kus~1_6:
       dc.b      84,104,105,115,32,105,115,32,116,104,101,32
       dc.b      114,101,99,101,105,118,101,100,32,66,121,116
       dc.b      101,58,32,37,117,13,10,0
       xref      _scanflush
       xref      _printf
