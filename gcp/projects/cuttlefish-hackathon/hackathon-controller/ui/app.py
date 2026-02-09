import os
import requests
from flask import Flask, render_template, request, jsonify
from google.auth.transport.requests import Request
from google.oauth2 import id_token
import google.auth
import logging

# Configure logging
logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(name)s - %(levelname)s - %(message)s")
logger = logging.getLogger(__name__)

app = Flask(__name__)

API_URI = os.environ.get("API_URI", "http://localhost:8080")

def get_auth_token(audience: str) -> str:
    """
    Obtains an OIDC token for the given audience using default Google credentials.
    Suitable for calling another Cloud Run service.
    """
    credentials, _ = google.auth.default()
    
    # If using ADC locally (e.g. gcloud auth application-default login),
    # there is no guaranteed OIDC token available for arbitrary audiences
    # But in Cloud Run, this will fetch the identity token from the metadata server.
    req = Request()
    credentials.refresh(req)
    # The identity token is available if the credentials support it
    if hasattr(credentials, 'id_token'):
        return credentials.id_token
        
    # Attempt to fetch directly for Cloud Run environment
    try:
        url = f"http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/identity?audience={audience}"
        headers = {"Metadata-Flavor": "Google"}
        r = requests.get(url, headers=headers, timeout=2)
        r.raise_for_status()
        return r.text
    except Exception as e:
        logger.warning(f"Failed to fetch metadata token (normal locally): {e}")
        return ""

@app.route("/")
def index():
    return render_template("index.html")

@app.route("/api/principals", methods=["GET"])
def list_principals():
    """Proxy GET request to the backend API. Unauthenticated."""
    logger.info("Handling request to list principals")
    try:
        resp = requests.get(f"{API_URI}/api/principals")
        resp.raise_for_status()
        return jsonify(resp.json())
    except Exception as e:
        logger.error(f"Error listing principals: {e}")
        return jsonify({"error": str(e)}), 500

@app.route("/api/principals/<doc_id>", methods=["PATCH"])
def update_principal(doc_id):
    """Proxy PATCH request to backend API. Must attach GCP token."""
    logger.info(f"Handling request to update principal {doc_id}")
    data = request.json
    try:
        # Get token. In production Cloud Run, the audience is typically the backend service URL
        token = get_auth_token(audience=API_URI)
        
        headers = {"Content-Type": "application/json"}
        if token:
            headers["Authorization"] = f"Bearer {token}"
            
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
    """Proxy DELETE request to backend API. Must attach GCP token."""
    logger.info(f"Handling request to delete principal {doc_id}")
    try:
        # Get token. In production Cloud Run, the audience is typically the backend service URL
        token = get_auth_token(audience=API_URI)
        
        headers = {}
        if token:
            headers["Authorization"] = f"Bearer {token}"
            
        resp = requests.delete(
            f"{API_URI}/api/principals/{doc_id}",
            headers=headers
        )
        resp.raise_for_status()
        return jsonify(resp.json())
    except Exception as e:
        logger.error(f"Error deleting principal {doc_id}: {e}")
        return jsonify({"error": str(e), "details": resp.text if 'resp' in locals() and hasattr(resp, 'text') else ""}), 500

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8081))
    app.run(host="0.0.0.0", port=port, debug=True)
