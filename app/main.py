from fastapi import FastAPI

from app.config import APP_ENV
from app.database import Base, engine

Base.metadata.create_all(bind=engine)

app = FastAPI(title="SmartCampus")


@app.get("/health")
def health():
    return {"status": "ok", "env": APP_ENV}
