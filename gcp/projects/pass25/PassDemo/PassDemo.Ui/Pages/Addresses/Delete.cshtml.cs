using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using PassDemo.Common.Models;

namespace PassDemo.Ui.Pages.Addresses
{
    public class DeleteModel : PageModel
    {
        private readonly IHttpClientFactory _httpClientFactory;

        public DeleteModel(IHttpClientFactory httpClientFactory)
        {
            _httpClientFactory = httpClientFactory;
        }

        [BindProperty]
        public Address Address { get; set; } = new();

        public async Task<IActionResult> OnGetAsync(int? id)
        {
            if (id == null)
            {
                return NotFound();
            }

            var client = _httpClientFactory.CreateClient("ApiClient");
            // Fetch the address details to display them for confirmation
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

            return NotFound();
        }

        public async Task<IActionResult> OnPostAsync()
        {
            var client = _httpClientFactory.CreateClient("ApiClient");

            // Call the API's DELETE endpoint
            var response = await client.DeleteAsync($"/api/addresses/{Address.Id}");

            if (response.IsSuccessStatusCode)
            {
                // On successful deletion, go back to the list
                return RedirectToPage("/Index");
            }
            
            // If deletion fails, show an error on the same page
            ModelState.AddModelError(string.Empty, "Could not delete the address. It may have already been removed.");
            return Page();
        }
    }
}
