using System.Text.Json.Serialization;

namespace PassDemo.Common.Api.Models
{
    [JsonConverter(typeof(JsonStringEnumConverter))]
    public enum DatabaseConnectionState
    {
        Disconnected,
        Connected
    }
}