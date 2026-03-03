# Offline Survival Companion - User Manual

## 1. Project Description
The **Offline Survival Companion** is an advanced, production-ready emergency preparedness application designed to function entirely without internet connectivity. It provides critical tools for survival, including geospatial navigation, emergency communication, secure document storage, and survival guides.

The project consists of two main components:
- **Flutter Mobile App**: An offline-first mobile application optimized for disconnected environments.
- **Node.js Backend**: A supporting API for optional cloud synchronization, vault backups, and content distribution.

---

## 2. Main Functions and Sub-functions

### 🌍 Geospatial Engine
*Provides autonomous navigation and mapping capabilities.*
- **Offline Vector Maps**: Access topographic maps without data.
- **Real-Time Tracking**: GPS route tracking persisted locally to SQLite.
- **Breadcrumb Trail**: Automatic logging of coordinates and timestamps.
- **Dynamic POIs**: Pre-loaded database of hospitals, police stations, and safe havens.
- **Safety Pins**: Drop geo-tagged hazard markers for future reference.

### 🚨 Emergency SOS
*Aggressive distress signaling and evidence collection.*
- **Silent SOS**: Discreet trigger of emergency protocols.
- **Shake-to-SOS**: Accelerometer-based detection for background activation.
- **Voice Trigger**: "Help Help Help" local speech recognition.
- **Auto SMS**: Encrypted location sharing with emergency contacts.
- **Panic Siren**: High-decibel audio signal forced to maximum volume.
- **Evidence Chain**: Automatic capture of photos, 15s audio, and 15s video.

### 🛡️ Women's Safety Module
*Specialized features for personal safety and defense.*
- **Safety Timer**: A "Dead Man's Switch" that triggers SOS if check-in is missed.
- **Fake Call Simulator**: High-fidelity incoming call UI to deter threats.
- **Helpline Directory**: Offline database of regional emergency and helpline numbers.
- **Self-Defense Guides**: Illustrated tutorials for physical safety.

### 🔒 Secure Vault
*AES-256 encrypted storage for sensitive information.*
- **Encryption Engine**: Hardware-backed AES-256 keys that never leave the device.
- **Biometric Gate**: Access protected by FaceID, TouchID, or Fingerprint.
- **Document Scanner**: Securely store identity documents and medical records.
- **Cloud Backup**: Encrypted syncing to Backblaze B2 (optional).
- **Auto-Wipe**: Automatic data purge after repeated failed authentication attempts.

### 🧰 Survival Toolkit
*Essential utility tools for different survival scenarios.*
- **AR Compass HUD**: Augmented reality overlay for POI bearings.
- **Signal Tools**: Morse code strobe, flashlight control, and mirror signaling.
- **Webpage Archiver**: Save survival guides and articles for offline viewing.
- **Low Battery Mode**: Activates at 15% battery to disable non-essential animations and sync.

---

## 3. Technical Overview
- **Frontend**: Flutter (Dart) with BLoC state management.
- **Local Storage**: SQLite (relational) and Hive (encrypted key-value).
- **Security**: AES-256 encryption, PBKDF2 key derivation.
- **Backend**: Node.js, Express, PostgreSQL, Backblaze B2.
