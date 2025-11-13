using PassDemo.Common.Models;
using Microsoft.EntityFrameworkCore;

namespace PassDemo.Api.Data
{
    public class AddressDbContext : DbContext
    {
        private readonly ILogger<AddressDbContext>? _logger;

        public AddressDbContext(DbContextOptions<AddressDbContext> options, ILogger<AddressDbContext>? logger = null) : base(options)
        {
            _logger = logger;
        }

        public DbSet<Address> Addresses { get; set; }
        public DbSet<WeatherData> WeatherData { get; set; }
    }
}