#include <stdio.h>

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
#define PRERlo *(volatile unsigned char *)(0x00408000) // Clock Prescale register lo-byte
#define PRERhi *(volatile unsigned char *)(0x00408002) // Clock Prescale register hi-byte
#define CTR *(volatile unsigned char *)(0x00408004) // Control Register
#define TXR *(volatile unsigned char *)(0x00408006) // Transmit Register
#define RXR *(volatile unsigned char *)(0x00408006) // Receive Register
#define CR *(volatile unsigned char *)(0x00408008) // Command Register
#define SR *(volatile unsigned char *)(0x00408008) // Status Register

#define startWrite  0x90
#define startRead   0xA8
#define stop        0x41

/*********************************************************************************************
**  Function protoTypes
*********************************************************************************************/
void writeByteToChip(char c);
char readByteFromChip(void);
void waitForTXByte(void);
void waitForReceivedByte(void);
int checkForACK(void);
void IIC_Init(void);

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
void writeByteToChip(char c){

    int checkACKFlag = 0;

    waitForTXByte();

    while(checkACKFlag != 1){
        TXR = 0xA0; // Write Control Byte
        CR = startWrite;
        waitForTXByte();
        checkACKFlag = checkForACK();
    }

    checkACKFlag = 0;
    while(checkACKFlag != 1){
        TXR = 0x00; // Address Byte 1
        waitForTXByte();
        checkACKFlag = checkForACK();
    }

    checkACKFlag = 0;
    while(checkACKFlag != 1){
        TXR = 0x00; // Address Byte 2
        waitForTXByte();
        checkACKFlag = checkForACK();
    }

    checkACKFlag = 0;
    while(checkACKFlag != 1){
        TXR = c;    // send 1 byte of data
        waitForTXByte();
        checkACKFlag = checkForACK();
    }
    CR = stop;
}

/*********************************************************************************************
**  Read Byte from EEPROM flash
*********************************************************************************************/
char readByteFromChip(void){
    
    int checkACKFlag = 0;
    char receivedByte;

    while(checkACKFlag != 1){
        TXR = 0xA0; // Write Control Byte
        CR = startWrite;
        waitForTXByte();
        checkACKFlag = checkForACK();
    }

    checkACKFlag = 0;
    while(checkACKFlag != 1){
        TXR = 0x00; // Address Byte 1
        waitForTXByte();
        checkACKFlag = checkForACK();
    }

    checkACKFlag = 0;
    while(checkACKFlag != 1){
        TXR = 0x00; // Address Byte 2
        waitForTXByte();
        checkACKFlag = checkForACK();
    }


    while(checkACKFlag != 1){
        TXR = 0xA1; // Read Control Byte
        CR = startRead;
        waitForTXByte();
        checkACKFlag = checkForACK();
    }
    
    waitForReceivedByte();
    receivedByte = RXR;
    CR = stop;

    return receivedByte;
}

/*********************************************************************************************
** Probe SR register to check if TIP bit is clear
*********************************************************************************************/
void waitForTXByte(void){
    while ((SR & 0x02) >> 1 == 1);
}

/*********************************************************************************************
** Probe RX register to check if it has received data from slave
*********************************************************************************************/
void waitForReceivedByte(void){
    while ((SR & 0x01) == 0);
}

/*********************************************************************************************
** Probe Status Register to check if slave has ACKed
*********************************************************************************************/
int checkForACK(void){
    if ((SR & 0x80) >> 7)
       return 0;
    else return 1;
}

/*********************************************************************************************
** Initialize IIC Communication
*********************************************************************************************/
void IIC_Init(void){

    // Set Clock Frequency to 100kHz as per page 7 of in IIC controller Document
    CTR = 0x00; // Clear EN bit to set clock value first
    PRERlo = 0x32;
    PRERhi = 0x00;

    // Enable EN bit (core is disable) & Disable IEN bit (interrupts disable)
    CTR = 0x80;
}

void main(void)
{
    char sendByte = 's';
    char recievedByte;
    scanflush() ;                       // flush any text that may have been typed ahead
    printf("\r\nHello CPEN 412 Student\r\nWelcome to Lab3!!!\r\n");

    IIC_Init();
    writeByteToChip(sendByte);
    recievedByte = readByteFromChip();

    printf("This is the sent Byte: %c\r\n", sendByte);
    printf("This is the received Byte: %c\r\n", recievedByte);

    while(1);
   // programs should NOT exit as there is nothing to Exit TO !!!!!!
   // There is no OS - just press the reset button to end program and call debug
}
