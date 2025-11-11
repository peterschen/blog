using System.ComponentModel.DataAnnotations;

namespace PassDemo.Common.Models
{
    public class Address
    {
        public int Id { get; set; }

        [Required]
        public string Name { get; set; } = string.Empty;

        [Required]
        public string Surname { get; set; } = string.Empty;

        [Required]
        public string Street { get; set; } = string.Empty;
        
        [Required]
        public string City { get; set; } = string.Empty;
        
        public string? State { get; set; }
        
        [Required]
        public string ZipCode { get; set; } = string.Empty;
    }
}
