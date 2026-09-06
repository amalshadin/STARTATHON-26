#include "MPU.h"
#include "PIN.h"

#include <Wire.h>
#include <Arduino.h>

const int MPU_ADDR = 0x68;

void MPU6050::begin() {
  // Initialize I2C pins (SDA=21, SCL=22)
  Wire.begin(::PIN::SDAPin, ::PIN::SCLPin);

  // Wake up the MPU-6500 / MPU-6050
  // By default, it starts in sleep mode.
  // We write 0x00 to the Power Management 1 register (0x6B) to wake it up.
  Wire.beginTransmission(MPU_ADDR);
  Wire.write(0x6B);  // PWR_MGMT_1 register
  Wire.write(0x00);  // 0 wakes up the sensor
  Wire.endTransmission(true);

  MPU6050::InitializedMessage();
}

void MPU6050::InitializedMessage() {
  Serial.println("MPU6050 Initialized!");
  Serial.println("Printing raw data from the sensor:");
}

MPUData MPU6050::read() {
  MPUData data;

  Wire.beginTransmission(MPU_ADDR);
  Wire.write(0x3B);             // Starting register for accelerometer data (ACCEL_XOUT_H)
  Wire.endTransmission(false);  // Restart condition

  // Request 14 consecutive bytes:
  // 6 bytes Accel + 2 bytes Temp + 6 bytes Gyro
  Wire.requestFrom(MPU_ADDR, 14, true);

  // Combine the High and Low bytes for each axis
  // Read accelerometer data
  data.accX = (Wire.read() << 8 | Wire.read());
  data.accY = (Wire.read() << 8 | Wire.read());
  data.accZ = (Wire.read() << 8 | Wire.read());

  // Read temperature data
  data.tempRaw = (Wire.read() << 8 | Wire.read());

  // Read gyroscope data
  data.gyroX = (Wire.read() << 8 | Wire.read());
  data.gyroY = (Wire.read() << 8 | Wire.read());
  data.gyroZ = (Wire.read() << 8 | Wire.read());

  return data;
}

void MPU6050::printData(const MPUData& data) {
  Serial.print("Accel X: ");
  Serial.print(data.accX);
  Serial.print(", Accel Y: ");
  Serial.print(data.accY);
  Serial.print(", Accel Z: ");
  Serial.println(data.accZ);

  Serial.print("Temp Raw: ");
  Serial.println(data.tempRaw);

  Serial.print("Gyro X: ");
  Serial.print(data.gyroX);
  Serial.print(", Gyro Y: ");
  Serial.print(data.gyroY);
  Serial.print(", Gyro Z: ");
  Serial.println(data.gyroZ);

  Serial.println("-----------------------");
}
