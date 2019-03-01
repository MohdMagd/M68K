; C:\M68K\PROGRAMS\DEBUGMONITORCODE\USERPROGRAM FILES\M68KUSERPROGRAM (DE1).C - Compiled by CC68K  Version 5.00 (c) 1991-2005  Peter J. Fondse
; #include <stdio.h>
; // #include <string.h>
; // #include <ctype.h>
; /*********************************************************************************************
; **  RS232 port addresses
; *********************************************************************************************/
; #define RS232_Control     *(volatile unsigned char *)(0x00400040)
; #define RS232_Status      *(volatile unsigned char *)(0x00400040)
; #define RS232_TxData      *(volatile unsigned char *)(0x00400042)
; #define RS232_RxData      *(volatile unsigned char *)(0x00400042)
; #define RS232_Baud        *(volatile unsigned char *)(0x00400044)
; /*************************************************************
; ** SPI Controller registers
; **************************************************************/
; // SPI Registers
; #define SPI_Control         (*(volatile unsigned char *)(0x00408020))
; #define SPI_Status          (*(volatile unsigned char *)(0x00408022))
; #define SPI_Data            (*(volatile unsigned char *)(0x00408024))
; #define SPI_Ext             (*(volatile unsigned char *)(0x00408026))
; #define SPI_CS              (*(volatile unsigned char *)(0x00408028))
; // these two macros enable or disable the flash memory chip enable off SSN_O[7..0]
; // in this case we assume there is only 1 device connected to SSN_O[0] so we can
; // write hex FE to the SPI_CS to enable it (the enable on the flash chip is active low)
; // and write FF to disable it
; #define   Enable_SPI_CS()             SPI_CS = 0xFE
; #define   Disable_SPI_CS()            SPI_CS = 0xFF 
; /*******************************************************************************************
; ** Function Prototypes
; *******************************************************************************************/
; int sprintf(char *out, const char *format, ...) ;
; int TestForSPITransmitDataComplete(void);
; void SPI_Init(void);
; void WaitForSPITransmitComplete(void);
; void DisableWriteProtect(void);
; void WriteSPIChar(char c);
; char ReadSPIChar(void);
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
; /******************************************************************************************
; ** The following code is for the SPI controller
; *******************************************************************************************/
; // return true if the SPI has finished transmitting a byte (to say the Flash chip) return false otherwise
; // this can be used in a polling algorithm to know when the controller is busy or idle.
; int TestForSPITransmitDataComplete(void)
; {
       xdef      _TestForSPITransmitDataComplete
_TestForSPITransmitDataComplete:
; /* if register SPIF bit set, return true, otherwise wait*/
; Enable_SPI_CS();
       move.b    #254,4227112
; SPI_Data = 0x05; // Read Status register command
       move.b    #5,4227108
; SPI_Data = 0xFF; // dummy byte
       move.b    #255,4227108
; while ((SPI_Status & 128) >> 7 != 1);
TestForSPITransmitDataComplete_1:
       move.b    4227106,D0
       and.w     #255,D0
       and.w     #128,D0
       asr.w     #7,D0
       cmp.w     #1,D0
       beq.s     TestForSPITransmitDataComplete_3
       bra       TestForSPITransmitDataComplete_1
TestForSPITransmitDataComplete_3:
; printf("\r\n SPI_Status = %d \r\n", SPI_Status); // 128
       move.b    4227106,D1
       and.l     #255,D1
       move.l    D1,-(A7)
       pea       @m68kus~1_1.L
       jsr       _printf
       addq.w    #8,A7
; Disable_SPI_CS();
       move.b    #255,4227112
; return 1;
       moveq     #1,D0
       rts
; }
; /************************************************************************************
; ** initialises the SPI controller chip to set speed, interrupt capability etc.
; ************************************************************************************/
; void SPI_Init(void)
; {
       xdef      _SPI_Init
_SPI_Init:
; //TODO
; //
; // Program the SPI Control, EXT, CS and Status registers to initialise the SPI controller
; // Don't forget to call this routine from main() before you do anything else with SPI
; //
; // Here are some settings we want to create
; //
; // Control Reg     - interrupts disabled, core enabled, Master mode, Polarity and Phase of clock = [0,0], speed =  divide by 32 = approx 700Khz
; SPI_Control = 0x53; // 8'b01X10011, X = don't Care (Use 0)
       move.b    #83,4227104
; // Ext Reg         - in conjunction with control reg sets speed to above and also sets interrupt flag after every completed transfer (each byte)
; SPI_Ext = 0;        //8'b00XXXX00
       clr.b     4227110
; // SPI_CS Reg      - disable all connected SPI chips via their CS signals
; SPI_CS = Disable_SPI_CS();
       move.b    #255,4227112
       move.b    #255,4227112
; // Status Reg      - clear any write collision and interrupt on transmit complete flag
; SPI_Status = 0xC0;  // 8'b11XX0000, X = don't Care (Use 0)
       move.b    #192,4227106
       rts
; }
; /************************************************************************************
; ** return ONLY when the SPI controller has finished transmitting a byte
; ************************************************************************************/
; void WaitForSPITransmitComplete(void)
; {
       xdef      _WaitForSPITransmitComplete
_WaitForSPITransmitComplete:
; // poll the status register SPIF bit looking for completion of transmission
; TestForSPITransmitDataComplete();
       jsr       _TestForSPITransmitDataComplete
; // once transmission is complete, clear the write collision and interrupt on transmit complete flags in the status register (read documentation)
; // in case they were set
; SPI_Status = 0xC0; //  (8'b11XX0000, X = don't Care (Use 0))
       move.b    #192,4227106
       rts
; }
; /************************************************************************************
; ** Disable Write Protect to allow writing access to chip
; ************************************************************************************/
; void DisableWriteProtect(void){
       xdef      _DisableWriteProtect
_DisableWriteProtect:
; // Enable Chip Select
; SPI_CS = Enable_SPI_CS();
       move.b    #254,4227112
       move.b    #254,4227112
; // Send Write Command to Chip
; SPI_Data = 0x6;
       move.b    #6,4227108
; // Disable Chip Select
; SPI_CS = Disable_SPI_CS();
       move.b    #255,4227112
       move.b    #255,4227112
       rts
; }
; /************************************************************************************
; ** Write a byte to the SPI flash chip via the controller and returns (reads) whatever was
; ** given back by SPI device at the same time (removes the read byte from the FIFO)
; ************************************************************************************/
; void WriteSPIChar(char c)
; {
       xdef      _WriteSPIChar
_WriteSPIChar:
       link      A6,#0
       move.l    A2,-(A7)
       lea       _printf.L,A2
; // Enable Chip Select
; SPI_CS = Enable_SPI_CS();
       move.b    #254,4227112
       move.b    #254,4227112
; DisableWriteProtect();
       jsr       _DisableWriteProtect
; // Send Write Command to Chip
; SPI_Data = 0x2;
       move.b    #2,4227108
; // Send 24-bit Address that we stored c in
; SPI_Data = 0x0; // 24-bit address - 1st Byte
       clr.b     4227108
; SPI_Data = 0x0; // 24-bit address - 2nd Byte
       clr.b     4227108
; SPI_Data = 0xF; // 24-bit address - 3rd Byte
       move.b    #15,4227108
; // Payload Data
; SPI_Data = c;
       move.b    11(A6),4227108
; printf("\r\n SPI_Data before disable = %c", SPI_Data);
       move.b    4227108,D1
       and.l     #255,D1
       move.l    D1,-(A7)
       pea       @m68kus~1_2.L
       jsr       (A2)
       addq.w    #8,A7
; //  Disable Chip Select
; SPI_CS = Disable_SPI_CS();
       move.b    #255,4227112
       move.b    #255,4227112
; printf("\r\n SPI_Data before wait = %c", SPI_Data);
       move.b    4227108,D1
       and.l     #255,D1
       move.l    D1,-(A7)
       pea       @m68kus~1_3.L
       jsr       (A2)
       addq.w    #8,A7
; // wait for completion of transmission
; WaitForSPITransmitComplete();
       jsr       _WaitForSPITransmitComplete
; printf("\r\n SPI_Data after wait= %c", SPI_Data);
       move.b    4227108,D1
       and.l     #255,D1
       move.l    D1,-(A7)
       pea       @m68kus~1_4.L
       jsr       (A2)
       addq.w    #8,A7
       move.l    (A7)+,A2
       unlk      A6
       rts
; }
; char ReadSPIChar(void){
       xdef      _ReadSPIChar
_ReadSPIChar:
       move.l    D2,-(A7)
; char read_byte;
; // Enable Chip Select
; SPI_CS = Enable_SPI_CS();
       move.b    #254,4227112
       move.b    #254,4227112
; // Send Read Command to Chip
; SPI_Data = 0x3;
       move.b    #3,4227108
; // Send 24-bit Address that we stored c in
; SPI_Data = 0x0; // 24-bit address - 1st Byte
       clr.b     4227108
; SPI_Data = 0x0; // 24-bit address - 2nd Byte
       clr.b     4227108
; SPI_Data = 0xF; // 24-bit address - 3rd Byte
       move.b    #15,4227108
; // Send Dummy Data to purge c out of read FIFO
; SPI_Data = 0xFF;
       move.b    #255,4227108
; // wait for completion of transmission
; WaitForSPITransmitComplete();
       jsr       _WaitForSPITransmitComplete
; // store data from read FIFO into temporary variable
; read_byte = SPI_Data;
       move.b    4227108,D2
; //  Disable Chip Select
; SPI_CS = Disable_SPI_CS();
       move.b    #255,4227112
       move.b    #255,4227112
; printf("\r\nRead back Data (as int) = %d", read_byte);
       ext.w     D2
       ext.l     D2
       move.l    D2,-(A7)
       pea       @m68kus~1_5.L
       jsr       _printf
       addq.w    #8,A7
; printf("\r\nRead back Data (as char) = %c", read_byte);
       ext.w     D2
       ext.l     D2
       move.l    D2,-(A7)
       pea       @m68kus~1_6.L
       jsr       _printf
       addq.w    #8,A7
; return read_byte;
       move.b    D2,D0
       move.l    (A7)+,D2
       rts
; // return the received data from Flash chip 
; }
; /******************************************************************************************************************************
; * Start of user program
; ******************************************************************************************************************************/
; void main()
; {
       xdef      _main
_main:
       link      A6,#-4
; int test_byte;
; scanflush() ;                       // flush any text that may have been typed ahead
       jsr       _scanflush
; printf("\r\nHello CPEN 412 Student\r\n") ;
       pea       @m68kus~1_7.L
       jsr       _printf
       addq.w    #4,A7
; SPI_Init();
       jsr       _SPI_Init
; WriteSPIChar('k');
       pea       107
       jsr       _WriteSPIChar
       addq.w    #4,A7
; test_byte = ReadSPIChar();
       jsr       _ReadSPIChar
       and.l     #255,D0
       move.l    D0,-4(A6)
; while(1);
main_1:
       bra       main_1
; // programs should NOT exit as there is nothing to Exit TO !!!!!!
; // There is no OS - just press the reset button to end program and call debug
; }
       section   const
@m68kus~1_1:
       dc.b      13,10,32,83,80,73,95,83,116,97,116,117,115,32
       dc.b      61,32,37,100,32,13,10,0
@m68kus~1_2:
       dc.b      13,10,32,83,80,73,95,68,97,116,97,32,98,101
       dc.b      102,111,114,101,32,100,105,115,97,98,108,101
       dc.b      32,61,32,37,99,0
@m68kus~1_3:
       dc.b      13,10,32,83,80,73,95,68,97,116,97,32,98,101
       dc.b      102,111,114,101,32,119,97,105,116,32,61,32,37
       dc.b      99,0
@m68kus~1_4:
       dc.b      13,10,32,83,80,73,95,68,97,116,97,32,97,102
       dc.b      116,101,114,32,119,97,105,116,61,32,37,99,0
@m68kus~1_5:
       dc.b      13,10,82,101,97,100,32,98,97,99,107,32,68,97
       dc.b      116,97,32,40,97,115,32,105,110,116,41,32,61
       dc.b      32,37,100,0
@m68kus~1_6:
       dc.b      13,10,82,101,97,100,32,98,97,99,107,32,68,97
       dc.b      116,97,32,40,97,115,32,99,104,97,114,41,32,61
       dc.b      32,37,99,0
@m68kus~1_7:
       dc.b      13,10,72,101,108,108,111,32,67,80,69,78,32,52
       dc.b      49,50,32,83,116,117,100,101,110,116,13,10,0
       xref      _scanflush
       xref      _printf
