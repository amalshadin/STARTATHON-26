#include "../../main/FLEX.h"
#include "../../main/FLEX.cpp"

FLEXManager flex;

void setup() {
  // Start the Serial communication at 115200 baud rate
  Serial.begin(115200);

  // Wait a moment for the serial port to initialize
  delay(1000);
  Serial.println("Flex Sensor Test Started.");
}

void loop() {
  FLEXData data = flex.read();
  flex.printData(data);
  delay(100);
}
