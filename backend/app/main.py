from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.features.auth.router import router as auth_router
from app.features.entrance.router import router as entrance_router
from app.features.admin.router import router as admin_router
from app.features.finance.router import router as finance_router

app = FastAPI(
    title="Internship Seminar System (Feature-First API)",
    version="2.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router)
app.include_router(entrance_router)
app.include_router(admin_router)
app.include_router(finance_router)


@app.get("/api/health")
def health():
    return {"status": "ok"}