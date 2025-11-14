using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
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

        private async Task<PassDemoDbContext> CreateAndEnsureDbReadyAsync(string environment)
        {
            var optionsBuilder = new DbContextOptionsBuilder<PassDemoDbContext>();
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

            var context = new PassDemoDbContext(optionsBuilder.Options);

            try
            {
                // This is now the single place where this check is performed.
                await context.Database.MigrateAsync();
            }
            catch (Exception ex)
            {
                // Log the error with the connection string, as requested.
                _logger.LogError(ex, "Failed to ensure database was created for environment {Environment} with connection string: {ConnectionString}", environment, connectionString);
                // Re-throw the exception so the calling method knows something went wrong.
                throw;
            }

            return context;
        }

        [HttpGet("{environment}")]
        public async Task<ActionResult<IEnumerable<WeatherData>>> GetWeatherData(string environment, [FromQuery] long? startTimestamp, [FromQuery] long? endTimestamp, [FromQuery] WeatherDataType? dataType)
        {
            await using var context = await CreateAndEnsureDbReadyAsync(environment);
            await context.Database.EnsureCreatedAsync();

            long effectiveStart = startTimestamp ?? DateTimeOffset.UtcNow.AddHours(-24).ToUnixTimeMilliseconds();
            long effectiveEnd = endTimestamp ?? DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();

            var query = context.WeatherData.Where(wd => wd.Timestamp >= effectiveStart && wd.Timestamp <= effectiveEnd);
            if (dataType.HasValue) query = query.Where(wd => wd.DataType == dataType.Value);

            return await query.OrderBy(wd => wd.Timestamp).ToListAsync();
        }

        [HttpPost("{environment}")]
        public async Task<IActionResult> StoreWeatherData(string environment, [FromBody] WeatherData weatherData)
        {
            try
            {
                await using var context = await CreateAndEnsureDbReadyAsync(environment);
                await context.Database.EnsureCreatedAsync();
                context.WeatherData.Add(weatherData);
                await context.SaveChangesAsync();
                return CreatedAtAction(nameof(StoreWeatherData), new { id = weatherData.Id }, weatherData);
            }
            catch (Exception ex)
            {
                return StatusCode(500, $"Error: {ex.Message}");
            }
        }

        [HttpPost("batch/{environment}")]
        public async Task<IActionResult> StoreWeatherDataBatch(string environment, [FromBody] List<WeatherData> weatherDataList)
        {
            if (weatherDataList == null || !weatherDataList.Any()) return BadRequest("Batch is empty.");
            await using var context = await CreateAndEnsureDbReadyAsync(environment);
            await context.Database.EnsureCreatedAsync();
            context.WeatherData.AddRange(weatherDataList);
            await context.SaveChangesAsync();
            return Ok(new { message = $"{weatherDataList.Count} records submitted to {environment}." });
        }

        [HttpDelete("{environment}")]
        public async Task<IActionResult> DeleteAllWeatherData(string environment)
        {
            await using var context = await CreateAndEnsureDbReadyAsync(environment);
            await context.Database.EnsureCreatedAsync();
            await context.WeatherData.ExecuteDeleteAsync();
            return NoContent();
        }
    }
}