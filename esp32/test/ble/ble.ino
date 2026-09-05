#include "../../main/BLE.cpp"

BLEManager ble;

int value = 0;

void setup() {
  Serial.begin(115200);

  ble.begin();
}

void loop() {
  ble.update(String(value));
  Serial.println(value);
  value++;
  delay(1000);
}
