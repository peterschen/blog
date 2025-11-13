using Microsoft.Extensions.Logging;
using PassDemo.Common.Models;
using System.Net.Http.Json;

public class BatchDataGenerator
{
    private readonly ILogger<BatchDataGenerator> _logger;
    private readonly IHttpClientFactory _httpClientFactory;
    private readonly Random _random = new();

    // These values will be used as a starting point for the batch generation.
    private double _lastTemperature = 5.0;
    private double _lastHumidity = 85.0;

    private const int BatchSize = 1000;

    public BatchDataGenerator(ILogger<BatchDataGenerator> logger, IHttpClientFactory httpClientFactory)
    {
        _logger = logger;
        _httpClientFactory = httpClientFactory;
    }

    public async Task RunAsync(string environment)
    {
        _logger.LogInformation("Starting batch data generation...");

        var allGeneratedData = new List<WeatherData>();

        var startTime = DateTime.UtcNow.AddMinutes(-60);
        var endTime = DateTime.UtcNow.AddHours(47);
        var currentTime = startTime;

        _logger.LogInformation("Generating data from {Start} to {End}", startTime, endTime);

        // Generate all data points first
        while (currentTime <= endTime)
        {
            _lastTemperature = GenerateNextValue(_lastTemperature, 0.15, -5.0, 15.0);
            allGeneratedData.Add(new WeatherData
            {
                Location = "Hamburg",
                Timestamp = new DateTimeOffset(currentTime).ToUnixTimeMilliseconds(),
                DataType = WeatherDataType.Temperature,
                Value = _lastTemperature
            });

            _lastHumidity = GenerateNextValue(_lastHumidity, 0.15, 65.0, 99.0);
            allGeneratedData.Add(new WeatherData
            {
                Location = "Hamburg",
                Timestamp = new DateTimeOffset(currentTime).ToUnixTimeMilliseconds(),
                DataType = WeatherDataType.Humidity,
                Value = _lastHumidity
            });

            currentTime = currentTime.AddSeconds(10);
        }

        _logger.LogInformation("Posting {Count} total data points to environment '{Environment}'...", allGeneratedData.Count, environment);

        var client = _httpClientFactory.CreateClient("ApiClient");

        for (int i = 0; i < allGeneratedData.Count; i += BatchSize)
        {
            var batch = allGeneratedData.Skip(i).Take(BatchSize).ToList();
            await SendBatchDataAsync(client, batch, environment, CancellationToken.None);
        }

        _logger.LogInformation("Batch data generation complete.");
    }

    // This logic is identical to the one in WeatherDataProducer
    private double GenerateNextValue(double previousValue, double maxChangePercent, double absoluteMin, double absoluteMax)
    {
        double changeFactor = (_random.NextDouble() * (maxChangePercent * 2)) - maxChangePercent;
        double nextValue = previousValue * (1 + changeFactor);
        double clampedValue = Math.Clamp(nextValue, absoluteMin, absoluteMax);
        return Math.Round(clampedValue, 1);
    }

    private async Task SendBatchDataAsync(HttpClient client, List<WeatherData> dataList, string environment, CancellationToken token)
    {
        if (!dataList.Any()) return;

        try
        {
            var response = await client.PostAsJsonAsync($"/api/weatherdata/batch/{environment}", dataList, token);

            if (response.IsSuccessStatusCode)
            {
                _logger.LogInformation("Batch: Successfully sent {Count} records.", dataList.Count);
            }
            else
            {
                _logger.LogWarning("Batch: Failed to send {Count} records. API responded with {StatusCode}.",
                    dataList.Count, response.StatusCode);
            }
        }
        catch (HttpRequestException ex)
        {
            _logger.LogError(ex, "Batch: HTTP request failed while sending {Count} records. Is the API running?", dataList.Count);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Batch: An unexpected error occurred while sending {Count} records.", dataList.Count);
        }
    }
}