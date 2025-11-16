using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Storage;
using Microsoft.Extensions.Options;
using PassDemo.Api.Data;
using PassDemo.Api.Options;
using PassDemo.Common.Models;

namespace PassDemo.Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class WeatherDataController : ControllerBase
    {
        private readonly IOptions<ConnectionStringsOptions> _csOptions;
        private readonly IWebHostEnvironment _env;
        private readonly ILogger<WeatherDataController> _logger;

        public WeatherDataController(IOptions<ConnectionStringsOptions> csOptions, IWebHostEnvironment env, ILogger<WeatherDataController> logger)
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
                var exists = context.Database.GetService<IRelationalDatabaseCreator>().Exists();
                if(_env.IsDevelopment() || exists)
                {
                    await context.Database.MigrateAsync();
                }
                else
                {
                    _logger.LogInformation("Not applying migrations (IsDevelopment={Environment}; Database.Exists={exists})", _env.IsDevelopment(), exists);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError("Failed to create tables for environment {Environment} with connection string: {ConnectionString}: {Exception}", environment, connectionString, ex.Message);
            }

            return context;
        }

        [HttpGet("{environment}")]
        public async Task<ActionResult<IEnumerable<WeatherData>>> GetWeatherData(string environment, [FromQuery] long? startTimestamp, [FromQuery] long? endTimestamp, [FromQuery] WeatherDataType? dataType)
        {
            try
            {
                await using var context = await CreateAndEnsureDbReadyAsync(environment);
                if(context == null) return Problem();

                long effectiveStart = startTimestamp ?? DateTimeOffset.UtcNow.AddHours(-24).ToUnixTimeMilliseconds();
                long effectiveEnd = endTimestamp ?? DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();

                var query = context.WeatherData.Where(wd => wd.Timestamp >= effectiveStart && wd.Timestamp <= effectiveEnd);
                if (dataType.HasValue) query = query.Where(wd => wd.DataType == dataType.Value);

                return await query.OrderBy(wd => wd.Timestamp).ToListAsync();
            }
            catch(Exception e)
            {
                return Problem(e.Message);
            }
        }

        [HttpPost("{environment}")]
        public async Task<IActionResult> StoreWeatherData(string environment, [FromBody] WeatherData weatherData)
        {
            try
            {
                await using var context = await CreateAndEnsureDbReadyAsync(environment);
                if(context == null) return Problem();
                context.WeatherData.Add(weatherData);
                await context.SaveChangesAsync();
                return CreatedAtAction(nameof(StoreWeatherData), new { id = weatherData.Id }, weatherData);
            }
            catch (Exception e)
            {
                return Problem(e.Message);
            }
        }

        [HttpPost("batch/{environment}")]
        public async Task<IActionResult> StoreWeatherDataBatch(string environment, [FromBody] List<WeatherData> weatherDataList)
        {
            if (weatherDataList == null || !weatherDataList.Any()) return BadRequest("Batch is empty.");
            await using var context = await CreateAndEnsureDbReadyAsync(environment);
            if(context == null) return Problem();
            context.WeatherData.AddRange(weatherDataList);
            await context.SaveChangesAsync();
            return Ok(new { message = $"{weatherDataList.Count} records submitted to {environment}." });
        }

        [HttpDelete("{environment}")]
        public async Task<IActionResult> DeleteAllWeatherData(string environment)
        {
            await using var context = await CreateAndEnsureDbReadyAsync(environment);
            if(context == null) return Problem();
            await context.WeatherData.ExecuteDeleteAsync();
            return NoContent();
        }
    }
}