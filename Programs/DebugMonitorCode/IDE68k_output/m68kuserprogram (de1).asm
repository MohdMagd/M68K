; C:\M68K\PROGRAMS\DEBUGMONITORCODE\IIC EEPROM PROGRAM FILES\M68KUSERPROGRAM (DE1).C - Compiled by CC68K  Version 5.00 (c) 1991-2005  Peter J. Fondse
; #include <stdio.h>
; #include <stdlib.h>
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
; void SequentialBlockWrite(long address, long sizeOfBlock, char payloadByte);
; void UtilSequentialBlockWrite(long address, long endAddress, char payloadByte);
; void WritePageToChip(void);
; void WriteByteToChip(char c);
; void initiateWriteSequence(long address);
; void WaitForWriteCycle(void);
; void SequentialBlockRead(long address, long sizeOfBlock, char expectedByte);
; int utilSequentialBlockRead(long utilAddress, long utilEndAddress, char expectedByte);
; void ReadPageFromChip(void);
; char ReadByteFromChip(void);
; void initiateReadSequence(long address);
; void BlockDecode(char * writeControlByte, char * readControlByte, long address);
; void WaitForTXByte(void);
; void WaitForReceivedByte(void);
; int CheckForACK(void);
; void IIC_Init(void);
; void GenerateADCOutput(void);
; void DValueOfAInput(void);
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
; void SequentialBlockWrite(long address, long sizeOfBlock, char payloadByte){
       xdef      _SequentialBlockWrite
_SequentialBlockWrite:
       link      A6,#-4
       movem.l   D2/D3/D4/A2,-(A7)
       lea       _printf.L,A2
       move.l    8(A6),D4
; int i = 0;
       clr.l     -4(A6)
; long endAddress = (address + sizeOfBlock) - 1;
       move.l    D4,D0
       add.l     12(A6),D0
       subq.l    #1,D0
       move.l    D0,D2
; long overflowEndAddress = 0;
       clr.l     D3
; // Safety check
; if (sizeOfBlock > 0x1FFFF){
       move.l    12(A6),D0
       cmp.l     #131071,D0
       ble.s     SequentialBlockWrite_1
; printf("SequentialBlockWrite: Size of Input Data Block cannot exceed 128kBytes\r\n");
       pea       @m68kus~1_1.L
       jsr       (A2)
       addq.w    #4,A7
; return;
       bra       SequentialBlockWrite_3
SequentialBlockWrite_1:
; }
; if (address > 0x1FFFF){
       cmp.l     #131071,D4
       ble.s     SequentialBlockWrite_4
; printf("SequentialBlockWrite: Entered Address Out of Range\r\n");
       pea       @m68kus~1_2.L
       jsr       (A2)
       addq.w    #4,A7
; return;
       bra       SequentialBlockWrite_3
SequentialBlockWrite_4:
; }
; // Wrap-Around check
; if (endAddress > 0x1FFFF){
       cmp.l     #131071,D2
       ble.s     SequentialBlockWrite_6
; overflowEndAddress = endAddress - 0x20000;
       move.l    D2,D0
       sub.l     #131072,D0
       move.l    D0,D3
; endAddress = 0x1FFFF;
       move.l    #131071,D2
SequentialBlockWrite_6:
; }
; printf("Performing Sequential Block Write to EEPROM\r\n");
       pea       @m68kus~1_3.L
       jsr       (A2)
       addq.w    #4,A7
; initiateWriteSequence(address);
       move.l    D4,-(A7)
       jsr       _initiateWriteSequence
       addq.w    #4,A7
; UtilSequentialBlockWrite(address, endAddress, payloadByte);
       move.b    19(A6),D1
       ext.w     D1
       ext.l     D1
       move.l    D1,-(A7)
       move.l    D2,-(A7)
       move.l    D4,-(A7)
       jsr       _UtilSequentialBlockWrite
       add.w     #12,A7
; if (overflowEndAddress){
       tst.l     D3
       beq.s     SequentialBlockWrite_8
; initiateWriteSequence(0x00000);
       clr.l     -(A7)
       jsr       _initiateWriteSequence
       addq.w    #4,A7
; UtilSequentialBlockWrite(0x00000, overflowEndAddress, payloadByte);
       move.b    19(A6),D1
       ext.w     D1
       ext.l     D1
       move.l    D1,-(A7)
       move.l    D3,-(A7)
       clr.l     -(A7)
       jsr       _UtilSequentialBlockWrite
       add.w     #12,A7
SequentialBlockWrite_8:
; }
; printf("Sequential Block Write Completed!\r\n\r\n");
       pea       @m68kus~1_4.L
       jsr       (A2)
       addq.w    #4,A7
; return;
SequentialBlockWrite_3:
       movem.l   (A7)+,D2/D3/D4/A2
       unlk      A6
       rts
; }
; /*********************************************************************************************
; **  Write Sequential Block to EEPROM Chip -- Utility
; *********************************************************************************************/
; void UtilSequentialBlockWrite(long address, long endAddress, char payloadByte){
       xdef      _UtilSequentialBlockWrite
_UtilSequentialBlockWrite:
       link      A6,#0
       move.l    D2,-(A7)
       move.l    8(A6),D2
; while (address <= endAddress){
UtilSequentialBlockWrite_1:
       cmp.l     12(A6),D2
       bgt       UtilSequentialBlockWrite_3
; if (address%128 != 0 || address == 0){
       move.l    D2,-(A7)
       pea       128
       jsr       LDIV
       move.l    4(A7),D0
       addq.w    #8,A7
       tst.l     D0
       bne.s     UtilSequentialBlockWrite_6
       tst.l     D2
       bne.s     UtilSequentialBlockWrite_4
UtilSequentialBlockWrite_6:
; // Fill up a 128 byte block
; TXR = payloadByte;        
       move.b    19(A6),4227078
; CR = Write;
       move.b    #16,4227080
; WaitForTXByte();
       jsr       _WaitForTXByte
; if(!CheckForACK())
       jsr       _CheckForACK
       tst.l     D0
       bne.s     UtilSequentialBlockWrite_7
; printf("UtilSequentialBlockWrite: No ACK returned for byte at 0x%X\r\n", address);
       move.l    D2,-(A7)
       pea       @m68kus~1_5.L
       jsr       _printf
       addq.w    #8,A7
UtilSequentialBlockWrite_7:
       bra.s     UtilSequentialBlockWrite_5
UtilSequentialBlockWrite_4:
; } else {    
; // Need to write in next 128 Byte block
; CR = stop;
       move.b    #64,4227080
; WaitForWriteCycle();
       jsr       _WaitForWriteCycle
; initiateWriteSequence(address);
       move.l    D2,-(A7)
       jsr       _initiateWriteSequence
       addq.w    #4,A7
; // Write 1st Byte in new block
; TXR = payloadByte;        
       move.b    19(A6),4227078
; CR = Write;
       move.b    #16,4227080
; WaitForTXByte();
       jsr       _WaitForTXByte
UtilSequentialBlockWrite_5:
; }
; address ++;
       addq.l    #1,D2
       bra       UtilSequentialBlockWrite_1
UtilSequentialBlockWrite_3:
; }
; CR = stop;
       move.b    #64,4227080
; WaitForWriteCycle();
       jsr       _WaitForWriteCycle
       move.l    (A7)+,D2
       unlk      A6
       rts
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
       pea       @m68kus~1_6.L
       jsr       _printf
       addq.w    #4,A7
; initiateWriteSequence(0x12000);
       pea       73728
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
; printf("No ACK returned for byte #%d\r\n", i);
       move.l    D2,-(A7)
       pea       @m68kus~1_7.L
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
; printf("Writing Byte to EEPROM\r\n");
       pea       @m68kus~1_8.L
       jsr       _printf
       addq.w    #4,A7
; initiateWriteSequence(0x1F000);
       pea       126976
       jsr       _initiateWriteSequence
       addq.w    #4,A7
; TXR = c;            // send 1 byte of data
       move.b    11(A6),4227078
; CR = Write;
       move.b    #16,4227080
; WaitForTXByte();
       jsr       _WaitForTXByte
; if(!CheckForACK())
       jsr       _CheckForACK
       tst.l     D0
       bne.s     WriteByteToChip_1
; printf("No ACK returned\r\n");
       pea       @m68kus~1_9.L
       jsr       _printf
       addq.w    #4,A7
WriteByteToChip_1:
; CR = stop;
       move.b    #64,4227080
; WaitForWriteCycle();
       jsr       _WaitForWriteCycle
       unlk      A6
       rts
; }
; /*********************************************************************************************
; **  Write Page to EEPROM Chip
; *********************************************************************************************/
; void initiateWriteSequence(long address){
       xdef      _initiateWriteSequence
_initiateWriteSequence:
       link      A6,#-4
       movem.l   D2/A2/A3/A4,-(A7)
       lea       _WaitForTXByte.L,A2
       lea       _printf.L,A3
       lea       _CheckForACK.L,A4
       move.l    8(A6),D2
; unsigned char writeControlByte = 0, unusedControlByte = 0;
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
; printf("No ACK returned\r\n");
       pea       @m68kus~1_9.L
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
; printf("No ACK returned\r\n");
       pea       @m68kus~1_9.L
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
; printf("No ACK returned\r\n");
       pea       @m68kus~1_9.L
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
       pea       @m68kus~1_10.L
       jsr       _printf
       addq.w    #4,A7
       lea       _CheckForACK.L,A0
       move.l    A0,D0
       beq       WaitForWriteCycle_1
; } while (!CheckForACK);
; printf("Internal Write Complete!\r\n");
       pea       @m68kus~1_11.L
       jsr       _printf
       addq.w    #4,A7
; return;
       rts
; }
; /*********************************************************************************************
; **  Read Block from EEPROM flash
; *********************************************************************************************/
; void SequentialBlockRead(long address, long sizeOfBlock, char expectedByte){
       xdef      _SequentialBlockRead
_SequentialBlockRead:
       link      A6,#0
       movem.l   D2/D3/D4/A2,-(A7)
       lea       _printf.L,A2
       move.l    8(A6),D4
; long endAddress = (address + sizeOfBlock) - 1;
       move.l    D4,D0
       add.l     12(A6),D0
       subq.l    #1,D0
       move.l    D0,D2
; long overflowEndAddress = 0;
       clr.l     D3
; // Safety check
; if (sizeOfBlock > 0x1FFFF){
       move.l    12(A6),D0
       cmp.l     #131071,D0
       ble.s     SequentialBlockRead_1
; printf("SequentialBlockRead: Size of Input Data Block cannot exceed 128kBytes\r\n");
       pea       @m68kus~1_12.L
       jsr       (A2)
       addq.w    #4,A7
; return;
       bra       SequentialBlockRead_3
SequentialBlockRead_1:
; }
; if (address > 0x1FFFF){
       cmp.l     #131071,D4
       ble.s     SequentialBlockRead_4
; printf("SequentialBlockRead: Entered Address Out of Range\r\n");
       pea       @m68kus~1_13.L
       jsr       (A2)
       addq.w    #4,A7
; return;
       bra       SequentialBlockRead_3
SequentialBlockRead_4:
; }
; // Wrap-Around check
; if (endAddress > 0x1FFFF){
       cmp.l     #131071,D2
       ble.s     SequentialBlockRead_6
; overflowEndAddress = endAddress - 0x20000;
       move.l    D2,D0
       sub.l     #131072,D0
       move.l    D0,D3
; endAddress = 0x1FFFF;
       move.l    #131071,D2
SequentialBlockRead_6:
; }
; printf("Starting Sequential Block Read...\r\n");
       pea       @m68kus~1_14.L
       jsr       (A2)
       addq.w    #4,A7
; initiateReadSequence(address);
       move.l    D4,-(A7)
       jsr       _initiateReadSequence
       addq.w    #4,A7
; if(!utilSequentialBlockRead(address, endAddress, expectedByte)){
       move.b    19(A6),D1
       ext.w     D1
       ext.l     D1
       move.l    D1,-(A7)
       move.l    D2,-(A7)
       move.l    D4,-(A7)
       jsr       _utilSequentialBlockRead
       add.w     #12,A7
       tst.l     D0
       bne.s     SequentialBlockRead_8
; printf("Sequential Block Read Failed!\r\n");
       pea       @m68kus~1_15.L
       jsr       (A2)
       addq.w    #4,A7
; return;
       bra       SequentialBlockRead_3
SequentialBlockRead_8:
; }
; if (overflowEndAddress){
       tst.l     D3
       beq       SequentialBlockRead_12
; initiateReadSequence(0x00000);
       clr.l     -(A7)
       jsr       _initiateReadSequence
       addq.w    #4,A7
; if(!utilSequentialBlockRead(0x00000, overflowEndAddress, expectedByte)){
       move.b    19(A6),D1
       ext.w     D1
       ext.l     D1
       move.l    D1,-(A7)
       move.l    D3,-(A7)
       clr.l     -(A7)
       jsr       _utilSequentialBlockRead
       add.w     #12,A7
       tst.l     D0
       bne.s     SequentialBlockRead_12
; printf("Sequential Block Read Failed!\r\n");
       pea       @m68kus~1_15.L
       jsr       (A2)
       addq.w    #4,A7
; return;
       bra.s     SequentialBlockRead_3
SequentialBlockRead_12:
; }
; }
; printf("Sequential Block Read successful!\r\n");
       pea       @m68kus~1_16.L
       jsr       (A2)
       addq.w    #4,A7
SequentialBlockRead_3:
       movem.l   (A7)+,D2/D3/D4/A2
       unlk      A6
       rts
; }
; int utilSequentialBlockRead(long utilAddress, long utilEndAddress, char expectedByte){
       xdef      _utilSequentialBlockRead
_utilSequentialBlockRead:
       link      A6,#-4
       movem.l   D2/D3,-(A7)
       move.l    8(A6),D2
       move.l    12(A6),D3
; char receivedByte;
; while (utilAddress <= utilEndAddress){
utilSequentialBlockRead_1:
       cmp.l     D3,D2
       bgt       utilSequentialBlockRead_3
; if (utilAddress == utilEndAddress || utilAddress == 0x0FFFF)
       cmp.l     D3,D2
       beq.s     utilSequentialBlockRead_6
       cmp.l     #65535,D2
       bne.s     utilSequentialBlockRead_4
utilSequentialBlockRead_6:
; CR = ReadNACKIACK;
       move.b    #41,4227080
       bra.s     utilSequentialBlockRead_5
utilSequentialBlockRead_4:
; else CR = ReadIACK;
       move.b    #33,4227080
utilSequentialBlockRead_5:
; WaitForReceivedByte();
       jsr       _WaitForReceivedByte
; receivedByte = RXR;
       move.b    4227078,-1(A6)
; if ((utilAddress != utilEndAddress && utilAddress != 0xFFFF) && !CheckForACK())
       cmp.l     D3,D2
       beq.s     utilSequentialBlockRead_7
       cmp.l     #65535,D2
       beq.s     utilSequentialBlockRead_7
       jsr       _CheckForACK
       tst.l     D0
       bne.s     utilSequentialBlockRead_7
; printf("No ACK returned for read at address: 0x%X\r\n", utilAddress);
       move.l    D2,-(A7)
       pea       @m68kus~1_17.L
       jsr       _printf
       addq.w    #8,A7
utilSequentialBlockRead_7:
; if (receivedByte != expectedByte){
       move.b    -1(A6),D0
       cmp.b     19(A6),D0
       beq.s     utilSequentialBlockRead_9
; printf("Sequential Read Error at address: 0x%X\r\n", utilAddress);
       move.l    D2,-(A7)
       pea       @m68kus~1_18.L
       jsr       _printf
       addq.w    #8,A7
; CR = stop;
       move.b    #64,4227080
; return 0;
       clr.l     D0
       bra.s     utilSequentialBlockRead_11
utilSequentialBlockRead_9:
; }
; if (utilAddress == 0x0FFFF){ // Stop and Start Read from 2nd bank
       cmp.l     #65535,D2
       bne.s     utilSequentialBlockRead_12
; CR = stop;
       move.b    #64,4227080
; initiateReadSequence(utilAddress+1);
       move.l    D2,D1
       addq.l    #1,D1
       move.l    D1,-(A7)
       jsr       _initiateReadSequence
       addq.w    #4,A7
utilSequentialBlockRead_12:
; }
; utilAddress ++;
       addq.l    #1,D2
       bra       utilSequentialBlockRead_1
utilSequentialBlockRead_3:
; }
; CR = stop;
       move.b    #64,4227080
; return 1;
       moveq     #1,D0
utilSequentialBlockRead_11:
       movem.l   (A7)+,D2/D3
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
       movem.l   D2/A2,-(A7)
       lea       _printf.L,A2
; int i = 0;
       clr.l     D2
; char receivedByte;
; printf("Reading Page from EEPROM \r\n");
       pea       @m68kus~1_19.L
       jsr       (A2)
       addq.w    #4,A7
; initiateReadSequence(0x12000);
       pea       73728
       jsr       _initiateReadSequence
       addq.w    #4,A7
; for (i=0; i<128; i++){
       clr.l     D2
ReadPageFromChip_1:
       cmp.l     #128,D2
       bge       ReadPageFromChip_3
; if (i != 127)
       cmp.l     #127,D2
       beq.s     ReadPageFromChip_4
; CR = ReadIACK;
       move.b    #33,4227080
       bra.s     ReadPageFromChip_5
ReadPageFromChip_4:
; else  CR = ReadNACKIACK;
       move.b    #41,4227080
ReadPageFromChip_5:
; WaitForReceivedByte();
       jsr       _WaitForReceivedByte
; receivedByte = RXR;
       move.b    4227078,-1(A6)
; if (i != 127 && !CheckForACK())
       cmp.l     #127,D2
       beq.s     ReadPageFromChip_6
       jsr       _CheckForACK
       tst.l     D0
       bne.s     ReadPageFromChip_6
; printf("No ACK returned for byte #%d\r\n", i);
       move.l    D2,-(A7)
       pea       @m68kus~1_7.L
       jsr       (A2)
       addq.w    #8,A7
ReadPageFromChip_6:
; if (receivedByte != i){
       move.b    -1(A6),D0
       ext.w     D0
       ext.l     D0
       cmp.l     D2,D0
       beq.s     ReadPageFromChip_8
; printf("Page Read Failed at Byte #%d\r\n", i);
       move.l    D2,-(A7)
       pea       @m68kus~1_20.L
       jsr       (A2)
       addq.w    #8,A7
; CR = stop;
       move.b    #64,4227080
; return;
       bra.s     ReadPageFromChip_10
ReadPageFromChip_8:
       addq.l    #1,D2
       bra       ReadPageFromChip_1
ReadPageFromChip_3:
; }
; }
; CR = stop;
       move.b    #64,4227080
; printf("Page Read Successful\r\n");
       pea       @m68kus~1_21.L
       jsr       (A2)
       addq.w    #4,A7
ReadPageFromChip_10:
       movem.l   (A7)+,D2/A2
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
; char receivedByte;
; printf("Reading Byte from EEPROM \r\n");
       pea       @m68kus~1_22.L
       jsr       _printf
       addq.w    #4,A7
; initiateReadSequence(0x1F000);
       pea       126976
       jsr       _initiateReadSequence
       addq.w    #4,A7
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
       unlk      A6
       rts
; }
; /*********************************************************************************************
; **  Initiate Read Command to EEPROM
; *********************************************************************************************/
; void initiateReadSequence(long address){
       xdef      _initiateReadSequence
_initiateReadSequence:
       link      A6,#-4
       movem.l   D2/A2/A3/A4,-(A7)
       lea       _WaitForTXByte.L,A2
       lea       _printf.L,A3
       lea       _CheckForACK.L,A4
       move.l    8(A6),D2
; unsigned char writeControlByte = 0, readControlByte = 0;
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
; TXR = writeControlByte;         // Write Control Byte
       move.b    -2(A6),4227078
; CR = startWrite;                // set STA bit
       move.b    #144,4227080
; WaitForTXByte();
       jsr       (A2)
; if(!CheckForACK())
       jsr       (A4)
       tst.l     D0
       bne.s     initiateReadSequence_1
; printf("No ACK returned\r\n");
       pea       @m68kus~1_9.L
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
; printf("No ACK returned\r\n");
       pea       @m68kus~1_9.L
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
; printf("No ACK returned\r\n");
       pea       @m68kus~1_9.L
       jsr       (A3)
       addq.w    #4,A7
initiateReadSequence_5:
; TXR = readControlByte;          // Read Control Byte
       move.b    -1(A6),4227078
; CR = startWrite;                // Set STA bit, WR bit
       move.b    #144,4227080
; WaitForTXByte();
       jsr       (A2)
; if(!CheckForACK())
       jsr       (A4)
       tst.l     D0
       bne.s     initiateReadSequence_7
; printf("No ACK returned\r\n");
       pea       @m68kus~1_9.L
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
; void BlockDecode(char * writeControlByte, char * readControlByte, long address){
       xdef      _BlockDecode
_BlockDecode:
       link      A6,#-4
; char bank;
; // Block Decoder
; if (address < 0x10000){
       move.l    16(A6),D0
       cmp.l     #65536,D0
       bge.s     BlockDecode_1
; *writeControlByte = 0xA0;
       move.l    8(A6),A0
       move.b    #160,(A0)
; *readControlByte = 0xA1;
       move.l    12(A6),A0
       move.b    #161,(A0)
       bra.s     BlockDecode_2
BlockDecode_1:
; }
; else {
; *writeControlByte = 0xA8;
       move.l    8(A6),A0
       move.b    #168,(A0)
; *readControlByte = 0xA9;
       move.l    12(A6),A0
       move.b    #169,(A0)
BlockDecode_2:
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
; /*********************************************************************************************
; ** Generate ADC Output
; *********************************************************************************************/
; void GenerateADCOutput(void){
       xdef      _GenerateADCOutput
_GenerateADCOutput:
       movem.l   D2/A2/A3/A4,-(A7)
       lea       _WaitForTXByte.L,A2
       lea       _printf.L,A3
       lea       _CheckForACK.L,A4
; char i=0;
       clr.b     D2
; printf("Writing continuous data to ADC\r\n");
       pea       @m68kus~1_23.L
       jsr       (A3)
       addq.w    #4,A7
; // Ensure TX is ready before sending control byte
; WaitForTXByte();
       jsr       (A2)
; TXR = 0x9E;         //AddresByte
       move.b    #158,4227078
; CR = startWrite;    // Set STA bit, set WR bit
       move.b    #144,4227080
; WaitForTXByte();
       jsr       (A2)
; if(!CheckForACK())
       jsr       (A4)
       tst.l     D0
       bne.s     GenerateADCOutput_1
; printf("no ACK returned");
       pea       @m68kus~1_24.L
       jsr       (A3)
       addq.w    #4,A7
GenerateADCOutput_1:
; TXR = 0x60;         // ControlByte
       move.b    #96,4227078
; CR = Write;         // Set WR bit
       move.b    #16,4227080
; WaitForTXByte();
       jsr       (A2)
; if(!CheckForACK())
       jsr       (A4)
       tst.l     D0
       bne.s     GenerateADCOutput_3
; printf("no ACK returned");
       pea       @m68kus~1_24.L
       jsr       (A3)
       addq.w    #4,A7
GenerateADCOutput_3:
; while(1)
GenerateADCOutput_5:
; {
; if(i==0)
       tst.b     D2
       bne.s     GenerateADCOutput_8
; {            
; TXR = i;         // Send 0V
       move.b    D2,4227078
; CR = Write;         // Set WR bit
       move.b    #16,4227080
; WaitForTXByte();
       jsr       (A2)
; if(!CheckForACK())
       jsr       (A4)
       tst.l     D0
       bne.s     GenerateADCOutput_10
; printf("no ACK returned");
       pea       @m68kus~1_24.L
       jsr       (A3)
       addq.w    #4,A7
GenerateADCOutput_10:
; i=255;          //set i high 
       move.b    #255,D2
       bra.s     GenerateADCOutput_9
GenerateADCOutput_8:
; }
; else
; {
; TXR = i;         // Send 5V
       move.b    D2,4227078
; CR = Write;         // Set WR bit
       move.b    #16,4227080
; WaitForTXByte();
       jsr       (A2)
; if(!CheckForACK())
       jsr       (A4)
       tst.l     D0
       bne.s     GenerateADCOutput_12
; printf("no ACK returned");
       pea       @m68kus~1_24.L
       jsr       (A3)
       addq.w    #4,A7
GenerateADCOutput_12:
; i=0;            //set i low
       clr.b     D2
GenerateADCOutput_9:
       bra       GenerateADCOutput_5
; }
; }
; }
; /*********************************************************************************************
; ** Digital Value of input channel
; *********************************************************************************************/
; void DValueOfAInput(void){
       xdef      _DValueOfAInput
_DValueOfAInput:
       link      A6,#-4
       move.l    A2,-(A7)
       lea       _printf.L,A2
; int DecimalRx;
; printf("Generating digital value for analong input on pin AIN0 \r\n");
       pea       @m68kus~1_25.L
       jsr       (A2)
       addq.w    #4,A7
; // Ensure TX is ready before sending control byte
; WaitForTXByte();
       jsr       _WaitForTXByte
; TXR = 0x9F;         //AddresByte
       move.b    #159,4227078
; CR = startWrite;    // Set STA bit, set WR bit
       move.b    #144,4227080
; WaitForTXByte();
       jsr       _WaitForTXByte
; if(!CheckForACK())
       jsr       _CheckForACK
       tst.l     D0
       bne.s     DValueOfAInput_1
; printf("no ACK returned");
       pea       @m68kus~1_24.L
       jsr       (A2)
       addq.w    #4,A7
DValueOfAInput_1:
; // ControlByte
; CR = ReadIACK;
       move.b    #33,4227080
; WaitForReceivedByte();
       jsr       _WaitForReceivedByte
; DecimalRx = (int) RXR;
       move.b    4227078,D0
       and.l     #255,D0
       move.l    D0,-4(A6)
; if(DecimalRx<100)
       move.l    -4(A6),D0
       cmp.l     #100,D0
       bge.s     DValueOfAInput_3
; printf("The digital value on pin Ain0 is: 0 V \r\n");
       pea       @m68kus~1_26.L
       jsr       (A2)
       addq.w    #4,A7
       bra.s     DValueOfAInput_4
DValueOfAInput_3:
; else    
; printf("The digital value on pin Ain0 is: %d V \r\n",(RXR/46));
       move.b    4227078,D1
       and.l     #65535,D1
       divu.w    #46,D1
       and.l     #255,D1
       move.l    D1,-(A7)
       pea       @m68kus~1_27.L
       jsr       (A2)
       addq.w    #8,A7
DValueOfAInput_4:
; CR = stop;
       move.b    #64,4227080
       move.l    (A7)+,A2
       unlk      A6
       rts
; }
; void main(void)
; {
       xdef      _main
_main:
       link      A6,#-4
       movem.l   D2/A2,-(A7)
       lea       _printf.L,A2
; char sendByte = 0x78;
       moveq     #120,D2
; char recievedByte;
; scanflush();     // flush any text that may have been typed ahead
       jsr       _scanflush
; printf("\r\nHello IIC Lab\r\n\r\n");
       pea       @m68kus~1_28.L
       jsr       (A2)
       addq.w    #4,A7
; IIC_Init();
       jsr       _IIC_Init
; SequentialBlockWrite(0x1FFF0, 0x1FFFF, sendByte);
       ext.w     D2
       ext.l     D2
       move.l    D2,-(A7)
       pea       131071
       pea       131056
       jsr       _SequentialBlockWrite
       add.w     #12,A7
; SequentialBlockRead(0x1FFF0, 0x1FFFF, sendByte);
       ext.w     D2
       ext.l     D2
       move.l    D2,-(A7)
       pea       131071
       pea       131056
       jsr       _SequentialBlockRead
       add.w     #12,A7
; printf("\r\n");
       pea       @m68kus~1_29.L
       jsr       (A2)
       addq.w    #4,A7
; WritePageToChip();
       jsr       _WritePageToChip
; ReadPageFromChip();
       jsr       _ReadPageFromChip
; printf("\r\n");
       pea       @m68kus~1_29.L
       jsr       (A2)
       addq.w    #4,A7
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
       pea       @m68kus~1_30.L
       jsr       (A2)
       add.w     #12,A7
; // GenerateADCOutput();
; // DValueOfAInput();
; while(1);
main_1:
       bra       main_1
; // programs should NOT exit as there is nothing to Exit TO !!!!!!
; // There is no OS - just press the reset button to end program and call debug
; }
       section   const
@m68kus~1_1:
       dc.b      83,101,113,117,101,110,116,105,97,108,66,108
       dc.b      111,99,107,87,114,105,116,101,58,32,83,105,122
       dc.b      101,32,111,102,32,73,110,112,117,116,32,68,97
       dc.b      116,97,32,66,108,111,99,107,32,99,97,110,110
       dc.b      111,116,32,101,120,99,101,101,100,32,49,50,56
       dc.b      107,66,121,116,101,115,13,10,0
@m68kus~1_2:
       dc.b      83,101,113,117,101,110,116,105,97,108,66,108
       dc.b      111,99,107,87,114,105,116,101,58,32,69,110,116
       dc.b      101,114,101,100,32,65,100,100,114,101,115,115
       dc.b      32,79,117,116,32,111,102,32,82,97,110,103,101
       dc.b      13,10,0
@m68kus~1_3:
       dc.b      80,101,114,102,111,114,109,105,110,103,32,83
       dc.b      101,113,117,101,110,116,105,97,108,32,66,108
       dc.b      111,99,107,32,87,114,105,116,101,32,116,111
       dc.b      32,69,69,80,82,79,77,13,10,0
@m68kus~1_4:
       dc.b      83,101,113,117,101,110,116,105,97,108,32,66
       dc.b      108,111,99,107,32,87,114,105,116,101,32,67,111
       dc.b      109,112,108,101,116,101,100,33,13,10,13,10,0
@m68kus~1_5:
       dc.b      85,116,105,108,83,101,113,117,101,110,116,105
       dc.b      97,108,66,108,111,99,107,87,114,105,116,101
       dc.b      58,32,78,111,32,65,67,75,32,114,101,116,117
       dc.b      114,110,101,100,32,102,111,114,32,98,121,116
       dc.b      101,32,97,116,32,48,120,37,88,13,10,0
@m68kus~1_6:
       dc.b      87,114,105,116,105,110,103,32,80,97,103,101
       dc.b      32,116,111,32,69,69,80,82,79,77,13,10,0
@m68kus~1_7:
       dc.b      78,111,32,65,67,75,32,114,101,116,117,114,110
       dc.b      101,100,32,102,111,114,32,98,121,116,101,32
       dc.b      35,37,100,13,10,0
@m68kus~1_8:
       dc.b      87,114,105,116,105,110,103,32,66,121,116,101
       dc.b      32,116,111,32,69,69,80,82,79,77,13,10,0
@m68kus~1_9:
       dc.b      78,111,32,65,67,75,32,114,101,116,117,114,110
       dc.b      101,100,13,10,0
@m68kus~1_10:
       dc.b      87,97,105,116,105,110,103,32,102,111,114,32
       dc.b      73,110,116,101,114,110,97,108,32,87,114,105
       dc.b      116,101,33,13,10,0
@m68kus~1_11:
       dc.b      73,110,116,101,114,110,97,108,32,87,114,105
       dc.b      116,101,32,67,111,109,112,108,101,116,101,33
       dc.b      13,10,0
@m68kus~1_12:
       dc.b      83,101,113,117,101,110,116,105,97,108,66,108
       dc.b      111,99,107,82,101,97,100,58,32,83,105,122,101
       dc.b      32,111,102,32,73,110,112,117,116,32,68,97,116
       dc.b      97,32,66,108,111,99,107,32,99,97,110,110,111
       dc.b      116,32,101,120,99,101,101,100,32,49,50,56,107
       dc.b      66,121,116,101,115,13,10,0
@m68kus~1_13:
       dc.b      83,101,113,117,101,110,116,105,97,108,66,108
       dc.b      111,99,107,82,101,97,100,58,32,69,110,116,101
       dc.b      114,101,100,32,65,100,100,114,101,115,115,32
       dc.b      79,117,116,32,111,102,32,82,97,110,103,101,13
       dc.b      10,0
@m68kus~1_14:
       dc.b      83,116,97,114,116,105,110,103,32,83,101,113
       dc.b      117,101,110,116,105,97,108,32,66,108,111,99
       dc.b      107,32,82,101,97,100,46,46,46,13,10,0
@m68kus~1_15:
       dc.b      83,101,113,117,101,110,116,105,97,108,32,66
       dc.b      108,111,99,107,32,82,101,97,100,32,70,97,105
       dc.b      108,101,100,33,13,10,0
@m68kus~1_16:
       dc.b      83,101,113,117,101,110,116,105,97,108,32,66
       dc.b      108,111,99,107,32,82,101,97,100,32,115,117,99
       dc.b      99,101,115,115,102,117,108,33,13,10,0
@m68kus~1_17:
       dc.b      78,111,32,65,67,75,32,114,101,116,117,114,110
       dc.b      101,100,32,102,111,114,32,114,101,97,100,32
       dc.b      97,116,32,97,100,100,114,101,115,115,58,32,48
       dc.b      120,37,88,13,10,0
@m68kus~1_18:
       dc.b      83,101,113,117,101,110,116,105,97,108,32,82
       dc.b      101,97,100,32,69,114,114,111,114,32,97,116,32
       dc.b      97,100,100,114,101,115,115,58,32,48,120,37,88
       dc.b      13,10,0
@m68kus~1_19:
       dc.b      82,101,97,100,105,110,103,32,80,97,103,101,32
       dc.b      102,114,111,109,32,69,69,80,82,79,77,32,13,10
       dc.b      0
@m68kus~1_20:
       dc.b      80,97,103,101,32,82,101,97,100,32,70,97,105
       dc.b      108,101,100,32,97,116,32,66,121,116,101,32,35
       dc.b      37,100,13,10,0
@m68kus~1_21:
       dc.b      80,97,103,101,32,82,101,97,100,32,83,117,99
       dc.b      99,101,115,115,102,117,108,13,10,0
@m68kus~1_22:
       dc.b      82,101,97,100,105,110,103,32,66,121,116,101
       dc.b      32,102,114,111,109,32,69,69,80,82,79,77,32,13
       dc.b      10,0
@m68kus~1_23:
       dc.b      87,114,105,116,105,110,103,32,99,111,110,116
       dc.b      105,110,117,111,117,115,32,100,97,116,97,32
       dc.b      116,111,32,65,68,67,13,10,0
@m68kus~1_24:
       dc.b      110,111,32,65,67,75,32,114,101,116,117,114,110
       dc.b      101,100,0
@m68kus~1_25:
       dc.b      71,101,110,101,114,97,116,105,110,103,32,100
       dc.b      105,103,105,116,97,108,32,118,97,108,117,101
       dc.b      32,102,111,114,32,97,110,97,108,111,110,103
       dc.b      32,105,110,112,117,116,32,111,110,32,112,105
       dc.b      110,32,65,73,78,48,32,13,10,0
@m68kus~1_26:
       dc.b      84,104,101,32,100,105,103,105,116,97,108,32
       dc.b      118,97,108,117,101,32,111,110,32,112,105,110
       dc.b      32,65,105,110,48,32,105,115,58,32,48,32,86,32
       dc.b      13,10,0
@m68kus~1_27:
       dc.b      84,104,101,32,100,105,103,105,116,97,108,32
       dc.b      118,97,108,117,101,32,111,110,32,112,105,110
       dc.b      32,65,105,110,48,32,105,115,58,32,37,100,32
       dc.b      86,32,13,10,0
@m68kus~1_28:
       dc.b      13,10,72,101,108,108,111,32,73,73,67,32,76,97
       dc.b      98,13,10,13,10,0
@m68kus~1_29:
       dc.b      13,10,0
@m68kus~1_30:
       dc.b      83,101,110,116,32,66,121,116,101,58,32,48,120
       dc.b      37,88,32,38,32,82,101,99,105,101,118,101,100
       dc.b      32,66,121,116,101,58,32,48,120,37,88,13,10,13
       dc.b      10,0
       xref      LDIV
       xref      _scanflush
       xref      _printf
