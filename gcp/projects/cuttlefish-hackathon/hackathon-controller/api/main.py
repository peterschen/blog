import os
from datetime import datetime, timezone
from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from google.oauth2 import id_token
from google.auth.transport import requests as google_requests
from google.cloud import firestore

from pydantic import BaseModel

class PrincipalRequest(BaseModel):
    project: str

class PrincipalUpdateRequest(BaseModel):
    nickname: str

app = FastAPI(title="Hackathon Controller", description="API that validates Google Cloud Tokens and stores requests in Firestore")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize Firestore client. 
# Cloud Run natively provides default credentials which give access to Firestore
# if the underlying Service Account has the required Datastore/Firestore permissions.
try:
    db_name = os.environ.get("DB_NAME", "(default)")
    db = firestore.Client(database=db_name)
except Exception as e:
    print(f"Warning: Failed to initialize Firestore (Normal if testing locally without ADC): {e}")
    db = None

security = HTTPBearer()

def verify_gcp_token(cred: HTTPAuthorizationCredentials = Depends(security)):
    """
    Validates the bearer token as an OIDC token from a Google Cloud service (e.g., GCE, Cloud Run, Cloud Functions).
    """
    token = cred.credentials
    try:
        # Verify token. The audience is usually the URL of this service.
        req = google_requests.Request()
        
        # In a real environment, provide `audience="https://your-cloud-run-url"` 
        # to ensure the token was minted specifically for this API.
        token_info = id_token.verify_oauth2_token(token, req)
        return token_info
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid Token: {str(e)}",
            headers={"WWW-Authenticate": "Bearer"},
        )

@app.post("/api/principals")
def add_principal(request: PrincipalRequest, token_info: dict = Depends(verify_gcp_token)):
    """
    Endpoint that requires a valid GCP token.
    Stores the metadata in a lightweight Firebase (Firestore) database.
    """
    if db is None:
        raise HTTPException(status_code=500, detail="Database not initialized. Check server configurations.")
        
    email = token_info.get("email", "unknown_email")

    # Store request details in Firestore
    try:
        doc_ref = db.collection("principals").document()
        doc_ref.set({
            "email": email,
            "project": request.project,
            "date_created": int(datetime.now(timezone.utc).timestamp()),
            "date_modified": int(datetime.now(timezone.utc).timestamp())
        })
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to write to DB: {e}")

    return {
        "status": "success",
        "message": "Request authenticated and stored",
        "data": {
            "email": email,
            "project": request.project,
            "doc_id": doc_ref.id
        }
    }

@app.get("/api/principals")
def list_principals():
    """
    Lists out the registered principals from the database.
    """
    if db is None:
        raise HTTPException(status_code=500, detail="Database not initialized. Check server configurations.")

    try:
        # Fetching records from Firestore
        # This gets all documents in the 'principals' collection
        docs = db.collection("principals").stream()
        
        principals = []
        for doc in docs:
            data = doc.to_dict()
            principal = {
                "id": doc.id,
                "email": data.get("email"),
                "project": data.get("project"),
                "nickname": data.get("nickname"),
                "date_created": data.get("date_created"),
                "date_modified": data.get("date_modified")
            }
            principals.append(principal)
            
        return {"status": "success", "data": principals}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to fetch from DB: {e}")

@app.patch("/api/principals/{doc_id}")
def update_principal(doc_id: str, request: PrincipalUpdateRequest, token_info: dict = Depends(verify_gcp_token)):
    """
    Updates an existing principal to set their nickname.
    Requires a valid GCP token.
    """
    if db is None:
        raise HTTPException(status_code=500, detail="Database not initialized. Check server configurations.")

    doc_ref = db.collection("principals").document(doc_id)
    if not doc_ref.get().exists:
        raise HTTPException(status_code=404, detail="Principal not found")

    try:
        current_time = int(datetime.now(timezone.utc).timestamp())
        doc_ref.update({
            "nickname": request.nickname,
            "date_modified": current_time
        })
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to update DB: {e}")

    return {
        "status": "success",
        "message": "Nickname updated successfully",
        "data": {
            "doc_id": doc_id,
            "nickname": request.nickname,
            "date_modified": current_time
        }
    }

@app.delete("/api/principals/{doc_id}")
def delete_principal(doc_id: str, token_info: dict = Depends(verify_gcp_token)):
    """
    Deletes an existing principal.
    Requires a valid GCP token.
    """
    if db is None:
        raise HTTPException(status_code=500, detail="Database not initialized. Check server configurations.")

    doc_ref = db.collection("principals").document(doc_id)
    if not doc_ref.get().exists:
        raise HTTPException(status_code=404, detail="Principal not found")

    try:
        doc_ref.delete()
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to delete DB: {e}")

    return {
        "status": "success",
        "message": "Principal deleted successfully",
        "data": {
            "doc_id": doc_id
        }
    }
