from typing import List

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from api.database import get_db
from api.models.reports import User
from api.schemas.reports import Reports, ReportsFull, UsersDetailed
from api.services import reports as reports_service
from api.services.auth import get_current_user, get_optional_user

router = APIRouter(tags=["reports"])


@router.post("/reports", response_model=ReportsFull)
def create_report(
    report: Reports,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # Always attribute the report to the authenticated user
    report.user_id = current_user.id
    return reports_service.create_report(db, report)


@router.get("/reports", response_model=List[ReportsFull])
def get_all_reports(db: Session = Depends(get_db)):
    return reports_service.get_all_reports(db)


@router.get("/reports/recent", response_model=List[ReportsFull])
def get_most_recent_reports(
    amount: int = Query(default=10, ge=1, le=100),
    db: Session = Depends(get_db),
):
    return reports_service.get_most_recent_reports(db, amount)


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
