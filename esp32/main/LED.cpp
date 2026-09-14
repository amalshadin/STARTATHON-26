#include "LED.h"

Ticker LED::blinker;
Ticker LED::durationTimer;
bool LED::state = false;

uint32_t LED::currentInterval = 0;
uint32_t LED::currentDuration = 0;
uint32_t LED::currentStartTime = 0;
LedState LED::stateStack[10];
int LED::stackPointer = 0;

void LED::pushState() {
  if (currentInterval == 0) return; // Nothing to push
  if (stackPointer >= 10) return; // Stack full

  if (currentDuration <= 0) {
    // If no duration is set or negative value is provided, we can't calculate remaining time
    stateStack[stackPointer++] = {currentInterval, 0};
    return;
  }

  uint32_t elapsed = millis() - currentStartTime;
  uint32_t remaining = 0;

  if (elapsed >= currentDuration) {
    return; // already expired
  }
  remaining = currentDuration - elapsed;

  stateStack[stackPointer++] = {currentInterval, remaining};
}

void LED::popState() {
  currentInterval = 0;
  currentDuration = 0;
  currentStartTime = 0;

  if (stackPointer > 0) {
    LedState s = stateStack[--stackPointer];
    if (s.duration_ms > 0) {
      blinkFor(s.interval_ms, s.duration_ms);
    } else {
      blink(s.interval_ms);
    }
  } else {
    off();
  }
}

void LED::clearStack() {
  stackPointer = 0;
}

void LED::onDurationEnd() {
  popState();
}

void LED::begin() {
  pinMode(::PIN::ledPin, OUTPUT);
  off();
}

void LED::on() {
  // used to turn on the LED and reset the blink state
  clearStack();
  stopBlink();
  state = true;
  digitalWrite(::PIN::ledPin, HIGH);
}

void LED::off() {
  // used to turn off the LED and reset the blink state
  clearStack();
  stopBlink();
  currentInterval = 0;
  currentDuration = 0;
  state = false;
  digitalWrite(::PIN::ledPin, LOW);
}

void LED::setState(bool newState) {
  if (newState) on();
  else off();
}

void LED::blink(uint32_t interval_ms) {
  pushState();
  stopBlink();
  currentInterval = interval_ms;
  currentDuration = 0; // Infinite
  currentStartTime = millis();
  blinker.attach_ms(interval_ms, toggle);
}

void LED::blinkFor(uint32_t interval_ms, uint32_t duration_ms) {
  pushState();
  stopBlink();
  currentInterval = interval_ms;
  currentDuration = duration_ms;
  currentStartTime = millis();
  blinker.attach_ms(interval_ms, toggle);
  durationTimer.once_ms(duration_ms, onDurationEnd);
}

void LED::stopBlink() {
  blinker.detach();
  durationTimer.detach();
}

void LED::toggle() {
  state = !state;
  digitalWrite(::PIN::ledPin, state ? HIGH : LOW);
}
