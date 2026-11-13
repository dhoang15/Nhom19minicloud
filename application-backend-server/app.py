import os
import time

import pymysql
import requests
from flask import Flask, jsonify, request
from jose import jwt
from jose.exceptions import JWTError

ISSUER = os.getenv(
    "OIDC_ISSUER",
    "http://localhost:8081/realms/realm_52300070",
)
AUDIENCE = os.getenv("OIDC_AUDIENCE", "flask-app")
JWKS_URL = os.getenv(
    "OIDC_JWKS_URL",
    "http://authentication-identity-server:8080/realms/"
    "realm_52300070/protocol/openid-connect/certs",
)

_JWKS = None
_TS = 0


def get_jwks():
    global _JWKS, _TS
    now = time.time()
    if (not _JWKS) or (now - _TS > 600):
        resp = requests.get(JWKS_URL, timeout=5)
        resp.raise_for_status()
        _JWKS = resp.json()
        _TS = now
    return _JWKS


def get_signing_key(token: str):
    global _JWKS, _TS
    jwks = get_jwks()
    unverified_header = jwt.get_unverified_header(token)
    kid = unverified_header.get("kid")
    for key in jwks["keys"]:
        if key.get("kid") == kid:
            return key
    _JWKS = None
    _TS = 0
    jwks = get_jwks()
    for key in jwks["keys"]:
        if key.get("kid") == kid:
            return key
    raise JWTError("No matching signing key found")


def get_db_connection():
    return pymysql.connect(
        host=os.getenv("DB_HOST", "relational-database-server"),
        port=int(os.getenv("DB_PORT", "3306")),
        user=os.getenv("DB_USER", "root"),
        password=os.environ["DB_PASSWORD"],
        database=os.getenv("DB_NAME", "studentdb"),
        cursorclass=pymysql.cursors.DictCursor,
        charset="utf8mb4",
        connect_timeout=5,
    )


app = Flask(__name__)


@app.get("/")
def home():
    return jsonify(message="MiniCloud Backend Server is running successfully!")


@app.get("/hello")
def hello():
    return jsonify(message="Hello from App Server!")


@app.get("/secure")
def secure():
    auth = request.headers.get("Authorization", "")
    if not auth.startswith("Bearer "):
        return jsonify(error="Missing Bearer token"), 401
    token = auth.split(" ", 1)[1]
    try:
        public_key = get_signing_key(token)
        payload = jwt.decode(
            token,
            key=public_key,
            algorithms=["RS256"],
            audience=AUDIENCE,
            issuer=ISSUER,
        )
        return jsonify(
            message="Secure resource OK",
            preferred_username=payload.get("preferred_username"),
        )
    except requests.RequestException:
        app.logger.exception("Unable to retrieve the identity provider signing keys")
        return jsonify(error="Identity provider is unavailable"), 503
    except (JWTError, KeyError, TypeError, ValueError):
        app.logger.info("Rejected an invalid bearer token")
        return jsonify(error="Invalid bearer token"), 401


@app.get("/student")
def student():
    return query_students(
        "SELECT id, student_id, fullname AS name, dob, major, gpa "
        "FROM students ORDER BY id"
    )


@app.get("/students-db")
def students_db():
    return query_students("SELECT * FROM students ORDER BY id")


def query_students(query):
    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor() as cursor:
            cursor.execute(query)
            rows = cursor.fetchall()
        return jsonify(rows)
    except pymysql.MySQLError:
        app.logger.exception("Unable to query the student database")
        return jsonify(error="Student database is unavailable"), 503
    finally:
        if conn is not None:
            conn.close()


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8081, threaded=True)