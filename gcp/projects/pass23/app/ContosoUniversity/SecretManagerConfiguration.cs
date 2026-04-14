using Google.Cloud.SecretManager.V1;

namespace ContosoUniversity
{
    public class SecretManagerConfiguration
    {
        public string ProjectId { get; set; }
        public string Name { get; set; }
        public string Version { get; set; }

        public string AccessSecret()
        {
            SecretManagerServiceClient client = SecretManagerServiceClient.Create();

            AccessSecretVersionRequest request = new AccessSecretVersionRequest {
                SecretVersionName = new SecretVersionName(ProjectId, Name, Version)
            };
            
            AccessSecretVersionResponse response = client.AccessSecretVersion(request);
            return response.Payload.Data.ToStringUtf8();
        }
    }
}