using PassDemo.Common.Models;
using Microsoft.EntityFrameworkCore;

namespace PassDemo.Api.Data
{
    public class PassDemoDbContext : DbContext
    {
        private readonly ILogger<PassDemoDbContext>? _logger;

        public PassDemoDbContext(DbContextOptions<PassDemoDbContext> options, ILogger<PassDemoDbContext>? logger = null) : base(options)
        {
            _logger = logger;
        }

        public DbSet<WeatherData> WeatherData { get; set; }
    }
}