using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using ContosoUniversity.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Hosting;
using Microsoft.AspNetCore.Localization;
using System;

namespace ContosoUniversity
{
    public class Startup
    {
        public Startup(IConfiguration configuration)
        {
            Configuration = configuration;
        }

        public IConfiguration Configuration { get; }

        // This method gets called by the runtime. Use this method to add services to the container.
        public void ConfigureServices(IServiceCollection services)
        {
            Console.WriteLine($"DatabaseMode: {Configuration["DatabaseMode"]}");

            if(Configuration["DatabaseMode"] == "memory")
            {
                services.AddDbContext<SchoolContext>(options => options.UseInMemoryDatabase("university"));
            }
            else
            {
                var connectionString = Configuration.GetConnectionString(Configuration["DatabaseMode"]);

                // Append password for the connection string
                if(Configuration["DatabasePassword"] != "")
                {
                    connectionString = $"{connectionString}; Password={Configuration["DatabasePassword"]}";
                }

                Console.WriteLine($"connectionString: {connectionString}");
                services.AddDbContext<SchoolContext>(options => options.UseSqlServer(connectionString));
            }

            services.AddRazorPages();
        }

        // This method gets called by the runtime. Use this method to configure the HTTP request pipeline.
        public void Configure(IApplicationBuilder app, IWebHostEnvironment env)
        {
            if (env.IsDevelopment())
            {
                app.UseDeveloperExceptionPage();
            }
            else
            {
                app.UseExceptionHandler("/Home/Error");
                app.UseHsts();
            }

            // app.UseHttpsRedirection();
            app.UseStaticFiles();
            app.UseRouting();
            app.UseRequestLocalization(new RequestLocalizationOptions
            {
                DefaultRequestCulture = new RequestCulture("en-US")
            });

            app.UseEndpoints(endpoints => 
            {
                endpoints.MapControllerRoute(
                    name: "default",
                    pattern: "{controller=Home}/{action=Index}/{id?}"
                );
            });
        }
    }
}
