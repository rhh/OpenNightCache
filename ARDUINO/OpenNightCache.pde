//****************************************************************
/*
 * NightCacheBlinker_0_2 (rhh - 06aug10)
 * Waits in Powerdown-mode for the Watchdog to expire;
 * then checks for light deviation and in case its above
 * the pos. theshhold (lamp inlluminates the photocell
 * at night) blinks the LED as an answer...
 * 
 */
//****************************************************************

#include <avr/sleep.h>
#include <avr/wdt.h>

int pinLed = 13;        // as usual...

volatile boolean f_wdt = 1;
volatile int LastLight = 0;  // MinValue...

// -------------------------------- Setup Method ----------------------------
void setup(){

  Serial.begin(38400);
  pinMode(pinLed,OUTPUT);
  Serial.println("NightCacheBlinker  0.2 (rhh, 06aug10)");

  wdt_mysetup(WDTO_120MS);  // [WDTO_15MS..WDTO_8S] - (15, 30, 60, 120, 250, 500, 1S, 2S, 4s, 8s)
}

//--------------------------------- Main-Loop -------------------------------
void loop()
{
  int Light, LightDeviation;

  Light = analogRead(0);  // reading photoresistor
  LightDeviation = LastLight - Light;
  LastLight = Light;
  Serial.print("l: " );
  Serial.print(Light);
  Serial.print(" - dl: " );
  Serial.println(LightDeviation);

  if(LightDeviation > 100)    // abrupt increase!
  {
    BlinkLed(20, 200, 20);      // ...(OnTime, OffTime, Cycles)
  }


  Serial.println("Sleep " );
  delay(2);               // wait until the last serial character is send

  // -------------------------- go to sleep...
  pinMode(pinLed,INPUT);               // set all used port to intput to save power
  ADCSRA &= ~(1<<ADEN);                // switch Analog to Digitalconverter OFF
  set_sleep_mode(SLEEP_MODE_PWR_DOWN); // ... SLEEP_MODE_STANDBY
  sleep_enable();

  sleep_mode();                        // System sleeps here

    // -------------------------- wake up again...
  sleep_disable();                     // System continues execution here when watchdog timed out 
  ADCSRA |= (1<<ADEN);                 // switch Analog to Digitalconverter ON
  pinMode(pinLed,OUTPUT);              // restore all pins state
}


void wdt_mysetup(byte wdt_time) {
  byte prescaler;

  wdt_time %= 10;                     // [0..9] allowed
  prescaler = wdt_time & 7;           // take lower 3 bits from argument
  if (wdt_time > 7) prescaler|= (1<<WDP3);  // if wdt_time = 8 or 9: set WDP3-Bit 

  MCUSR &= ~(1<<WDRF);                // reset "Watchdog System Reset Flag"

  // don't ask me about that sequence...
  WDTCSR |= (1<<WDCE) | (1<<WDE);    // set WDT "System Reset Mode"
  WDTCSR = (1<<WDCE) | prescaler ;   // set prescaler
  WDTCSR |= (1<<WDIE);               // set WDT "Interrupt Mode"

  Serial.print("wdt_mysetup: ");
  Serial.println(prescaler, BIN);  
}

// Watchdog Interrupt Service / is executed when  watchdog timed out
ISR(WDT_vect) {
  f_wdt=1;  // meeningless, just to do something...
}

// Utility method
void BlinkLed(int OnTime, int OffTime, int Cycles) {

  for(int i=0; i<Cycles; i++)
  {
    digitalWrite(pinLed,1);  
    delay(OnTime);          // just long enough to make it visible
    digitalWrite(pinLed,0); 
    delay(OffTime);
  }
}





