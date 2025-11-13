using Microsoft.AspNetCore.Mvc;
using PassDemo.Common.Models;
using System.Web;

namespace PassDemo.Ui.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class WeatherDataController : ControllerBase
    {
        private readonly IHttpClientFactory _httpClientFactory;
        public WeatherDataController(IHttpClientFactory httpClientFactory) { _httpClientFactory = httpClientFactory; }

        [HttpGet]
        public async Task<IActionResult> GetWeatherData([FromQuery] string environment, [FromQuery] long? startTimestamp, [FromQuery] long? endTimestamp, [FromQuery] WeatherDataType? dataType)
        {
            var client = _httpClientFactory.CreateClient("ApiClient");
            var query = HttpUtility.ParseQueryString(string.Empty);
            
            if (startTimestamp.HasValue) query["startTimestamp"] = startTimestamp.Value.ToString();
            if (endTimestamp.HasValue) query["endTimestamp"] = endTimestamp.Value.ToString();
            if (dataType.HasValue) query["dataType"] = dataType.Value.ToString();

            var requestUri = $"/api/weatherdata/{environment}?{query}";
            var response = await client.GetAsync(requestUri);
            var content = await response.Content.ReadAsStringAsync();

            return new ContentResult
            {
                Content = content,
                ContentType = "application/json",
                StatusCode = (int)response.StatusCode
            };
        }
    }
}