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

        public StatusController(IOptions<ConnectionStringsOptions> csOptions, IWebHostEnvironment env)
        {
            _csOptions = csOptions;
            _env = env;
        }

        private AddressDbContext CreateDbContextForEnvironment(string environment)
        {
            var optionsBuilder = new DbContextOptionsBuilder<AddressDbContext>();
            string connectionString = environment.ToUpper() switch 
            {
                "DEMO1" => _csOptions.Value.DEMO1,
                "DEMO2" => _csOptions.Value.DEMO2,
                "DEMO3" => _csOptions.Value.DEMO3,
                "DEMO4" => _csOptions.Value.DEMO4,
                _ => _csOptions.Value.DEMO1
            };
            if (_env.IsDevelopment()) optionsBuilder.UseSqlite(connectionString);
            else optionsBuilder.UseSqlServer(connectionString);
            return new AddressDbContext(optionsBuilder.Options);
        }

        [HttpGet("{environment}")]
        public async Task<IActionResult> GetStatus(string environment)
        {
            var response = new Status { ActiveConnectionName = environment };
            try
            {
                await using var context = CreateDbContextForEnvironment(environment);
                if (await context.Database.CanConnectAsync())
                {
                    response.DatabaseState = DatabaseConnectionState.Connected;
                    var connection = context.Database.GetDbConnection();
                    response.DatabaseServer = $"{connection.DataSource} ({connection.ServerVersion})";
                }
                else
                {
                    response.DatabaseState = DatabaseConnectionState.Disconnected;
                    response.DatabaseServer = "N/A";
                }
            }
            catch
            {
                response.DatabaseState = DatabaseConnectionState.Disconnected;
                response.DatabaseServer = "Error";
            }
            return Ok(response);
        }
    }
}