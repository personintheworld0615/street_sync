from datetime import datetime
from typing import Optional

from api.schemas.reports import Reports, ReportsFull, Users, UsersDetailed
from fastapi import HTTPException
from api.models.reports import User, Report
from api.services.storage import persist_report_image


def report_to_schema(row: Report) -> ReportsFull:
    return ReportsFull(
        id=row.id,
        title=row.title,
        description=row.description,
        category=row.category,
        latitude=row.latitude,
        longitude=row.longitude,
        location=row.location,
        image=row.image,
        time=row.time,
        severity=row.severity,
        status=row.status,
        user_id=row.user_id,
        isDraft=row.is_draft,
    )


def create_report(db, report: Reports):
    user = db.query(User).filter(User.id == report.user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    # Store only a Storage URL (upload base64/data-URI if needed)
    image_url = persist_report_image(report.image)
    row = Report(
        title=report.title,
        description=report.description,
        category=report.category,
        latitude=report.latitude,
        longitude=report.longitude,
        location=report.location,
        severity=report.severity,
        user_id=report.user_id,
        is_draft=report.isDraft,
        image=image_url,
        # Drafts must not appear in public "Open" feeds
        status="Draft" if report.isDraft else "Open",
        time=report.time,
    )
    db.add(row)
    db.commit()
    db.refresh(row)

    if not report.isDraft:
        bump_user_report_count(db, report.user_id)

    return report_to_schema(row)


def bump_user_report_count(db, user_id: int):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    user.total_reports += 1
    db.commit()


def get_report(db, report_id: int, current_user: User | None = None):
    row = db.query(Report).filter(Report.id == report_id).first()
    if not row:
        raise HTTPException(status_code=404, detail="Report not found")
    # Drafts are private to the owner
    if row.is_draft:
        if current_user is None or row.user_id != current_user.id:
            raise HTTPException(status_code=404, detail="Report not found")
    return report_to_schema(row)




def get_all_reports_by_user_notdraft(db, user_id: int):
    rows = (
        db.query(Report)
        .filter(Report.user_id == user_id, Report.is_draft == False)
        .order_by(Report.time.desc())
        .all()
    )
    return [report_to_schema(report) for report in rows]


def get_all_reports_by_user_draft(db, user_id: int):
    rows = (
        db.query(Report)
        .filter(Report.user_id == user_id, Report.is_draft == True)
        .order_by(Report.time.desc())
        .all()
    )
    return [report_to_schema(report) for report in rows]


def get_all_reports(db):
    # Public list: submitted reports only (never drafts)
    rows = db.query(Report).filter(Report.is_draft == False).all()
    return [report_to_schema(report) for report in rows]


def get_most_recent_reports(db, amount: int):
    rows = []
    rows.extend(db.query(Report).filter(Report.is_draft == False, Report.category == "Road Damage").order_by(Report.time.desc()).limit(amount).all())
    rows.extend(db.query(Report).filter(Report.is_draft == False, Report.category == "Public Works").order_by(Report.time.desc()).limit(amount).all())
    rows.extend(db.query(Report).filter(Report.is_draft == False, Report.category == "Environmental").order_by(Report.time.desc()).limit(amount).all())
    rows.extend(db.query(Report).filter(Report.is_draft == False, Report.category == "Accessibility").order_by(Report.time.desc()).limit(amount).all())
    rows.extend(db.query(Report).filter(Report.is_draft == False, Report.category != "Road Damage", Report.category != "Public Works", Report.category != "Environmental", Report.category != "Accessibility").order_by(Report.time.desc()).limit(amount).all())

    rows.sort(key=lambda x: x.time, reverse=True)
    # rows = db.query(Report).filter(Report.is_draft == False).order_by(Report.time.desc()).limit(amount).all()
    return [report_to_schema(report) for report in rows]


def get_reports_feed(
    db,
    amount: int,
    category: Optional[str] = None,
    before: Optional[datetime] = None,
):
    """Newest-first feed with optional category filter and cursor (`before` timestamp)."""
    q = db.query(Report).filter(Report.is_draft == False)

    if category:
        if category == "Other":
            q = q.filter(
                ~Report.category.in_(
                    [
                        "Road Damage",
                        "Public Works",
                        "Environmental",
                        "Accessibility",
                    ]
                )
            )
        else:
            q = q.filter(Report.category == category)

    if before is not None:
        if isinstance(before, str):
            before = datetime.fromisoformat(before.replace("Z", "+00:00"))
        q = q.filter(Report.time < before)

    rows = q.order_by(Report.time.desc()).limit(amount).all()
    return [report_to_schema(report) for report in rows]


def get_top10_users(db, user_id: int):
    rows = (
        db.query(User)
        .filter(User.id != user_id)
        .order_by(User.total_reports.desc())
        .limit(10)
        .all()
    )
    you = db.query(User).filter(User.id == user_id).first()
    if not you:
        raise HTTPException(status_code=404, detail="User not found")

    you_in_top10 = False
    for user in rows:
        if user.id == user_id:
            you_in_top10 = True
            break
    if not you_in_top10:
        rows.append(you)
    rows.sort(key=lambda x: x.total_reports, reverse=True)
    return [
        UsersDetailed(
            id=user.id,
            first_name=user.first_name,
            last_name=user.last_name,
            total_reports=user.total_reports,
            reports=[],
        )
        for user in rows
    ]
def get_reports_open(db):
    rows = (
        db.query(Report)
        .filter(Report.status == "Open", Report.is_draft == False)
        .all()
    )
    return [report_to_schema(report) for report in rows]

def get_reports_resolved(db):
    rows = (
        db.query(Report)
        .filter(Report.status == "Resolved", Report.is_draft == False)
        .all()
    )
    return [report_to_schema(report) for report in rows]

def get_reports_in_progress(db):
    rows = (
        db.query(Report)
        .filter(Report.status == "In Progress", Report.is_draft == False)
        .all()
    )
    return [report_to_schema(report) for report in rows]
def delete_account(db, user_id: int):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    # Remove reports first so FK constraints don't block the user delete.
    db.query(Report).filter(Report.user_id == user_id).delete()
    db.delete(user)
    db.commit()
    return {"message": "Account deleted successfully"}
def delete_report(db, report_id: int, current_user: User):
    report = db.query(Report).filter(Report.id == report_id).first()
    if not report:
        raise HTTPException(status_code=404, detail="Report not found")
    if report.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not allowed to delete this report")
    db.delete(report)
    db.commit()
    return {"message": "Report deleted successfully"}


def update_report(db, report_id: int, report: Reports, current_user: User):
    """Update an owned report. Used to edit/publish drafts in place."""
    row = db.query(Report).filter(Report.id == report_id).first()
    if not row:
        raise HTTPException(status_code=404, detail="Report not found")
    if row.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not allowed to update this report")

    was_draft = row.is_draft

    row.title = report.title
    row.description = report.description
    row.category = report.category
    row.latitude = report.latitude
    row.longitude = report.longitude
    row.location = report.location
    row.severity = report.severity
    row.time = report.time
    row.is_draft = report.isDraft

    # New image URL/data → upload; None means keep existing photo
    if report.image is not None:
        image_value = report.image.strip()
        if image_value:
            if image_value.startswith("http://") or image_value.startswith("https://"):
                row.image = image_value
            else:
                row.image = persist_report_image(image_value)

    if report.isDraft:
        row.status = "Draft"
    elif was_draft or row.status == "Draft":
        row.status = "Open"

    db.commit()
    db.refresh(row)

    if was_draft and not report.isDraft:
        bump_user_report_count(db, report.user_id)

    return report_to_schema(row)