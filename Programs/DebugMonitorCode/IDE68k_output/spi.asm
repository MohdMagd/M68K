; C:\M68K\PROGRAMS\DEBUGMONITORCODE\SPI FLASH MEMORY FILES\SPI.C - Compiled by CC68K  Version 5.00 (c) 1991-2005  Peter J. Fondse
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
; /******************************************************************************************
; ** The following code is for the SPI controller
; *******************************************************************************************/
; // return true if the SPI has finished transmitting a byte (to say the Flash chip) return false otherwise
; // this can be used in a polling algorithm to know when the controller is busy or idle.
; int TestForSPITransmitDataComplete(void)
; {
       section   code
       xdef      _TestForSPITransmitDataComplete
_TestForSPITransmitDataComplete:
; /* if register SPIF bit set, return true, otherwise wait*/
; while ((SPI_Status & 128) >> 7 != 1 );
TestForSPITransmitDataComplete_1:
       move.b    4227106,D0
       and.w     #255,D0
       and.w     #128,D0
       asr.w     #7,D0
       cmp.w     #1,D0
       beq.s     TestForSPITransmitDataComplete_3
       bra       TestForSPITransmitDataComplete_1
TestForSPITransmitDataComplete_3:
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
; SPI_Ext = 0; 		//8'b00XXXX00
       clr.b     4227110
; // SPI_CS Reg      - disable all connected SPI chips via their CS signals
; SPI_CS = Disable_SPI_CS();
       move.b    #255,4227112
       move.b    #255,4227112
; // Status Reg      - clear any write collision and interrupt on transmit complete flag
; SPI_Status = 0xC0;       // 8'b11XX0000, X = don't Care (Use 0)
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
; while(TestForSPITransmitDataComplete);
WaitForSPITransmitComplete_1:
       lea       _TestForSPITransmitDataComplete.L,A0
       move.l    A0,D0
       beq.s     WaitForSPITransmitComplete_3
       bra       WaitForSPITransmitComplete_1
WaitForSPITransmitComplete_3:
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
; int WriteSPIChar(char c)
; {
       xdef      _WriteSPIChar
_WriteSPIChar:
       link      A6,#-4
; int read_byte;
; DisableWriteProtect();
       jsr       _DisableWriteProtect
; // Enable Chip Select
; SPI_CS = Enable_SPI_CS();
       move.b    #254,4227112
       move.b    #254,4227112
; // Send Write Command to Chip
; SPI_Data = 0x2;
       move.b    #2,4227108
; // Send 24-bit Address
; SPI_Data = 0x0; // 24-bit address - 1st Byte
       clr.b     4227108
; SPI_Data = 0x0; // 24-bit address - 2nd Byte
       clr.b     4227108
; SPI_Data = 0x0; // 24-bit address - 3rd Byte
       clr.b     4227108
; // Payload Data
; SPI_Data = c; 
       move.b    11(A6),4227108
; //  Disable Chip Select
; SPI_CS = Disable_SPI_CS();
       move.b    #255,4227112
       move.b    #255,4227112
; // wait for completion of transmission
; WaitForSPITransmitComplete();
       jsr       _WaitForSPITransmitComplete
; // Read Back c ->
; // Enable Chip Select
; DisableWriteProtect();
       jsr       _DisableWriteProtect
; SPI_CS = Enable_SPI_CS();
       move.b    #254,4227112
       move.b    #254,4227112
; // Send Read Command to Chip
; SPI_Data = 0x3;
       move.b    #3,4227108
; // Send 24-bit Address
; SPI_Data = 0x0; // 24-bit address - 1st Byte
       clr.b     4227108
; SPI_Data = 0x0; // 24-bit address - 2nd Byte
       clr.b     4227108
; SPI_Data = 0x0; // 24-bit address - 3rd Byte
       clr.b     4227108
; // Send Dummy Data
; SPI_Data = 0xFF;
       move.b    #255,4227108
; // store received data from Flash chip in temporary variable
; read_byte = SPI_Data;
       move.b    4227108,D0
       and.l     #255,D0
       move.l    D0,-4(A6)
; //  Disable Chip Select
; SPI_CS = Disable_SPI_CS();
       move.b    #255,4227112
       move.b    #255,4227112
; // wait for completion of transmission
; WaitForSPITransmitComplete();
       jsr       _WaitForSPITransmitComplete
; // return the received data from Flash chip 
; return read_byte;
       move.l    -4(A6),D0
       unlk      A6
       rts
; }
; int main(void)
; {
       xdef      _main
_main:
       link      A6,#-4
; char test_byte;
; SPI_Init();
       jsr       _SPI_Init
; test_byte = WriteSPIChar('X');
       pea       88
       jsr       _WriteSPIChar
       addq.w    #4,A7
       move.b    D0,-1(A6)
; printf("%c\n", test_byte);
       move.b    -1(A6),D1
       ext.w     D1
       ext.l     D1
       move.l    D1,-(A7)
       pea       @spi_1.L
       jsr       _printf
       addq.w    #8,A7
; return 0;
       clr.l     D0
       unlk      A6
       rts
; }
       section   const
@spi_1:
       dc.b      37,99,10,0
       xref      _printf
