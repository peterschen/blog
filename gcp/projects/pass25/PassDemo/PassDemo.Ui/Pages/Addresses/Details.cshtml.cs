using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using PassDemo.Common.Models;

namespace PassDemo.Ui.Pages.Addresses
{
    public class DetailsModel : PageModel
    {
        private readonly IHttpClientFactory _httpClientFactory;

        public DetailsModel(IHttpClientFactory httpClientFactory)
        {
            _httpClientFactory = httpClientFactory;
        }

        // This property will hold the address data fetched from the API to be displayed on the page.
        public Address Address { get; set; } = new();

        // OnGetAsync is called when the page is requested with an ID in the URL.
        public async Task<IActionResult> OnGetAsync(int? id)
        {
            // If no ID is provided in the URL, the request is invalid.
            if (id == null)
            {
                return NotFound();
            }

            var client = _httpClientFactory.CreateClient("ApiClient");
            try
            {
                // Make a GET request to the API for the specific address.
                var response = await client.GetAsync($"/api/addresses/{id}");

                if (response.IsSuccessStatusCode)
                {
                    // If the API returns a successful response, deserialize the JSON into our Address model.
                    var address = await response.Content.ReadFromJsonAsync<Address>();
                    
                    // If deserialization results in a null object (e.g., empty response body), treat it as not found.
                    if (address == null)
                    {
                        return NotFound();
                    }
                    
                    Address = address;
                    return Page(); // Render the page with the fetched data.
                }
                else
                {
                    // If the API returns a non-success status code (like 404), return a Not Found result.
                    return NotFound();
                }
            }
            catch
            {
                // If there's an exception (e.g., the API is not running), redirect to a generic error page.
                return RedirectToPage("/Error");
            }
        }
    }
}
