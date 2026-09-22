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
- Docker & Docker Compose (optional for full stack run)
- JDK 21+ and Maven 3.9+ (for backend local development)
- Python 3.11+ (for AI service local development)
- Flutter SDK 3.24+ (for client local development)

---

### Option 1: Running with Docker Compose (Recommended)

1. **Clone and setup environment variables:**
   ```bash
   cp .env.example .env
   # Edit .env if you wish to customize ports or credentials
   ```

2. **Start all services:**
   ```bash
   docker compose up -d
   ```

3. **Service URLs:**
   - **Flutter Web Client:** `http://localhost:3000`
   - **Spring Boot API:** `http://localhost:8080`
   - **FastAPI AI Service:** `http://localhost:8001` (Docs at `http://localhost:8001/docs`)
   - **PostgreSQL:** `localhost:5432`

---

### Option 2: Running Services Individually

#### 1. Start PostgreSQL
```bash
docker compose up -d postgres
```

#### 2. Start AI Service (FastAPI)
```bash
cd ai-service
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
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

---

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `POSTGRES_DB` | `library_db` | PostgreSQL Database name |
| `POSTGRES_USER` | `postgres` | PostgreSQL Database user |
| `POSTGRES_PASSWORD` | `postgres_secure_password` | PostgreSQL Database password |
| `BACKEND_PORT` | `8080` | Spring Boot HTTP port |
| `AI_SERVICE_PORT` | `8001` | FastAPI AI microservice port |
| `CLIENT_PORT` | `3000` | Flutter Web container port |
| `JWT_SECRET` | *(Random 32+ char key)* | Secret key for signing JWTs |
| `AI_SERVICE_URL` | `http://ai-service:8001` | Backend connection to AI service |
