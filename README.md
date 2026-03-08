<div align="center">

<!-- Animated Typing Header -->
<img src="https://readme-typing-svg.herokuapp.com?font=Fira+Code&weight=600&size=40&pause=1000&color=FFFFFF&center=true&vCenter=true&width=800&lines=Offline+Survival+Companion;Zero-Connectivity+Resilience;Edge-Computed+Intelligence" alt="Animated Header" />

<!-- Capsule Banner -->
<img src="https://capsule-render.vercel.app/api?type=waving&color=gradient&height=200&section=header&text=SURVIVAL_PROTOCOL_ACTIVE&fontSize=40&fontColor=ffffff&fontAlignY=35" width="100%" />

<br/>

**The Ultimate Autonomous Utility for Disconnected Environments**

[![Version](https://img.shields.io/badge/version-v1.0.0--Beta-blue?style=for-the-badge&logo=semver)](https://github.com/rajkrish0608/Offline-Survival-Companion/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Node.js](https://img.shields.io/badge/Node.js-339933?style=for-the-badge&logo=node.js&logoColor=white)](https://nodejs.org)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-316192?style=for-the-badge&logo=postgresql&logoColor=white)](https://neon.tech)
[![Backblaze B2](https://img.shields.io/badge/Backblaze_B2-E05C2C?style=for-the-badge&logo=backblaze&logoColor=white)](https://backblaze.com)

</div>

---

## 🚀 1. Project Overview

**Problem Statement:**
Modern mobile utilities are structurally dependent on active internet connections. In high-risk scenarios — natural disasters, remote expeditions, cellular infrastructure collapse — these apps become useless exactly when they're needed most.

**Solution:**
**Offline Survival Companion** is an aggressive **offline-first** Android app. It pushes computation entirely to the edge — including spatial rendering, cryptographic hashing, and sensor fusion — with optional cloud sync when connectivity is restored.

**Built for:**
- 🚑 First responders in compromised environments
- 🏔️ Wilderness/expedition teams without network access
- 🛡️ High-risk individuals needing instant panic-hardware integration

---

## 🏛️ 2. System Architecture

```mermaid
graph TD
    subgraph Edge_Device [Flutter Mobile App - Offline First]
        UI[Presentation Layer]
        BLoC[State Management - flutter_bloc]
        Services[Services - GPS, Sensor, Camera, Audio]
        SQLite[(SQLite - sqflite)]
        Hive[(Hive - Encrypted Vault)]
    end

    subgraph Cloud_Optional [Optional Cloud Sync]
        API[Node.js + Express API]
        PG[(PostgreSQL - Neon.tech)]
        B2[(Backblaze B2 - Vault Storage)]
    end

    UI <-->|Events/States| BLoC
    BLoC <--> Services
    Services --> SQLite
    Services --> Hive
    Services -.->|Optimistic Sync| API
    API <--> PG
    API <--> B2
```

### Data Flow
1. **Sensor Capture:** 60Hz loop polls native sensors (magnetometer, GPS, accelerometer)
2. **State Mutation:** Data is processed in Dart Isolates (background threads) → pushed to BLoC
3. **Optimistic Persistence:** Events (safety pins, routes, SOS) are saved locally with `sync_status: PENDING`
4. **Outbox Sync:** On connectivity restore, a `SyncEngine` flushes pending changes to the backend via exponential-backoff retry

---

## ⚙️ 3. Technology Stack

| Category | Technology | Purpose |
| :--- | :--- | :--- |
| **Mobile** | Flutter 3.x (Dart) | Cross-platform, compiled to native ARM |
| **State** | `flutter_bloc` | Unidirectional data flow, testable states |
| **Local DB** | SQLite (`sqflite`) | Routes, POIs, contacts, SOS archives |
| **Secure Store** | Hive | AES-256 encrypted vault documents |
| **Backend** | Node.js + Express | REST API, vault sync, authentication |
| **Cloud DB** | PostgreSQL (Neon.tech) | User accounts, vault metadata |
| **File Storage** | Backblaze B2 | Encrypted vault files (photos, audio, video) |
| **Auth** | JWT + bcrypt | Stateless auth with secure sessions |
| **Maps** | MapLibre GL | GPU-accelerated offline vector maps |
| **Sensors** | `camera`, `geolocator`, `flutter_compass` | Hardware abstraction |
| **Security** | AES-256, biometric auth | Device-native secure enclave |

---

## 🛠️ 4. Features

### 🌍 Geospatial Engine
- **Offline Vector Maps** (MapLibre GL) with topographic tile support
- **Real-Time GPS Route Tracking** — routes persisted to local SQLite
- **Breadcrumb Trail** with timestamp and coordinate logging
- **Dynamic POIs** — hospitals, police stations, safe havens
- **Safety Pin Drops** — geo-tagged hazard markers

### 🚨 Emergency SOS
- **Silent SOS** — discreet trigger without visual alert
- **Shake-to-SOS** — accelerometer-based background detection
- **Voice Trigger** — local speech recognition ("Help Help Help")
- **Auto SMS** — sends encrypted location to emergency contacts
- **Panic Siren** — max-volume audio distress signal
- **Evidence Chain** — auto photo → 15s audio → 15s video capture routed to encrypted vault

### 🛡️ Women's Safety Module
- **Safety Timer** ("Dead Man's Switch") — auto-SOS if check-in missed
- **Fake Call Simulator** — high-fidelity incoming call UI overlay
- **Helpline Directory** — offline emergency numbers by category
- **Self-Defense Guides** — illustrated offline reference

### 🔒 Encrypted Vault
- **AES-256 Encryption** — keys never leave the device
- **Biometric Auth Gate** — FaceID / TouchID / Fingerprint
- **Document Scanner** — store identity docs, medical records offline
- **Cloud Backup** — encrypted upload to Backblaze B2 via backend
- **Auto-Wipe** — configurable purge after failed auth attempts

### 🧰 Survival Toolkit
- **AR Compass HUD** — sensor-fusion overlay on camera feed with POI bearings
- **Signal Tools** — Morse SOS strobe, flashlight control, mirror signaling
- **Offline Manual** — searchable JSON knowledge base for all features
- **Webpage Archiver** — snapshot survival guides for offline reading
- **Survival Mode** — OLED black theme + battery saver triggers below 20%

---

## 🧠 5. Agentic AI Ecosystem

The Offline Survival Companion isn't just a toolkit—it's an autonomous AI ecosystem designed to protect you completely offline. A specialized `AgentOrchestrator` manages 16 unique AI agents that run efficiently on the edge:

### 🚨 Critical Response
1. **Emergency Response Agent** — Orchestrates the master SOS sequence (hardware signals, offline routing, location beacons).
2. **Rescue Coordinator Agent** — Manages multi-party SMS SOS communication and role assignments.
3. **Auto Caller Agent** — Autonomously dials emergency contacts and plays Text-to-Speech distress messages.
4. **Mesh Network Relay Agent** — Establishes P2P Bluetooth/Wi-Fi mesh networks (`nearby_connections`) to bounce data out of dead zones.

### 🩺 Health & Survival
5. **Survival Advisor Agent** — Offline LLM (RAG) that answers complex survival queries referencing a local knowledge base.
6. **First Aid Diagnosis Agent** — Analyzes symptoms offline to provide step-by-step trauma response and CPR guides.
7. **Mental Health & Calm Agent** — Audio-guided breathing exercises and grounding techniques for high-stress scenarios.
8. **Supply & Resource Tracker Agent** — Manages offline inventory, computes burn rates, and alerts on critical hydration/food levels.

### 📡 Environmental & Spatial
9. **Map Intelligence Agent** — Projects vector map overlays for danger zones (floods, fires) and computes maximum-safety paths offline.
10. **Situation Awareness Agent** — Background sensor-fusion daemon listening for anomalies like device drops (falls) or sudden battery death.
11. **Weather Prediction Agent** — Uses the device barometer to detect pressure drops indicative of incoming storms.

### 🛡️ Security & Utility
12. **Vault Intelligence Agent** — Uses ML Kit OCR to auto-categorize scanned IDs/medical docs and extract expiry dates.
13. **Identity Obfuscation Agent** — "Panic PIN" system that wipes tracks and launches a fake UI under duress while triggering a silent SOS.
14. **Intelligent Sync Agent** — A priority queue system that caches operations and syncs them smartly when connectivity returns.
15. **Voice Command Agent** — Hands-free offline NLP interface parsing phrases like "Send SOS" or "Turn on flashlight".
16. **Intelligent Scheduler Agent** — Headless task runner firing automated check-in reminders and background pings.

---

## 📦 6. Local Development Setup

### Prerequisites
- Flutter SDK 3.x (`flutter --version`)
- Node.js 18+ (`node --version`)
- Android Studio + ADB
- A connected Android device or emulator

### 1. Clone & Setup Flutter App
```bash
git clone https://github.com/rajkrish0608/Offline-Survival-Companion.git
cd Offline-Survival-Companion/flutter_app

flutter clean && flutter pub get
```

### 2. Configure Flutter Environment
Create `flutter_app/.env`:
```env
API_BASE_URL=http://10.0.2.2:3000/api   # Use your machine IP for physical device
```

### 3. Run on Device
```bash
# List connected devices
flutter devices

# Run on connected Android device
flutter run -d <device-id>
```

### 4. Setup Backend
```bash
cd backend
npm install
```

Create `backend/.env`:
```env
NODE_ENV=development
PORT=3000

# PostgreSQL (get from neon.tech)
DATABASE_URL=postgresql://user:pass@host/dbname?sslmode=require

# Auth
JWT_SECRET=your-64-char-random-secret

# CORS
ALLOWED_ORIGINS=http://localhost:3000

# Backblaze B2 (vault file storage)
B2_ENDPOINT=https://s3.us-west-004.backblazeb2.com
B2_REGION=us-west-004
B2_KEY_ID=your-b2-key-id
B2_APP_KEY=your-b2-app-key
B2_BUCKET=survival-vault
VAULT_MAX_FILE_SIZE_MB=500

LOG_LEVEL=debug
```

Start the backend:
```bash
node src/index.js
```

---

## 🚀 6. Production Deployment

### Backend → Render.com
1. Go to [render.com](https://render.com) → **New Web Service**
2. Connect your GitHub repo
3. Settings:
   - **Root Directory**: `backend`
   - **Build Command**: `npm install`
   - **Start Command**: `node src/index.js`
4. Add all environment variables from `.env` (with production values)
5. Deploy ✅

### Database → Neon.tech (Free)
- Sign up at [neon.tech](https://neon.tech)
- Copy the PostgreSQL connection string → set as `DATABASE_URL`
- Migrations run automatically on first backend start

### Vault Storage → Backblaze B2 (Free 10 GB)
- Create a **private** bucket named `survival-vault`
- Generate an App Key with Read/Write permissions
- Add credentials to backend environment variables

### Flutter – Build Release APK
```bash
cd flutter_app

# Update API_BASE_URL to your Render URL first
flutter build apk --split-per-abi --release

# Best APK for modern phones:
# build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

---

## 📡 7. API Reference

Base URL: `https://your-backend.onrender.com/api`

| Method | Endpoint | Auth | Description |
|---|---|---|---|
| `POST` | `/auth/register` | None | Create account |
| `POST` | `/auth/login` | None | Get JWT token |
| `POST` | `/auth/logout` | JWT | Invalidate session |
| `GET` | `/vault/files` | JWT | List vault files |
| `POST` | `/vault/upload-url` | JWT | Get B2 upload URL |
| `DELETE` | `/vault/files/:id` | JWT | Delete vault file |
| `POST` | `/sync/push` | JWT | Push pending changes |
| `GET` | `/sync/pull` | JWT | Pull server updates |

### Health Check
```bash
curl https://your-backend.onrender.com/health
# {"status":"ok","timestamp":"2026-02-28T..."}
```

---

## 📁 8. Project Structure

```
Offline-Survival-Companion/
├── flutter_app/
│   └── lib/
│       ├── core/                   # App constants, theme, encryption engine
│       ├── presentation/
│       │   ├── bloc/               # AppBloc — central state machine
│       │   ├── screens/            # All screens (home, emergency, vault, maps…)
│       │   └── widgets/            # Reusable UI components
│       └── services/
│           ├── auth/               # JWT session management
│           ├── emergency/          # SOS, flashlight, survival mode
│           ├── navigation/         # GPS tracking, route engine
│           ├── safety/             # Evidence capture, voice SOS
│           ├── storage/            # SQLite local storage
│           ├── sync/               # SyncEngine — outbox pattern
│           └── vault/              # Encrypted document vault
└── backend/
    └── src/
        ├── routes/                 # auth, vault, sync, user, content
        ├── middleware/             # JWT auth, error handler
        ├── services/               # Backblaze B2 storage service
        ├── migrations/             # PostgreSQL schema setup
        └── index.js                # Express app entry point
```

---

## 🗺️ 9. Roadmap

| Timeline | Feature |
|---|---|
| Q3 2026 | BLE Mesh Network — P2P SOS relay without infrastructure |
| Q4 2026 | Satellite Integration — sub-50-byte SOS over IoT satellites |
| Q1 2027 | On-Device LLM — TFLite natural language distress commands |
| Q2 2027 | iOS release — full App Store distribution |

---

## 🔐 10. Security

- All vault files encrypted with **AES-256** before storage — keys never leave the device
- Backend uses **JWT** with `httpOnly` session handling
- Backblaze B2 bucket is **private** — files only accessible via time-limited signed URLs (1 hour)
- All API routes protected — no unauthenticated data access
- `DATABASE_URL` uses `sslmode=require` — transit encrypted
- Passwords hashed with **bcrypt** (never stored in plaintext)

---

## 🛡️ 11. Contributing

We enforce **Conventional Commits** and require 90%+ unit test coverage for changes to `core/encryption` or `services/safety`. See `CONTRIBUTING.md` for branch strategy and CI/CD hooks.

## 📄 12. License

Distributed under the MIT License. See `LICENSE` for full text.

<br/>

<div align="center">
  <img src="https://capsule-render.vercel.app/api?type=waving&color=gradient&height=100&section=footer" width="100%" />
</div>
