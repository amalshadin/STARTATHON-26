#include "../../main/BLE.cpp"
#include "../../main/FLEX.cpp"
#include "../../main/MPU.cpp"
#include "../../main/PAYLOAD.h"

BLEManager ble;
FLEXManager flex;
MPU6050 mpu;

FLEXData flexData;
MPUData mpuData;
Payload payload;

int value = 0;

void setup() {
  Serial.begin(115200);

  ble.begin();
}

void loop() {
  randomValues();
  ble.update(String(value));  Serial.println(value++);
  ble.update(payload);  payload.printData();
  delay(1000);
}

void randomValues() {
  flexData.flex1 = random(0, 1024);
  flexData.flex2 = random(0, 1024);
  flexData.flex3 = random(0, 1024);

  mpuData.accX = random(-32768, 32767);
  mpuData.accY = random(-32768, 32767);
  mpuData.accZ = random(-32768, 32767);

  mpuData.tempRaw = random(-40, 85);

  mpuData.gyroX = random(-32768, 32767);
  mpuData.gyroY = random(-32768, 32767);
  mpuData.gyroZ = random(-32768, 32767);

  payload.flexData = flexData;
  payload.mpuData = mpuData;
}
