from datetime import datetime
from typing import List, Optional

from fastapi import (
    APIRouter,
    Depends,
    File,
    Form,
    HTTPException,
    Query,
    UploadFile,
    status,
)
from sqlalchemy.orm import Session

from api.database import get_db
from api.models.reports import User
from api.schemas.reports import (
    Reports,
    ReportsFull,
    UsersDetailed,
)
from api.schemas.voice import ModelOutput, VoiceReportInput
from api.services import reports as reports_service
from api.services.auth import get_current_user, get_optional_user
from api.services.storage import upload_report_image

router = APIRouter(tags=["reports"])


@router.post("/reports", response_model=ReportsFull)
async def create_report(
    title: str = Form(...),
    description: str = Form(...),
    category: str = Form(...),
    latitude: float = Form(0.0),
    longitude: float = Form(0.0),
    location: str = Form(...),
    severity: str = Form(...),
    isDraft: bool = Form(False),
    time: Optional[str] = Form(None),
    image: Optional[UploadFile] = File(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # Upload photo to Supabase Storage; DB only stores the public URL
    image_url: Optional[str] = None
    if image is not None and image.filename:
        data = await image.read()
        if data:
            image_url = upload_report_image(
                data,
                content_type=image.content_type or "image/jpeg",
                filename=image.filename,
            )

    severity_norm = severity.strip().lower()
    if severity_norm not in ("low", "medium", "high"):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="severity must be low, medium, or high",
        )

    if time:
        try:
            report_time = datetime.fromisoformat(time.replace("Z", "+00:00"))
        except ValueError as e:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Invalid time format",
            ) from e
    else:
        report_time = datetime.utcnow()

    report = Reports(
        title=title,
        description=description,
        category=category,
        latitude=latitude,
        longitude=longitude,
        location=location,
        image=image_url,
        time=report_time,
        severity=severity_norm,  # type: ignore[arg-type]
        user_id=current_user.id,
        isDraft=isDraft,
    )
    return reports_service.create_report(db, report)


@router.put("/reports/{report_id}", response_model=ReportsFull)
async def update_report(
    report_id: int,
    title: str = Form(...),
    description: str = Form(...),
    category: str = Form(...),
    latitude: float = Form(0.0),
    longitude: float = Form(0.0),
    location: str = Form(...),
    severity: str = Form(...),
    isDraft: bool = Form(False),
    time: Optional[str] = Form(None),
    image: Optional[UploadFile] = File(None),
    existing_image_url: Optional[str] = Form(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Update a report in place (publish draft or re-save draft)."""
    image_url: Optional[str] = None
    if image is not None and image.filename:
        data = await image.read()
        if data:
            image_url = upload_report_image(
                data,
                content_type=image.content_type or "image/jpeg",
                filename=image.filename,
            )
    elif existing_image_url and existing_image_url.strip():
        image_url = existing_image_url.strip()

    severity_norm = severity.strip().lower()
    if severity_norm not in ("low", "medium", "high"):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="severity must be low, medium, or high",
        )

    if time:
        try:
            report_time = datetime.fromisoformat(time.replace("Z", "+00:00"))
        except ValueError as e:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Invalid time format",
            ) from e
    else:
        report_time = datetime.utcnow()

    report = Reports(
        title=title,
        description=description,
        category=category,
        latitude=latitude,
        longitude=longitude,
        location=location,
        image=image_url,
        time=report_time,
        severity=severity_norm,  # type: ignore[arg-type]
        user_id=current_user.id,
        isDraft=isDraft,
    )
    return reports_service.update_report(db, report_id, report, current_user)


@router.get("/reports", response_model=List[ReportsFull])
def get_all_reports(db: Session = Depends(get_db)):
    return reports_service.get_all_reports(db)


@router.get("/reports/recent", response_model=List[ReportsFull])
def get_most_recent_reports(
    amount: int = Query(default=10, ge=1, le=100),
    db: Session = Depends(get_db),
):
    return reports_service.get_most_recent_reports(db, amount)


@router.get("/reports/feed", response_model=List[ReportsFull])
def get_reports_feed(
    amount: int = Query(default=10, ge=1, le=100),
    category: Optional[str] = Query(default=None),
    before: Optional[datetime] = Query(default=None),
    db: Session = Depends(get_db),
):
    return reports_service.get_reports_feed(
        db,
        amount=amount,
        category=category,
        before=before,
    )


@router.get("/reports/user/{user_id}/drafts", response_model=List[ReportsFull])
def get_user_draft_reports(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not allowed to view another user's drafts",
        )
    return reports_service.get_all_reports_by_user_draft(db, user_id)


@router.get("/reports/user/{user_id}/submitted", response_model=List[ReportsFull])
def get_user_submitted_reports(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not allowed to view another user's reports",
        )
    return reports_service.get_all_reports_by_user_notdraft(db, user_id)


@router.get("/reports/nearme", response_model=List[ReportsFull])
def get_reports_nearme(db: Session = Depends(get_db)):
    return reports_service.get_reports_open(db)


@router.get("/reports/resolved", response_model=List[ReportsFull])
def get_reports_resolved(db: Session = Depends(get_db)):
    return reports_service.get_reports_resolved(db)


@router.get("/reports/in_progress", response_model=List[ReportsFull])
def get_reports_in_progress(db: Session = Depends(get_db)):
    return reports_service.get_reports_in_progress(db)


@router.get("/reports/{report_id}", response_model=ReportsFull)
def get_report(
    report_id: int,
    db: Session = Depends(get_db),
    current_user: User | None = Depends(get_optional_user),
):
    return reports_service.get_report(db, report_id, current_user)


@router.get("/users/top/{user_id}", response_model=List[UsersDetailed])
def get_top_users(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # Use the authenticated user so leaderboard always includes "you"
    return reports_service.get_top10_users(db, current_user.id)


@router.post("/reports/analyze-voice", response_model=ModelOutput)
def analyze_voice_report(body: VoiceReportInput):
    """Turn a voice-report description into title, severity, and category."""
    return reports_service.analyze_voice_report(body.description)


@router.post("/reports/generate-title")
def generate_report_title(body: VoiceReportInput):
    """Legacy title-only helper — same AI path, returns just the title."""
    return {"title": reports_service.generate_ai_title(body.description)}
