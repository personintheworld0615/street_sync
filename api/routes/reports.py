from typing import List

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from api.database import get_db
from api.schemas.reports import Reports, ReportsFull, Users, UsersDetailed
from api.services import reports as reports_service

router = APIRouter(tags=["reports"])


@router.post("/reports", response_model=ReportsFull)
def create_report(report: Reports, db: Session = Depends(get_db)):
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
def get_user_draft_reports(user_id: int, db: Session = Depends(get_db)):
    return reports_service.get_all_reports_by_user_draft(db, user_id)


@router.get("/reports/user/{user_id}/submitted", response_model=List[ReportsFull])
def get_user_submitted_reports(user_id: int, db: Session = Depends(get_db)):
    return reports_service.get_all_reports_by_user_notdraft(db, user_id)


@router.get("/reports/{report_id}", response_model=ReportsFull)
def get_report(report_id: int, db: Session = Depends(get_db)):
    return reports_service.get_report(db, report_id)


@router.post("/users", response_model=UsersDetailed)
def create_user(user: Users, db: Session = Depends(get_db)):
    return reports_service.create_user(db, user)


@router.get("/users/top/{user_id}", response_model=List[UsersDetailed])
def get_top_users(user_id: int, db: Session = Depends(get_db)):
    return reports_service.get_top10_users(db, user_id)
@router.get("/reports/nearme", response_model=List[ReportsFull])
def get_reports_nearme(db: Session = Depends(get_db)):
    return reports_service.get_reports_open(db)
@router.get("/reports/resolved", response_model=List[ReportsFull])
def get_reports_resolved(db: Session = Depends(get_db)):
    return reports_service.get_reports_resolved(db)
@router.get("/reports/in_progress", response_model=List[ReportsFull])
def get_reports_in_progress(db: Session = Depends(get_db)):
    return reports_service.get_reports_in_progress(db)