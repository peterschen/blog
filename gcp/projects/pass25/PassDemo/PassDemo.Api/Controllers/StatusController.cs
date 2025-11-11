using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using PassDemo.Api.Data;
using PassDemo.Common.Api.Models;
using System.Data.Common;

namespace PassDemo.Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class StatusController : ControllerBase
    {
        private readonly AddressDbContext _context;

        public StatusController(AddressDbContext context)
        {
            _context = context;
        }

        [HttpGet]
        public async Task<IActionResult> GetStatus()
        {
            var response = new Status();

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
    }
}