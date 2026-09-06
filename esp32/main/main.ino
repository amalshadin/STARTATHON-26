#include "BLE.h"
#include "MPU.h"
#include "FLEX.h"
#include "PAYLOAD.h"
#include "LED.h"

BLEManager ble;
MPU6050 mpu;
FLEXManager flex;
Payload payload;

void setup() {
  Serial.begin(115200);

  ble.begin();
  mpu.begin();
  LED::begin();
  LED::blinkFor(200, 1000, [](){ LED::blink(1000); });
}

void loop() {
  // Read sensor data
  payload.mpuData = mpu.read();
  payload.flexData = flex.read();
  ble.update(payload);
}
