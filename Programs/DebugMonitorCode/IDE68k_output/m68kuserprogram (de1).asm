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
; #define ReadIACK        0x21    // Set RD, IACK bits        --> (0010 0001)
; #define ReadNACKIACK    0x29    // Set RD, ACK, IACK bits   --> (0010 1001)
; #define stopWrite       0x50    // set STO, WR bit          --> (0101 0000)
; // Read Command Register Commands
; #define startRead       0xA8    // set STA, RD, ACK bit     --> (1010 1000)
; #define stopRead        0x41    // set STO, IACK bit        --> (0100 0001)
; /*********************************************************************************************
; **  Function protoTypes
; *********************************************************************************************/
; void SequentialBlockWrite(int address, int sizeOfBlock, char payloadByte);
; void WritePageToChip(void);
; void WriteByteToChip(char c);
; void initiateWriteSequence(int address);
; void WaitForWriteCycle(void);
; void SequentialBlockRead(int address, int sizeOfBlock, char expectedByte);
; void ReadPageFromChip(void);
; char ReadByteFromChip(void);
; void initiateReadSequence(int address);
; void BlockDecode(char * writeControlByte, char * readControlByte, int address);
; void WaitForTXByte(void);
; void WaitForReceivedByte(void);
; int CheckForACK(void);
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
; **  Write Sequential Block to EEPROM Chip
; *********************************************************************************************/
; void SequentialBlockWrite(int address, int sizeOfBlock, char payloadByte){
       xdef      _SequentialBlockWrite
_SequentialBlockWrite:
       link      A6,#0
       movem.l   D2/D3/D4/A2,-(A7)
       move.l    8(A6),D2
       lea       _printf.L,A2
; int i = 0;
       clr.l     D3
; int endAddress = address + sizeOfBlock;
       move.l    D2,D0
       add.l     12(A6),D0
       move.l    D0,D4
; // Parameter checks
; if (endAddress > 0x1FFFF){
       cmp.l     #131071,D4
       ble.s     SequentialBlockWrite_1
; printf("Not Enough Memory locations!\r\n");
       pea       @m68kus~1_1.L
       jsr       (A2)
       addq.w    #4,A7
; return;
       bra       SequentialBlockWrite_6
SequentialBlockWrite_1:
; }
; printf("Writing Sequential Block of Data to EEPROM\r\n");
       pea       @m68kus~1_2.L
       jsr       (A2)
       addq.w    #4,A7
; while (address <= endAddress){
SequentialBlockWrite_4:
       cmp.l     D4,D2
       bgt       SequentialBlockWrite_6
; initiateWriteSequence(address);
       move.l    D2,-(A7)
       jsr       _initiateWriteSequence
       addq.w    #4,A7
; // Fill up a 128 byte block
; for(i= address%128; i<128; i++){
       move.l    D2,-(A7)
       pea       128
       jsr       LDIV
       move.l    4(A7),D0
       addq.w    #8,A7
       move.l    D0,D3
SequentialBlockWrite_7:
       cmp.l     #128,D3
       bge.s     SequentialBlockWrite_9
; TXR = payloadByte;        
       move.b    19(A6),4227078
; CR = Write;
       move.b    #16,4227080
; WaitForTXByte();
       jsr       _WaitForTXByte
; if(!CheckForACK())
       jsr       _CheckForACK
       tst.l     D0
       bne.s     SequentialBlockWrite_10
; printf("No ACK returned for byte #%d", i);
       move.l    D3,-(A7)
       pea       @m68kus~1_3.L
       jsr       (A2)
       addq.w    #8,A7
SequentialBlockWrite_10:
; address ++;
       addq.l    #1,D2
       addq.l    #1,D3
       bra       SequentialBlockWrite_7
SequentialBlockWrite_9:
; }
; CR = stop;
       move.b    #64,4227080
; WaitForWriteCycle();
       jsr       _WaitForWriteCycle
       bra       SequentialBlockWrite_4
SequentialBlockWrite_6:
       movem.l   (A7)+,D2/D3/D4/A2
       unlk      A6
       rts
; }
; }
; /*********************************************************************************************
; **  Write Page to EEPROM Chip
; *********************************************************************************************/
; void WritePageToChip(void){
       xdef      _WritePageToChip
_WritePageToChip:
       move.l    D2,-(A7)
; int i = 0;
       clr.l     D2
; printf("Writing Page to EEPROM\r\n");
       pea       @m68kus~1_4.L
       jsr       _printf
       addq.w    #4,A7
; initiateWriteSequence(0x00000);
       clr.l     -(A7)
       jsr       _initiateWriteSequence
       addq.w    #4,A7
; for(i=0; i<128; i++){
       clr.l     D2
WritePageToChip_1:
       cmp.l     #128,D2
       bge.s     WritePageToChip_3
; TXR = i;            // send 1 byte of data
       move.b    D2,4227078
; CR = Write;
       move.b    #16,4227080
; WaitForTXByte();
       jsr       _WaitForTXByte
; if(!CheckForACK())
       jsr       _CheckForACK
       tst.l     D0
       bne.s     WritePageToChip_4
; printf("No ACK returned for byte #%d", i);
       move.l    D2,-(A7)
       pea       @m68kus~1_3.L
       jsr       _printf
       addq.w    #8,A7
WritePageToChip_4:
       addq.l    #1,D2
       bra       WritePageToChip_1
WritePageToChip_3:
; }
; CR = stop;
       move.b    #64,4227080
; WaitForWriteCycle();
       jsr       _WaitForWriteCycle
       move.l    (A7)+,D2
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
       lea       _printf.L,A3
       lea       _CheckForACK.L,A4
; printf("Writing Byte to EEPROM\r\n");
       pea       @m68kus~1_5.L
       jsr       (A3)
       addq.w    #4,A7
; // Ensure TX is ready before sending control byte
; WaitForTXByte();
       jsr       (A2)
; TXR = 0xA0;         // Write Control Byte (1010 0000)
       move.b    #160,4227078
; CR = startWrite;    // Set STA bit, set WR bit
       move.b    #144,4227080
; WaitForTXByte();
       jsr       (A2)
; if(!CheckForACK())
       jsr       (A4)
       tst.l     D0
       bne.s     WriteByteToChip_1
; printf("No ACK returned");
       pea       @m68kus~1_6.L
       jsr       (A3)
       addq.w    #4,A7
WriteByteToChip_1:
; TXR = 0x20;         // Address Byte 1
       move.b    #32,4227078
; CR = Write;         // Set WR bit
       move.b    #16,4227080
; WaitForTXByte();
       jsr       (A2)
; if(!CheckForACK())
       jsr       (A4)
       tst.l     D0
       bne.s     WriteByteToChip_3
; printf("No ACK returned");
       pea       @m68kus~1_6.L
       jsr       (A3)
       addq.w    #4,A7
WriteByteToChip_3:
; TXR = 0x00;         // Address Byte 2
       clr.b     4227078
; CR = Write;         // Set WR bit
       move.b    #16,4227080
; WaitForTXByte();
       jsr       (A2)
; if(!CheckForACK())
       jsr       (A4)
       tst.l     D0
       bne.s     WriteByteToChip_5
; printf("No ACK returned");
       pea       @m68kus~1_6.L
       jsr       (A3)
       addq.w    #4,A7
WriteByteToChip_5:
; TXR = c;            // send 1 byte of data
       move.b    11(A6),4227078
; CR = Write;
       move.b    #16,4227080
; WaitForTXByte();
       jsr       (A2)
; if(!CheckForACK())
       jsr       (A4)
       tst.l     D0
       bne.s     WriteByteToChip_7
; printf("No ACK returned");
       pea       @m68kus~1_6.L
       jsr       (A3)
       addq.w    #4,A7
WriteByteToChip_7:
; CR = stop;
       move.b    #64,4227080
; WaitForWriteCycle();
       jsr       _WaitForWriteCycle
       movem.l   (A7)+,A2/A3/A4
       unlk      A6
       rts
; }
; /*********************************************************************************************
; **  Write Page to EEPROM Chip
; *********************************************************************************************/
; void initiateWriteSequence(int address){
       xdef      _initiateWriteSequence
_initiateWriteSequence:
       link      A6,#-4
       movem.l   D2/A2/A3/A4,-(A7)
       lea       _WaitForTXByte.L,A2
       lea       _printf.L,A3
       lea       _CheckForACK.L,A4
       move.l    8(A6),D2
; char writeControlByte = 0, unusedControlByte = 0;
       clr.b     -2(A6)
       clr.b     -1(A6)
; BlockDecode(&writeControlByte, &unusedControlByte, address);
       move.l    D2,-(A7)
       pea       -1(A6)
       pea       -2(A6)
       jsr       _BlockDecode
       add.w     #12,A7
; // Ensure TX is ready before sending control byte
; WaitForTXByte();
       jsr       (A2)
; TXR = writeControlByte;     // Write Control Byte (1010 0000)
       move.b    -2(A6),4227078
; CR = startWrite;            // Set STA bit, set WR bit
       move.b    #144,4227080
; WaitForTXByte();
       jsr       (A2)
; if(!CheckForACK())
       jsr       (A4)
       tst.l     D0
       bne.s     initiateWriteSequence_1
; printf("No ACK returned");
       pea       @m68kus~1_6.L
       jsr       (A3)
       addq.w    #4,A7
initiateWriteSequence_1:
; TXR = (address >> 8) & 0xFF;    // Address Byte 1
       move.l    D2,D0
       asr.l     #8,D0
       and.l     #255,D0
       move.b    D0,4227078
; CR = Write;                 // Set WR bit
       move.b    #16,4227080
; WaitForTXByte();
       jsr       (A2)
; if(!CheckForACK())
       jsr       (A4)
       tst.l     D0
       bne.s     initiateWriteSequence_3
; printf("No ACK returned");
       pea       @m68kus~1_6.L
       jsr       (A3)
       addq.w    #4,A7
initiateWriteSequence_3:
; TXR = address & 0xFF;       // Address Byte 2
       move.l    D2,D0
       and.l     #255,D0
       move.b    D0,4227078
; CR = Write;                 // Set WR bit
       move.b    #16,4227080
; WaitForTXByte();
       jsr       (A2)
; if(!CheckForACK())
       jsr       (A4)
       tst.l     D0
       bne.s     initiateWriteSequence_5
; printf("No ACK returned");
       pea       @m68kus~1_6.L
       jsr       (A3)
       addq.w    #4,A7
initiateWriteSequence_5:
; return;
       movem.l   (A7)+,D2/A2/A3/A4
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
; printf("Waiting for Internal Write!\r\n");
       pea       @m68kus~1_7.L
       jsr       _printf
       addq.w    #4,A7
       lea       _CheckForACK.L,A0
       move.l    A0,D0
       beq       WaitForWriteCycle_1
; } while (!CheckForACK);
; printf("Internal Write Complete!\r\n");
       pea       @m68kus~1_8.L
       jsr       _printf
       addq.w    #4,A7
; return;
       rts
; }
; /*********************************************************************************************
; **  Read Block from EEPROM flash
; *********************************************************************************************/
; void SequentialBlockRead(int address, int sizeOfBlock, char expectedByte){
       xdef      _SequentialBlockRead
_SequentialBlockRead:
       link      A6,#-4
       movem.l   D2/D3/A2,-(A7)
       move.l    8(A6),D2
       lea       _printf.L,A2
; char receivedByte;
; int endAddress = address + sizeOfBlock;
       move.l    D2,D0
       add.l     12(A6),D0
       move.l    D0,D3
; // Parameter checks
; if (endAddress > 0x1FFFF){
       cmp.l     #131071,D3
       ble.s     SequentialBlockRead_1
; printf("Not Enough Memory locations!\r\n");
       pea       @m68kus~1_1.L
       jsr       (A2)
       addq.w    #4,A7
; return;
       bra       SequentialBlockRead_3
SequentialBlockRead_1:
; }
; initiateReadSequence(address);
       move.l    D2,-(A7)
       jsr       _initiateReadSequence
       addq.w    #4,A7
; while (address < endAddress){
SequentialBlockRead_4:
       cmp.l     D3,D2
       bge       SequentialBlockRead_6
; if (address == endAddress - 1 || address == 0xFFFF)
       move.l    D3,D0
       subq.l    #1,D0
       cmp.l     D0,D2
       beq.s     SequentialBlockRead_9
       cmp.l     #65535,D2
       bne.s     SequentialBlockRead_7
SequentialBlockRead_9:
; CR = ReadNACKIACK;
       move.b    #41,4227080
       bra.s     SequentialBlockRead_8
SequentialBlockRead_7:
; else CR = ReadIACK;
       move.b    #33,4227080
SequentialBlockRead_8:
; WaitForReceivedByte();
       jsr       _WaitForReceivedByte
; receivedByte = RXR;
       move.b    4227078,-1(A6)
; if (address != (endAddress - 1) && !CheckForACK())
       move.l    D3,D0
       subq.l    #1,D0
       cmp.l     D0,D2
       beq.s     SequentialBlockRead_10
       jsr       _CheckForACK
       tst.l     D0
       bne.s     SequentialBlockRead_10
; printf("No ACK returned for read at address: 0x%X", address);
       move.l    D2,-(A7)
       pea       @m68kus~1_9.L
       jsr       (A2)
       addq.w    #8,A7
SequentialBlockRead_10:
; if (receivedByte != expectedByte){
       move.b    -1(A6),D0
       cmp.b     19(A6),D0
       beq.s     SequentialBlockRead_12
; printf("Sequential Read Error at address: 0x%X\r\n", address);
       move.l    D2,-(A7)
       pea       @m68kus~1_10.L
       jsr       (A2)
       addq.w    #8,A7
; CR = stop;
       move.b    #64,4227080
; return;
       bra.s     SequentialBlockRead_3
SequentialBlockRead_12:
; }
; if (address == 0x0FFFF){ // Stop and Start Read from 2nd bank
       cmp.l     #65535,D2
       bne.s     SequentialBlockRead_14
; CR = stop;
       move.b    #64,4227080
; initiateReadSequence(address);
       move.l    D2,-(A7)
       jsr       _initiateReadSequence
       addq.w    #4,A7
SequentialBlockRead_14:
; }
; address ++;        
       addq.l    #1,D2
       bra       SequentialBlockRead_4
SequentialBlockRead_6:
; }
; CR = stop;
       move.b    #64,4227080
; printf("Sequential Block Read Successful\r\n");
       pea       @m68kus~1_11.L
       jsr       (A2)
       addq.w    #4,A7
SequentialBlockRead_3:
       movem.l   (A7)+,D2/D3/A2
       unlk      A6
       rts
; }
; /*********************************************************************************************
; **  Read Page from EEPROM flash
; *********************************************************************************************/
; void ReadPageFromChip(void){
       xdef      _ReadPageFromChip
_ReadPageFromChip:
       link      A6,#-4
       movem.l   D2/A2/A3/A4,-(A7)
       lea       _printf.L,A2
       lea       _CheckForACK.L,A3
       lea       _WaitForTXByte.L,A4
; int i = 0;
       clr.l     D2
; char receivedByte;
; printf("Reading Page from EEPROM \r\n");
       pea       @m68kus~1_12.L
       jsr       (A2)
       addq.w    #4,A7
; // Ensure TX is ready before sending control byte
; WaitForTXByte();
       jsr       (A4)
; TXR = 0xA0;         // Write Control Byte (1010 0000)
       move.b    #160,4227078
; CR = startWrite;    // set STA bit
       move.b    #144,4227080
; WaitForTXByte();
       jsr       (A4)
; if(!CheckForACK())
       jsr       (A3)
       tst.l     D0
       bne.s     ReadPageFromChip_1
; printf("No ACK returned");
       pea       @m68kus~1_6.L
       jsr       (A2)
       addq.w    #4,A7
ReadPageFromChip_1:
; TXR = 0x00;         // Address Byte 1
       clr.b     4227078
; CR = Write;         // set WR bit
       move.b    #16,4227080
; WaitForTXByte();
       jsr       (A4)
; if(!CheckForACK())
       jsr       (A3)
       tst.l     D0
       bne.s     ReadPageFromChip_3
; printf("No ACK returned");
       pea       @m68kus~1_6.L
       jsr       (A2)
       addq.w    #4,A7
ReadPageFromChip_3:
; TXR = 0x00;         // Address Byte 2
       clr.b     4227078
; CR = Write;         // set WR bit
       move.b    #16,4227080
; WaitForTXByte();
       jsr       (A4)
; if(!CheckForACK())
       jsr       (A3)
       tst.l     D0
       bne.s     ReadPageFromChip_5
; printf("No ACK returned");
       pea       @m68kus~1_6.L
       jsr       (A2)
       addq.w    #4,A7
ReadPageFromChip_5:
; TXR = 0xA1;         // Read Control Byte (1010 0001)
       move.b    #161,4227078
; CR = startWrite;    // Set STA bit, WR bit
       move.b    #144,4227080
; WaitForTXByte();
       jsr       (A4)
; if(!CheckForACK())
       jsr       (A3)
       tst.l     D0
       bne.s     ReadPageFromChip_7
; printf("No ACK returned");
       pea       @m68kus~1_6.L
       jsr       (A2)
       addq.w    #4,A7
ReadPageFromChip_7:
; for (i=0; i<128; i++){
       clr.l     D2
ReadPageFromChip_9:
       cmp.l     #128,D2
       bge       ReadPageFromChip_11
; if (i != 127)
       cmp.l     #127,D2
       beq.s     ReadPageFromChip_12
; CR = ReadIACK;
       move.b    #33,4227080
       bra.s     ReadPageFromChip_13
ReadPageFromChip_12:
; else  CR = ReadNACKIACK;
       move.b    #41,4227080
ReadPageFromChip_13:
; WaitForReceivedByte();
       jsr       _WaitForReceivedByte
; receivedByte = RXR;
       move.b    4227078,-1(A6)
; if (i != 127 && !CheckForACK())
       cmp.l     #127,D2
       beq.s     ReadPageFromChip_14
       jsr       (A3)
       tst.l     D0
       bne.s     ReadPageFromChip_14
; printf("No ACK returned for byte #%d", i);
       move.l    D2,-(A7)
       pea       @m68kus~1_3.L
       jsr       (A2)
       addq.w    #8,A7
ReadPageFromChip_14:
; if (receivedByte != i){
       move.b    -1(A6),D0
       ext.w     D0
       ext.l     D0
       cmp.l     D2,D0
       beq.s     ReadPageFromChip_16
; printf("Page Read Failed at Byte #%d\r\n", i);
       move.l    D2,-(A7)
       pea       @m68kus~1_13.L
       jsr       (A2)
       addq.w    #8,A7
; CR = stop;
       move.b    #64,4227080
; return;
       bra.s     ReadPageFromChip_18
ReadPageFromChip_16:
       addq.l    #1,D2
       bra       ReadPageFromChip_9
ReadPageFromChip_11:
; }
; }
; CR = stop;
       move.b    #64,4227080
; printf("Page Read Successful\r\n");
       pea       @m68kus~1_14.L
       jsr       (A2)
       addq.w    #4,A7
ReadPageFromChip_18:
       movem.l   (A7)+,D2/A2/A3/A4
       unlk      A6
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
       lea       _printf.L,A3
       lea       _CheckForACK.L,A4
; char receivedByte;
; printf("Reading Byte from EEPROM \r\n");
       pea       @m68kus~1_15.L
       jsr       (A3)
       addq.w    #4,A7
; // Ensure TX is ready before sending control byte
; WaitForTXByte();
       jsr       (A2)
; TXR = 0xA0;         // Write Control Byte (1010 0000)
       move.b    #160,4227078
; CR = startWrite;    // set STA bit
       move.b    #144,4227080
; WaitForTXByte();
       jsr       (A2)
; if(!CheckForACK())
       jsr       (A4)
       tst.l     D0
       bne.s     ReadByteFromChip_1
; printf("No ACK returned");
       pea       @m68kus~1_6.L
       jsr       (A3)
       addq.w    #4,A7
ReadByteFromChip_1:
; TXR = 0x20;         // Address Byte 1
       move.b    #32,4227078
; CR = Write;         // set WR bit
       move.b    #16,4227080
; WaitForTXByte();
       jsr       (A2)
; if(!CheckForACK())
       jsr       (A4)
       tst.l     D0
       bne.s     ReadByteFromChip_3
; printf("No ACK returned");
       pea       @m68kus~1_6.L
       jsr       (A3)
       addq.w    #4,A7
ReadByteFromChip_3:
; TXR = 0x00;         // Address Byte 2
       clr.b     4227078
; CR = Write;         // set WR bit
       move.b    #16,4227080
; WaitForTXByte();
       jsr       (A2)
; if(!CheckForACK())
       jsr       (A4)
       tst.l     D0
       bne.s     ReadByteFromChip_5
; printf("No ACK returned");
       pea       @m68kus~1_6.L
       jsr       (A3)
       addq.w    #4,A7
ReadByteFromChip_5:
; TXR = 0xA1;         // Read Control Byte (1010 0001)
       move.b    #161,4227078
; CR = startWrite;    // Set STA bit, WR bit
       move.b    #144,4227080
; WaitForTXByte();
       jsr       (A2)
; if(!CheckForACK())
       jsr       (A4)
       tst.l     D0
       bne.s     ReadByteFromChip_7
; printf("No ACK returned");
       pea       @m68kus~1_6.L
       jsr       (A3)
       addq.w    #4,A7
ReadByteFromChip_7:
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
; **  Initiate Read Command to EEPROM
; *********************************************************************************************/
; void initiateReadSequence(int address){
       xdef      _initiateReadSequence
_initiateReadSequence:
       link      A6,#-4
       movem.l   D2/A2/A3/A4,-(A7)
       lea       _WaitForTXByte.L,A2
       lea       _printf.L,A3
       lea       _CheckForACK.L,A4
       move.l    8(A6),D2
; char writeControlByte = 0, readControlByte = 0;
       clr.b     -2(A6)
       clr.b     -1(A6)
; // Decode Address to determine bank
; BlockDecode(&writeControlByte, &readControlByte, address);
       move.l    D2,-(A7)
       pea       -1(A6)
       pea       -2(A6)
       jsr       _BlockDecode
       add.w     #12,A7
; // Ensure TX is ready before transmission
; WaitForTXByte();
       jsr       (A2)
; TXR = writeControlByte;          // Write Control Byte (1010 0000)
       move.b    -2(A6),4227078
; CR = startWrite;                // set STA bit
       move.b    #144,4227080
; WaitForTXByte();
       jsr       (A2)
; if(!CheckForACK())
       jsr       (A4)
       tst.l     D0
       bne.s     initiateReadSequence_1
; printf("No ACK returned");
       pea       @m68kus~1_6.L
       jsr       (A3)
       addq.w    #4,A7
initiateReadSequence_1:
; TXR = (address >> 8) & 0xFF;    // Address Byte 1
       move.l    D2,D0
       asr.l     #8,D0
       and.l     #255,D0
       move.b    D0,4227078
; CR = Write;                     // set WR bit
       move.b    #16,4227080
; WaitForTXByte();
       jsr       (A2)
; if(!CheckForACK())
       jsr       (A4)
       tst.l     D0
       bne.s     initiateReadSequence_3
; printf("No ACK returned");
       pea       @m68kus~1_6.L
       jsr       (A3)
       addq.w    #4,A7
initiateReadSequence_3:
; TXR = address & 0xFF;           // Address Byte 2
       move.l    D2,D0
       and.l     #255,D0
       move.b    D0,4227078
; CR = Write;                     // set WR bit
       move.b    #16,4227080
; WaitForTXByte();
       jsr       (A2)
; if(!CheckForACK())
       jsr       (A4)
       tst.l     D0
       bne.s     initiateReadSequence_5
; printf("No ACK returned");
       pea       @m68kus~1_6.L
       jsr       (A3)
       addq.w    #4,A7
initiateReadSequence_5:
; TXR = readControlByte;          // Read Control Byte (1010 0001)
       move.b    -1(A6),4227078
; CR = startWrite;                // Set STA bit, WR bit
       move.b    #144,4227080
; WaitForTXByte();
       jsr       (A2)
; if(!CheckForACK())
       jsr       (A4)
       tst.l     D0
       bne.s     initiateReadSequence_7
; printf("No ACK returned");
       pea       @m68kus~1_6.L
       jsr       (A3)
       addq.w    #4,A7
initiateReadSequence_7:
       movem.l   (A7)+,D2/A2/A3/A4
       unlk      A6
       rts
; }
; /*********************************************************************************************
; **  Decode Bank from address
; *********************************************************************************************/
; void BlockDecode(char * writeControlByte, char * readControlByte, int address){
       xdef      _BlockDecode
_BlockDecode:
       link      A6,#0
       move.l    D2,-(A7)
; char bank;
; // Block Decoder
; bank = (address >> 16) & 0xF;
       move.l    16(A6),D0
       asr.l     #8,D0
       asr.l     #8,D0
       and.l     #15,D0
       move.b    D0,D2
; if (bank == 0){
       tst.b     D2
       bne.s     BlockDecode_1
; *writeControlByte = 0xA0;
       move.l    8(A6),A0
       move.b    #160,(A0)
; *readControlByte = 0xA1;
       move.l    12(A6),A0
       move.b    #161,(A0)
       bra.s     BlockDecode_3
BlockDecode_1:
; }
; else if (bank == 1){
       cmp.b     #1,D2
       bne.s     BlockDecode_3
; *writeControlByte = 0xA8;
       move.l    8(A6),A0
       move.b    #168,(A0)
; *readControlByte = 0xA9;
       move.l    12(A6),A0
       move.b    #169,(A0)
BlockDecode_3:
       move.l    (A7)+,D2
       unlk      A6
       rts
; }
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
       move.l    D2,-(A7)
; char sendByte = 0x55;
       moveq     #85,D2
; char recievedByte;
; scanflush();     // flush any text that may have been typed ahead
       jsr       _scanflush
; printf("\r\nHello IIC Lab\r\n\r\n");
       pea       @m68kus~1_16.L
       jsr       _printf
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
; printf("Sent Byte: 0x%X & Recieved Byte: 0x%X\r\n\r\n", sendByte, recievedByte);
       move.b    -1(A6),D1
       ext.w     D1
       ext.l     D1
       move.l    D1,-(A7)
       ext.w     D2
       ext.l     D2
       move.l    D2,-(A7)
       pea       @m68kus~1_17.L
       jsr       _printf
       add.w     #12,A7
; WritePageToChip();
       jsr       _WritePageToChip
; ReadPageFromChip();
       jsr       _ReadPageFromChip
; SequentialBlockWrite(0x00000, 16384, sendByte);
       ext.w     D2
       ext.l     D2
       move.l    D2,-(A7)
       pea       16384
       clr.l     -(A7)
       jsr       _SequentialBlockWrite
       add.w     #12,A7
; SequentialBlockRead(0x00000, 16384, sendByte);
       ext.w     D2
       ext.l     D2
       move.l    D2,-(A7)
       pea       16384
       clr.l     -(A7)
       jsr       _SequentialBlockRead
       add.w     #12,A7
; while(1);
main_1:
       bra       main_1
; // programs should NOT exit as there is nothing to Exit TO !!!!!!
; // There is no OS - just press the reset button to end program and call debug
; }
       section   const
@m68kus~1_1:
       dc.b      78,111,116,32,69,110,111,117,103,104,32,77,101
       dc.b      109,111,114,121,32,108,111,99,97,116,105,111
       dc.b      110,115,33,13,10,0
@m68kus~1_2:
       dc.b      87,114,105,116,105,110,103,32,83,101,113,117
       dc.b      101,110,116,105,97,108,32,66,108,111,99,107
       dc.b      32,111,102,32,68,97,116,97,32,116,111,32,69
       dc.b      69,80,82,79,77,13,10,0
@m68kus~1_3:
       dc.b      78,111,32,65,67,75,32,114,101,116,117,114,110
       dc.b      101,100,32,102,111,114,32,98,121,116,101,32
       dc.b      35,37,100,0
@m68kus~1_4:
       dc.b      87,114,105,116,105,110,103,32,80,97,103,101
       dc.b      32,116,111,32,69,69,80,82,79,77,13,10,0
@m68kus~1_5:
       dc.b      87,114,105,116,105,110,103,32,66,121,116,101
       dc.b      32,116,111,32,69,69,80,82,79,77,13,10,0
@m68kus~1_6:
       dc.b      78,111,32,65,67,75,32,114,101,116,117,114,110
       dc.b      101,100,0
@m68kus~1_7:
       dc.b      87,97,105,116,105,110,103,32,102,111,114,32
       dc.b      73,110,116,101,114,110,97,108,32,87,114,105
       dc.b      116,101,33,13,10,0
@m68kus~1_8:
       dc.b      73,110,116,101,114,110,97,108,32,87,114,105
       dc.b      116,101,32,67,111,109,112,108,101,116,101,33
       dc.b      13,10,0
@m68kus~1_9:
       dc.b      78,111,32,65,67,75,32,114,101,116,117,114,110
       dc.b      101,100,32,102,111,114,32,114,101,97,100,32
       dc.b      97,116,32,97,100,100,114,101,115,115,58,32,48
       dc.b      120,37,88,0
@m68kus~1_10:
       dc.b      83,101,113,117,101,110,116,105,97,108,32,82
       dc.b      101,97,100,32,69,114,114,111,114,32,97,116,32
       dc.b      97,100,100,114,101,115,115,58,32,48,120,37,88
       dc.b      13,10,0
@m68kus~1_11:
       dc.b      83,101,113,117,101,110,116,105,97,108,32,66
       dc.b      108,111,99,107,32,82,101,97,100,32,83,117,99
       dc.b      99,101,115,115,102,117,108,13,10,0
@m68kus~1_12:
       dc.b      82,101,97,100,105,110,103,32,80,97,103,101,32
       dc.b      102,114,111,109,32,69,69,80,82,79,77,32,13,10
       dc.b      0
@m68kus~1_13:
       dc.b      80,97,103,101,32,82,101,97,100,32,70,97,105
       dc.b      108,101,100,32,97,116,32,66,121,116,101,32,35
       dc.b      37,100,13,10,0
@m68kus~1_14:
       dc.b      80,97,103,101,32,82,101,97,100,32,83,117,99
       dc.b      99,101,115,115,102,117,108,13,10,0
@m68kus~1_15:
       dc.b      82,101,97,100,105,110,103,32,66,121,116,101
       dc.b      32,102,114,111,109,32,69,69,80,82,79,77,32,13
       dc.b      10,0
@m68kus~1_16:
       dc.b      13,10,72,101,108,108,111,32,73,73,67,32,76,97
       dc.b      98,13,10,13,10,0
@m68kus~1_17:
       dc.b      83,101,110,116,32,66,121,116,101,58,32,48,120
       dc.b      37,88,32,38,32,82,101,99,105,101,118,101,100
       dc.b      32,66,121,116,101,58,32,48,120,37,88,13,10,13
       dc.b      10,0
       xref      LDIV
       xref      _scanflush
       xref      _printf
