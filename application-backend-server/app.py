from flask import Flask, jsonify, request, Response
import time, requests, os, json, pymysql
from jose import jwt

ISSUER = "http://localhost:8081/realms/realm_52300070"
AUDIENCE = "account"
JWKS_URL = "http://authentication-identity-server:8080/realms/realm_52300070/protocol/openid-connect/certs"

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
    jwks = get_jwks()
    unverified_header = jwt.get_unverified_header(token)
    kid = unverified_header.get("kid")
    for key in jwks["keys"]:
        if key.get("kid") == kid:
            return key
    raise Exception("No matching JWK found for kid: " + str(kid))

def get_db_connection():
    conn = pymysql.connect(
        host="relational-database-server",
        user="root",
        password="root",
        database="studentdb",
        cursorclass=pymysql.cursors.DictCursor,
        charset="utf8mb4"
    )
    return conn

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
    except Exception as e:
        print("JWT error:", repr(e))
        return jsonify(error=str(e)), 401

@app.get("/students-db")
def students_db():
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT * FROM students")
            rows = cursor.fetchall()
            
            # Format JSON xuống dòng (indent=4) và hiển thị tiếng Việt có dấu (ensure_ascii=False)
            json_output = json.dumps(rows, ensure_ascii=False, indent=4)
            return Response(json_output, mimetype='application/json')
            
    except Exception as e:
        print("DB error:", e)
        return jsonify({"error": str(e)}), 500
    finally:
        conn.close()

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8081)