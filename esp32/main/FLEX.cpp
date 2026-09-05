#include <Arduino.h>
#include "FLEX.h"

const int flexPin1 = 34;
const int flexPin2 = 35;
const int flexPin3 = 36;

FLEXData FLEXManager::read() {
  FLEXData data;
  data.flex1 = analogRead(flexPin1);
  data.flex2 = analogRead(flexPin2);
  data.flex3 = analogRead(flexPin3);
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
