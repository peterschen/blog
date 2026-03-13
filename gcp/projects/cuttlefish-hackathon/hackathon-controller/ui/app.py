import os
import requests
from flask import Flask, render_template, request, jsonify
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
    # Create current time and expiration time (1 hour later) in UTC
    iat = datetime.datetime.now(tz=datetime.timezone.utc)
    exp = iat + datetime.timedelta(seconds=3600)

    # Convert datetime objects to numeric timestamps (seconds since epoch)
    # as required by JWT standard (RFC 7519)
    payload = {
        "iss": service_account_email,
        "sub": service_account_email,
        "aud": audience,
        "iat": int(iat.timestamp()),
        "exp": int(exp.timestamp()),
    }

    return json.dumps(payload)

def sign_jwt(audience: str) -> str:
    # Get default credentials from environment or application credentials
    credentials, project_id = google.auth.default()

    # Initialize IAM credentials client with source credentials
    iam_client = IAMCredentialsClient(credentials=credentials)

    # In a Cloud Run environment, the credentials need to be refreshed to fetch 
    # the service account email from the metadata server.
    req = Request()
    credentials.refresh(req)

    # Retrieve service account from Cloud Run
    service_account = credentials.service_account_email

    # Generate the service account resource name.
    # Project should always be "-".
    # Replacing the wildcard character with a project ID is invalid.
    name = iam_client.service_account_path("-", service_account)

    # Create and sign the JWT payload
    payload = generate_jwt_payload(service_account, audience)

    # Sign the JWT using the IAM credentials API
    response = iam_client.sign_jwt(name=name, payload=payload)

    return response.signed_jwt

def get_auth_headers(audience: str, additional_headers: dict = None) -> dict:
    """Helper to construct authentication and additional headers."""
    headers = additional_headers or {}
    token = get_auth_token(audience=audience)
    if token:
        headers["Authorization"] = f"Bearer {token}"
    return headers

@app.route("/")
def index():
    return render_template("index.html")

@app.route("/api/principals", methods=["GET"])
def list_principals():
    """Proxy GET request to the backend API."""
    logger.info("Handling request to list principals")
    try:
        resp = requests.get(
            f"{API_URI}/api/principals",
            headers=get_auth_headers(audience=f"{API_URI}/api/principals")
        )
        resp.raise_for_status()
        return jsonify(resp.json())
    except Exception as e:
        logger.error(f"Error listing principals: {e}")
        return jsonify({"error": str(e)}), 500

@app.route("/api/principals/<doc_id>", methods=["PATCH"])
def update_principal(doc_id):
    """Proxy PATCH request to backend API."""
    logger.info(f"Handling request to update principal {doc_id}")
    data = request.json
    try:
        # Get token. In production Cloud Run, the audience is typically the backend service URL
        headers = get_auth_headers(
            audience=f"{API_URI}/api/principals/{doc_id}",
            additional_headers={"Content-Type": "application/json"}
        )
        
        resp = requests.patch(
            f"{API_URI}/api/principals/{doc_id}",
            json=data,
            headers=headers
        )
        resp.raise_for_status()
        return jsonify(resp.json())
    except Exception as e:
        logger.error(f"Error updating principal {doc_id}: {e}")
        return jsonify({"error": str(e), "details": resp.text if 'resp' in locals() and hasattr(resp, 'text') else ""}), 500

@app.route("/api/principals/<doc_id>", methods=["DELETE"])
def delete_principal(doc_id):
    """Proxy DELETE request to backend API."""
    logger.info(f"Handling request to delete principal {doc_id}")
    try:
        resp = requests.delete(
            f"{API_URI}/api/principals/{doc_id}",
            headers=get_auth_headers(audience=f"{API_URI}/api/principals/{doc_id}")
        )
        resp.raise_for_status()
        return jsonify(resp.json())
    except Exception as e:
        logger.error(f"Error deleting principal {doc_id}: {e}")
        return jsonify({"error": str(e), "details": resp.text if 'resp' in locals() and hasattr(resp, 'text') else ""}), 500

@app.route("/api/principals/<doc_id>/grant_permissions", methods=["POST"])
def grant_permissions(doc_id):
    """Proxy POST request to backend API."""
    logger.info(f"Handling request to grant permissions for principal {doc_id}")
    try:
        resp = requests.post(
            f"{API_URI}/api/principals/{doc_id}/grant_permissions",
            headers=get_auth_headers(audience=f"{API_URI}/api/principals/{doc_id}/grant_permissions")
        )
        resp.raise_for_status()
        return jsonify(resp.json())
    except Exception as e:
        logger.error(f"Error granting permissions for principal {doc_id}: {e}")
        return jsonify({"error": str(e), "details": resp.text if 'resp' in locals() and hasattr(resp, 'text') else ""}), 500

@app.route("/api/principals/<doc_id>/progress", methods=["POST"])
def record_progress(doc_id):
    """Proxy POST request to backend API to record stage progress."""
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
    port = int(os.environ.get("PORT", 8081))
    app.run(host="0.0.0.0", port=port, debug=True)
