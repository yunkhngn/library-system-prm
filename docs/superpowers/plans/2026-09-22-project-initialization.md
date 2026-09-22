# Project Initialization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Initialize a clean, readable, best-practice monorepo structure containing a Spring Boot (Java 21) backend, a Python FastAPI AI Face Recognition service, and a Flutter client, along with Docker configuration and updated documentation.

**Architecture:** A 3-tier microservice architecture where Spring Boot acts as the central business orchestrator and gateway, FastAPI operates as a dedicated Computer Vision inference microservice, Flutter serves as the cross-platform client, and PostgreSQL stores system records.

**Tech Stack:**
- **Backend:** Java 21, Spring Boot 3.4.x, Maven, Spring Data JPA, Spring Security, Flyway, PostgreSQL, WebSocket (STOMP), Lombok
- **AI Service:** Python 3.11/3.13, FastAPI, Pydantic v2, Uvicorn, OpenCV (headless), NumPy, Pytest
- **Client:** Flutter 3.x, Dart 3.x, Riverpod, Dio, GoRouter, Mobile Scanner
- **DevOps:** Docker, Docker Compose, Alpine/Slim multi-stage images

## Global Constraints
- **ZERO BUILD EXECUTION**: Do NOT run `docker build`, `docker compose up`, `mvn package`, `flutter build`, or install heavy ML packages on host. The machine has ~2.9GB disk remaining.
- **READABILITY & BEST PRACTICES**: Code must be modular, easy to navigate, with clean separation of concerns, descriptive naming, and clear comments.
- **ACCURATE INTERFACES**: Port 8080 for Spring Boot, 8001 for FastAPI, 5432 for Postgres, 3000 for Flutter Web.

---

### Task 1: Environment & Root Configuration
**Files:**
- Create: `.gitignore`
- Create: `.env.example`
- Create: `docker-compose.yml`

- [ ] Step 1: Create comprehensive root `.gitignore` covering Java, Python, Flutter, Docker, and IDE files.
- [ ] Step 2: Create `.env.example` defining environment variables for DB, JWT, and service endpoints.
- [ ] Step 3: Create `docker-compose.yml` defining `postgres`, `backend`, `ai-service`, and `client` services with healthchecks, environment links, volumes, and network.

---

### Task 2: Scaffold Spring Boot Backend (`backend/`)
**Files:**
- Create: `backend/pom.xml`
- Create: `backend/.dockerignore`
- Create: `backend/Dockerfile`
- Create: `backend/mvnw`, `backend/mvnw.cmd`, `backend/.mvn/wrapper/maven-wrapper.properties`
- Create: `backend/src/main/resources/application.yml`
- Create: `backend/src/main/resources/db/migration/V1__init_schema.sql`
- Create: `backend/src/main/java/com/library/checkin/LibraryCheckinApplication.java`
- Create: `backend/src/main/java/com/library/checkin/config/SecurityConfig.java`
- Create: `backend/src/main/java/com/library/checkin/config/WebSocketConfig.java`
- Create: `backend/src/main/java/com/library/checkin/entity/User.java`
- Create: `backend/src/main/java/com/library/checkin/entity/CheckInLog.java`
- Create: `backend/src/main/java/com/library/checkin/dto/CheckInRequest.java`
- Create: `backend/src/main/java/com/library/checkin/dto/CheckInResponse.java`
- Create: `backend/src/main/java/com/library/checkin/dto/OccupancyDto.java`
- Create: `backend/src/main/java/com/library/checkin/repository/UserRepository.java`
- Create: `backend/src/main/java/com/library/checkin/repository/CheckInLogRepository.java`
- Create: `backend/src/main/java/com/library/checkin/service/AiServiceClient.java`
- Create: `backend/src/main/java/com/library/checkin/service/CheckInService.java`
- Create: `backend/src/main/java/com/library/checkin/service/OccupancyService.java`
- Create: `backend/src/main/java/com/library/checkin/controller/CheckInController.java`
- Create: `backend/src/main/java/com/library/checkin/controller/OccupancyController.java`
- Create: `backend/src/test/java/com/library/checkin/LibraryCheckinApplicationTests.java`

- [ ] Step 1: Create `backend/pom.xml` and wrapper configuration.
- [ ] Step 2: Create `backend/Dockerfile` and `backend/.dockerignore`.
- [ ] Step 3: Create `application.yml` and Flyway migration `V1__init_schema.sql`.
- [ ] Step 4: Create Java entities, repositories, DTOs, services, controllers, and application entrypoint.
- [ ] Step 5: Create basic application context test.

---

### Task 3: Scaffold Python FastAPI AI Service (`ai-service/`)
**Files:**
- Create: `ai-service/requirements.txt`
- Create: `ai-service/.dockerignore`
- Create: `ai-service/Dockerfile`
- Create: `ai-service/app/__init__.py`
- Create: `ai-service/app/core/config.py`
- Create: `ai-service/app/models/schemas.py`
- Create: `ai-service/app/services/face_service.py`
- Create: `ai-service/app/api/v1/endpoints/recognition.py`
- Create: `ai-service/app/api/v1/router.py`
- Create: `ai-service/app/main.py`
- Create: `ai-service/tests/test_api.py`

- [ ] Step 1: Create `requirements.txt`, `.dockerignore`, and `Dockerfile`.
- [ ] Step 2: Create Pydantic v2 schemas and application settings (`core/config.py`).
- [ ] Step 3: Create `face_service.py` with face detection, embedding extraction, and cosine similarity comparison logic.
- [ ] Step 4: Create API endpoints (`/api/v1/health`, `/api/v1/detect`, `/api/v1/extract-embedding`, `/api/v1/verify`).
- [ ] Step 5: Create FastAPI application with CORS and test case.

---

### Task 4: Scaffold Flutter Client (`client/`)
**Files:**
- Create: `client/pubspec.yaml`
- Create: `client/analysis_options.yaml`
- Create: `client/.dockerignore`
- Create: `client/Dockerfile`
- Create: `client/lib/main.dart`
- Create: `client/lib/app.dart`
- Create: `client/lib/core/config/env.dart`
- Create: `client/lib/core/network/api_client.dart`
- Create: `client/lib/core/theme/app_theme.dart`
- Create: `client/lib/features/checkin/presentation/checkin_screen.dart`
- Create: `client/lib/features/dashboard/presentation/occupancy_screen.dart`
- Create: `client/test/widget_test.dart`

- [ ] Step 1: Create `pubspec.yaml` with Riverpod, Dio, and UI dependencies.
- [ ] Step 2: Create `Dockerfile` and `.dockerignore`.
- [ ] Step 3: Create core config, Dio network client, and Material 3 theme.
- [ ] Step 4: Create entrypoint `main.dart`, `app.dart`, check-in screen (QR & Camera) and dashboard screen.
- [ ] Step 5: Create smoke widget test.

---

### Task 5: Update Root README.md
**Files:**
- Modify: `README.md`

- [ ] Step 1: Update Architecture Diagram with 3 services (Flutter, Spring Boot, FastAPI AI) and PostgreSQL.
- [ ] Step 2: Update Tech Stack tables for all three layers.
- [ ] Step 3: Add Project Structure tree.
- [ ] Step 4: Add Docker Compose and local development quickstart instructions.
