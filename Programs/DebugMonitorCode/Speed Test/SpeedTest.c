#include <stdio.h>
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


int a[100][100], b[100][100], c[100][100];
int i, j, k, sum;


void SpeedTest(void){

    printf("\n\nStart.....");
    for(i=0; i <50; i ++)  {
        printf("%d ", i);
        for(j=0; j < 50; j++)  {
            sum = 0 ;
            for(k=0; k <50; k++)   {
                sum = sum + b[i][k] * b[k][j] + a[i][k] * c[i][j];
                sum = sum + b[i][k] * b[k][j] + a[i][k] * c[i][j];
                sum = sum + b[i][k] * b[k][j] + a[i][k] * c[i][j];
                sum = sum + b[i][k] * b[k][j] + a[i][k] * c[i][j];
                sum = sum + b[i][k] * b[k][j] + a[i][k] * c[i][j];
                sum = sum + b[i][k] * b[k][j] + a[i][k] * c[i][j];
                sum = sum + b[i][k] * b[k][j] + a[i][k] * c[i][j];
                sum = sum + b[i][k] * b[k][j] + a[i][k] * c[i][j];
                sum = sum + b[i][k] * b[k][j] + a[i][k] * c[i][j];
                sum = sum + b[i][k] * b[k][j] + a[i][k] * c[i][j];
                sum = sum + b[i][k] * b[k][j] + a[i][k] * c[i][j];
                sum = sum + b[i][k] * b[k][j] + a[i][k] * c[i][j];
                sum = sum + b[i][k] * b[k][j] + a[i][k] * c[i][j];
                sum = sum + b[i][k] * b[k][j] + a[i][k] * c[i][j];
                sum = sum + b[i][k] * b[k][j] + a[i][k] * c[i][j];
                sum = sum + b[i][k] * b[k][j] + a[i][k] * c[i][j];
                sum = sum + b[i][k] * b[k][j] + a[i][k] * c[i][j];
                sum = sum + b[i][k] * b[k][j] + a[i][k] * c[i][j];
                sum = sum + b[i][k] * b[k][j] + a[i][k] * c[i][j];
                sum = sum + b[i][k] * b[k][j] + a[i][k] * c[i][j];
            }
            c[i][j] = sum ;
        }
    }
    printf("\n\nDone.....");
}

/******************************************************************************************************************************
* Start of user program
******************************************************************************************************************************/

void main()
{
    scanflush() ;                       // flush any text that may have been typed ahead
    printf("\r\nHello CPEN 412 TA\r\nWelcome to Lab3!!!\r\n");

    SpeedTest();

    while(1);
   // programs should NOT exit as there is nothing to Exit TO !!!!!!
   // There is no OS - just press the reset button to end program and call debug
}