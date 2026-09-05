#ifndef PAYLOAD_H
#define PAYLOAD_H

#include "MPU.h"
#include "FLEX.h"

struct Payload {
  MPUData mpuData;
  FLEXData flexData;

  void printData() const {
    MPU6050::printData(mpuData);
    FLEXManager::printData(flexData);
  }
};
#endif
