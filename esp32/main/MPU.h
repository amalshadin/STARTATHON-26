#ifndef MPU_H
#define MPU_H

#include <stdint.h>

struct MPUData {
  int16_t accX;
  int16_t accY;
  int16_t accZ;

  int16_t tempRaw;

  int16_t gyroX;
  int16_t gyroY;
  int16_t gyroZ;
};

class MPU6050 {
public:
  void begin();
  MPUData read();
  void InitializedMessage();
  static void printData(const MPUData& data);
};

#endif
