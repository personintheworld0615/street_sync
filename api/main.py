from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from api.database import Base, engine
from api.models import reports as models_reports 
from api.routes.reports import router as reports_router

app = FastAPI(title="StreetSync API")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.include_router(reports_router)
Base.metadata.create_all(bind=engine)


@app.get("/")
async def root():
    return {"message": "Hello World"}
