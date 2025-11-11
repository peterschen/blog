using System.Text.Json.Serialization;

namespace PassDemo.Common.Models
{
    [JsonConverter(typeof(JsonStringEnumConverter))]
    public enum WeatherDataType
    {
        Temperature,
        Humidity
    }
}