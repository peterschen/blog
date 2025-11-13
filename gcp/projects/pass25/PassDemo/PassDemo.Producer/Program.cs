using System.Diagnostics;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

public class Program
{
    public static async Task Main(string[] args)
    {
        // Check for the presence of the command-line arguments.
        bool isBatchMode = args.Contains("--batch");
        bool isCleanMode = args.Contains("--clean");

        string? targetEnvironment = null;

        for (int i = 0; i < args.Length; i++)
        {
            if (args[i].ToLower() == "--env" && i + 1 < args.Length)
            {
                targetEnvironment = args[i + 1].ToUpper(); // Standardize to uppercase (DEMO1, etc.)
            }
        }

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
            services.AddTransient<EnvironmentSetter>();
            services.AddHostedService<WeatherDataProducer>();
        });

        // Build and run the host. This will start the WeatherDataProducer service.
        var host = builder.Build();

        var allDemos = new List<string> { "DEMO1", "DEMO2", "DEMO3", "DEMO4" };
        var environmentsToProcess = new List<string>();

        if ("ALL".Equals(targetEnvironment, StringComparison.OrdinalIgnoreCase))
        {
            environmentsToProcess.AddRange(allDemos);
        }
        else if (!string.IsNullOrEmpty(targetEnvironment))
        {
            environmentsToProcess.Add(targetEnvironment);
        }

        if (!isBatchMode && environmentsToProcess.Count > 1)
        {
            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine($"Spawning separate producer processes for all {environmentsToProcess.Count} environments...");
            Console.ResetColor();

            foreach (var env in environmentsToProcess)
            {
                var processStartInfo = new ProcessStartInfo
                {
                    FileName = "dotnet",
                    Arguments = $"run -- --env {env}" // Pass the specific environment flag
                };
                
                // If --clean was also specified, add it to the arguments for the child process
                if (isCleanMode)
                {
                    processStartInfo.Arguments += " --clean";
                }
                
                Console.WriteLine($"Starting continuous producer for {env}...");
                Process.Start(processStartInfo);
            }
            // The main process exits after launching the child processes.
            return;
        }

        // --- Standard Logic for Single-Target or Batch/Clean Operations ---
        var setter = host.Services.GetRequiredService<EnvironmentSetter>();
        var cleaner = host.Services.GetRequiredService<DatabaseCleaner>();
        var batchGenerator = host.Services.GetRequiredService<BatchDataGenerator>();

        // If a specific environment is targeted (single or "all" for batch/clean), loop through.
        if (environmentsToProcess.Any())
        {
            foreach (var env in environmentsToProcess)
            {
                Console.ForegroundColor = ConsoleColor.Cyan;
                Console.WriteLine($"--- Acting on Environment: {env} ---");
                Console.ResetColor();

                await setter.RunAsync(env);
                if (isCleanMode) await cleaner.RunAsync();
                if (isBatchMode) await batchGenerator.RunAsync();
            }

            if (isBatchMode || isCleanMode) return; // Exit after batch/clean
        }
        // If no specific environment was targeted, run actions on the current environment.
        else 
        {
            if (isCleanMode) await cleaner.RunAsync();
            if (isBatchMode) await batchGenerator.RunAsync();
        }
        
        // If neither batch nor clean mode was specified, or if only --env [single] was used,
        // run the default continuous mode for the current/selected environment.
        if (!isBatchMode && !isCleanMode)
        {
            await host.RunAsync();
        }
    }
}