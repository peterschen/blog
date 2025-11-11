using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

public class Program
{
    public static async Task Main(string[] args)
    {
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

            // Register our producer as a background service that the host will manage.
            services.AddHostedService<WeatherDataProducer>();
        });

        // Build and run the host. This will start the WeatherDataProducer service.
        var host = builder.Build();
        await host.RunAsync();
    }
}