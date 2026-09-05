#ifndef BLE_H
#define BLE_H

#include <Arduino.h>

class BLEManager {
public:
  void begin();
  void update(String value);
  void update(uint8_t* data, size_t length);

  // Template to send any standard data type or struct automatically
  template <typename T>
  void update(const T& data) {
    update((uint8_t*)&data, sizeof(T));
  }
};

#endif
