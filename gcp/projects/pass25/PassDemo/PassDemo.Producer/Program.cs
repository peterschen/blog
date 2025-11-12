using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

public class Program
{
    public static async Task Main(string[] args)
    {
        // Check for the presence of the command-line arguments.
        bool isBatchMode = args.Contains("--batch");
        bool isCleanMode = args.Contains("--clean");

        var builder = Host.CreateDefaultBuilder(args);

        builder.ConfigureServices((hostContext, services) =>
        {
            // Configure the HttpClient to communicate with our API
            services.AddHttpClient("ApiClient", client =>
            {
                string? apiBaseUrl = hostContext.Configuration["ApiBaseUrl"];
                if (string.IsNullOrEmpty(apiBaseUrl))
                {
                    throw new InvalidOperationException("ApiBaseUrl is not configured in appsettings.json");
                }
                client.BaseAddress = new Uri(apiBaseUrl);
            });

            services.AddTransient<BatchDataGenerator>();
            services.AddTransient<DatabaseCleaner>();
            services.AddHostedService<WeatherDataProducer>();
        });

        // Build and run the host. This will start the WeatherDataProducer service.
        var host = builder.Build();
        if (isCleanMode)
        {
            // For clean mode, resolve the cleaner and run its single operation.
            var cleaner = host.Services.GetRequiredService<DatabaseCleaner>();
            await cleaner.RunAsync();
        }
        else if (isBatchMode)
        {
            // For batch mode, we get the generator service from the DI container...
            var batchGenerator = host.Services.GetRequiredService<BatchDataGenerator>();
            await batchGenerator.RunAsync();
        }
        else
        {
            // For continuous mode, we run the host, which starts the WeatherDataProducer
            // and keeps the application alive.
            await host.RunAsync();
        }
    }
}