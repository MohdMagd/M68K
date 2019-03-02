#include <stdio.h>
// #include <string.h>
// #include <ctype.h>

/*********************************************************************************************
**  RS232 port addresses
*********************************************************************************************/

#define RS232_Control     *(volatile unsigned char *)(0x00400040)
#define RS232_Status      *(volatile unsigned char *)(0x00400040)
#define RS232_TxData      *(volatile unsigned char *)(0x00400042)
#define RS232_RxData      *(volatile unsigned char *)(0x00400042)
#define RS232_Baud        *(volatile unsigned char *)(0x00400044)

/*************************************************************
** SPI Controller registers
**************************************************************/
// SPI Registers
#define SPI_Control         (*(volatile unsigned char *)(0x00408020))
#define SPI_Status          (*(volatile unsigned char *)(0x00408022))
#define SPI_Data            (*(volatile unsigned char *)(0x00408024))
#define SPI_Ext             (*(volatile unsigned char *)(0x00408026))
#define SPI_CS              (*(volatile unsigned char *)(0x00408028))

// these two macros enable or disable the flash memory chip enable off SSN_O[7..0]
// in this case we assume there is only 1 device connected to SSN_O[0] so we can
// write hex FE to the SPI_CS to enable it (the enable on the flash chip is active low)
// and write FF to disable it

#define   Enable_SPI_CS()             SPI_CS = 0xFE
#define   Disable_SPI_CS()            SPI_CS = 0xFF 


/*******************************************************************************************
** Function Prototypes
*******************************************************************************************/
int sprintf(char *out, const char *format, ...) ;
int TestForSPITransmitDataComplete(void);
void SPI_Init(void);
void WaitForSPITransmitComplete(void);
void WriteEnable(void);
void WriteSPIChar(unsigned char c);
unsigned char ReadSPIChar(void);
void WaitWriteCommandCompletion(void);
void DisableBlockProtect(void);

int _getch( void )
{
    char c ;
    while((RS232_Status & (char)(0x01)) != (char)(0x01))    // wait for Rx bit in 6850 serial comms chip status register to be '1'
        ;

    return (RS232_RxData & (char)(0x7f));                   // read received character, mask off top bit and return as 7 bit ASCII character
}

int _putch( int c)
{
    while((RS232_Status & (char)(0x02)) != (char)(0x02))    // wait for Tx bit in status register or 6850 serial comms chip to be '1'
        ;

    RS232_TxData = (c & (char)(0x7f));                      // write to the data register to output the character (mask off bit 8 to keep it 7 bit ASCII)
    return c ;                                              // putchar() expects the character to be returned
}

/******************************************************************************************
** The following code is for the SPI controller
*******************************************************************************************/
// return true if the SPI has finished transmitting a byte (to say the Flash chip) return false otherwise
// this can be used in a polling algorithm to know when the controller is busy or idle.

int TestForSPITransmitDataComplete(void)
{
    /* if register SPIF bit set, return true, otherwise wait*/
    while ((SPI_Status & 128) >> 7 != 1);
    return 1;
}

/************************************************************************************
** initialises the SPI controller chip to set speed, interrupt capability etc.
************************************************************************************/
void SPI_Init(void)
{
    //TODO
    //
    // Program the SPI Control, EXT, CS and Status registers to initialise the SPI controller
    // Don't forget to call this routine from main() before you do anything else with SPI
    //
    // Here are some settings we want to create
    //
    // Control Reg     - interrupts disabled, core enabled, Master mode, Polarity and Phase of clock = [0,0], speed =  divide by 32 = approx 700Khz
    SPI_Control = 0x53; // 8'b01X10011, X = don't Care (Use 0)
    // Ext Reg         - in conjunction with control reg sets speed to above and also sets interrupt flag after every completed transfer (each byte)
    SPI_Ext = 0;        //8'b00XXXX00
    // SPI_CS Reg      - disable all connected SPI chips via their CS signals
    SPI_CS = Disable_SPI_CS();
    // Status Reg      - clear any write collision and interrupt on transmit complete flag
    SPI_Status = 0xC0;  // 8'b11XX0000, X = don't Care (Use 0)
}

/************************************************************************************
** return ONLY when the SPI controller has finished transmitting a byte
************************************************************************************/
void WaitForSPITransmitComplete(void)
{
    // poll the status register SPIF bit looking for completion of transmission
    TestForSPITransmitDataComplete();
    // once transmission is complete, clear the write collision and interrupt on transmit complete flags in the status register (read documentation)
    // in case they were set
    SPI_Status = 0xC0; //  (8'b11000000, X = don't Care (Use 0))
}

/************************************************************************************
** Disable Write Protect to allow writing access to chip
************************************************************************************/
void WriteEnable(void){
    unsigned char x;

  	// Enable Chip Select
  	Enable_SPI_CS();
  
  	// Send Write Command to Chip
    SPI_Data = 6;
    WaitForSPITransmitComplete();
    x = SPI_Data;

    // Disable Chip Select
    Disable_SPI_CS();
}

/************************************************************************************
** Disable Write Protect to allow writing access to chip
************************************************************************************/
void DisableBlockProtect(void){

    unsigned char x;
    Enable_SPI_CS();

    // Send Write To status Register Command to Chip
    SPI_Data = 1;
    WaitForSPITransmitComplete();
    x = SPI_Data;

    // Send Write To status Register Command to Chip
    SPI_Data = 2;   // 8'b00000010
    WaitForSPITransmitComplete();
    x = SPI_Data;   

    Disable_SPI_CS(); 
}


/************************************************************************************
** Wait for Write Command Completion
************************************************************************************/
void WaitWriteCommandCompletion(void){
	unsigned char x;

	// Enable Chip Select
  	Enable_SPI_CS();
  
  	// Send Write Command to Chip
    SPI_Data = 5;
    WaitForSPITransmitComplete();
    x = SPI_Data;

    while(1){

    	SPI_Data = 0xFF;
    	WaitForSPITransmitComplete();
    	x = SPI_Data;

    	if ((x & 1) != 1)
    		break;
    }

    // Disable Chip Select
    Disable_SPI_CS();
}

/************************************************************************************
** Write a byte to the SPI flash chip via the controller and returns (reads) whatever was
** given back by SPI device at the same time (removes the read byte from the FIFO)
************************************************************************************/
void WriteSPIChar(unsigned char c)
{
	
	unsigned char x;
    unsigned char addr1, addr2, addr3;
    addr1 = addr2 = addr3 = 6;

    printf("\r\nc = %u \n", c);

    DisableBlockProtect();
    WriteEnable();

    // Enable Chip Select
    Enable_SPI_CS();
    
    // Send Write Command to Chip
    SPI_Data = 2;
    WaitForSPITransmitComplete();
    x = SPI_Data;

    // Send 24-bit Address that we stored c in
    SPI_Data = addr1; // 24-bit address - 1st Byte
    WaitForSPITransmitComplete();
	x = SPI_Data;

    SPI_Data = addr2; // 24-bit address - 2nd Byte
    WaitForSPITransmitComplete();
    x = SPI_Data;

    SPI_Data = addr3; // 24-bit address - 3rd Byte
    WaitForSPITransmitComplete();
    x = SPI_Data;

    // Payload Data
    SPI_Data = c;
    WaitForSPITransmitComplete();
    x = SPI_Data;

    //  Disable Chip Select
    Disable_SPI_CS();

    // Poll Chip Status register for write completion
    WaitWriteCommandCompletion();
}

/************************************************************************************
** Read contents of SPI flash chip from address 0
************************************************************************************/

unsigned char ReadSPIChar(void){

	unsigned char x;
    unsigned char read_byte;
    unsigned char addr1, addr2, addr3;
    addr1 = addr2 = addr3 = 6;

    // Enable Chip Select
    Enable_SPI_CS();

    // Send Read Command to Chip
    SPI_Data = 3;
    WaitForSPITransmitComplete();
    x = SPI_Data;

    // Send 24-bit Address that we stored c in
    // 24-bit address - 1st Byte
    SPI_Data = addr1;
    WaitForSPITransmitComplete();
    x = SPI_Data;

    // 24-bit address - 2nd Byte
    SPI_Data = addr2;
    WaitForSPITransmitComplete();
    x = SPI_Data;

    // 24-bit address - 3rd Byte
    SPI_Data = addr3;
    WaitForSPITransmitComplete();
    x = SPI_Data;

    // Send Dummy Data to purge c out of read FIFO
    SPI_Data = 0xF0;
    WaitForSPITransmitComplete();
    read_byte = SPI_Data;	// store data from read FIFO into temporary variable

    //  Disable Chip Select
    Disable_SPI_CS();

    printf("Read back Data (as u-char) = %u \n", read_byte);
    return read_byte;
    // return the received data from Flash chip 
}

/************************************************************************************
** Erase Chip Contents in SPI flash chip
************************************************************************************/
void ChipErase(void){

    unsigned char x;

    WriteEnable();
    DisableBlockProtect();

    Enable_SPI_CS();

    // Send Dummy Data to purge c out of read FIFO
    SPI_Data = 199;
    WaitForSPITransmitComplete();
    x = SPI_Data;
    
    Disable_SPI_CS();

    WaitWriteCommandCompletion();

    printf("Chip Erased!");
}

/******************************************************************************************************************************
* Start of user program
******************************************************************************************************************************/

void main()
{
    int test_byte;
    scanflush() ;                       // flush any text that may have been typed ahead
    printf("\r\nHello CPEN 412 Student\r\n") ;

    SPI_Init();
    ChipErase();
    WriteSPIChar('m');
    test_byte = ReadSPIChar();

    while(1);

   // programs should NOT exit as there is nothing to Exit TO !!!!!!
   // There is no OS - just press the reset button to end program and call debug
}