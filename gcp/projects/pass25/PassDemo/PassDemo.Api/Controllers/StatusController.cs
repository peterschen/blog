using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using PassDemo.Api.Data;
using PassDemo.Common.Api.Models;
using PassDemo.Api.Options;
using Microsoft.Extensions.Options;

namespace PassDemo.Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class StatusController : ControllerBase
    {
        private readonly IOptions<ConnectionStringsOptions> _csOptions;
        private readonly IWebHostEnvironment _env;
        private readonly ILogger<StatusController> _logger;

        public StatusController(IOptions<ConnectionStringsOptions> csOptions, IWebHostEnvironment env, ILogger<StatusController> logger)
        {
            _csOptions = csOptions;
            _env = env;
            _logger = logger;
        }

        private async Task<DbContextBase> CreateAndEnsureDbReadyAsync(string environment)
        {
            string connectionString = environment.ToUpper() switch 
            {
                "DEMO1" => _csOptions.Value.DEMO1,
                "DEMO2" => _csOptions.Value.DEMO2,
                "DEMO3" => _csOptions.Value.DEMO3,
                "DEMO4" => _csOptions.Value.DEMO4,
                _ => _csOptions.Value.DEMO1
            };

            DbContextBase context;

            // Decide which DbContext to instantiate based on the environment
            if (_env.IsDevelopment())
            {
                var optionsBuilder = new DbContextOptionsBuilder<SqliteDbContext>().UseSqlite(connectionString);
                context = new SqliteDbContext(optionsBuilder.Options);
            }
            else
            {
                var optionsBuilder = new DbContextOptionsBuilder<SqlDbContext>().UseSqlServer(connectionString);
                context = new SqlDbContext(optionsBuilder.Options);
            }

            try
            {
                await context.Database.MigrateAsync();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to ensure database was created for environment {Environment} with connection string: {ConnectionString}", environment, connectionString);
                throw;
            }

            return context;
        }

        [HttpGet("{environment}")]
        public async Task<IActionResult> GetStatus(string environment)
        {
            var response = new Status { ActiveConnectionName = environment, DatabaseState = DatabaseConnectionState.Disconnected, DatabaseServer = string.Empty};
            await using var context = await CreateAndEnsureDbReadyAsync(environment);

            try
            {
                if (await context.Database.CanConnectAsync())
                {
                    response.DatabaseState = DatabaseConnectionState.Connected;
                    var connection = context.Database.GetDbConnection();
                    string provider = context.Database.ProviderName ?? "N/A";
                    
                    if (provider.Contains("SqlServer"))
                    {
                        await context.Database.OpenConnectionAsync();
                        response.DatabaseServer = $"{connection.DataSource} / {await context.Database.SqlQueryRaw<string>("SELECT SERVERPROPERTY('ComputerNamePhysicalNetBIOS') AS Value").FirstOrDefaultAsync()}";
                    }
                    else
                    {
                        response.DatabaseServer = $"{connection.DataSource}";
                    }
                }
            }
            catch(Exception e)
            {
                _logger.LogError(e, "Error getting status for environment {Environment}", environment);
                response.DatabaseState = DatabaseConnectionState.Failed;
                response.DatabaseServer = string.Empty;
            }
            finally
            {
                await context.Database.CloseConnectionAsync();        
            }
            return Ok(response);
        }
    }
}