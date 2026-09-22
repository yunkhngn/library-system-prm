# Project Initialization Specification: Library Check-in/Check-out System

**Date:** 2026-09-22  
**Status:** Approved  
**Author:** Pair Programming Agent & User  

---

## 1. Overview & Objectives

The goal is to initialize a multi-service monorepo structure for the Library Check-in/Check-out System, supporting QR-code and Face Recognition based check-in.

The system consists of:
1. **`client/`**: Flutter cross-platform application (Mobile, Web, Desktop) with Riverpod, Dio, and camera/scanner capabilities.
2. **`backend/`**: Spring Boot 3.x (Java 21) application serving as the primary API Gateway and business orchestrator (PostgreSQL, JPA, Flyway, WebSocket STOMP, Spring Security JWT).
3. **`ai-service/`**: Python FastAPI microservice dedicated to AI Face Recognition and biometric embedding extraction.
4. **Containerization**: Multi-stage `Dockerfile`s for each service, `.dockerignore`, `.env.example`, and a consolidated `docker-compose.yml`.
5. **Documentation**: Overhaul `README.md` to reflect the 3-service architecture, AI recognition features, and Docker instructions.

> **Storage Constraint**: The local system has limited free disk space (~2.9 GB). Under no circumstances will heavy build commands (`docker build`, `docker compose up`, `mvn package`, `flutter build`, or massive PyPI wheel downloads) be triggered during initialization. Only project structures, templates, configuration files, and boilerplate codes are generated.

---

## 2. Architecture & Service Interactions

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

### Communication Flow:
1. **Face Check-in Request**: Flutter client captures a face photo and posts it to Spring Boot (`POST /api/v1/check-in/face`).
2. **AI Inference Delegation**: Spring Boot forwards the image data to FastAPI (`POST http://ai-service:8001/api/v1/recognition/verify` or `extract-embedding`).
3. **Verification Result**: FastAPI returns the extracted vector embedding and/or recognized student identifier with confidence score.
4. **Business Validation & Storage**: Spring Boot validates student enrollment, checks capacity and operating hours, logs the entry/exit in PostgreSQL, and broadcasts real-time occupancy updates over WebSocket STOMP.

---

## 3. Directory & File Structure

```
.
├── .env.example
├── docker-compose.yml
├── README.md
├── docs/
│   └── superpowers/specs/2026-09-22-project-initialization-design.md
├── backend/                             # Spring Boot 3.x (Java 21)
│   ├── pom.xml
│   ├── mvnw & mvnw.cmd
│   ├── .mvn/wrapper/maven-wrapper.properties
│   ├── Dockerfile
│   ├── .dockerignore
│   └── src/
│       ├── main/
│       │   ├── java/com/library/checkin/
│       │   │   ├── LibraryCheckinApplication.java
│       │   │   ├── config/ (Security, WebSocket, WebClient/RestClient)
│       │   │   ├── controller/ (AuthController, CheckInController, OccupancyController)
│       │   │   ├── dto/
│       │   │   ├── entity/ (User, CheckInLog, SystemConfig)
│       │   │   ├── repository/
│       │   │   └── service/ (CheckInService, AiServiceClient, UserService)
│       │   └── resources/
│       │       ├── application.yml
│       │       └── db/migration/V1__init_schema.sql
│       └── test/java/com/library/checkin/LibraryCheckinApplicationTests.java
├── client/                              # Flutter Application
│   ├── pubspec.yaml
│   ├── analysis_options.yaml
│   ├── Dockerfile
│   ├── .dockerignore
│   ├── lib/
│   │   ├── main.dart
│   │   ├── app.dart
│   │   ├── core/
│   │   │   ├── config/env.dart
│   │   │   ├── network/api_client.dart
│   │   │   └── theme/app_theme.dart
│   │   └── features/
│   │       ├── auth/
│   │       ├── checkin/ (QR Scanner & Face Capture UI)
│   │       └── dashboard/
│   └── test/widget_test.dart
└── ai-service/                          # FastAPI Microservice
    ├── requirements.txt
    ├── Dockerfile
    ├── .dockerignore
    └── app/
        ├── __init__.py
        ├── main.py
        ├── core/config.py
        ├── models/schemas.py
        ├── api/
        │   └── v1/
        │       ├── __init__.py
        │       ├── router.py
        │       └── endpoints/recognition.py
        └── services/
            └── face_recognition_service.py
```

---

## 4. Docker & Container Specification

### `docker-compose.yml` Services:
- **`postgres`**: Image `postgres:16-alpine`, persistent volume `pgdata`, port 5432.
- **`backend`**: Multi-stage build (Eclipse Temurin 21 Alpine JRE runtime), depends on `postgres` and `ai-service`, port 8080.
- **`ai-service`**: Python 3.11-slim, uvicorn runtime, port 8001.
- **`client`**: Multi-stage Flutter web build served with `nginx:alpine` (optional profile or standard service on port 3000).
- **Networks**: Dedicated bridge network `library_network`.

---

## 5. README.md Updates

Update the root `README.md` to:
- Document all 3 sub-projects (`client/`, `backend/`, `ai-service/`).
- Update the system architecture ASCII diagram.
- Add Tech Stack tables for `ai-service` (FastAPI, OpenCV, InsightFace/ONNX, Uvicorn).
- Add Quickstart instructions for running standalone services or via `docker compose`.
