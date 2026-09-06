#include "LED.h"

Ticker LED::blinker;
Ticker LED::durationTimer;
bool LED::state = false;

void LED::begin() {
  pinMode(::PIN::ledPin, OUTPUT);
  off();
}

void LED::on() {
  stopBlink();
  state = true;
  digitalWrite(::PIN::ledPin, HIGH);
}

void LED::off() {
  stopBlink();
  state = false;
  digitalWrite(::PIN::ledPin, LOW);
}

void LED::setState(bool newState) {
  stopBlink();
  state = newState;
  digitalWrite(::PIN::ledPin, state ? HIGH : LOW);
}

void LED::blink(uint32_t interval_ms) {
  // attach_ms calls toggle() every interval_ms
  blinker.attach_ms(interval_ms, toggle);
}

void LED::blinkFor(uint32_t interval_ms, uint32_t duration_ms) {
  blink(interval_ms);
  durationTimer.once_ms(duration_ms, LED::off);
}

void LED::stopBlink() {
  blinker.detach();
  durationTimer.detach();
}

void LED::toggle() {
  state = !state;
  digitalWrite(::PIN::ledPin, state ? HIGH : LOW);
}
