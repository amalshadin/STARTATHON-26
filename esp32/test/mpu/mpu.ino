#include <Wire.h>

const int MPU_ADDR = 0x68;

void setup() {
  Serial.begin(115200);

  // Initialize I2C pins (SDA=21, SCL=22)
  Wire.begin(21, 22);

  // Wake up the MPU-6500 / MPU-6050
  // By default, it starts in sleep mode.
  // We write 0x00 to the Power Management 1 register (0x6B) to wake it up.
  Wire.beginTransmission(MPU_ADDR);
  Wire.write(0x6B);  // PWR_MGMT_1 register
  Wire.write(0x00);  // 0 wakes up the sensor
  Wire.endTransmission(true);

  Serial.println("MPU initialized, reading data...");
}

void loop() {
  Wire.beginTransmission(MPU_ADDR);
  Wire.write(0x3B);             // Starting register for accelerometer data (ACCEL_XOUT_H)
  Wire.endTransmission(false);  // Restart condition

  // Request 14 consecutive bytes:
  // 6 bytes Accel + 2 bytes Temp + 6 bytes Gyro
  Wire.requestFrom(MPU_ADDR, 14, true);

  // Combine the High and Low bytes for each axis
  int16_t accX = (Wire.read() << 8 | Wire.read());
  int16_t accY = (Wire.read() << 8 | Wire.read());
  int16_t accZ = (Wire.read() << 8 | Wire.read());

  int16_t tempRaw = (Wire.read() << 8 | Wire.read());

  int16_t gyroX = (Wire.read() << 8 | Wire.read());
  int16_t gyroY = (Wire.read() << 8 | Wire.read());
  int16_t gyroZ = (Wire.read() << 8 | Wire.read());

  // Print values to Serial Monitor
  Serial.print("AccX: ");
  Serial.print(accX);
  Serial.print("\t| AccY: ");
  Serial.print(accY);
  Serial.print("\t| AccZ: ");
  Serial.print(accZ);

  // Print raw temp (conversion formula varies slightly between 6050 and 6500)
  Serial.print("\t| Temp_Raw: ");
  Serial.print(tempRaw);

  Serial.print("\t| GyroX: ");
  Serial.print(gyroX);
  Serial.print("\t| GyroY: ");
  Serial.print(gyroY);
  Serial.print("\t| GyroZ: ");
  Serial.println(gyroZ);

  delay(100);  // Read 10 times a second
}