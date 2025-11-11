namespace PassDemo.Common.Api.Models
{
    public class Status
    {
        public DatabaseConnectionState DatabaseState { get; set; }
        public string DatabaseServer { get; set; } = string.Empty;
    }
}