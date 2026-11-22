"""Account endpoints backed by the huni_db MySQL database.

The Flutter app previously kept accounts in SharedPreferences on each
device, which meant anyone could register locally and log in whether or
not the account existed in the database — and the accounts already in
huni_db could not log in at all. These endpoints make the database the
single source of truth.

The app talks to this API; only this API talks to MySQL. Database
credentials must never ship inside the APK, where anyone who decompiles it
would gain full read/write access.

Run standalone:  python auth_api.py       (port 8001)
or mount into crepe_server.py:  app.include_router(auth_router)
"""
from __future__ import annotations

import os
import re

import bcrypt
import pymysql
from fastapi import APIRouter, FastAPI, HTTPException
from pydantic import BaseModel, Field

DB_HOST = os.getenv("HUNI_DB_HOST", "127.0.0.1")
DB_PORT = int(os.getenv("HUNI_DB_PORT", "3306"))
DB_USER = os.getenv("HUNI_DB_USER", "root")
DB_PASSWORD = os.getenv("HUNI_DB_PASSWORD", "")  # XAMPP default is empty
DB_NAME = os.getenv("HUNI_DB_NAME", "huni_db")

auth_router = APIRouter(tags=["auth"])


def _connect():
    try:
        return pymysql.connect(
            host=DB_HOST, port=DB_PORT, user=DB_USER,
            password=DB_PASSWORD, database=DB_NAME,
            cursorclass=pymysql.cursors.DictCursor, autocommit=True,
            connect_timeout=5,
        )
    except pymysql.err.OperationalError as exc:
        # Surfaced rather than swallowed: the usual cause is XAMPP's MySQL
        # not running, and a clear message saves a lot of guessing.
        raise HTTPException(
            status_code=503,
            detail=f"Cannot reach MySQL at {DB_HOST}:{DB_PORT}/{DB_NAME} — "
                   f"is XAMPP's MySQL started? ({exc.args[1] if len(exc.args) > 1 else exc})",
        ) from exc


def _check_password(plain: str, stored: str) -> bool:
    """Verifies against the bcrypt hashes already in the table.

    Those were written by PHP's password_hash(), which emits the `$2y$`
    prefix; Python's bcrypt only accepts `$2a$`/`$2b$`. The formats are
    identical apart from that tag, so it is rewritten before checking —
    without this every pre-existing account would fail to log in.
    """
    if not stored:
        return False
    if stored.startswith("$2y$"):
        stored = "$2b$" + stored[4:]
    try:
        return bcrypt.checkpw(plain.encode(), stored.encode())
    except ValueError:
        return False  # not a bcrypt hash at all


def _hash_password(plain: str) -> str:
    return bcrypt.hashpw(plain.encode(), bcrypt.gensalt()).decode()


def _public(row: dict) -> dict:
    """Everything about a user except the password hash."""
    return {
        "id": row["id"],
        "username": row["username"],
        "email": row.get("email"),
        "firstName": row.get("first_name"),
        "lastName": row.get("last_name"),
        # Decided by the database, never by the client. The app asks to sign
        # in as admin; only this flag grants it.
        "isAdmin": bool(row.get("is_admin", 0)),
    }


class LoginRequest(BaseModel):
    username: str = Field(min_length=1, max_length=100)
    password: str = Field(min_length=1)

    # requireAdmin is set by the "Log in as Admin" screen. Credentials are
    # still verified first, so a wrong password fails as a wrong password
    # rather than revealing whether the account is an admin.
    requireAdmin: bool = False


class RegisterRequest(BaseModel):
    username: str = Field(min_length=3, max_length=100)
    password: str = Field(min_length=4)
    email: str = Field(min_length=3, max_length=255)
    firstName: str | None = None
    lastName: str | None = None


@auth_router.get("/auth/health")
def auth_health():
    """Confirms the API can actually reach the database, not just that it
    is running — the app shows a useful message instead of a login failure
    when MySQL is down."""
    conn = _connect()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT COUNT(*) AS n FROM users")
            n = cur.fetchone()["n"]
        return {"status": "ok", "database": DB_NAME, "users": n}
    finally:
        conn.close()


@auth_router.post("/auth/login")
def login(req: LoginRequest):
    conn = _connect()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT * FROM users WHERE username = %s OR email = %s LIMIT 1",
                (req.username, req.username),
            )
            row = cur.fetchone()
    finally:
        conn.close()

    # Same response whether the user is missing or the password is wrong,
    # so the endpoint can't be used to enumerate valid usernames.
    if row is None or not _check_password(req.password, row["password"]):
        raise HTTPException(status_code=401, detail="Invalid username or password")

    user = _public(row)

    # Checked only after the password is confirmed, so this can't be used to
    # find out which accounts are admins.
    if req.requireAdmin and not user["isAdmin"]:
        raise HTTPException(
            status_code=403, detail="This account does not have admin access")

    return {"ok": True, "user": user}


@auth_router.post("/auth/register")
def register(req: RegisterRequest):
    if not re.match(r"^[^@\s]+@[^@\s]+\.[^@\s]+$", req.email):
        raise HTTPException(status_code=400, detail="Enter a valid email address")

    conn = _connect()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT username, email FROM users WHERE username = %s OR email = %s",
                (req.username, req.email),
            )
            clash = cur.fetchone()
            if clash:
                field = ("Username" if clash["username"] == req.username else "Email")
                raise HTTPException(status_code=409, detail=f"{field} is already taken")

            cur.execute(
                "INSERT INTO users (username, password, email, first_name, last_name) "
                "VALUES (%s, %s, %s, %s, %s)",
                (req.username, _hash_password(req.password), req.email,
                 req.firstName, req.lastName),
            )
            cur.execute("SELECT * FROM users WHERE id = %s", (cur.lastrowid,))
            row = cur.fetchone()
    finally:
        conn.close()

    return {"ok": True, "user": _public(row)}


app = FastAPI(title="Huni auth API")
app.include_router(auth_router)


if __name__ == "__main__":
    import uvicorn
    print(f"Huni auth API -> mysql://{DB_USER}@{DB_HOST}:{DB_PORT}/{DB_NAME}")
    uvicorn.run(app, host="0.0.0.0", port=8001, log_level="info")
