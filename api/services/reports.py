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
    rows.extend(db.query(Report).filter(Report.is_draft == False, Report.category == "Road Damage").order_by(Report.time.desc()).limit(amount).all())
    rows.extend(db.query(Report).filter(Report.is_draft == False, Report.category == "Public Works").order_by(Report.time.desc()).limit(amount).all())
    rows.extend(db.query(Report).filter(Report.is_draft == False, Report.category == "Environmental").order_by(Report.time.desc()).limit(amount).all())
    rows.extend(db.query(Report).filter(Report.is_draft == False, Report.category == "Accessibility").order_by(Report.time.desc()).limit(amount).all())
    rows.extend(db.query(Report).filter(Report.is_draft == False, Report.category != "Road Damage", Report.category != "Public Works", Report.category != "Environmental", Report.category != "Accessibility").order_by(Report.time.desc()).limit(amount).all())

    rows.sort(key=lambda x: x.time, reverse=True)
    # rows = db.query(Report).filter(Report.is_draft == False).order_by(Report.time.desc()).limit(amount).all()
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
def delete_report(db, report_id: int):
    report = db.query(Report).filter(Report.id == report_id).first()
    if not report:
        raise HTTPException(status_code=404, detail="Report not found")
    db.delete(report)
    db.commit()
    return {"message": "Report deleted successfully"}