┌───────────────┐
│     ESP32     │
│ Sensors + BLE │
└───────┬───────┘
        │
       BLE
        │
        ▼
┌───────────────┐
│ Flutter App   │  ← Frontend
│               │
│ Games         │
│ BLE           │
│ Real-time     │
└───────┬───────┘
        │ HTTPS
        ▼
┌───────────────┐
│    Backend    │  ← Server
│               │
│ Auth          │
│ APIs          │
│ Data logic    │
│ AI agents     │
└───────┬───────┘
        │
        ▼
┌───────────────┐
│   Database    │
└───────────────┘