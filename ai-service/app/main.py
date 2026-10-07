from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(
    title="Library AI Recognition Service",
    description="Microservice for face recognition and student verification",
    version="0.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


from app.api.v1.health import router as health_router

app.include_router(health_router)


@app.post("/api/v1/verify")
def verify_face():
    # Placeholder for Face Recognition inference
    return {"verified": True, "studentId": "SV2026001", "confidence": 0.95}
