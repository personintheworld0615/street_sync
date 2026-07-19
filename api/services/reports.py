from api.schemas.reports import Reports, ReportsFull, Users, UsersDetailed
from fastapi import HTTPException
fake_db = {}
fake_db_users = {}
next_id = 1
next_id_user = 1
def create_report(report: Reports):
    global next_id
    new_report = report.model_dump()
    report_detailed = ReportsFull(**new_report,id=next_id,status="pending")
    fake_db[next_id] = report_detailed
    next_id += 1
    return report_detailed

def get_report(report_id: int):
    if report_id not in fake_db:
        raise HTTPException(status_code=404, detail="Report not found")
    return fake_db[report_id]

def create_user(user: Users):
    global next_id_user
    new_user = user.model_dump()
    user_detailed = UsersDetailed(**new_user,id=next_id_user)
    fake_db_users[next_id_user] = user_detailed
    next_id_user += 1
    return user_detailed
def get_all_reportsbyUser_notPending(user_id: int):
    return [report for report in fake_db.values() if report.user_id == user_id and not report.isPending]

def get_all_reportsbyUser_pending(user_id: int):
    return [report for report in fake_db.values() if report.user_id == user_id and  report.isPending]
def def_getalluserReports(user_id: int):
    return get_all_reportsbyUser_notPending(user_id) + get_all_reportsbyUser_pending(user_id)

def get_all_reports():
    return list(fake_db.values())

def get_most_recent_reports(amount:int):
    return sorted(fake_db.values(), key=lambda x: x.time, reverse=True)[:amount]

def get_top10_users():
    return sorted(fake_db_users.values(), key=lambda x: x.total_reports, reverse=True)[:10]
