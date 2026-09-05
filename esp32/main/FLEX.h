#ifndef FLEX_H
#define FLEX_H

#include <stdint.h>

struct FLEXData {
  uint16_t flex1;
  uint16_t flex2;
  uint16_t flex3;
};

class FLEXManager {
public:
  FLEXData read();
  static void printData(const FLEXData& data);
};

#endif
