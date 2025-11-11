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

        public WeatherDataController(IHttpClientFactory httpClientFactory)
        {
            _httpClientFactory = httpClientFactory;
        }

        [HttpGet]
        public async Task<IActionResult> GetWeatherData(
            [FromQuery] long? startTimestamp,
            [FromQuery] long? endTimestamp,
            [FromQuery] WeatherDataType? dataType)
        {
            var client = _httpClientFactory.CreateClient("ApiClient");

            // --- Build the query string to forward to the real API ---
            var query = HttpUtility.ParseQueryString(string.Empty);
            if (startTimestamp.HasValue)
            {
                query["startTimestamp"] = startTimestamp.Value.ToString();
            }
            
            if (endTimestamp.HasValue)
            {
                query["endTimestamp"] = endTimestamp.Value.ToString();
            }

            if (dataType.HasValue)
            {
                query["dataType"] = dataType.Value.ToString();
            }

            string requestUri = "/api/weatherdata";
            if (query.Count > 0)
            {
                requestUri += "?" + query.ToString();
            }
            // --- End of query string building ---

            try
            {
                // Call the actual API with the constructed query string
                var response = await client.GetAsync(requestUri);

                if (response.IsSuccessStatusCode)
                {
                    // If the API call was successful, pass its JSON content directly back to the browser.
                    var apiContent = await response.Content.ReadAsStringAsync();
                    return Content(apiContent, "application/json");
                }
                else
                {
                    // If the API returned an error, bubble up that error status.
                    return StatusCode((int)response.StatusCode, "Failed to retrieve weather data from the backend API.");
                }
            }
            catch (HttpRequestException)
            {
                // If the API is completely unreachable, return a 503 Service Unavailable error.
                return StatusCode(503, "Backend API is unavailable.");
            }
        }
    }
}