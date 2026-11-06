# Library Check-in/Check-out System

A cross-platform library entry/exit tracking and occupancy monitoring system. Students can check in/out via **QR Code** or **AI Face Recognition**. Library staff receive a real-time view of building occupancy via WebSockets, along with access logs and analytics.

---

## Architecture

The project is organized as a modular monorepo composed of three core services and a PostgreSQL database:

```
┌────────────────────────────────────────┐
│              Flutter App               │
│       (Mobile / Web / Desktop)         │
└──────────────────┬─────────────────────┘
                   │
                   │ REST (HTTPS) + WebSocket (STOMP)
                   ▼
┌────────────────────────────────────────┐
│            Spring Boot API             │
│            (Port: 8080)                │
│ ┌────────────────────────────────────┐ │
│ │ Security / JWT / Check-in Logs     │ │
│ └────────────────────────────────────┘ │
└───────┬────────────────────────┬───────┘
        │                        │
        │ Internal REST          │ JDBC / SQL
        ▼ (Port: 8001)           ▼ (Port: 5432)
┌──────────────────┐    ┌──────────────────┐
│ FastAPI (AI)     │    │   PostgreSQL 16  │
│ Face Recognition │    │ (Flyway managed) │
└──────────────────┘    └──────────────────┘
```

- **Client (`client/`)**: Flutter + Dart cross-platform client (Android, iOS, Web, Windows, macOS, Linux).
- **Backend (`backend/`)**: Spring Boot 3.x (Java 21) orchestrator handling business logic, authentication, occupancy metrics, and WebSocket broadcasting.
- **AI Service (`ai-service/`)**: Python FastAPI microservice dedicated to AI Face Recognition and biometric embedding extraction.
- **Database**: PostgreSQL 16 with Flyway database migration versioning.

---

## Tech Stack

### 1. Client (`client/`)
| Component | Technology |
|---|---|
| Framework | Flutter 3.x / Dart 3.x |
| State Management | Riverpod |
| Networking | Dio |
| Navigation | GoRouter |
| Hardware / Scanner | mobile_scanner, camera |
| Storage | flutter_secure_storage |
| Realtime | web_socket_channel (STOMP) |

### 2. Backend (`backend/`)
| Component | Technology |
|---|---|
| Language / Runtime | Java 21 |
| Framework | Spring Boot 3.x |
| Persistence & ORM | Spring Data JPA / Hibernate |
| Database | PostgreSQL 16 |
| Migrations | Flyway |
| Security | Spring Security + JWT |
| Realtime Push | Spring WebSocket (STOMP) |
| Build Tool | Maven |

### 3. AI Service (`ai-service/`)
| Component | Technology |
|---|---|
| Language / Runtime | Python 3.11+ |
| Framework | FastAPI + Uvicorn |
| Validation | Pydantic v2 |
| Computer Vision | OpenCV (Headless), NumPy, Pillow |
| Face detection / landmarks | MediaPipe Face Landmarker (Apache-2.0) |
| Face embedding | ArcFace ResNet100, 512-d, via ONNX Runtime (ONNX Model Zoo, Apache-2.0) |
| Liveness | Challenge-response: blink, then turn left/right (landmark based) |

---

## Project Structure

```
.
├── .env.example                 # Environment variables template
├── docker-compose.yml           # Multi-container orchestration
├── README.md                    # Project documentation
│
├── backend/                     # Spring Boot (Java 21, Maven)
│   ├── pom.xml
│   ├── Dockerfile
│   ├── .dockerignore
│   └── src/
│       ├── main/java/com/library/checkin/
│       │   ├── config/          # Security, WebSocket, RestClient
│       │   ├── controller/      # REST API Controllers
│       │   ├── dto/             # Data Transfer Objects
│       │   ├── entity/          # JPA Entities
│       │   ├── repository/      # Spring Data Repositories
│       │   └── service/         # Business logic & AI client
│       └── main/resources/
│           ├── application.yml
│           └── db/migration/    # Flyway SQL migrations
│
├── ai-service/                  # Python FastAPI (Face Recognition)
│   ├── requirements.txt
│   ├── Dockerfile
│   ├── .dockerignore
│   └── app/
│       ├── main.py              # Application entrypoint & CORS
│       ├── core/                # Configuration & Settings
│       ├── models/              # Pydantic Schemas
│       ├── services/            # Face detection & inference
│       └── api/v1/              # Versioned API routes
│
└── client/                      # Flutter application
    ├── pubspec.yaml
    ├── analysis_options.yaml
    ├── Dockerfile               # Flutter Web + Nginx
    ├── .dockerignore
    └── lib/
        ├── main.dart
        ├── core/                # API client, config, themes
        └── features/            # Feature modules (checkin, dashboard)
```

---

## Getting Started

### Prerequisites
- Docker & Docker Compose v2+
- JDK 21+ and Maven 3.9+ (or use included `./backend/mvnw`)
- Python 3.11+ (for AI service local testing)
- Flutter SDK 3.24+ (for client local development)

---

### Option 1: Quick Start with Scripts (Recommended)

1. **Setup environment and start services:**
   ```bash
   cp .env.example .env
   ./scripts/dev-up.sh
   ```
2. **Access Interactive Interfaces:**
   - **Swagger UI:** `http://localhost:8080/swagger-ui/index.html` (or configured `BACKEND_PORT`)
   - **OpenAPI Schema (Raw JSON):** `http://localhost:8080/v3/api-docs`
   - **Actuator Health:** `http://localhost:8080/actuator/health`
   - **AI Service Health:** `http://localhost:8001/api/v1/health`
   - **AI OpenAPI Docs:** `http://localhost:8001/docs`

3. **Stop services:**
   ```bash
   ./scripts/dev-down.sh
   ```

---

### Option 2: Full Testing & Verification

Run the automated test runner which spins up an isolated test stack, executes AI unit tests, contract tests, and backend integration tests, then tears down test volumes automatically:
```bash
./scripts/test-stack.sh
```

Export the runtime OpenAPI schema from a running backend into `docs/api/openapi.json`:
```bash
./scripts/export-openapi.sh
```

---

### Option 3: Running Services Individually (Local Dev)

#### 1. Start PostgreSQL (with pgvector)
```bash
docker compose -f compose.dev.yml up -d postgres
```

#### 2. Start AI Service (FastAPI)
```bash
cd ai-service
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python scripts/fetch_models.py        # downloads + verifies the ArcFace and landmarker models (~265 MB)
export AI_DATABASE_URL=postgresql://ai_service_user:ai_service_secure_password@localhost:5432/library_db
uvicorn app.main:app --port 8001 --reload
# No model files / just exploring the API? `export AI_MOCK_MODE=true` returns synthetic results that
# the backend refuses to use for entry/exit (SIMULATED_RESULT_REJECTED).
```

#### 3. Start Backend (Spring Boot)
```bash
cd backend
./mvnw spring-boot:run
```

#### 4. Start Client (Flutter)
```bash
cd client
flutter pub get
flutter run -d chrome        # Web
flutter run -d <device_id>   # Mobile / Desktop
```

> **Mobile Device / Emulator Connectivity:**
> - **Android Emulator:** Set `API_BASE_URL=http://10.0.2.2:8080` (maps to host `localhost:8080`).
> - **iOS Simulator:** Set `API_BASE_URL=http://localhost:8080`.
> - **Physical Device (LAN):** Set `API_BASE_URL=http://<YOUR_LAN_IP>:8080`.

---

## Face recognition and liveness

`ai-service` runs the real pipeline: detect one face, align it to the ArcFace template, embed with
ArcFace R100, and match 1:N by cosine distance against the enrolled students.

- **Readiness is real.** `/api/v1/ready` is `READY` only once both models are loaded and their SHA-256
  matches `app/models/manifest.json`. There is no "ready" flag to flip.
- **Liveness is a random challenge** (blink, then turn left or right). The clip must show a single face
  blinking (eyes open, closed, open) and then turning at least ~17 degrees in the requested direction.
  The face at the start and end of the clip must be the same person.
- **Thresholds** (`faceMaxCosineDistance`, `faceMinDistanceGap`, `livenessMinScore`) come from the admin
  recognition settings; defaults are 0.50 / 0.15 / 0.90. They were chosen from a handful of measured pairs
  (same person 0.27-0.53, different people 0.89-1.12), so **calibrate on your own students and kiosk camera**.
- Use `python scripts/inspect_clip.py clip.mp4` to see the signals the service extracts from a recorded
  kiosk clip and whether it would pass.
- **Re-enroll after switching from mock.** Embeddings stored while `AI_MOCK_MODE=true` are tagged
  `arcface-512-mock` and are ignored by the real matcher; students must enroll again.

Known limit: liveness is not a passive anti-spoofing model. A real-time replay or deepfake that performs
the requested actions in order is not detected.

---

## Seed Accounts (Development)

When started with `SPRING_PROFILES_ACTIVE=dev`, the backend automatically seeds sample accounts (password: `dev_secret_password_123` or configured `DEV_SEED_PASSWORD`):

| Identifier | Role | Purpose |
|---|---|---|
| `AD001` | `ADMIN` | System administrator, kiosk & user management |
| `LIB001` | `LIBRARIAN` | Library staff, shift schedules, manual check-in |
| `LIB002` | `LIBRARIAN` | Secondary librarian for shift overlap testing |
| `SV001` | `STUDENT` | Standard student for QR entry and face consent |
| `SV002` | `STUDENT` | Secondary student account |

---

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `POSTGRES_DB` | `library_db` | PostgreSQL Database name |
| `POSTGRES_USER` | `postgres` | PostgreSQL Database user |
| `POSTGRES_PASSWORD` | `postgres_secure_password` | PostgreSQL Database password |
| `BACKEND_PORT` | `8080` | Spring Boot HTTP port |
| `SPRING_PROFILES_ACTIVE` | `dev` | Active Spring profile (`dev`, `prod`, `it`, `test`) |
| `JWT_SECRET` | *(Random 32+ char key)* | Secret key for signing JWTs |
| `DEV_SEED_PASSWORD` | `dev_secret_password_123` | Default password for seeded accounts |
| `AI_SERVICE_URL` | `http://ai-service:8001` | Backend connection to AI service |
| `AI_SERVICE_KEY` | *(Secret key)* | Pre-shared key for AI internal API security |
| `AI_MOCK_MODE` | `false` | `false`: real ArcFace + liveness. `true`: synthetic results, never accepted for access |
| `AI_DATABASE_URL` | *(compose sets it)* | Read-only DB role (`ai_service_user`) the AI service uses to read enrolled faces |
| `AI_DB_PASSWORD` | `ai_service_secure_password` | Password of that role (see `scripts/db-bootstrap.sql`) |
| `AI_LIVENESS_MIRRORED_INPUT` | `false` | Set `true` if the kiosk records a mirrored video (TURN_LEFT/RIGHT are the user's left/right) |
| `AI_FACE_MODEL_VERSION` | `arcface-512-v1` | Face embedding model version string |
| `CLIENT_PORT` | `3000` | Flutter Web container port |
| `API_BASE_URL` | `http://localhost:8080` | Client target API endpoint |
