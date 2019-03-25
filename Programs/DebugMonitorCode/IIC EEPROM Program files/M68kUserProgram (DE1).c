#include <stdio.h>
#include <time.h>

/*********************************************************************************************
**  RS232 port addresses
*********************************************************************************************/
#define RS232_Control     *(volatile unsigned char *)(0x00400040)
#define RS232_Status      *(volatile unsigned char *)(0x00400040)
#define RS232_TxData      *(volatile unsigned char *)(0x00400042)
#define RS232_RxData      *(volatile unsigned char *)(0x00400042)
#define RS232_Baud        *(volatile unsigned char *)(0x00400044)

/*********************************************************************************************
**  IIC registers
*********************************************************************************************/
#define PRERlo  (*(volatile unsigned char *)(0x00408000)) // Clock Prescale register lo-byte
#define PRERhi  (*(volatile unsigned char *)(0x00408002)) // Clock Prescale register hi-byte
#define CTR     (*(volatile unsigned char *)(0x00408004)) // Control Register
#define TXR     (*(volatile unsigned char *)(0x00408006)) // Transmit Register
#define RXR     (*(volatile unsigned char *)(0x00408006)) // Receive Register
#define CR      (*(volatile unsigned char *)(0x00408008)) // Command Register
#define SR      (*(volatile unsigned char *)(0x00408008)) // Status Register

// Sequence Start & Stop Register Commands
#define start           0x80    // Set STA bit              --> (1000 0000)
#define stop            0x40    // Set STO bit              --> (0100 0000)
// Write Command Register Commands
#define startWrite      0x90    // set STA, WR bit          --> (1001 0000)
#define Write           0x10    // set WR bit               --> (0001 0000)
#define read            0x20    // set RD bit               --> (0010 0000)
#define NACK            0x08    // Set ACK bit              --> (0000 1000)
#define ReadNACK        0x28    // Set RD, ACK bits         --> (0010 1000)
#define stopWrite       0x50    // set STO, WR bit          --> (0101 0000)
// Read Command Register Commands
#define startRead       0xA8    // set STA, RD, ACK bit     --> (1010 1000)
#define stopRead        0x41    // set STO, IACK bit        --> (0100 0001)


/*********************************************************************************************
**  Function protoTypes
*********************************************************************************************/
void WriteByteToChip(char c);
char ReadByteFromChip(void);
void WaitForTXByte(void);
void WaitForReceivedByte(void);
int CheckForACK(void);
void IIC_Init(void);
void WaitForWriteCycle(void);

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

/*********************************************************************************************
**  Write Byte to EEPROM Chip
*********************************************************************************************/
void WriteByteToChip(char c){

    char tempByte;

    // Ensure TX is ready before sending control byte
    WaitForTXByte();

    TXR = 0xA0;         // Write Control Byte (1010 0000)
    CR = startWrite;    // Set STA bit, set WR bit
    WaitForTXByte();
    printf("ACK = %d\r\n", CheckForACK());
    tempByte = RXR;
    printf("tempByte = %d\r\n", tempByte);

    TXR = 0x20;         // Address Byte 1
    CR = Write;         // Set WR bit
    WaitForTXByte();
    printf("ACK = %d\r\n", CheckForACK());
    tempByte = RXR;
    printf("tempByte = %d\r\n", tempByte);


    TXR = 0x00;         // Address Byte 2
    CR = Write;         // Set WR bit
    WaitForTXByte();
    printf("ACK = %d\r\n", CheckForACK());
    tempByte = RXR;
    printf("tempByte = %d\r\n", tempByte);


    TXR = c;            // send 1 byte of data
    CR = Write;
    WaitForTXByte();
    printf("ACK = %d\r\n", CheckForACK());
    tempByte = RXR;
    printf("tempByte = %d\r\n", tempByte);

    CR = stop;
    WaitForWriteCycle();
}

/*********************************************************************************************
** Wait For EEPROM to complete internal Write Cycle
*********************************************************************************************/
void WaitForWriteCycle(void){
    do
    {
        TXR = 0xA0; // Write Control Byte (1010 0000)
        CR = start;
        printf("WaitForWriteCycle SR = %d\r\n", SR);
    } while (!CheckForACK);
    printf("WaitForWriteCycle 1 SR = %d\r\n", SR);
    return;
}

/*********************************************************************************************
**  Read Byte from EEPROM flash
*********************************************************************************************/
char ReadByteFromChip(void){

    char x;
    char receivedByte;

    // Ensure TX is ready before sending control byte
    WaitForTXByte();

    TXR = 0xA0;         // Write Control Byte (1010 0000)
    CR = startWrite;    // set STA bit
    WaitForTXByte();
    printf("ACK = %d\r\n", CheckForACK());
    // x = RXR;
    // printf("*x = %d\r\n", x);

    TXR = 0x20;         // Address Byte 1
    CR = Write;         // set WR bit
    WaitForTXByte();
    printf("ACK = %d\r\n", CheckForACK());
    // x = RXR;
    // printf("*x = %d\r\n", x);
    
    TXR = 0x00;         // Address Byte 2
    CR = Write;         // set WR bit
    WaitForTXByte();
    printf("ACK = %d\r\n", CheckForACK());
    // x = RXR;
    // printf("*x = %d\r\n", x);

    TXR = 0xA1;         // Read Control Byte (1010 0001)
    CR = startWrite;    // Set STA bit
    WaitForTXByte();
    printf("ACK = %d\r\n", CheckForACK());
    // x = RXR;
    // printf("*x = %d\r\n", x);

    CR = ReadNACK;
 
    WaitForReceivedByte();
    x = RXR;
    printf("*x = %d\r\n", x);
    x = RXR;
    printf("*x = %d\r\n", x);

    CR = stop;

    return x;
}


/*********************************************************************************************
** Probe SR register to check if TIP bit is clear
*********************************************************************************************/
void WaitForTXByte(void){
    while ((SR & 0x02) >> 1 == 1);
}


/*********************************************************************************************
** Probe RX register to check if it has received data from slave
*********************************************************************************************/
void WaitForReceivedByte(void){
    while ((SR & 0x01) == 0);
}


/*********************************************************************************************
** Probe Status Register to check if slave has ACKed
    Returns 0 of not ACKed and 1 if ACKed
*********************************************************************************************/
int CheckForACK(void){
    if ((SR & 0x80)>> 7 == 1)
       return 0;
    else return 1;
}


/*********************************************************************************************
** Initialize IIC Communication
*********************************************************************************************/
void IIC_Init(void){

    // Set Clock Frequency to 100kHz as per page 7 of in IIC controller Document
    CTR = 0x00; // Clear EN bit to set clock value first
    PRERlo = 0x31;
    PRERhi = 0x00;

    // Enable EN bit (core is disable) & Disable IEN bit (interrupts disable)
    CTR = 0x80;
}


void main(void)
{
    char sendByte = 64;
    char recievedByte;

    scanflush() ;                       // flush any text that may have been typed ahead
    printf("\r\nHello IIC Lab\r\n");

    IIC_Init();
    // WriteByteToChip(sendByte);
    recievedByte = ReadByteFromChip();

    printf("This is the sent Byte: %u\r\n", sendByte);
    printf("This is the received Byte: %u\r\n", recievedByte);

    while(1);
   // programs should NOT exit as there is nothing to Exit TO !!!!!!
   // There is no OS - just press the reset button to end program and call debug
}
