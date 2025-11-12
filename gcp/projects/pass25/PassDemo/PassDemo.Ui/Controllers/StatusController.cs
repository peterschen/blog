using Microsoft.AspNetCore.Mvc;
using PassDemo.Common.DTOs;

namespace PassDemo.Ui.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class StatusController : ControllerBase
    {
        private readonly IHttpClientFactory _httpClientFactory;

        public StatusController(IHttpClientFactory httpClientFactory)
        {
            _httpClientFactory = httpClientFactory;
        }

        [HttpGet]
        public async Task<IActionResult> GetStatus()
        {
            var client = _httpClientFactory.CreateClient("ApiClient");

            try
            {
                // Call the actual API endpoint
                var response = await client.GetAsync("/api/status");

                // Check if the call to the actual API was successful
                if (response.IsSuccessStatusCode)
                {
                    // Read the content from the API's response...
                    var apiContent = await response.Content.ReadAsStringAsync();
                    // ...and return it directly. This acts as a pass-through.
                    return Content(apiContent, "application/json");
                }
                else
                {
                    // If the API call failed, return the same status code to the browser.
                    return StatusCode((int)response.StatusCode, "Failed to retrieve status from the backend API.");
                }
            }
            catch (HttpRequestException)
            {
                // This catches network errors if the API is completely unreachable.
                return StatusCode(503, "Backend API is unavailable."); // 503 Service Unavailable
            }
        }
    
        [HttpPost("connection")]
        public async Task<IActionResult> UpdateActiveConnection([FromBody] ConnectionUpdateRequest request)
        {
            var client = _httpClientFactory.CreateClient("ApiClient");
            try
            {
                var response = await client.PostAsJsonAsync("/api/status/connection", request);
                if (response.IsSuccessStatusCode)
                {
                    var apiContent = await response.Content.ReadAsStringAsync();
                    return Content(apiContent, "application/json");
                }
                return StatusCode((int)response.StatusCode, "Failed to update connection on the backend API.");
            }
            catch (HttpRequestException)
            {
                return StatusCode(503, "Backend API is unavailable.");
            }
        }
    }
}