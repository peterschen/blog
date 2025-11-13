using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using PassDemo.Api.Data;
using PassDemo.Common.Api.Models;
using PassDemo.Common.DTOs;
using PassDemo.Api.Options;
using System.Data.Common;
using System.Text.Json;
using Microsoft.Extensions.Options;
using Microsoft.Extensions.DependencyInjection;

namespace PassDemo.Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class StatusController : ControllerBase
    {
        private readonly ActiveConnectionService _activeConnectionService; // Inject the singleton
        private readonly IServiceProvider _serviceProvider; // Inject IServiceProvider

        public StatusController(ActiveConnectionService activeConnectionService, IServiceProvider serviceProvider)
        {
            _activeConnectionService = activeConnectionService;
            _serviceProvider = serviceProvider;
        }

        [HttpGet]
        public async Task<IActionResult> GetStatus()
        {
            var response = new Status();

            // Get the current state from the singleton service.
            response.ActiveConnectionName = _activeConnectionService.ActiveConnectionName;

            try
            {
                await using var scope = _serviceProvider.CreateAsyncScope();
                var context = scope.ServiceProvider.GetRequiredService<AddressDbContext>();

                // CanConnectAsync() is the most reliable way to check connectivity.
                if (await context.Database.CanConnectAsync())
                {
                    // If we can connect, set the state to Connected.
                    response.DatabaseState = DatabaseConnectionState.Connected;

                    DbConnection connection = context.Database.GetDbConnection();
                    string provider = context.Database.ProviderName ?? "N/A";
                    string server = $"({connection.DataSource}, {connection.ServerVersion})";

                    if (provider.Contains("SqlServer"))
                    {
                        response.DatabaseServer = $"SQL Server {server}";
                    }
                    else if (provider.Contains("Sqlite"))
                    {
                        response.DatabaseServer = $"SQLite {server}";
                    }
                    else
                    {
                        response.DatabaseServer = provider;
                    }
                }
                else
                {
                    // If we can't connect, set the state to Disconnected.
                    response.DatabaseState = DatabaseConnectionState.Disconnected;
                    response.DatabaseServer = string.Empty;
                }
            }
            catch
            {
                // If any exception occurs, we are disconnected.
                response.DatabaseState = DatabaseConnectionState.Disconnected;
                response.DatabaseServer = "Error"; // Indicate an error condition.
            }

            return Ok(response);
        }
    
        [HttpPost("connection")]
        public async Task<IActionResult> UpdateActiveConnection([FromBody] ConnectionUpdateRequest request)
        {
            if (string.IsNullOrEmpty(request.ConnectionName))
            {
                return BadRequest("ConnectionName cannot be empty.");
            }

            var validNames = new[] { "DEMO1", "DEMO2", "DEMO3", "DEMO4" };
            if (!validNames.Contains(request.ConnectionName))
            {
                return BadRequest("Invalid ConnectionName specified.");
            }

            // Update the in-memory state in the singleton service.
            _activeConnectionService.SetActiveConnection(request.ConnectionName);

            try
            {
                // 2. Create a new DI scope.
                // We use CreateAsyncScope for compatibility with async disposal.
                await using var scope = _serviceProvider.CreateAsyncScope();
                
                // 3. Resolve a new DbContext instance from this scope.
                // It will be created with the new connection string because it reads from the updated singleton.
                var dbContextForValidation = scope.ServiceProvider.GetRequiredService<AddressDbContext>();
                
                // 4. Ensure the newly selected database exists and its schema is created.
                await dbContextForValidation.Database.EnsureCreatedAsync();
            }
            catch (Exception ex)
            {
                // If creating the new database fails (e.g., bad connection string, permissions issue),
                // we should inform the client.
                return StatusCode(500, $"Connection state was switched to {request.ConnectionName}, but an error occurred while ensuring database creation: {ex.Message}");
            }

            // Return a success message.
            return Ok(new { message = $"In-memory active connection switched to {request.ConnectionName}. New requests will use this connection." });
        }
    }
}