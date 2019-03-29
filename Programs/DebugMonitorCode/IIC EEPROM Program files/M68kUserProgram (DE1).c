#include <stdio.h>
#include <stdlib.h>

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
void SequentialBlockWrite(long address, long sizeOfBlock, char payloadByte);
void UtilSequentialBlockWrite(long address, long endAddress, char payloadByte);
void WritePageToChip(void);
void WriteByteToChip(char c);
void initiateWriteSequence(long address);
void WaitForWriteCycle(void);
void SequentialBlockRead(long address, long sizeOfBlock, char expectedByte);
int utilSequentialBlockRead(long utilAddress, long utilEndAddress, char expectedByte);
void ReadPageFromChip(void);
char ReadByteFromChip(void);
void initiateReadSequence(long address);
void BlockDecode(char * writeControlByte, char * readControlByte, long address);
void WaitForTXByte(void);
void WaitForReceivedByte(void);
int CheckForACK(void);
void IIC_Init(void);
void GenerateADCOutput(void);
void DValueOfAInput(void);
void delay(int seconds);

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
void SequentialBlockWrite(long address, long sizeOfBlock, char payloadByte){
    int i = 0;
    long endAddress = (address + sizeOfBlock) - 1;
    long overflowEndAddress = 0;

    // Safety check
    if (sizeOfBlock > 0x1FFFF){
        printf("SequentialBlockWrite: Size of Input Data Block cannot exceed 128kBytes\r\n");
        return;
    }

    if (address > 0x1FFFF){
        printf("SequentialBlockWrite: Entered Address Out of Range\r\n");
        return;
    }

    // Wrap-Around check
    if (endAddress > 0x1FFFF){
        overflowEndAddress = endAddress - 0x20000;
        endAddress = 0x1FFFF;
    }

    printf("Performing Sequential Block Write to EEPROM...\r\n");

    initiateWriteSequence(address);
    UtilSequentialBlockWrite(address, endAddress, payloadByte);

    if (overflowEndAddress){
        initiateWriteSequence(0x00000);
        UtilSequentialBlockWrite(0x00000, overflowEndAddress, payloadByte);
    }

    printf("Sequential Block Write Completed!\r\n\r\n");
    return;
}

/*********************************************************************************************
**  Write Sequential Block to EEPROM Chip -- Utility
*********************************************************************************************/
void UtilSequentialBlockWrite(long address, long endAddress, char payloadByte){
    while (address <= endAddress){

        if (address%128 != 0 || address == 0){
            // Fill up a 128 byte block
            TXR = payloadByte;        
            CR = Write;
            WaitForTXByte();

            if(!CheckForACK())
                printf("UtilSequentialBlockWrite: No ACK returned for byte at 0x%X\r\n", address);

        } else {    
            // Need to write in next 128 Byte block
            CR = stop;
            WaitForWriteCycle();
            initiateWriteSequence(address);

            // Write 1st Byte in new block
            TXR = payloadByte;        
            CR = Write;
            WaitForTXByte();
        }
        address ++;
    }

    CR = stop;
    WaitForWriteCycle();
}

/*********************************************************************************************
**  Write Page to EEPROM Chip
*********************************************************************************************/
void WritePageToChip(void){

    int i = 0;

    printf("Writing Page to EEPROM\r\n");
    initiateWriteSequence(0x12000);

    for(i=0; i<128; i++){
        TXR = i;            // send 1 byte of data
        CR = Write;
        WaitForTXByte();
        if(!CheckForACK())
            printf("No ACK returned for byte #%d\r\n", i);
    }

    CR = stop;
    WaitForWriteCycle();
}

/*********************************************************************************************
**  Write Byte to EEPROM Chip
*********************************************************************************************/
void WriteByteToChip(char c){

    printf("Writing Byte to EEPROM\r\n");
    initiateWriteSequence(0x1F000);

    TXR = c;            // send 1 byte of data
    CR = Write;
    WaitForTXByte();
    if(!CheckForACK())
        printf("No ACK returned\r\n");

    CR = stop;
    WaitForWriteCycle();
}

/*********************************************************************************************
**  Write Page to EEPROM Chip
*********************************************************************************************/
void initiateWriteSequence(long address){
    unsigned char writeControlByte = 0, unusedControlByte = 0;

    BlockDecode(&writeControlByte, &unusedControlByte, address);

    // Ensure TX is ready before sending control byte
    WaitForTXByte();

    TXR = writeControlByte;     // Write Control Byte (1010 0000)
    CR = startWrite;            // Set STA bit, set WR bit
    WaitForTXByte();
    if(!CheckForACK())
        printf("No ACK returned\r\n");

    TXR = (address >> 8) & 0xFF;    // Address Byte 1
    CR = Write;                 // Set WR bit
    WaitForTXByte();
    if(!CheckForACK())
        printf("No ACK returned\r\n");

    TXR = address & 0xFF;       // Address Byte 2
    CR = Write;                 // Set WR bit
    WaitForTXByte();
    if(!CheckForACK())
        printf("No ACK returned\r\n");

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
        delay(1);
    } while (!CheckForACK);
    return;
}

/*********************************************************************************************
**  Read Block from EEPROM flash
*********************************************************************************************/
void SequentialBlockRead(long address, long sizeOfBlock, char expectedByte){
    
    long endAddress = (address + sizeOfBlock) - 1;
    long overflowEndAddress = 0;

    // Safety check
    if (sizeOfBlock > 0x1FFFF){
        printf("SequentialBlockRead: Size of Input Data Block cannot exceed 128kBytes\r\n");
        return;
    }

    if (address > 0x1FFFF){
        printf("SequentialBlockRead: Entered Address Out of Range\r\n");
        return;
    }

    // Wrap-Around check
    if (endAddress > 0x1FFFF){
        overflowEndAddress = endAddress - 0x20000;
        endAddress = 0x1FFFF;
    }

    printf("Starting Sequential Block Read...\r\n");
    
    initiateReadSequence(address);
    if(!utilSequentialBlockRead(address, endAddress, expectedByte)){
            printf("Sequential Block Read Failed!\r\n");
            return;
    }

    if (overflowEndAddress){
        initiateReadSequence(0x00000);
        if(!utilSequentialBlockRead(0x00000, overflowEndAddress, expectedByte)){
            printf("Sequential Block Read Failed!\r\n");
            return;
        }
    }

    printf("Sequential Block Read successful!\r\n");
}


int utilSequentialBlockRead(long utilAddress, long utilEndAddress, char expectedByte){

    char receivedByte;

    while (utilAddress <= utilEndAddress){
        
        if (utilAddress == utilEndAddress || utilAddress == 0x0FFFF)
            CR = ReadNACKIACK;
        else CR = ReadIACK;

        WaitForReceivedByte();
        receivedByte = RXR;

        if ((utilAddress != utilEndAddress && utilAddress != 0xFFFF) && !CheckForACK())
            printf("No ACK returned for read at address: 0x%X\r\n", utilAddress);

        if (receivedByte != expectedByte){
                printf("Sequential Read Error at address: 0x%X\r\n", utilAddress);
                CR = stop;
                return 0;
        }

        if (utilAddress == 0x0FFFF){ // Stop and Start Read from 2nd bank
            CR = stop;
            initiateReadSequence(utilAddress+1);
        }
        utilAddress ++;
    }
    CR = stop;
    return 1;
}

/*********************************************************************************************
**  Read Page from EEPROM flash
*********************************************************************************************/
void ReadPageFromChip(void){

    int i = 0;
    char receivedByte;

    printf("Reading Page from EEPROM \r\n");

    initiateReadSequence(0x12000);

    for (i=0; i<128; i++){
        if (i != 127)
            CR = ReadIACK;
        else  CR = ReadNACKIACK;

        WaitForReceivedByte();
        receivedByte = RXR;

        if (i != 127 && !CheckForACK())
            printf("No ACK returned for byte #%d\r\n", i);

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
    initiateReadSequence(0x1F000);

    CR = ReadNACKIACK;
    WaitForReceivedByte();
    receivedByte = RXR;

    CR = stop;
    return receivedByte;
}

/*********************************************************************************************
**  Initiate Read Command to EEPROM
*********************************************************************************************/
void initiateReadSequence(long address){

    unsigned char writeControlByte = 0, readControlByte = 0;
   
    // Decode Address to determine bank
    BlockDecode(&writeControlByte, &readControlByte, address);
        
    // Ensure TX is ready before transmission
    WaitForTXByte();

    TXR = writeControlByte;         // Write Control Byte
    CR = startWrite;                // set STA bit
    WaitForTXByte();
    if(!CheckForACK())
        printf("No ACK returned\r\n");

    TXR = (address >> 8) & 0xFF;    // Address Byte 1
    CR = Write;                     // set WR bit
    WaitForTXByte();
    if(!CheckForACK())
        printf("No ACK returned\r\n");
    
    TXR = address & 0xFF;           // Address Byte 2
    CR = Write;                     // set WR bit
    WaitForTXByte();
    if(!CheckForACK())
        printf("No ACK returned\r\n");

    TXR = readControlByte;          // Read Control Byte
    CR = startWrite;                // Set STA bit, WR bit
    WaitForTXByte();
    if(!CheckForACK())
        printf("No ACK returned\r\n");
}

/*********************************************************************************************
**  Decode Bank from address
*********************************************************************************************/
void BlockDecode(char * writeControlByte, char * readControlByte, long address){
    char bank;

    // Block Decoder
    if (address < 0x10000){
        *writeControlByte = 0xA0;
        *readControlByte = 0xA1;
    }
    else {
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

/*********************************************************************************************
** Generate ADC Output
*********************************************************************************************/
void GenerateADCOutput(void){

    char i=0;
    printf("Writing continuous data to ADC\r\n");
    // Ensure TX is ready before sending control byte
    WaitForTXByte();

    TXR = 0x9E;         //AddresByte
    CR = startWrite;    // Set STA bit, set WR bit
    WaitForTXByte();
    if(!CheckForACK())
        printf("no ACK returned");

    TXR = 0x60;         // ControlByte
    CR = Write;         // Set WR bit
    WaitForTXByte();
    if(!CheckForACK())
        printf("no ACK returned");
    while(1)
    {
            if(i==0)
            {            
                TXR = i;         // Send 0V
                CR = Write;         // Set WR bit
                WaitForTXByte();
                    if(!CheckForACK())
                         printf("no ACK returned");
                i=255;          //set i high 
            }
            else
            {
                TXR = i;         // Send 5V
                CR = Write;         // Set WR bit
                WaitForTXByte();
                    if(!CheckForACK())
                        printf("no ACK returned");
                i=0;            //set i low
            }

    }
}

/*********************************************************************************************
** Digital Value of input channel
*********************************************************************************************/
void DValueOfAInput(void){

    int DecimalRx;

    printf("Generating digital value for analong input on pin AIN0 \r\n");
    // Ensure TX is ready before sending control byte
    WaitForTXByte();
    TXR = 0x9F;         //AddresByte
    CR = startWrite;    // Set STA bit, set WR bit
    WaitForTXByte();
    if(!CheckForACK())
        printf("no ACK returned");
         // ControlByte
    CR = ReadIACK;
    WaitForReceivedByte();
    DecimalRx = (int) RXR;
    if(DecimalRx<100)
    printf("The digital value on pin Ain0 is: 0 V \r\n");
    else    
    printf("The digital value on pin Ain0 is: %d V \r\n",(RXR/46));
    CR = stop;
}

void delay(int seconds)
{   // this function needs to be finetuned for the specific microprocessor
    int i, j, k;
    int wait_loop0 = 100;
    int wait_loop1 = 3;

    for(i = 0; i < seconds; i++)
    {
        for(j = 0; j < wait_loop0; j++)
        {
            for(k = 0; k < wait_loop1; k++)
            {   // waste function, volatile makes sure it is not being optimized out by compiler
                int volatile t = 120 * j * i + k;
                t = t + 5;
            }
        }
    }
}

void main(void)
{
    char sendByte = 0x72;
    char recievedByte;

    scanflush();     // flush any text that may have been typed ahead
    printf("\r\nHello IIC Lab\r\n\r\n");

    IIC_Init();

    SequentialBlockWrite(0x1FFF0, 0x1FFFF, sendByte);
    SequentialBlockRead(0x1FFF0, 0x1FFFF, sendByte);

    printf("\r\n");

    WritePageToChip();
    ReadPageFromChip();

    printf("\r\n");

    WriteByteToChip(sendByte);
    recievedByte = ReadByteFromChip();

    printf("Sent Byte: 0x%X & Recieved Byte: 0x%X\r\n\r\n", sendByte, recievedByte);

    // GenerateADCOutput();
    // DValueOfAInput();

    while(1);
   // programs should NOT exit as there is nothing to Exit TO !!!!!!
   // There is no OS - just press the reset button to end program and call debug
}
