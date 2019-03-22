#include <stdio.h>

/*********************************************************************************************
**  IIC registers
*********************************************************************************************/
#define PRERlo *(volatile unsigned char *)(0x0040800) // Clock Prescale register lo-byte
#define PRERhi *(volatile unsigned char *)(0x0040800) // Clock Prescale register hi-byte
#define CTR *(volatile unsigned char *)(0x0040800) // Control Register
#define TXR *(volatile unsigned char *)(0x0040800) // Transmit Register
#define RXR *(volatile unsigned char *)(0x0040800) // Receive Register
#define CR *(volatile unsigned char *)(0x0040800) // Command Register
#define SR *(volatile unsigned char *)(0x0040800) // Status Register


/*********************************************************************************************
**  Write to EEPROM
*********************************************************************************************/
void writeToChip(char c){

}

/*********************************************************************************************
**  Read from EEPROM
*********************************************************************************************/
void readFromChip(){
    
}

/*********************************************************************************************
**  
*********************************************************************************************/
void waitForACK(){

}

/*********************************************************************************************
** 
*********************************************************************************************/
void generateStartCondition(){

}

/*********************************************************************************************
** 
*********************************************************************************************/
void generateStopCondition(){

}


/*********************************************************************************************
** Initialize IIC Communication
*********************************************************************************************/
void IIC_Init(){

    // Set Clock Frequency to 100kHz as per page 7 of in IIC controller Document
    CTR = 0x00; // Clear EN bit to set clock value first
    PRERlo = 0x3F;
    PRERhi = 0x00;

    // Enable EN bit (core is disable) & Disable IEN bit (interrupts disable)
    CTR = 0x80;
}

void main()
{
    char test_byte;
    scanflush() ;                       // flush any text that may have been typed ahead
    printf("\r\nHello CPEN 412 Student\r\nWelcome to Lab3!!!\r\n");

    while(1);
   // programs should NOT exit as there is nothing to Exit TO !!!!!!
   // There is no OS - just press the reset button to end program and call debug
}