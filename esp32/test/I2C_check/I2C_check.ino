#include <Wire.h>

void setup() {
  Serial.begin(115200);

  Wire.begin(21, 22);

  Serial.println("I2C Scanner");

  for (byte address = 1; address < 127; address++) {

    Wire.beginTransmission(address);

    if (Wire.endTransmission() == 0) {
      Serial.print("I2C device found at 0x");
      Serial.println(address, HEX);
    }
  }
}

void loop() {
}
