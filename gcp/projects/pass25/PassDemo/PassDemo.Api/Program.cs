using PassDemo.Api.Data;
using Microsoft.EntityFrameworkCore;
using PassDemo.Api.Options;

var builder = WebApplication.CreateBuilder(args);

builder.Services.Configure<ConnectionStringsOptions>(
    builder.Configuration.GetSection(ConnectionStringsOptions.ConnectionStrings));

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

// We no longer register a DbContext here because it will be created manually in the controllers.
// Instead, we ensure the options for creating it are available.
builder.Services.AddDbContext<AddressDbContext>(options =>
{
    // Provide a dummy default configuration to satisfy DI requirements.
    // This context will NOT be used directly.
    options.UseSqlite("Data Source=dummy.db");
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
