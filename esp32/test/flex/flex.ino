const int flexPin = 34;

void setup() {
  // Start the Serial communication at 115200 baud rate
  Serial.begin(115200);

  // Wait a moment for the serial port to initialize
  delay(1000);
  Serial.println("Flex Sensor Test Started.");
}

void loop() {
  // Read the raw analog value from the sensor (0 to 4095)
  int flexValue = analogRead(flexPin);

  // Print the value to the Serial Monitor
  Serial.print("Raw Flex Value: ");
  Serial.println(flexValue);

  delay(100);
}
