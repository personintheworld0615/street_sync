from datetime import datetime
from typing import Optional

from api.schemas.reports import (
    Reports,
    ReportsFull,
    UpdateOut,
    UsersDetailed,
)
from api.schemas.voice import ModelOutput
from fastapi import HTTPException
from api.models.reports import User, Report, Update
from api.services.storage import persist_report_image
from api.services.voice_ai import analyze_voice_report as _analyze_voice_report

_ALLOWED_STATUSES = {"Open", "In Progress", "Resolved"}

_CATEGORY_GROUPS = {
    "Streets & Transportation": [
        "Pothole",
        "Damaged Sidewalk/Curb",
        "Traffic Light",
        "Street Light",
        "Damaged/Missing Sign",
        "Road Debris",
        "Parking/Traffic",
    ],
    "Trash & Environment": [
        "Litter/Garbage",
        "Missed Trash/Recycling",
        "Illegal Dumping",
        "Graffiti",
        "Pollution",
        "Hazardous Waste",
        "Noise",
    ],
    "Nature & Water": [
        "Fallen Tree/Branch",
        "Overgrown Vegetation",
        "Tree Maintenance",
        "Flooding",
        "Clogged Storm Drain",
        "Standing Water",
        "Sewer/Water Problem",
    ],
    "Buildings & Public Spaces": [
        "Building Damage",
        "Property Maintenance",
        "Construction/Code Violation",
        "Housing/Rental Problem",
        "Park Maintenance",
        "Animal Issue",
        "Rodent/Insect Issue",
    ],
}

_ALL_CATEGORY_VALUES = [
    value for values in _CATEGORY_GROUPS.values() for value in values
]


def normalize_category(category: Optional[str]) -> str:
    if category is None:
        return "Other"
    value = category.strip()
    if not value:
        return "Other"
    for major, options in _CATEGORY_GROUPS.items():
        if value == major or value in options:
            return major
    return value


def analyze_voice_report(description: str) -> ModelOutput:
    return _analyze_voice_report(description)


def generate_ai_title(description: str) -> str:
    return _analyze_voice_report(description).title


def report_to_schema(row: Report) -> ReportsFull:
    return ReportsFull(
        id=row.id,
        title=row.title or "",
        description=row.description or "",
        category=row.category or "Other",
        latitude=float(row.latitude or 0.0),
        longitude=float(row.longitude or 0.0),
        location=row.location or "",
        image=row.image,
        time=row.time or datetime.utcnow(),
        severity=(row.severity or "medium"),
        status=row.status or "Open",
        user_id=row.user_id,
        isDraft=bool(row.is_draft),
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
        .all()
    )
    return [report_to_schema(report) for report in rows]


def get_all_reports_by_user_draft(db, user_id: int):
    rows = (
        db.query(Report)
        .filter(Report.user_id == user_id, Report.is_draft == True)
        .all()
    )
    return [report_to_schema(report) for report in rows]


def get_all_reports(db):
    # Public list: submitted reports only (never drafts)
    rows = db.query(Report).filter(Report.is_draft == False).all()
    return [report_to_schema(report) for report in rows]


def get_most_recent_reports(db, amount: int):
    rows = []
    for major_category, options in _CATEGORY_GROUPS.items():
        rows.extend(
            db.query(Report)
            .filter(Report.is_draft == False, Report.category.in_(options + [major_category]))
            .order_by(Report.time.desc())
            .limit(amount)
            .all()
        )

    rows.extend(
        db.query(Report)
        .filter(Report.is_draft == False, ~Report.category.in_(_ALL_CATEGORY_VALUES + list(_CATEGORY_GROUPS.keys())))
        .order_by(Report.time.desc())
        .limit(amount)
        .all()
    )

    rows.sort(key=lambda x: x.time, reverse=True)
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
        normalized = normalize_category(category)
        if normalized == "Other":
            q = q.filter(~Report.category.in_(_ALL_CATEGORY_VALUES + list(_CATEGORY_GROUPS.keys())))
        else:
            q = q.filter(Report.category.in_(_CATEGORY_GROUPS.get(normalized, [normalized]) + [normalized]))

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
    # Remove updates + reports first so FK constraints don't block the user delete.
    db.query(Update).filter(Update.user_id == user_id).delete()
    db.query(Report).filter(Report.user_id == user_id).delete()
    db.delete(user)
    db.commit()
    return {"message": "Account deleted successfully"}


def delete_report(db, report_id: int):
    report = db.query(Report).filter(Report.id == report_id).first()
    if not report:
        raise HTTPException(status_code=404, detail="Report not found")
    db.query(Update).filter(Update.report_id == report_id).delete()
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


def update_to_schema(row: Update) -> UpdateOut:
    return UpdateOut(
        id=row.id,
        report_id=row.report_id,
        user_id=row.user_id,
        report_title=row.report_title,
        old_status=row.old_status,
        new_status=row.new_status,
        comment=row.comment,
        is_read=row.is_read,
        created_at=row.created_at,
    )


def _normalize_status(status: str) -> str:
    cleaned = (status or "").strip()
    lowered = cleaned.lower()
    aliases = {
        "open": "Open",
        "in progress": "In Progress",
        "in_progress": "In Progress",
        "inprogress": "In Progress",
        "resolved": "Resolved",
        "closed": "Resolved",
    }
    if lowered in aliases:
        return aliases[lowered]
    if cleaned in _ALLOWED_STATUSES:
        return cleaned
    raise HTTPException(
        status_code=422,
        detail="status must be Open, In Progress, or Resolved",
    )


def update_report_status(
    db,
    report_id: int,
    new_status: str,
    comment: Optional[str] = None,
):
    """Dashboard status change: update report + insert an Updates feed row."""
    row = db.query(Report).filter(Report.id == report_id).first()
    if not row:
        raise HTTPException(status_code=404, detail="Report not found")
    if row.is_draft:
        raise HTTPException(
            status_code=400,
            detail="Cannot change status on a draft report",
        )

    normalized = _normalize_status(new_status)
    old_status = row.status or "Open"
    cleaned_comment = (comment or "").strip() or None

    if old_status == normalized and cleaned_comment is None:
        raise HTTPException(
            status_code=400,
            detail="Status is unchanged and no comment was provided",
        )

    row.status = normalized

    update_row = Update(
        report_id=row.id,
        user_id=row.user_id,
        report_title=row.title or "",
        old_status=old_status,
        new_status=normalized,
        comment=cleaned_comment,
        is_read=False,
        created_at=datetime.utcnow(),
    )
    db.add(update_row)
    db.commit()
    db.refresh(update_row)
    return update_to_schema(update_row)


def get_updates_for_user(db, user_id: int, limit: int = 50):
    rows = (
        db.query(Update)
        .filter(Update.user_id == user_id)
        .order_by(Update.created_at.desc())
        .limit(limit)
        .all()
    )
    return [update_to_schema(r) for r in rows]


def mark_updates_read(db, user_id: int, update_ids: Optional[list[int]] = None):
    q = db.query(Update).filter(Update.user_id == user_id, Update.is_read == False)
    if update_ids:
        q = q.filter(Update.id.in_(update_ids))
    q.update({"is_read": True}, synchronize_session=False)
    db.commit()
    return {"message": "ok"}