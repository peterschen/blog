using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using PassDemo.Common.Models;
using System.Text.Json;

namespace PassDemo.Ui.Pages.Addresses
{
    public class CreateModel : PageModel
    {
        private readonly IHttpClientFactory _httpClientFactory;

        public CreateModel(IHttpClientFactory httpClientFactory)
        {
            _httpClientFactory = httpClientFactory;
        }

        // The [BindProperty] attribute is crucial. It tells ASP.NET Core to take the
        // form data from the POST request and map it to this Address property.
        [BindProperty]
        public Address Address { get; set; } = new();

        // This method handles the initial GET request. It does nothing but
        // display the empty form, which is the default behavior.
        public void OnGet()
        {
        }

        // This method handles the POST request when the user submits the form.
        public async Task<IActionResult> OnPostAsync()
        {
            // First, check for any client-side validation errors based on the model's data annotations (if any).
            if (!ModelState.IsValid)
            {
                // If there are errors, simply show the page again.
                // The validation tag helpers in the .cshtml file will display the errors.
                return Page();
            }

            try
            {
                var client = _httpClientFactory.CreateClient("ApiClient");

                // Call the POST endpoint of your API, sending the new address data as JSON.
                var response = await client.PostAsJsonAsync("/api/addresses", Address);

                // If the API confirms the creation was successful...
                if (response.IsSuccessStatusCode)
                {
                    // ...redirect the user back to the main list page.
                    return RedirectToPage("/Index");
                }
                else
                {
                    // If the API returns an error, add a model error to display to the user.
                    ModelState.AddModelError(string.Empty, "An error occurred while communicating with the API.");
                    return Page();
                }
            }
            catch (Exception ex)
            {
                // If there's a network or other exception, log it and inform the user.
                ModelState.AddModelError(string.Empty, $"An unexpected error occurred: {ex.Message}");
                return Page();
            }
        }
    }
}
