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
#define ReadIACK        0x21    // Set RD, IACK bits        --> (0010 0001)
#define ReadNACKIACK    0x29    // Set RD, ACK, IACK bits   --> (0010 1001)
#define stopWrite       0x50    // set STO, WR bit          --> (0101 0000)
// Read Command Register Commands
#define startRead       0xA8    // set STA, RD, ACK bit     --> (1010 1000)
#define stopRead        0x41    // set STO, IACK bit        --> (0100 0001)


/*********************************************************************************************
**  Function protoTypes
*********************************************************************************************/
void SequentialBlockWrite(int address, int sizeOfBlock, char payloadByte);
void WritePageToChip(void);
void WriteByteToChip(char c);
void initiateWriteSequence(int address);
void WaitForWriteCycle(void);
void SequentialBlockRead(int address, int sizeOfBlock, char expectedByte);
void ReadPageFromChip(void);
char ReadByteFromChip(void);
void initiateReadSequence(int address);
void BlockDecode(char * writeControlByte, char * readControlByte, int address);
void WaitForTXByte(void);
void WaitForReceivedByte(void);
int CheckForACK(void);
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
**  Write Sequential Block to EEPROM Chip
*********************************************************************************************/
void SequentialBlockWrite(int address, int sizeOfBlock, char payloadByte){
    int i = 0;
    int endAddress = address + sizeOfBlock;

    // Parameter checks
    if (endAddress > 0x1FFFF){
        printf("Not Enough Memory locations!\r\n");
        return;
    }

    printf("Writing Sequential Block of Data to EEPROM\r\n");

    while (address <= endAddress){

        initiateWriteSequence(address);

        // Fill up a 128 byte block
        for(i= address%128; i<128; i++){

            TXR = payloadByte;        
            CR = Write;
            WaitForTXByte();

            if(!CheckForACK())
                printf("No ACK returned for byte #%d", i);
            
            address ++;
        }

        CR = stop;
        WaitForWriteCycle();
    }
}

/*********************************************************************************************
**  Write Page to EEPROM Chip
*********************************************************************************************/
void WritePageToChip(void){

    int i = 0;

    printf("Writing Page to EEPROM\r\n");
    initiateWriteSequence(0x00000);

    for(i=0; i<128; i++){
        TXR = i;            // send 1 byte of data
        CR = Write;
        WaitForTXByte();
        if(!CheckForACK())
            printf("No ACK returned for byte #%d", i);
    }

    CR = stop;
    WaitForWriteCycle();
}

/*********************************************************************************************
**  Write Byte to EEPROM Chip
*********************************************************************************************/
void WriteByteToChip(char c){

    printf("Writing Byte to EEPROM\r\n");
    // Ensure TX is ready before sending control byte
    WaitForTXByte();

    TXR = 0xA0;         // Write Control Byte (1010 0000)
    CR = startWrite;    // Set STA bit, set WR bit
    WaitForTXByte();
    if(!CheckForACK())
        printf("No ACK returned");

    TXR = 0x20;         // Address Byte 1
    CR = Write;         // Set WR bit
    WaitForTXByte();
    if(!CheckForACK())
        printf("No ACK returned");

    TXR = 0x00;         // Address Byte 2
    CR = Write;         // Set WR bit
    WaitForTXByte();
    if(!CheckForACK())
        printf("No ACK returned");

    TXR = c;            // send 1 byte of data
    CR = Write;
    WaitForTXByte();
    if(!CheckForACK())
        printf("No ACK returned");

    CR = stop;
    WaitForWriteCycle();
}

/*********************************************************************************************
**  Write Page to EEPROM Chip
*********************************************************************************************/
void initiateWriteSequence(int address){
    char writeControlByte = 0, unusedControlByte = 0;

    BlockDecode(&writeControlByte, &unusedControlByte, address);

    // Ensure TX is ready before sending control byte
    WaitForTXByte();

    TXR = writeControlByte;     // Write Control Byte (1010 0000)
    CR = startWrite;            // Set STA bit, set WR bit
    WaitForTXByte();
    if(!CheckForACK())
        printf("No ACK returned");

    TXR = (address >> 8) & 0xFF;    // Address Byte 1
    CR = Write;                 // Set WR bit
    WaitForTXByte();
    if(!CheckForACK())
        printf("No ACK returned");

    TXR = address & 0xFF;       // Address Byte 2
    CR = Write;                 // Set WR bit
    WaitForTXByte();
    if(!CheckForACK())
        printf("No ACK returned");

    return;
}

/*********************************************************************************************
** Wait For EEPROM to complete internal Write Cycle
*********************************************************************************************/
void WaitForWriteCycle(void){
    do
    {
        TXR = 0xA0; // Write Control Byte (1010 0000)
        CR = start;
        printf("Waiting for Internal Write!\r\n");
    } while (!CheckForACK);
    printf("Internal Write Complete!\r\n");
    return;
}

/*********************************************************************************************
**  Read Block from EEPROM flash
*********************************************************************************************/
void SequentialBlockRead(int address, int sizeOfBlock, char expectedByte){

    char receivedByte;
    int endAddress = address + sizeOfBlock;

    // Parameter checks
    if (endAddress > 0x1FFFF){
        printf("Not Enough Memory locations!\r\n");
        return;
    }

    initiateReadSequence(address);

    while (address < endAddress){
        if (address == endAddress - 1 || address == 0xFFFF)
            CR = ReadNACKIACK;
        else CR = ReadIACK;

        WaitForReceivedByte();
        receivedByte = RXR;

        if (address != (endAddress - 1) && !CheckForACK())
            printf("No ACK returned for read at address: 0x%X", address);

        if (receivedByte != expectedByte){
                printf("Sequential Read Error at address: 0x%X\r\n", address);
                CR = stop;
                return;
        }

        if (address == 0x0FFFF){ // Stop and Start Read from 2nd bank
            CR = stop;
            initiateReadSequence(address);
        }
        address ++;        
    }

    CR = stop;
    printf("Sequential Block Read Successful\r\n");
}

/*********************************************************************************************
**  Read Page from EEPROM flash
*********************************************************************************************/
void ReadPageFromChip(void){

    int i = 0;
    char receivedByte;

    printf("Reading Page from EEPROM \r\n");

    // Ensure TX is ready before sending control byte
    WaitForTXByte();

    TXR = 0xA0;         // Write Control Byte (1010 0000)
    CR = startWrite;    // set STA bit
    WaitForTXByte();
    if(!CheckForACK())
        printf("No ACK returned");

    TXR = 0x00;         // Address Byte 1
    CR = Write;         // set WR bit
    WaitForTXByte();
    if(!CheckForACK())
        printf("No ACK returned");
    
    TXR = 0x00;         // Address Byte 2
    CR = Write;         // set WR bit
    WaitForTXByte();
    if(!CheckForACK())
        printf("No ACK returned");

    TXR = 0xA1;         // Read Control Byte (1010 0001)
    CR = startWrite;    // Set STA bit, WR bit
    WaitForTXByte();
    if(!CheckForACK())
        printf("No ACK returned");

    for (i=0; i<128; i++){
        if (i != 127)
            CR = ReadIACK;
        else  CR = ReadNACKIACK;

        WaitForReceivedByte();
        receivedByte = RXR;

        if (i != 127 && !CheckForACK())
            printf("No ACK returned for byte #%d", i);

        if (receivedByte != i){
                printf("Page Read Failed at Byte #%d\r\n", i);
                CR = stop;
                return;
        }
    }
    CR = stop;
    printf("Page Read Successful\r\n");
}

/*********************************************************************************************
**  Read Byte from EEPROM flash
*********************************************************************************************/
char ReadByteFromChip(void){

    char receivedByte;

    printf("Reading Byte from EEPROM \r\n");

    // Ensure TX is ready before sending control byte
    WaitForTXByte();

    TXR = 0xA0;         // Write Control Byte (1010 0000)
    CR = startWrite;    // set STA bit
    WaitForTXByte();
    if(!CheckForACK())
        printf("No ACK returned");

    TXR = 0x20;         // Address Byte 1
    CR = Write;         // set WR bit
    WaitForTXByte();
    if(!CheckForACK())
        printf("No ACK returned");
    
    TXR = 0x00;         // Address Byte 2
    CR = Write;         // set WR bit
    WaitForTXByte();
    if(!CheckForACK())
        printf("No ACK returned");

    TXR = 0xA1;         // Read Control Byte (1010 0001)
    CR = startWrite;    // Set STA bit, WR bit
    WaitForTXByte();
    if(!CheckForACK())
        printf("No ACK returned");

    CR = ReadNACKIACK;
 
    WaitForReceivedByte();
    receivedByte = RXR;

    CR = stop;

    return receivedByte;
}

/*********************************************************************************************
**  Initiate Read Command to EEPROM
*********************************************************************************************/
void initiateReadSequence(int address){

    char writeControlByte = 0, readControlByte = 0;
   
    // Decode Address to determine bank
    BlockDecode(&writeControlByte, &readControlByte, address);
    
    // Ensure TX is ready before transmission
    WaitForTXByte();

    TXR = writeControlByte;          // Write Control Byte (1010 0000)
    CR = startWrite;                // set STA bit
    WaitForTXByte();
    if(!CheckForACK())
        printf("No ACK returned");

    TXR = (address >> 8) & 0xFF;    // Address Byte 1
    CR = Write;                     // set WR bit
    WaitForTXByte();
    if(!CheckForACK())
        printf("No ACK returned");
    
    TXR = address & 0xFF;           // Address Byte 2
    CR = Write;                     // set WR bit
    WaitForTXByte();
    if(!CheckForACK())
        printf("No ACK returned");

    TXR = readControlByte;          // Read Control Byte (1010 0001)
    CR = startWrite;                // Set STA bit, WR bit
    WaitForTXByte();
    if(!CheckForACK())
        printf("No ACK returned");
}

/*********************************************************************************************
**  Decode Bank from address
*********************************************************************************************/
void BlockDecode(char * writeControlByte, char * readControlByte, int address){
    
    char bank;

    // Block Decoder
    bank = (address >> 16) & 0xF;
    if (bank == 0){
        *writeControlByte = 0xA0;
        *readControlByte = 0xA1;
    }
    else if (bank == 1){
        *writeControlByte = 0xA8;
        *readControlByte = 0xA9;
    }
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
    char sendByte = 0x55;
    char recievedByte;

    scanflush();     // flush any text that may have been typed ahead
    printf("\r\nHello IIC Lab\r\n\r\n");

    IIC_Init();
    WriteByteToChip(sendByte);
    recievedByte = ReadByteFromChip();

    printf("Sent Byte: 0x%X & Recieved Byte: 0x%X\r\n\r\n", sendByte, recievedByte);

    WritePageToChip();
    ReadPageFromChip();

    SequentialBlockWrite(0x00000, 16384, sendByte);
    SequentialBlockRead(0x00000, 16384, sendByte);

    while(1);
   // programs should NOT exit as there is nothing to Exit TO !!!!!!
   // There is no OS - just press the reset button to end program and call debug
}
