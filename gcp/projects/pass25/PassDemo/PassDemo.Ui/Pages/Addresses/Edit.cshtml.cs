using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using PassDemo.Common.Models;

namespace PassDemo.Ui.Pages.Addresses
{
    public class EditModel : PageModel
    {
        private readonly IHttpClientFactory _httpClientFactory;

        public EditModel(IHttpClientFactory httpClientFactory)
        {
            _httpClientFactory = httpClientFactory;
        }

        [BindProperty]
        public Address Address { get; set; } = new();

        // OnGetAsync is called when the page is first loaded.
        // It fetches the address data to pre-fill the form.
        public async Task<IActionResult> OnGetAsync(int? id)
        {
            if (id == null)
            {
                return NotFound();
            }

            var client = _httpClientFactory.CreateClient("ApiClient");
            try
            {
                // Call the API's GET endpoint for a single address
                var response = await client.GetAsync($"/api/addresses/{id}");

                if (response.IsSuccessStatusCode)
                {
                    var address = await response.Content.ReadFromJsonAsync<Address>();
                    if (address == null)
                    {
                        return NotFound();
                    }
                    Address = address;
                    return Page();
                }
                else
                {
                    // Handle cases where the API returns an error (e.g., 404 Not Found)
                    return NotFound();
                }
            }
            catch
            {
                // Handle exceptions (e.g., API is down)
                return RedirectToPage("/Error");
            }
        }

        // OnPostAsync is called when the user submits the edited form.
        public async Task<IActionResult> OnPostAsync()
        {
            if (!ModelState.IsValid)
            {
                return Page();
            }

            var client = _httpClientFactory.CreateClient("ApiClient");
            try
            {
                // Call the API's PUT endpoint to update the address
                var response = await client.PutAsJsonAsync($"/api/addresses/{Address.Id}", Address);

                if (response.IsSuccessStatusCode)
                {
                    return RedirectToPage("/Index");
                }
                else
                {
                    ModelState.AddModelError(string.Empty, "An error occurred while updating the address via the API.");
                    return Page();
                }
            }
            catch (Exception ex)
            {
                ModelState.AddModelError(string.Empty, $"An unexpected error occurred: {ex.Message}");
                return Page();
            }
        }
    }
}
