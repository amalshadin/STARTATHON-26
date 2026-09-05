#ifndef BLE_H
#define BLE_H

#include <Arduino.h>

class BLEManager {
public:
  void begin();
  void update(String value);
};

#endif
