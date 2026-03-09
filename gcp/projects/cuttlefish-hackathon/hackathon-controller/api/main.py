import os
from datetime import datetime, timezone
from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from google.oauth2 import id_token
from google.auth.transport import requests as google_requests
from google.cloud import firestore
from google.cloud import resourcemanager_v3
from google.cloud import storage
from typing import Optional

from pydantic import BaseModel

class PrincipalRequest(BaseModel):
    project: str
    nickname: Optional[str] = None

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
        doc_data = {
            "email": email,
            "project": request.project,
            "date_created": int(datetime.now(timezone.utc).timestamp()),
            "date_modified": int(datetime.now(timezone.utc).timestamp())
        }
        if request.nickname is not None:
            doc_data["nickname"] = request.nickname

        doc_ref.set(doc_data)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to write to DB: {e}")

    return {
        "status": "success",
        "message": "Request authenticated and stored",
        "data": {
            "email": email,
            "project": request.project,
            "nickname": request.nickname,
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
        # This gets all documents in the 'principals' collection ordered by creation date
        docs = db.collection("principals").order_by("date_created", direction=firestore.Query.DESCENDING).stream()
        
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

@app.post("/api/principals/{doc_id}/grant_permissions")
def grant_permissions(doc_id: str, token_info: dict = Depends(verify_gcp_token)):
    """
    Grants the Compute Engine default service account object viewer permissions to the bucket.
    Requires a valid GCP token.
    """
    if db is None:
        raise HTTPException(status_code=500, detail="Database not initialized. Check server configurations.")

    doc_ref = db.collection("principals").document(doc_id)
    doc = doc_ref.get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Principal not found")

    principal_data = doc.to_dict()
    project_id = principal_data.get("project")
    if not project_id:
        raise HTTPException(status_code=400, detail="Principal record is missing a project ID")

    try:
        # 1. Fetch project number using Resource Manager API
        rm_client = resourcemanager_v3.ProjectsClient()
        project_name = f"projects/{project_id}"
        project_obj = rm_client.get_project(name=project_name)
        
        # In the resourcemanager_v3 API, the `name` field returned from get_project is actually `projects/{project_number}`
        # The documentation is a bit tricky, but this is the standard way to extract it.
        # Alternatively, `project_obj.name.split("/")[1]`
        project_number = project_obj.name.split("/")[1]

        # 2. Construct default compute service account
        sa_email = f"{project_number}-compute@developer.gserviceaccount.com"
        
        # 3. Modify bucket IAM policy
        storage_client = storage.Client()
        bucket_name = "axion-hakaton-3298"
        bucket = storage_client.bucket(bucket_name)

        policy = bucket.get_iam_policy(requested_policy_version=3)
        
        # Add the role
        role = "roles/storage.objectViewer"
        member = f"serviceAccount:{sa_email}"
        
        # It's an array of bindings. Best edge-case handling is to avoid duplicating
        # Though the python client resolves duplicates, we should use the bindings helper.
        policy.bindings.append(
            {"role": role, "members": {member}}
        )
        
        bucket.set_iam_policy(policy)

        # 4. Update the Firestore document
        current_time = int(datetime.now(timezone.utc).timestamp())
        doc_ref.update({
            "permissions_granted": True,
            "date_modified": current_time
        })

        return {
            "status": "success",
            "message": f"Granted Object Viewer permissions to {sa_email}",
            "data": {
                "doc_id": doc_id,
                "permissions_granted": True,
                "date_modified": current_time
            }
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to grant permissions: {e}")

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
