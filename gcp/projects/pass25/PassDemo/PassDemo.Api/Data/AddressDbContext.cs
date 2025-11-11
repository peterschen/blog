using PassDemo.Common.Models;
using Microsoft.EntityFrameworkCore;

namespace PassDemo.Api.Data
{
    public class AddressDbContext : DbContext
    {
        public AddressDbContext(DbContextOptions<AddressDbContext> options) : base(options)
        {
        }

        public DbSet<Address> Addresses { get; set; }
        public DbSet<WeatherData> WeatherData { get; set; }
    }
}