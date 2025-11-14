using Microsoft.EntityFrameworkCore;
using PassDemo.Common.Models;

namespace PassDemo.Api.Data
{
    // Make the class abstract
    public abstract class DbContextBase : DbContext
    {
        public DbSet<WeatherData> WeatherData { get; set; }

        // This constructor will be called by the derived classes
        protected DbContextBase(DbContextOptions options) 
            : base(options)
        {
        }
    }
}