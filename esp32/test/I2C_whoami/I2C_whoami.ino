#include <Wire.h>

void setup() {
  Serial.begin(115200);

  Wire.begin(21, 22);

  Wire.beginTransmission(0x68);
  Wire.write(0x75);
  Wire.endTransmission(false);

  Wire.requestFrom(0x68, 1);

  if (Wire.available()) {
    byte whoAmI = Wire.read();

    Serial.print("WHO_AM_I = 0x");
    Serial.println(whoAmI, HEX);
  } else {
    Serial.println("No response");
  }
}

void loop() {
}