using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

public class Program
{
    public static async Task Main(string[] args)
    {
        // Check for the presence of the command-line arguments.
        bool doBatch = args.Contains("--batch");
        bool doClean = args.Contains("--clean");
        bool doWait = args.Contains("--wait"); // The new flag for continuous mode
        string? targetEnvironment = null;

        for (int i = 0; i < args.Length; i++)
        {
            if (args[i].ToLower() == "--env" && i + 1 < args.Length)
            {
                targetEnvironment = args[i + 1].ToUpper();
            }
        }

        var builder = Host.CreateDefaultBuilder(args);
        builder.ConfigureServices((hostContext, services) =>
        {
            services.AddHttpClient("ApiClient", client =>
            {
                string? apiBaseUrl = hostContext.Configuration["ApiBaseUrl"];
                if (string.IsNullOrEmpty(apiBaseUrl)) throw new InvalidOperationException("ApiBaseUrl is not configured");
                client.BaseAddress = new Uri(apiBaseUrl);
            });

            services.AddTransient<BatchDataGenerator>();
            services.AddTransient<DatabaseCleaner>();
            services.AddTransient<WeatherDataProducer>();
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
        else if (doClean || doBatch || doWait) // Default to DEMO1 if an action is requested without --env
        {
            environmentsToProcess.Add("DEMO1");
        }

        // Get services from DI container
        var cleaner = host.Services.GetRequiredService<DatabaseCleaner>();
        var batchGenerator = host.Services.GetRequiredService<BatchDataGenerator>();

        // Preparatory Action: Cleaning
        if (doClean)
        {
            foreach (var env in environmentsToProcess)
            {
                Console.ForegroundColor = ConsoleColor.Cyan;
                Console.WriteLine($"--- Cleaning Environment: {env} ---");
                Console.ResetColor();
                await cleaner.RunAsync(env);
            }
        }

        // Main Execution Action
        if (doBatch)
        {
            foreach (var env in environmentsToProcess)
            {
                Console.ForegroundColor = ConsoleColor.Yellow;
                Console.WriteLine($"--- Running Batch For Environment: {env} ---");
                Console.ResetColor();
                await batchGenerator.RunAsync(env);
            }
            Console.WriteLine("Batch mode complete.");
        }
        else if (doWait) // Use --wait to trigger continuous mode
        {
            var tasks = new List<Task>();
            var cts = new CancellationTokenSource();
            Console.CancelKeyPress += (s, e) => { e.Cancel = true; cts.Cancel(); };

            Console.WriteLine($"Starting continuous producer threads for: {string.Join(", ", environmentsToProcess)}");
            
            foreach (var env in environmentsToProcess)
            {
                var producer = host.Services.GetRequiredService<WeatherDataProducer>();
                // The 'wait' parameter is removed from ExecuteAsync, it uses the default random delay.
                tasks.Add(Task.Run(() => producer.ExecuteAsync(env, cts.Token)));
            }

            await Task.WhenAll(tasks);
            Console.WriteLine("All producers have stopped. Application exiting.");
        }
        else if (!doClean)
        {
            // If no action flags were given at all, show help text.
            Console.WriteLine("No action specified. Please use --clean, --batch, or --wait.");
            Console.WriteLine("Optionally combine with --env [DEMO1|DEMO2|DEMO3|DEMO4|all].");
            Console.WriteLine("Example: dotnet run -- --env all --clean --batch");
        }
    }
}