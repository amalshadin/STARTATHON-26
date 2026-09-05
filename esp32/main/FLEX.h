#ifndef FLEX_H
#define FLEX_H

#include <stdint.h>

struct FLEXData {
  int flex1;
  int flex2;
  int flex3;
};

class FLEXManager {
public:
  FLEXData read();
  static void printData(const FLEXData& data);
};

#endif
