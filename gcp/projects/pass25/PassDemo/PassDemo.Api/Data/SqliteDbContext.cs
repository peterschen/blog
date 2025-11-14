using Microsoft.EntityFrameworkCore;

namespace PassDemo.Api.Data
{
    public class SqliteDbContext : DbContextBase
    {
        public SqliteDbContext(DbContextOptions<SqliteDbContext> options) 
            : base(options)
        {
        }
    }
}