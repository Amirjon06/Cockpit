from fastapi import FastAPI, HTTPException

from app.agents.hein import HeinAgent
from app.agents.lily import LilyAgent
from app.model_client import ModelClient


app = FastAPI(title="Guided Generation Agents")

model_client = ModelClient()
hein = HeinAgent(model_client)
lily = LilyAgent(model_client)


@app.get("/health")
async def health():
    return {
        "status": "ok",
        "service": "guided-generation-python-agents",
    }


@app.post("/agents/hein/analyze")
async def analyze_assignment(payload: dict):
    try:
        return await hein.analyze(payload)
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error
    except Exception as error:
        raise HTTPException(status_code=502, detail=str(error)) from error


@app.post("/agents/lily/generate")
async def generate_outline(payload: dict):
    try:
        return await lily.generate(payload)
    except Exception as error:
        raise HTTPException(status_code=502, detail=str(error)) from error
