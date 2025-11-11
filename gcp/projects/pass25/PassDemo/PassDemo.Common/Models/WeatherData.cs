using System.ComponentModel.DataAnnotations;

namespace PassDemo.Common.Models
{
    public class WeatherData
    {
        [Key]
        public int Id { get; set; }

        [Required]
        public string Location { get; set; } = string.Empty;

        [Required]
        public long Timestamp { get; set; }

        [Required]
        public WeatherDataType DataType { get; set; }

        [Required]
        public double Value { get; set; }
    }
}