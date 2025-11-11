using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PassDemo.Api.Migrations
{
    /// <inheritdoc />
    public partial class ChangeWeatherDataDateToTimestamp : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.RenameColumn(
                name: "Date",
                table: "WeatherData",
                newName: "Timestamp");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.RenameColumn(
                name: "Timestamp",
                table: "WeatherData",
                newName: "Date");
        }
    }
}
