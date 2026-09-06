#ifndef LED_H
#define LED_H

#include "PIN.h"

#include <Arduino.h>
#include <Ticker.h>

class LED {
public:
  static void begin();
  static void on();
  static void off();
  static void setState(bool state);
  static void blink(uint32_t interval_ms);
  static void blinkFor(uint32_t interval_ms, uint32_t duration_ms);
  static void stopBlink();
  static void toggle();
private:
  static Ticker blinker;
  static Ticker durationTimer;
  static bool state;
};

#endif
