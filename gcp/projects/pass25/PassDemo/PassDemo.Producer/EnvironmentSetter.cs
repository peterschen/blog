using Microsoft.Extensions.Logging;
using PassDemo.Common.DTOs; // We need this for the ConnectionUpdateRequest DTO
using System.Net.Http;
using System.Net.Http.Json;
using System.Threading.Tasks;

public class EnvironmentSetter
{
    private readonly ILogger<EnvironmentSetter> _logger;
    private readonly IHttpClientFactory _httpClientFactory;

    public EnvironmentSetter(ILogger<EnvironmentSetter> logger, IHttpClientFactory httpClientFactory)
    {
        _logger = logger;
        _httpClientFactory = httpClientFactory;
    }

    /// <summary>
    /// Calls the API to set the active database connection environment.
    /// </summary>
    /// <param name="environmentName">The name of the environment to switch to (e.g., "DEMO1").</param>
    public async Task RunAsync(string environmentName)
    {
        _logger.LogInformation("Attempting to set active environment to '{EnvironmentName}' via API...", environmentName);

        var client = _httpClientFactory.CreateClient("ApiClient");

        try
        {
            var request = new ConnectionUpdateRequest { ConnectionName = environmentName };
            
            // Make a POST request to the API's status/connection endpoint
            var response = await client.PostAsJsonAsync("/api/status/connection", request);

            if (response.IsSuccessStatusCode)
            {
                var responseBody = await response.Content.ReadAsStringAsync();
                _logger.LogInformation("Successfully set environment. API response: {Response}", responseBody);
            }
            else
            {
                _logger.LogError("Failed to set environment. API responded with status code: {StatusCode}", response.StatusCode);
            }
        }
        catch (HttpRequestException ex)
        {
            _logger.LogError(ex, "HTTP request to set environment failed. Is the API running?");
        }
    }
}