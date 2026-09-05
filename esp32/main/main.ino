#include "BLE.h"

BLEManager ble;

void setup() {
  Serial.begin(115200);

  ble.begin();
}

void loop() {
}
