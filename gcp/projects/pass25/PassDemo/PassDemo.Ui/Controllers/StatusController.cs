using Microsoft.AspNetCore.Mvc;

namespace PassDemo.Ui.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class StatusController : ControllerBase
    {
        private readonly IHttpClientFactory _httpClientFactory;
        public StatusController(IHttpClientFactory httpClientFactory) { _httpClientFactory = httpClientFactory; }

        [HttpGet("{environment}")]
        public async Task<IActionResult> GetStatus(string environment)
        {
            var client = _httpClientFactory.CreateClient("ApiClient");
            var response = await client.GetAsync($"/api/status/{environment}");
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