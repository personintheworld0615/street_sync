from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

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


@app.get("/")
async def root():
    return {"message": "Hello World"}
