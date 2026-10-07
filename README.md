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
| AI Inference | InsightFace / ONNX Runtime / FaceNet |

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
export AI_MOCK_MODE=true
uvicorn app.main:app --port 8001 --reload
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
| `AI_MOCK_MODE` | `true` | `true` for synthetic embeddings/liveness; `false` for real InsightFace inference |
| `AI_MODELS_READY` | `false` | Readiness indicator for loaded ML weights |
| `FACE_SIMILARITY_THRESHOLD` | `0.65` | Distance threshold for face matching |
| `AI_FACE_MODEL_VERSION` | `arcface-512-v1` | Face embedding model version string |
| `CLIENT_PORT` | `3000` | Flutter Web container port |
| `API_BASE_URL` | `http://localhost:8080` | Client target API endpoint |
