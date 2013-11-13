//****************************************************************
/*
 * NightCacheBlinker_0_3 (rhh - 07aug10)
 * Waits in Powerdown-mode for the Watchdog to expire;
 * then checks for light deviation and in case its above
 * the pos. theshhold (lamp inlluminates the photocell
 * at night) blinks the LED as an answer...
 * 
 * Changelog:
 * 0.2 from elmentary blinking to aimed funcionallity 
 *     (photocell with 100k fixed pullup)
 * 0.3 changed fixed external pullup 
 *     against switchable internal pullup of A0 (i.e. pin14)
 *
 * current consumption:
 * a) active mode:     Ea = 10mA x 500uS = 5uAS 
 * b) heating up osc.: Eosc = 3.3mA x 1.11mS = 3.66uAS 
 * c) powerdown time:  Epd = 27,4uA x 120ms = 3.29uAS
 * => Iav(erage) = Eges/Tperiode = (5+3.66+3.29)/0.120 = 99,6uA
 * => Tbat = Ebat/Iav = 300mAh/0.0996ma = 3010h = 126d = 4month
 */
//****************************************************************

#include <avr/sleep.h>
#include <avr/wdt.h>

#define DEBUG false

#define PIN_LED  13        // as usual...
#define PIN_LDR  14        // => A(0)

volatile boolean wdt_expired = 1;
volatile int LastLight = 0;  // MinValue...

// -------------------------------- Setup Method ----------------------------
void setup(){

#if DEBUG
  Serial.begin(38400);
  Serial.println("NightCacheBlinker  0.3 (rhh, 08aug10)");
#endif

  pinMode(PIN_LED,OUTPUT);
  pinMode(PIN_LDR, INPUT);              // ... just to be shure ...
  digitalWrite(PIN_LDR, HIGH);          // switch on internal pullup

  wdt_mysetup(WDTO_120MS);  // [WDTO_15MS..WDTO_8S] - (15, 30, 60, 120, 250, 500, 1S, 2S, 4s, 8s)
}

//--------------------------------- Main-Loop -------------------------------
void loop()
{
  int Light, LightDeviation;

  Light = analogRead(0);  // reading photoresistor
  LightDeviation = LastLight - Light;
  LastLight = Light;

#if DEBUG
  Serial.print("l: " );
  Serial.print(Light);
  Serial.print(" - dl: " );
  Serial.println(LightDeviation);
#endif

  if(LightDeviation > 30)    // abrupt increase! // 100 -> 
  {
    BlinkLed(20, 200, 20);      // ...(OnTime, OffTime, Cycles)
  }

#if DEBUG
  Serial.println("Sleep " );
  delay(2);               // wait until the last serial character is send
#endif

  // -------------------------- go to sleep...
  pinMode(PIN_LED,INPUT);               // set all used port to intput to save power
  pinMode(PIN_LDR, INPUT);             // ... just to be shure ...
  digitalWrite(PIN_LDR, LOW);          // switch off internal pullup
  ADCSRA &= ~(1<<ADEN);                // switch Analog to Digitalconverter OFF

  set_sleep_mode(SLEEP_MODE_PWR_DOWN); // ... SLEEP_MODE_STANDBY
  sleep_enable();
  sei();

  sleep_mode();                        // System sleeps here

  // -------------------------- wake up again...
  //cli();          // ???
  sleep_disable();                     // System continues execution here when watchdog timed out 

  pinMode(PIN_LED,OUTPUT);              // restore all pins state
  pinMode(PIN_LDR, INPUT);              // ... just to be shure ...
  digitalWrite(PIN_LDR, HIGH);          // switch on internal pullup
  ADCSRA |= (1<<ADEN);                 // switch Analog to Digitalconverter ON
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

#if DEBUG
  Serial.print("wdt_mysetup: ");
  Serial.println(prescaler, BIN);  
#endif
}

// Watchdog Interrupt Service / is executed when  watchdog timed out
ISR(WDT_vect) {
  //wdt_expired=1;  // meeningless, just to do something...
}

// Utility method
void BlinkLed(int OnTime, int OffTime, int Cycles) {

  for(int i=0; i<Cycles; i++)
  {
    digitalWrite(PIN_LED,1);  
    delay(OnTime);          // just long enough to make it visible
    digitalWrite(PIN_LED,0); 
    delay(OffTime);
  }
}







