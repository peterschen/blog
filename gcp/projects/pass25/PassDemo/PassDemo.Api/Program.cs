using PassDemo.Api.Data;
using Microsoft.EntityFrameworkCore;
using PassDemo.Api.Options;
using Microsoft.Extensions.Options;

var builder = WebApplication.CreateBuilder(args);

builder.Services.Configure<ConnectionStringsOptions>(
    builder.Configuration.GetSection(ConnectionStringsOptions.ConnectionStrings));

builder.Services.AddSingleton<ActiveConnectionService>();

// Define a CORS policy
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader();
    });
});

// Add services to the container.
builder.Services.AddDbContext<AddressDbContext>((serviceProvider, options) =>
{
    var csOptions = serviceProvider.GetRequiredService<IOptions<ConnectionStringsOptions>>().Value;
    var activeConnectionService = serviceProvider.GetRequiredService<ActiveConnectionService>();
    
    // Get the current active connection name from the singleton service.
    string activeConnectionName = activeConnectionService.ActiveConnectionName;

    string connectionString = activeConnectionName switch
    {
        "DEMO2" => connectionString = csOptions.DEMO2,
        "DEMO3" => connectionString = csOptions.DEMO3,
        "DEMO4" => connectionString = csOptions.DEMO4,
        _ => connectionString = csOptions.DEMO1
    };

    if (builder.Environment.IsDevelopment())
    {
        // Use SQLite in development
        Console.WriteLine("Using SQLite for development.");
        options.UseSqlite(connectionString);
    }
    else
    {
        // Use SQL Server in production or other environments
        Console.WriteLine("Using SQL Server.");
        options.UseSqlServer(connectionString);
    }
});
builder.Services.AddControllers();

// Learn more about configuring OpenAPI at https://aka.ms/aspnet/openapi
builder.Services.AddOpenApi();

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.UseHttpsRedirection();
app.UseCors();
app.UseAuthorization();
app.MapControllers();
app.Run();
