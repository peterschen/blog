
using Ai4Sf.Common.Models;
using Microsoft.EntityFrameworkCore;

namespace Ai4Sf.TelemetryApi.Models
{
    public class TelemetryContext : DbContext
    {
        public TelemetryContext(DbContextOptions<TelemetryContext> options)
            : base(options)
        {
        }
        
        public DbSet<TelemetryItem> TelemetryItems { get; set; }
    }
}