#ifndef BLE_H
#define BLE_H

#include <Arduino.h>

class BLEManager {
public:
  static String deviceName;
  void begin();
  void update(String value);
  void update(uint8_t* data, size_t length);
  void setDeviceName(const String& name) {
    deviceName = name;
  }

  // Template to send any standard data type or struct automatically
  template <typename T>
  void update(const T& data) {
    update((uint8_t*)&data, sizeof(T));
  }
};

#endif
