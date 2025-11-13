using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using PassDemo.Common.Models;
using System.Net.Http.Json;

public class WeatherDataProducer
{
    private readonly ILogger<WeatherDataProducer> _logger;
    private readonly IHttpClientFactory _httpClientFactory;
    private readonly Random _random = new();

    private double _lastTemperature;
    private double _lastHumidity;

    public WeatherDataProducer(ILogger<WeatherDataProducer> logger, IHttpClientFactory httpClientFactory)
    {
        _logger = logger;
        _httpClientFactory = httpClientFactory;

        // Initialize with realiic baseline values for Hamburg in November.
        _lastTemperature = 5.0; 
        _lastHumidity = 85.0;
    }

    public async Task ExecuteAsync(string environment, CancellationToken stoppingToken)
    {
        _logger.LogInformation("Continuous producer starting for environment '{Environment}'.", environment);

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                // --- Generate and Send Temperature Data ---
                _lastTemperature = GenerateNextValue(_lastTemperature, 0.15, -5.0, 15.0); // Absolute min/max as a safety rail
                var tempData = new WeatherData
                {
                    Location = "Hamburg",
                    Timestamp = new DateTimeOffset(DateTime.UtcNow).ToUnixTimeMilliseconds(),
                    DataType = WeatherDataType.Temperature,
                    Value = _lastTemperature
                };
                await SendDataAsync(tempData, environment,stoppingToken);

                // --- Generate and Send Humidity Data ---
                _lastHumidity = GenerateNextValue(_lastHumidity, 0.15, 65.0, 99.0); // Absolute min/max
                var humidityData = new WeatherData
                {
                    Location = "Hamburg",
                    Timestamp = new DateTimeOffset(DateTime.UtcNow).ToUnixTimeMilliseconds(),
                    DataType = WeatherDataType.Humidity,
                    Value = _lastHumidity
                };
                await SendDataAsync(humidityData, environment, stoppingToken);

            }
            catch (Exception ex) when (ex is not OperationCanceledException)
            {
                _logger.LogError(ex, "An unexpected error occurred in the producer loop.");
            }

            int delaySeconds = 10;
            _logger.LogInformation("Next data submission in {Delay} seconds.", delaySeconds);
            await Task.Delay(TimeSpan.FromSeconds(delaySeconds), stoppingToken);
        }

        _logger.LogInformation("Weather Data Producer stopping.");
    }

    private double GenerateNextValue(double previousValue, double maxChangePercent, double absoluteMin, double absoluteMax)
    {
        // Calculate the change factor, e.g., a random number between -0.15 and +0.15
        double changeFactor = (_random.NextDouble() * (maxChangePercent * 2)) - maxChangePercent;

        // Calculate the new value
        double nextValue = previousValue * (1 + changeFactor);

        // Clamp the value to ensure it stays within the absolute realistic bounds and round it.
        double clampedValue = Math.Clamp(nextValue, absoluteMin, absoluteMax);
        
        return Math.Round(clampedValue, 1);
    }

    private async Task SendDataAsync(WeatherData data, string environment, CancellationToken token)
    {
        var client = _httpClientFactory.CreateClient("ApiClient");

        try
        {
            var response = await client.PostAsJsonAsync($"/api/weatherdata/{environment}", data, token);

            if (response.IsSuccessStatusCode)
            {
                _logger.LogInformation("Successfully sent {DataType} data: {Value}", data.DataType, data.Value);
            }
            else
            {
                _logger.LogWarning("Failed to send {DataType} data. API responded with {StatusCode}.", data.DataType, response.StatusCode);
            }
        }
        catch (HttpRequestException ex)
        {
            _logger.LogError(ex, "HTTP request failed while sending {DataType} data. Is the API running?", data.DataType);
        }
    }
}