/*
 Name:		Debug 65816.ino
 Author:	rehsd
*/

const char BANK[] = { 4, 5, 6, 7, 8, 9, 10, 11 };												//4=A23 <--> 11=A16
const char ADDR[] = { 22, 24, 26, 28, 30, 32, 34, 36, 38, 40, 42, 44, 46, 48, 50, 52 };		//22=A15 <--> 52=A0	
const char DATA[] = { 39, 41, 43, 45, 47, 49, 51, 53 };										//39=D7	<--> 53=D0
//GND!
#define CLOCK			2
#define READ_WRITE		3

#define OEB_RAM			37
#define OEB_ROM			35
#define OEB_RAMEXT		33
#define OEB_IO			31
#define OEB_VID			29
#define OEB_TBD1		27
#define OEB_TBD2		25
#define OEB_TBD3		23




void setup() {
	for (int n = 0; n < 8; n++)
	{
		pinMode(BANK[n], INPUT);
	}

	for (int n = 0; n < 16; n++)
	{
		pinMode(ADDR[n], INPUT);
	}

	for (int n = 0; n < 8; n++)
	{
		pinMode(DATA[n], INPUT);
	}

	pinMode(CLOCK, INPUT);
	pinMode(READ_WRITE, INPUT);

	pinMode(OEB_RAM, INPUT);
	pinMode(OEB_ROM, INPUT);
	pinMode(OEB_RAMEXT, INPUT);
	pinMode(OEB_IO, INPUT);
	pinMode(OEB_VID, INPUT);
	pinMode(OEB_TBD1, INPUT);
	pinMode(OEB_TBD2, INPUT);
	pinMode(OEB_TBD3, INPUT);


	attachInterrupt(digitalPinToInterrupt(CLOCK), onClock, RISING);
	Serial.begin(115200);

	Serial.println("Loading...");
}

void onClock()
{
	char output[40];
	unsigned int bank = 0;
	unsigned int address = 0;
	unsigned int data = 0;

	Serial.print("BANK:");
	for (int n = 0; n < 8; n++)
	{
		int bit = digitalRead(BANK[n]) ? 1 : 0;
		Serial.print(bit);
		bank = (bank << 1) + bit;
	}
	
	Serial.print(" ADDR:");
	for (int n = 0; n < 16; n++)
	{
		int bit = digitalRead(ADDR[n]) ? 1 : 0;
		Serial.print(bit);
		address = (address << 1) + bit;
	}

	Serial.print("  DATA:");
	for (int n = 0; n < 8; n++)
	{
		int bit = digitalRead(DATA[n]) ? 1 : 0;
		Serial.print(bit);
		/*if (n == 3)
		{
			Serial.print(":");
		}*/
		data = (data << 1) + bit;
	}



	sprintf(output, "    HEX: %02x:%04x  %c %02x    OEB: %c %c %c %c %c", bank, address, digitalRead(READ_WRITE) ? 'R' : 'W', data, 
		digitalRead(OEB_RAM) ? '-' : 'R', digitalRead(OEB_ROM) ? '-' : 'O', digitalRead(OEB_RAMEXT) ? '-' : 'E', digitalRead(OEB_IO) ? '-' : 'I', digitalRead(OEB_VID) ? '-' : 'V');
	Serial.print(output);

	Serial.print("   ");

	Serial.println();

	Serial.flush();

}

void loop() {

}
