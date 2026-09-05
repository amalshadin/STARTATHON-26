import serial
import matplotlib.pyplot as plt
import matplotlib.animation as animation
import numpy as np
import re
import sys
import argparse
import time
import math

parser = argparse.ArgumentParser(description='Visualize MPU6500 orientation using a Complementary Filter (Accel + Gyro).')
parser.add_argument('--port', type=str, default='/dev/ttyUSB0', help='Serial port')
parser.add_argument('--baud', type=int, default=115200, help='Baud rate')
args = parser.parse_args()

try:
    print(f"Connecting to {args.port} at {args.baud} baud...")
    ser = serial.Serial(args.port, args.baud, timeout=1)
    print("Connected! Waiting for data...")
except Exception as e:
    print(f"Error opening serial port: {e}")
    sys.exit(1)

fig = plt.figure(figsize=(8, 8))
ax = fig.add_subplot(111, projection='3d')

# Global variables for the filter and state
last_time = time.time()
pitch = 0.0
roll = 0.0
accX = accY = accZ = None
gyroX = gyroY = gyroZ = None

def animate(i):
    global last_time, pitch, roll
    global accX, accY, accZ, gyroX, gyroY, gyroZ
    
    updated = False
    
    # Read serial buffer
    while ser.in_waiting > 0:
        try:
            line = ser.readline().decode('utf-8', errors='ignore').strip()
            
            # Parse Accel line: "Accel X: 123, Accel Y: 456, Accel Z: 789"
            acc_match = re.search(r'Accel X:\s*(-?\d+),\s*Accel Y:\s*(-?\d+),\s*Accel Z:\s*(-?\d+)', line)
            if acc_match:
                accX = float(acc_match.group(1))
                accY = float(acc_match.group(2))
                accZ = float(acc_match.group(3))
            
            # Parse Gyro line: "Gyro X: 123, Gyro Y: 456, Gyro Z: 789"
            gyro_match = re.search(r'Gyro X:\s*(-?\d+),\s*Gyro Y:\s*(-?\d+),\s*Gyro Z:\s*(-?\d+)', line)
            if gyro_match:
                gyroX = float(gyro_match.group(1))
                gyroY = float(gyro_match.group(2))
                gyroZ = float(gyro_match.group(3))
                updated = True # We consider a frame complete when we get Gyro data
        except Exception:
            pass 

    if updated and accX is not None and gyroX is not None:
        current_time = time.time()
        dt = current_time - last_time
        last_time = current_time
        
        # 1. Convert raw Gyro data to radians per second
        # Default MPU6500 sensitivity is +/- 250 deg/s, which maps to 131 raw units per deg/s
        gyro_rate_x = (gyroX / 131.0) * (math.pi / 180.0)
        gyro_rate_y = (gyroY / 131.0) * (math.pi / 180.0)
        
        # 2. Calculate Pitch and Roll from Accelerometer
        acc_roll = math.atan2(accY, accZ)
        acc_pitch = math.atan2(accX, math.sqrt(accY**2 + accZ**2))
        
        # 3. Apply the Complementary Filter
        # We trust the Gyro for short-term quick movements (96%), 
        # but we slowly pull it toward the Accelerometer to fix drift over time (4%).
        alpha = 0.96 
        
        # Note: The signs (+/-) for the gyro integration depend on your physical IMU orientation.
        # If the arrow moves backwards during quick rotations, flip the + to a -.
        pitch = alpha * (pitch - gyro_rate_y * dt) + (1.0 - alpha) * acc_pitch
        roll = alpha * (roll + gyro_rate_x * dt) + (1.0 - alpha) * acc_roll
        
        # 4. Convert Pitch and Roll back into a 3D vector for matplotlib
        nx = math.sin(pitch)
        ny = math.sin(roll) * math.cos(pitch)
        nz = math.cos(roll) * math.cos(pitch)
        
        # Update the 3D plot
        ax.clear()
        ax.set_xlim([-1, 1])
        ax.set_ylim([-1, 1])
        ax.set_zlim([-1, 1])
        ax.set_xlabel('X Axis')
        ax.set_ylabel('Y Axis')
        ax.set_zlabel('Z Axis')
        ax.set_title('MPU6500 Sensor Fusion (Complementary Filter)')
        
        # Draw the filtered arrow
        ax.quiver(0, 0, 0, nx, ny, nz, color='blue', arrow_length_ratio=0.15, linewidth=4)
        
        # Draw reference lines
        ax.plot([-1, 1], [0, 0], [0, 0], color='gray', linestyle='--', alpha=0.3)
        ax.plot([0, 0], [-1, 1], [0, 0], color='gray', linestyle='--', alpha=0.3)
        ax.plot([0, 0], [0, 0], [-1, 1], color='gray', linestyle='--', alpha=0.3)

ani = animation.FuncAnimation(fig, animate, interval=50, cache_frame_data=False)
plt.show()
ser.close()
