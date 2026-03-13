import os
import requests
from flask import Flask, request, jsonify
from google.auth.transport.requests import Request
from google.cloud.iam_credentials_v1 import IAMCredentialsClient
import json
import datetime
import google.auth
import logging

# Configure logging
logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(name)s - %(levelname)s - %(message)s")
logger = logging.getLogger(__name__)

app = Flask(__name__)

API_URI = os.environ.get("API_URI", "http://localhost:8080")

def get_auth_token(audience: str) -> str:
    try:
        return sign_jwt(audience)
    except Exception as e:
        logger.warning(f"Failed to retrieve auth token: {e}")
        return ""

def generate_jwt_payload(service_account_email: str, audience: str) -> str:
    iat = datetime.datetime.now(tz=datetime.timezone.utc)
    exp = iat + datetime.timedelta(seconds=3600)

    payload = {
        "iss": service_account_email,
        "sub": service_account_email,
        "aud": audience,
        "iat": int(iat.timestamp()),
        "exp": int(exp.timestamp()),
    }

    return json.dumps(payload)

def sign_jwt(audience: str) -> str:
    credentials, project_id = google.auth.default()
    iam_client = IAMCredentialsClient(credentials=credentials)

    req = Request()
    credentials.refresh(req)

    service_account = credentials.service_account_email
    name = iam_client.service_account_path("-", service_account)

    payload = generate_jwt_payload(service_account, audience)
    response = iam_client.sign_jwt(name=name, payload=payload)

    return response.signed_jwt

def get_auth_headers(audience: str, additional_headers: dict = None) -> dict:
    headers = additional_headers or {}
    token = get_auth_token(audience=audience)
    if token:
        headers["Authorization"] = f"Bearer {token}"
    return headers

@app.route("/api/principals/<doc_id>/progress", methods=["POST"])
def record_progress(doc_id):
    """Proxy POST request to backend API to record participant progress."""
    logger.info(f"Handling request to record progress for principal {doc_id}")
    data = request.json
    
    try:
        headers = get_auth_headers(
            audience=f"{API_URI}/api/principals/{doc_id}/progress",
            additional_headers={"Content-Type": "application/json"}
        )
        
        resp = requests.post(
            f"{API_URI}/api/principals/{doc_id}/progress",
            json=data,
            headers=headers
        )
        resp.raise_for_status()
        return jsonify(resp.json())
    except Exception as e:
        logger.error(f"Error recording progress for {doc_id}: {e}")
        return jsonify({"error": str(e), "details": resp.text if 'resp' in locals() and hasattr(resp, 'text') else ""}), 500

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8082))
    app.run(host="0.0.0.0", port=port, debug=True)
