from fastapi import APIRouter, Depends, HTTPException

from app.security import require_jwt

router = APIRouter()


@router.post("/retraining/export-dataset")
def export_dataset(_claims: dict = Depends(require_jwt)) -> dict:
    raise HTTPException(status_code=501, detail="Retraining export not implemented yet")
