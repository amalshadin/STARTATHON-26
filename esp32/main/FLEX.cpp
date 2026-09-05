#include "PIN.h"
#include "FLEX.h"

#include <Arduino.h>

FLEXData FLEXManager::read() {
  FLEXData data;
  data.flex1 = analogRead(PIN::flexPin1);
  data.flex2 = analogRead(PIN::flexPin2);
  data.flex3 = analogRead(PIN::flexPin3);
  return data;
}

void FLEXManager::printData(const FLEXData& data) {
  Serial.println("Flex 1: ");
  Serial.println(data.flex1);
  Serial.println("Flex 2: ");
  Serial.println(data.flex2);
  Serial.println("Flex 3: ");
  Serial.println(data.flex3);

  Serial.println("-----------------------");
}
