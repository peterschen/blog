using Microsoft.Extensions.Logging;
using System.Net.Http;
using System.Threading.Tasks;

public class DatabaseCleaner
{
    private readonly ILogger<DatabaseCleaner> _logger;
    private readonly IHttpClientFactory _httpClientFactory;

    public DatabaseCleaner(ILogger<DatabaseCleaner> logger, IHttpClientFactory httpClientFactory)
    {
        _logger = logger;
        _httpClientFactory = httpClientFactory;
    }

    /// <summary>
    /// Calls the API to clear all weather data.
    /// </summary>
    public async Task RunAsync(string environment)
    {
        _logger.LogInformation("Attempting to clear all weather data via API...");

        var client = _httpClientFactory.CreateClient("ApiClient");

        try
        {
            // Make a DELETE request to the root of the weatherdata endpoint.
            var response = await client.DeleteAsync($"/api/weatherdata/{environment}");

            if (response.IsSuccessStatusCode)
            {
                _logger.LogInformation("Successfully received confirmation from API. Weather data has been cleared.");
            }
            else
            {
                _logger.LogError("Failed to clear weather data. API responded with status code: {StatusCode}", response.StatusCode);
            }
        }
        catch (HttpRequestException ex)
        {
            _logger.LogError("HTTP request failed data: {Message}", ex.Message);
        }
    }
}