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

/******************************************************************************************
** The following code is for the SPI controller
*******************************************************************************************/
// return true if the SPI has finished transmitting a byte (to say the Flash chip) return false otherwise
// this can be used in a polling algorithm to know when the controller is busy or idle.

int TestForSPITransmitDataComplete(void)
{
    /* if register SPIF bit set, return true, otherwise wait*/
    while ((SPI_Status & 128) >> 7 != 1 );
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
    SPI_Ext = 0; 		//8'b00XXXX00
    // SPI_CS Reg      - disable all connected SPI chips via their CS signals
    SPI_CS = Disable_SPI_CS();
    // Status Reg      - clear any write collision and interrupt on transmit complete flag
    SPI_Status = 0xC0;       // 8'b11XX0000, X = don't Care (Use 0)
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
    SPI_Status = 0xC0; //  (8'b11XX0000, X = don't Care (Use 0))
}

/************************************************************************************
** Disable Write Protect to allow writing access to chip
************************************************************************************/
void DisableWriteProtect(void){
	// Enable Chip Select
 	SPI_CS = Enable_SPI_CS();
 	
 	// Send Write Command to Chip
    SPI_Data = 0x6;

    // Disable Chip Select
    SPI_CS = Disable_SPI_CS();
}

/************************************************************************************
** Write a byte to the SPI flash chip via the controller and returns (reads) whatever was
** given back by SPI device at the same time (removes the read byte from the FIFO)
************************************************************************************/
int WriteSPIChar(char c)
{
	int read_byte;

	DisableWriteProtect();

 	// Enable Chip Select
 	SPI_CS = Enable_SPI_CS();
 	
 	// Send Write Command to Chip
    SPI_Data = 0x2;

    // Send 24-bit Address
    SPI_Data = 0x0; // 24-bit address - 1st Byte
    SPI_Data = 0x0; // 24-bit address - 2nd Byte
    SPI_Data = 0x0; // 24-bit address - 3rd Byte

    // Payload Data
    SPI_Data = c; 

    //  Disable Chip Select
    SPI_CS = Disable_SPI_CS();

    // wait for completion of transmission
    WaitForSPITransmitComplete();

	// Read Back c ->
 	// Enable Chip Select
 	DisableWriteProtect();

 	SPI_CS = Enable_SPI_CS();

 	// Send Read Command to Chip
    SPI_Data = 0x3;

    // Send 24-bit Address
    SPI_Data = 0x0; // 24-bit address - 1st Byte
    SPI_Data = 0x0; // 24-bit address - 2nd Byte
    SPI_Data = 0x0; // 24-bit address - 3rd Byte

    // Send Dummy Data
    SPI_Data = 0xFF;

  	// store received data from Flash chip in temporary variable
    read_byte = SPI_Data;

    //  Disable Chip Select
    SPI_CS = Disable_SPI_CS();
    
    // wait for completion of transmission
    WaitForSPITransmitComplete();

    // return the received data from Flash chip 
    return read_byte;
}

int main(void)
{
	char test_byte;

    SPI_Init();
   	test_byte = WriteSPIChar('X');

   	printf("%c\n", test_byte);

    return 0;
}
