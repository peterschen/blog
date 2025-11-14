using Microsoft.EntityFrameworkCore;

namespace PassDemo.Api.Data
{
    public class SqlDbContext : DbContextBase
    {
        public SqlDbContext(DbContextOptions<SqlDbContext> options) 
            : base(options)
        {
        }
    }
}