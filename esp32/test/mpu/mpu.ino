#include "../../main/MPU.cpp"

MPU6050 mpu;

void setup() {
  Serial.begin(115200);

  mpu.begin();
}

void loop() {
  MPUData data = mpu.read();
  mpu.printData(data);
}
