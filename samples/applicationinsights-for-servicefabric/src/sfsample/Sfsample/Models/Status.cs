namespace Sfsample.Models
{
    public class Status
    {
        public string Version { get; set; }
     
        public Status(string version)
        {
            Version = version;
        }
    }
}