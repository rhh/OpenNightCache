//****************************************************************
/*
 * NightCacheBlinker_0_1 (rhh - 05aug10)
 * Basic Watchdog Sleep Example 
 * should flash LED on pin 13 every second (@3..5V !!!)
 * 
 * based upon example code "Nightingale" by: 
 * Martin Nawrath nawrath@khm.de
 * Kunsthochschule fuer Medien Koeln
 * Academy of Media Arts Cologne
 
 */
//****************************************************************

#include <avr/sleep.h>
#include <avr/wdt.h>
// missing in this version of <sleep.h>
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

int pinLed = 13;        // as usual...

volatile boolean f_wdt = 1;
volatile int LastLight = 1023;  // MaxValue...

// -------------------------------- Setup Method ----------------------------
void setup(){

  Serial.begin(38400);
  pinMode(pinLed,OUTPUT);
  Serial.println("NightCacheBlinker 0.1 (rhh, 05aug10)");

  wdt_mysetup(WDTO_30MS);  // [WDTO_15MS..WDTO_8S] - (15MS, 30, 60, 120, 250, 500, 1S, 2S, 4s, 8s)
}

//--------------------------------- Main-Loop -------------------------------
void loop()
{
  int light;
  
  light=analogRead(0);  // reading photoresistor

  Serial.print("light: " );
  Serial.println(light );

  BlinkLed(50);

  Serial.println("Sleep " );
  delay(2);               // wait until the last serial character is send

  // -------------------------- go to sleep...
  pinMode(pinLed,INPUT);               // set all used port to intput to save power
  ADCSRA &= ~(1<<ADEN);                // switch Analog to Digitalconverter OFF                                       
  set_sleep_mode(SLEEP_MODE_PWR_DOWN); // was: (SLEEP_MODE_STANDBY)
  sleep_enable();                      // 
  sleep_bod_disable();                 // disable BrownOutDetection during sleep...
  sei();
  
  sleep_cpu();  //  sleep_mode();                        // System sleeps here

    // -------------------------- wake up again...
  sleep_disable();                     // System continues execution here when watchdog timed out 
  ADCSRA |= (1<<ADEN);                 // switch Analog to Digitalconverter ON
  pinMode(pinLed,OUTPUT);              // restore all pins state
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

//  Serial.print("wdt_mysetup: ");
//  Serial.println(prescaler, BIN);  
}

// Watchdog Interrupt Service / is executed when  watchdog timed out
ISR(WDT_vect) {
  f_wdt=1;  // meeningless, just to do something...
}

// Utility method
void BlinkLed(int duration) {
  digitalWrite(pinLed,1);  
  // Serial.print("LED on  " );
  delay(duration);          // just long enough to make it visible
  digitalWrite(pinLed,0); 
}




