using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using PassDemo.Api.Data;
using PassDemo.Common.Models;

namespace PassDemo.Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class WeatherDataController : ControllerBase
    {
        private readonly AddressDbContext _context;

        public WeatherDataController(AddressDbContext context)
        {
            _context = context;
        }

        public async Task<ActionResult<IEnumerable<WeatherData>>> GetWeatherData(
            [FromQuery] long? startTimestamp,
            [FromQuery] long? endTimestamp,
            [FromQuery] WeatherDataType? dataType)
        {
            IQueryable<WeatherData> query = _context.WeatherData;

            // If no start date is provided, default to 24 hours ago.
            // If no end date is provided, default to now.
            long effectiveStartDateTimestamp = startTimestamp ?? DateTimeOffset.UtcNow.AddHours(-24).ToUnixTimeMilliseconds();
            long effectiveEndDateTimestamp = endTimestamp ?? DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();

            // Ensure the start date is not after the end date.
            if (effectiveStartDateTimestamp > effectiveEndDateTimestamp)
            {
                return Ok(new List<WeatherData>());
            }

            // Filter by date range
            query = query.Where(wd => wd.Timestamp >= effectiveStartDateTimestamp && wd.Timestamp <= effectiveEndDateTimestamp);

            // Filter by data type, if provided
            if (dataType.HasValue)
            {
                query = query.Where(wd => wd.DataType == dataType.Value);
            }

            return await query.OrderBy(wd => wd.Timestamp).ToListAsync();
        }

        [HttpPost]
        public async Task<IActionResult> StoreWeatherData([FromBody] WeatherData weatherData)
        {
            try
            {
                _context.WeatherData.Add(weatherData);
                await _context.SaveChangesAsync();
                return CreatedAtAction(nameof(StoreWeatherData), new { id = weatherData.Id }, weatherData);
            }
            catch (Exception ex)
            {
                return StatusCode(500, $"Error: {ex.Message}");
            }
        }

        [HttpPost("batch")]
        public async Task<IActionResult> StoreWeatherDataBatch([FromBody] List<WeatherData> weatherDataList)
        {
            if (weatherDataList == null || !weatherDataList.Any())
            {
                return BadRequest("Batch submission list cannot be empty.");
            }

            try
            {
                _context.WeatherData.AddRange(weatherDataList);
                await _context.SaveChangesAsync();
                return Ok(new { message = $"{weatherDataList.Count} weather data records submitted successfully." });
            }
            catch (Exception ex)
            {
                return StatusCode(500, $"Error: {ex.Message}");
            }
        }

        [HttpDelete]
        public async Task<IActionResult> DeleteAllWeatherData()
        {
            try
            {
                // ExecuteDeleteAsync() translates directly to a `DELETE FROM WeatherData` SQL command.
                // It's extremely efficient as it doesn't load any data into memory.
                await _context.WeatherData.ExecuteDeleteAsync();
                return NoContent();
            }
            catch (Exception ex)
            {
                return StatusCode(500, $"Error: {ex.Message}");
            }
        }
    }
}