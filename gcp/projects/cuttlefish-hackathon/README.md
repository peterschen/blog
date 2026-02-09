# Antigravity prompts

1. I need an API layer that accepts requests signed with a Google Cloud token (as retrieved from the GCE Metadata server) and stores the user and the project in a lightweight database (e.g. firebase). The API needs to run in Cloud Run
1. Add a list method to the API that lists out the registered principals. Update the record_request method to also store the timestamp when the request was made.
1. Refactor the record_request method to add_principal and rename the api call to /api/principals
1. Rename the database to principals to match the api surface
1. Refactor database from Firebase to firestore
1. Change timestamp to a unix timestamp
1. Create cloud build instructions building the application
1. Change the Cloud Run name and all other references to hackathon-controller
1. Changer the list_principals method to work unauthenticated
1. Change the code to use a database name that is passed as an environmental setting to the Cloud Run service
1. Add a env statement for DB_NAME to Dockerfile defaulting to "(default)" reading anything passed into the container
1. Create a shell script that calls the principals API and stores a new principal
1. Refactor the add_principal API method to accept the project ID as a parameter, remove email and project logic from the method body. The subject attribute can be removed from being stored in the database  
1. Also update the list_principals method to remove subject
1. Move PrincipalRequest class to a separate file
1. Add a new api method to update the principal and set a nickname for the principal. 
1. Create a shell script that calls update_principal
1. Change timestamp to date_created and add a new field date_modified that is updated on each modification of the record.