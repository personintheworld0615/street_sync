from typing import List

from fastapi import APIRouter, Query

from api.schemas.reports import Reports, ReportsFull, Users, UsersDetailed
from api.services import reports as reports_service

router = APIRouter(tags=["reports"])


@router.post("/reports", response_model=ReportsFull)
def create_report(report: Reports):
    return reports_service.create_report(report)


@router.get("/reports", response_model=List[ReportsFull])
def get_all_reports():
    return reports_service.get_all_reports()


@router.get("/reports/recent", response_model=List[ReportsFull])
def get_most_recent_reports(amount: int = Query(default=10, ge=1, le=100)):
    return reports_service.get_most_recent_reports(amount)


@router.get("/reports/user/{user_id}", response_model=List[ReportsFull])
def get_all_user_reports(user_id: int):
    return reports_service.get_all_user_reports(user_id)


@router.get("/reports/user/{user_id}/drafts", response_model=List[ReportsFull])
def get_user_draft_reports(user_id: int):
    return reports_service.get_all_reports_by_user_draft(user_id)


@router.get("/reports/user/{user_id}/submitted", response_model=List[ReportsFull])
def get_user_submitted_reports(user_id: int):
    return reports_service.get_all_reports_by_user_submitted(user_id)


@router.get("/reports/{report_id}", response_model=ReportsFull)
def get_report(report_id: int):
    return reports_service.get_report(report_id)


@router.post("/users", response_model=UsersDetailed)
def create_user(user: Users):
    return reports_service.create_user(user)


@router.get("/users/top", response_model=List[UsersDetailed])
def get_top_users():
    return reports_service.get_top10_users()
