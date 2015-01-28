/*
Automatic door opener via RFID and a Servo
Created by: Kristian Lauszus and Thomas Jespersen - TKJ Electronics
Released under the GNU General Public License
Ver. 2
*/

//Start
#include <EEPROM.h>
#include <Servo.h> 

//Initialiser
Servo servoLock;  // create servo object to control a servo 
                // a maximum of eight servo objects can be created 
                
#define RFID_Enabled_Pin 2  // sets RFID enable pin to pin 2
#define servoPin 3 // sets the servo's pin to pin 3
#define LockedPos 10 //sets locked degrees on servo
#define UnlockedPos 110 //sets unlock degrees om servo

byte buffer[100]; //used to store the incoming bytes from the RFID
byte RFID_Master[10] = {'1', '7', '0', '0', '7', 'D', 'B', '2', '4', 'F'}; //the master RFID fob (key) to look for
byte RFID_Slave1[10], RFID_Slave2[10], RFID_Slave3[10]; //the varible which stores the slave fobs
byte i; //used to keep track of which bit to write to
byte i2; //used to erase the RFID fob (key) number from the buffer

boolean DoorLocked; //true if door is locked

byte checkPosition; //used to check if the incomming number is true or false
boolean RFID_Master_Correct; //true if Master fob is detected , false if not
boolean RFID_Slave1_Correct, RFID_Slave2_Correct, RFID_Slave3_Correct; //true if slave RFID fob (key) is detected, false if not
boolean RFID_SaveNextRead; //true if in programming mode

void setup() {
  pinMode(13, OUTPUT); //enables the diode on the arduino  
  pinMode(RFID_Enabled_Pin, OUTPUT); //sets the RFID pin to output
  RFID_Enable(false); //used to set the status of the RFID reader  
  EEPROM_Read_Slaves(); //Varible used to read EEPROM
//Lås
  PreLock(); //locks the arduino on startup
  RFID_Enable(true); //used to set the status of the RFID reader  
  Serial.begin(2400);  //sets baudrate
  i = 1; //sets the varible to 1, and thereby skip the start byte (0x0A)
}
//Gå til
//Loop
void loop() { //the main loop
// Seriel data
  if (Serial.available()) { //check if the RFID reader sends anything
    if (buffer[0] != 0x0A) { //check if it the start bit is 0x0A
      buffer[0] = Serial.read(); //write bit to buffer
    } else {
//Modtag      
      buffer[i] = Serial.read(); //write next bit to buffer
      if (buffer[i] == 0x0D) {   //if end bit is send, disable the RFID reader temporary
        Serial.print("RFID Tag scanned: ");
        RFID_Enable(false);
        RFID_Master_Correct = true;
        RFID_Slave1_Correct = true;
        RFID_Slave2_Correct = true;
        RFID_Slave3_Correct = true;        
        
//RFID
        // We have read all bytes - we are now going to check them
        for (checkPosition = 0; checkPosition < 10; checkPosition++) { //Read bit fra 0-9
#if defined(ARDUINO) && ARDUINO >=100
          Serial.write(buffer[checkPosition+1]);
#else
          Serial.print(buffer[checkPosition+1], BYTE);
#endif
          if (buffer[checkPosition+1] == RFID_Slave1[checkPosition] && RFID_Slave1_Correct == true) {   // compares the written bits to "RFID1" 
            RFID_Slave1_Correct = true; //Slave1 RFID tag is detected
          } else {
            RFID_Slave1_Correct = false; //Slave1 RFID tag is not detected  
          }
          if (buffer[checkPosition+1] == RFID_Slave2[checkPosition] && RFID_Slave2_Correct == true) {   // compares the written bits to "RFID2" 
            RFID_Slave2_Correct = true; //Slave2 RFID tag is detected
          } else {
            RFID_Slave2_Correct = false; //Slave2 RFID tag is not detected  
          }
          if (buffer[checkPosition+1] == RFID_Slave3[checkPosition] && RFID_Slave3_Correct == true) {   // compares the written bits to "RFID3" 
            RFID_Slave3_Correct = true; //Slave3 RFID tag is detected
          } else {
            RFID_Slave3_Correct = false; //Slave3 RFID tag is detected 
          }          
//Master
          if (buffer[checkPosition+1] == RFID_Master[checkPosition] && RFID_Master_Correct == true) {   // compares the written bits to "Master" 
            RFID_Master_Correct = true; //Master RFID tag is detected
          } else {
            RFID_Master_Correct = false; //Master RFID tag is detected  
          }
        }
        Serial.println("");
        if (RFID_SaveNextRead == false && (RFID_Slave1_Correct == true || RFID_Slave2_Correct == true || RFID_Slave3_Correct == true) && RFID_Master_Correct == false) { //see if the right RFID fob (key) is detected
          if (RFID_Slave1_Correct == true) { Serial.println("Slave1 Card Scanned"); }
          if (RFID_Slave2_Correct == true) { Serial.println("Slave2 Card Scanned"); }
          if (RFID_Slave3_Correct == true) { Serial.println("Slave3 Card Scanned"); }          
//Døren          
          if (DoorLocked == true) { //see if door is locked or not
//Lås op          
            Serial.print("Unlocking..."); //if the door is locked then unlocked it
            Unlock(5); //unlock with 5ms delay
            Serial.println(" Unlocked!");
          } else {
//Lås            
            Serial.print("Locking..."); //if the door is unlocked then lock it     
            Lock(5); //lock with 5ms delay
            Serial.println(" Locked!");            
          }
//Vent          
          delay(1000); // Wait for you to remove the RFID fob (key)
        } else if (RFID_Master_Correct == true && RFID_SaveNextRead == false) { // If the Master Card is scanned when not in programming mode
          Serial.println("Master Card Scanned - Programming mode Enabled");
          delay(1000);     
          RFID_SaveNextRead = true;  // Enable programming mode   
        } else if (RFID_Master_Correct == false && RFID_SaveNextRead == true) { // If another card is scanned when in programming mode      
          // Save the Card    
 //Ledige
 //Gem
          if (RFID_Slave1[0] == 0) { // Is the Slave1 Card slot empty?
            for (checkPosition = 0; checkPosition < 10; checkPosition++) { //Read bit fra 0-9
              RFID_Slave1[checkPosition] = buffer[checkPosition+1]; // Save the scanned card as Slave1
            }         
            Serial.println("RFID Card saved in: Slave1");
            delay(1000);             
          } else if (RFID_Slave2[0] == 0) { // Is the Slave2 Card slot empty?
            for (checkPosition = 0; checkPosition < 10; checkPosition++) { //Read bit fra 0-9
              RFID_Slave2[checkPosition] = buffer[checkPosition+1]; // Save the scanned card as Slave2
            }     
            Serial.println("RFID Card saved in: Slave2");            
            delay(1000);             
          } else if (RFID_Slave3[0] == 0) { // Is the Slave3 Card slot empty?
            for (checkPosition = 0; checkPosition < 10; checkPosition++) { //Read bit fra 0-9
              RFID_Slave3[checkPosition] = buffer[checkPosition+1]; // Save the scanned card as Slave3
            }
            Serial.println("RFID Card saved in: Slave3");            
            delay(1000);             
          } else {
            Serial.println("No free Card slots");
            RFID_Enable(true); //turns on the RFID reader
            delay(1000);   
            RFID_Enable(false); //turns off the RFID reader            
            delay(1000);
          }
          EEPROM_Save_Slaves();
          RFID_SaveNextRead = false;
//Master
        } else if (RFID_Master_Correct == true && RFID_SaveNextRead == true) { // If the Master Card is scanned when in programming mode
          Serial.println("Master Card Scanned again - Removing all saved Cards");
          delay(1000); 
//Slet
          // Remove all Slave Cards         
          for (checkPosition = 0; checkPosition < 10; checkPosition++) { //Read bit fra 0-9
            RFID_Slave1[checkPosition] = 0;
          }      
          for (checkPosition = 0; checkPosition < 10; checkPosition++) { //Read bit fra 0-9
            RFID_Slave2[checkPosition] = 0;
          }      
          for (checkPosition = 0; checkPosition < 10; checkPosition++) { //Read bit fra 0-9
            RFID_Slave3[checkPosition] = 0;
          }                
          EEPROM_Save_Slaves();
          RFID_SaveNextRead = false;          
        }     
          
        RFID_Enable(true); //turns on the RFID reader
        EmptySerialBuffer(); //erase the buffer
        Serial.println("");
      }
      i++; //used in the beginning to write to each bit in the buffer
    }
  }
//Gå til  
}


void EmptySerialBuffer() { //replaces all bits in the buffer with zeros
  while (Serial.available()) { Serial.read(); }
  for (i2 = 0; i2 <= i; i2++) { 
    buffer[i2] = 0; 
  }
  i = 0;
}   

void PreLock() {
  servoLock.attach(servoPin);  // attaches the servo on pin 3 to the servo object
  servoLock.write(LockedPos);              // tell servo to go to position in variable 'LockedPos' 
  delay(250);                       // waits 250ms for the servo to reach the position 
  servoLock.detach();   //detaches the servo, so it's not using power
  DoorLocked = true;    //the door is locked
}

void Unlock(byte speedDelay) {
  int pos;
  servoLock.attach(servoPin);  // attaches the servo on pin 3 to the servo object
  for(pos = LockedPos; pos < UnlockedPos; pos += 1)  // goes from 10 degrees to 110 degrees 
  {                                  // in steps of 1 degree 
    servoLock.write(pos);              // tell servo to go to position in variable 'pos' 
    delay(speedDelay);                       // waits 5ms for the servo to reach the position 
  } 
  servoLock.detach();   //detaches the servo, so it's not using power
  DoorLocked = false;   //the door is unlocked
}

void Lock(byte speedDelay) {
  int pos;
  servoLock.attach(servoPin);  // attaches the servo on pin 3 to the servo object
  for(pos = UnlockedPos; pos > LockedPos; pos -= 1)  // goes from 110 degrees to 10 degrees 
  {                                  // in steps of 1 degree 
    servoLock.write(pos);              // tell servo to go to position in variable 'pos' 
    delay(speedDelay);                       // waits 5ms for the servo to reach the position 
  } 
  servoLock.detach();   //detaches the servo, so it's not using power
  DoorLocked = true;    //the door is locked
}

void RFID_Enable(boolean enabled) {
  if (enabled == true) { 
    digitalWrite(RFID_Enabled_Pin, LOW); //enables the RDIF reader and turns on the diode on the arduino
    digitalWrite(13, HIGH);
  } else {                               //disables the RDIF reader and turns off the diode on the arduino
    digitalWrite(RFID_Enabled_Pin, HIGH);
    digitalWrite(13, LOW);    
  }
}


void EEPROM_Read_Slaves() {
  byte EPROMaddr;  
  for (EPROMaddr = 0; EPROMaddr < 10; EPROMaddr++) { //Read bit from 0-9
    RFID_Slave1[EPROMaddr] = EEPROM.read(EPROMaddr);
  } 
  for (EPROMaddr = 10; EPROMaddr < 20; EPROMaddr++) { //Read bit from 0-9
    RFID_Slave2[EPROMaddr-10] = EEPROM.read(EPROMaddr);
  }    
  for (EPROMaddr = 20; EPROMaddr < 30; EPROMaddr++) { //Read bit from 0-9
    RFID_Slave3[EPROMaddr-20] = EEPROM.read(EPROMaddr);
  }      
}

void EEPROM_Save_Slaves() {
  byte EPROMaddr;
  for (EPROMaddr = 0; EPROMaddr < 10; EPROMaddr++) { //Read bit from 0-9
    EEPROM.write(EPROMaddr, RFID_Slave1[EPROMaddr]);
  }     
  for (EPROMaddr = 10; EPROMaddr < 20; EPROMaddr++) { //Read bit from 0-9
    EEPROM.write(EPROMaddr, RFID_Slave2[EPROMaddr-10]);
  }     
  for (EPROMaddr = 20; EPROMaddr < 30; EPROMaddr++) { //Read bit from 0-9
    EEPROM.write(EPROMaddr, RFID_Slave3[EPROMaddr-20]);
  }       
}
