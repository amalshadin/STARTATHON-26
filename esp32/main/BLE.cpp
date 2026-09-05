#include "BLE.h"

#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>
#include <BLE2902.h>

#define SERVICE_UUID "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

class MyCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *pCharacteristic) {
    String rxValue = pCharacteristic->getValue();
    if (rxValue.length() > 0) {
      Serial.print("Received Value: ");
      Serial.println(rxValue.c_str());
    }
  }
};

BLECharacteristic *characteristic;

void BLEManager::begin() {

  BLEDevice::init("ESP32-BLE-Test");

  BLEServer *server = BLEDevice::createServer();

  BLEService *service = server->createService(SERVICE_UUID);

  characteristic = service->createCharacteristic(
    CHARACTERISTIC_UUID,
    BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_NOTIFY);

  characteristic->setCallbacks(new MyCallbacks());
  characteristic->addDescriptor(new BLE2902());

  characteristic->setValue("Hello from ESP32!");

  service->start();

  BLEAdvertising *advertising = BLEDevice::getAdvertising();
  advertising->addServiceUUID(SERVICE_UUID);
  advertising->setScanResponse(true);
  advertising->start();

  Serial.println("BLE started!");
  Serial.println("Device name: ESP32-BLE-Test");
}

void BLEManager::update(String value) {
  characteristic->setValue(value.c_str());
  characteristic->notify();
}

void BLEManager::update(uint8_t* data, size_t length) {
  characteristic->setValue(data, length);
  characteristic->notify();
}
