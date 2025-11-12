using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using PassDemo.Api.Data;
using PassDemo.Common.Api.Models;
using PassDemo.Common.DTOs;
using PassDemo.Api.Options;
using System.Data.Common;
using System.Text.Json;
using Microsoft.Extensions.Options;

namespace PassDemo.Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class StatusController : ControllerBase
    {
        private readonly AddressDbContext _context;
        private readonly ActiveConnectionService _activeConnectionService; // Inject the singleton

        public StatusController(AddressDbContext context, ActiveConnectionService activeConnectionService)
        {
            _context = context;
            _activeConnectionService = activeConnectionService;
        }

        [HttpGet]
        public async Task<IActionResult> GetStatus()
        {
            var response = new Status();

            // Get the current state from the singleton service.
            response.ActiveConnectionName = _activeConnectionService.ActiveConnectionName;

            try
            {
                // CanConnectAsync() is the most reliable way to check connectivity.
                if (await _context.Database.CanConnectAsync())
                {
                    // If we can connect, set the state to Connected.
                    response.DatabaseState = DatabaseConnectionState.Connected;

                    DbConnection connection = _context.Database.GetDbConnection();
                    string provider = _context.Database.ProviderName ?? "N/A";
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
        public IActionResult UpdateActiveConnection([FromBody] ConnectionUpdateRequest request)
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

            // Return a success message.
            return Ok(new { message = $"In-memory active connection switched to {request.ConnectionName}. New requests will use this connection." });
        }
    }
}