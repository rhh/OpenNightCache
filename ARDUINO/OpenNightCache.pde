//****************************************************************
/*
 * NightCacheBlinker_0_5 (rhh - 25aug10)
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
 * 0.4 added "night-detection" to prevent circuit to be triggered
 *     by moving leaves of a tree in front of the sun (or the like...)
 *     (yes A0 really goes up above 1000 
 * 0.5 changed watchdog initialisation to an understood register access
 *     sequence and added BrownOutDetection-disable while asleep
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
// ------------------------ unfortunately missing in this version of <sleep.h>
#define sleep_bod_disable() \
do { \
  uint8_t tempreg; \
  __asm__ __volatile__("in %[tempreg], %[mcucr]" "\n\t" \
                       "ori %[tempreg], %[bods_bodse]" "\n\t" \
                       "out %[mcucr], %[tempreg]" "\n\t" \
                       "andi %[tempreg], %[not_bodse]" "\n\t" \
                       "out %[mcucr], %[tempreg]" \
                       : [tempreg] "=&d" (tempreg) \
                       : [mcucr] "I" _SFR_IO_ADDR(MCUCR), \
                         [bods_bodse] "i" (_BV(BODS) | _BV(BODSE)), \
                         [not_bodse] "i" (~_BV(BODSE))); \
} while (0)

#define DEBUG false

#define PIN_LED  13        // as usual...
#define PIN_LDR  14        // equals to A(0)

volatile boolean wdt_expired = 1;
volatile int LastLight = 0;  // MinValue...

// -------------------------------- Setup Method ----------------------------
void setup(){

#if DEBUG
  Serial.begin(38400);
  Serial.println("NightCacheBlinker  0.5 (rhh, 25aug10)");
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
  bool AbruptIncrease, ReallyDark;

  Light = analogRead(0);  // reading photoresistor
  LightDeviation = LastLight - Light;

#if DEBUG
  Serial.print("L: " );
  Serial.print(Light);
  Serial.print(" - dL: " );
  Serial.println(LightDeviation);
#endif

  AbruptIncrease = LightDeviation > 30;
  ReallyDark = LastLight > 990;
  
  if(AbruptIncrease && ReallyDark)    
  {
    BlinkLed(20, 200, 20);      // ...(OnTime, OffTime, Cycles)
  }

#if DEBUG
  Serial.println("Sleep " );
  delay(2);               // wait until the last serial character is send
#endif

  // -------------------------- go to sleep...
  LastLight = Light;
  pinMode(PIN_LED,INPUT);              // set all used port to intput to save power
  pinMode(PIN_LDR, INPUT);             // ... just to be shure ...
  digitalWrite(PIN_LDR, LOW);          // switch off internal pullup
  ADCSRA &= ~(1<<ADEN);                // switch Analog to Digitalconverter OFF

  set_sleep_mode(SLEEP_MODE_PWR_DOWN); 
  sleep_enable();
  sleep_bod_disable();                 // disable BrownOutDetection during sleep...
  sei();

  sleep_cpu();                         // System sleeps here

  // -------------------------- wake up again...
  //cli();          // ???
  sleep_disable();                     // System continues execution here when watchdog timed out 

  pinMode(PIN_LED,OUTPUT);             // restore all pins state
  pinMode(PIN_LDR, INPUT);             // ... just to be shure ...
  digitalWrite(PIN_LDR, HIGH);         // switch on internal pullup
  ADCSRA |= (1<<ADEN);                 // switch Analog to Digitalconverter ON
}


void wdt_mysetup(byte wdt_time) {
  byte prescaler;

  // ------------ fiddle up prescaler bits
  wdt_time %= 10;                     // [0..9] allowed
  prescaler = wdt_time & 7;           // take lower 3 bits from argument
  if (wdt_time > 7) prescaler|= (1<<WDP3);  // if wdt_time = 8 or 9: set WDP3-Bit 


  // ------------ setup watchdog registers
  cli(); wdt_reset();                // no interruption please!!!
  
  MCUSR &= ~(1<<WDRF);               // reset "Watchdog System Reset Flag" (no override from there...)
  WDTCSR |= (1<<WDCE) | (1<<WDE);    // ---------- start of timed sequence (doc8271_ATmega168_328_Manual.pdf|p.52)
  WDTCSR = prescaler | (1<<WDIE);    // set prescaler & "WatchDog Interrupt Mode" (NO "Reset Mode"!)
                                     // ---------- end of the timed sequence
  sei();

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







