using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace PassDemo.Ui.Pages.Weather
{
    public class IndexModel : PageModel
    {
        [BindProperty(SupportsGet = true)]
        public DateTime StartDate { get; set; } = DateTime.UtcNow.AddHours(-24);

        [BindProperty(SupportsGet = true)]
        public DateTime EndDate { get; set; } = DateTime.UtcNow;

        public void OnGet()
        {
            // The default values are set in the property initializers.
            // If the user provides startDate/endDate in the query string, they will be bound automatically.
        }
    }
}