import os
from datetime import datetime, timezone
from fastapi import FastAPI, Request, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from google.cloud import firestore
from google.cloud import resourcemanager_v3
from google.cloud import storage
from typing import Optional
import logging

from pydantic import BaseModel

# Configure logging
logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(name)s - %(levelname)s - %(message)s")
logger = logging.getLogger(__name__)

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
    logger.warning(f"Failed to initialize Firestore (Normal if testing locally without ADC): {e}")
    db = None

bucket_name = os.environ.get("BUCKET_NAME", "axion-hackaton-3298")

def to_principal(doc, retrieve = True):
    if retrieve:
        data = doc.get().to_dict()
    else:
        data = doc.to_dict()

    return {
        "id": doc.id,
        "email": data.get("email"),
        "project": data.get("project"),
        "nickname": data.get("nickname"),
        "date_created": data.get("date_created"),
        "date_modified": data.get("date_modified"),
        "permissions_granted": data.get("permissions_granted", False)
    }

@app.post("/api/principals")
def add_principal(req: Request, request: PrincipalRequest):
    """
    Stores the metadata in a lightweight Firebase (Firestore) database.
    IAP handles authentication securely.
    """
    if db is None:
        logger.error("Database not initialized during add_principal")
        raise HTTPException(status_code=500, detail="Database not initialized. Check server configurations.")
        
    email = req.headers.get("X-Goog-Authenticated-User-Email", "unknown_email")
    if email.startswith("accounts.google.com:"):
        email = email.split(":", 1)[1]

    # Store request details in Firestore
    try:
        doc_ref = db.collection("principals").document()
        doc_data = {
            "email": email,
            "project": request.project,
            "date_created": int(datetime.now(timezone.utc).timestamp()),
            "date_modified": int(datetime.now(timezone.utc).timestamp()),
            "permissions_granted": False
        }
        if request.nickname is not None:
            doc_data["nickname"] = request.nickname

        doc_ref.set(doc_data)
    except Exception as e:
        logger.error(f"Failed to write to DB during add_principal: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to write to DB: {e}")

    return {
        "status": "success",
        "message": "Request authenticated and stored",
        "data": to_principal(doc_ref)
    }

@app.get("/api/principals")
def list_principals():
    """
    Lists out the registered principals from the database.
    """
    if db is None:
        logger.error("Database not initialized during list_principals")
        raise HTTPException(status_code=500, detail="Database not initialized. Check server configurations.")

    try:
        # Fetching records from Firestore
        # This gets all documents in the 'principals' collection ordered by creation date
        docs = db.collection("principals").order_by("date_created", direction=firestore.Query.DESCENDING).stream()
        
        principals = []
        for doc in docs:
            principals.append(to_principal(doc, False))
            
        return {"status": "success", "data": principals}
    except Exception as e:
        logger.error(f"Failed to fetch from DB during list_principals: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to fetch from DB: {e}")

@app.post("/api/principals/{doc_id}/grant_permissions")
def grant_permissions(doc_id: str):
    """
    Grants the Compute Engine default service account object viewer permissions to the bucket.
    IAP handles authentication securely.
    """
    if db is None:
        logger.error("Database not initialized during grant_permissions")
        raise HTTPException(status_code=500, detail="Database not initialized. Check server configurations.")

    doc_ref = db.collection("principals").document(doc_id)
    doc = doc_ref.get()
    if not doc.exists:
        logger.error(f"Principal {doc_id} not found during grant_permissions")
        raise HTTPException(status_code=404, detail="Principal not found")

    principal_data = doc.to_dict()
    project_id = principal_data.get("project")
    if not project_id:
        logger.error(f"Principal {doc_id} is missing a project ID during grant_permissions")
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
            "data": to_principal(doc_ref)
        }

    except Exception as e:
        logger.error(f"Failed to grant permissions for {doc_id}: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to grant permissions: {e}")

@app.patch("/api/principals/{doc_id}")
def update_principal(doc_id: str, request: PrincipalUpdateRequest):
    """
    Updates an existing principal to set their nickname.
    IAP handles authentication securely.
    """
    if db is None:
        logger.error("Database not initialized during update_principal")
        raise HTTPException(status_code=500, detail="Database not initialized. Check server configurations.")

    doc_ref = db.collection("principals").document(doc_id)
    if not doc_ref.get().exists:
        logger.error(f"Principal {doc_id} not found during update_principal")
        raise HTTPException(status_code=404, detail="Principal not found")

    try:
        current_time = int(datetime.now(timezone.utc).timestamp())
        doc_ref.update({
            "nickname": request.nickname,
            "date_modified": current_time
        })
    except Exception as e:
        logger.error(f"Failed to update DB for {doc_id} during update_principal: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to update DB: {e}")

    return {
        "status": "success",
        "message": "Nickname updated successfully",
        "data": to_principal(doc_ref)
    }

@app.delete("/api/principals/{doc_id}")
def delete_principal(doc_id: str):
    """
    Deletes an existing principal.
    IAP handles authentication securely.
    """
    if db is None:
        logger.error("Database not initialized during delete_principal")
        raise HTTPException(status_code=500, detail="Database not initialized. Check server configurations.")

    doc_ref = db.collection("principals").document(doc_id)
    if not doc_ref.get().exists:
        logger.error(f"Principal {doc_id} not found during delete_principal")
        raise HTTPException(status_code=404, detail="Principal not found")

    try:
        doc_ref.delete()
    except Exception as e:
        logger.error(f"Failed to delete DB record for {doc_id} during delete_principal: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to delete DB: {e}")

    return {
        "status": "success",
        "message": "Principal deleted successfully",
        "data": {
            "doc_id": doc_id
        }
    }
