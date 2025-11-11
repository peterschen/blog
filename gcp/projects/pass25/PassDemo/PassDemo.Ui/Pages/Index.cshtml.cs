using Microsoft.AspNetCore.Mvc.RazorPages;
using PassDemo.Common.Models;

namespace PassDemo.Ui.Pages
{
    public class IndexModel : PageModel
    {
        private readonly IHttpClientFactory _httpClientFactory;
        public List<Address> Addresses { get; set; } = new();

        public IndexModel(IHttpClientFactory httpClientFactory)
        {
            _httpClientFactory = httpClientFactory;
        }

        public async Task OnGetAsync()
        {
            var client = _httpClientFactory.CreateClient("ApiClient");
            var response = await client.GetAsync("/api/addresses");
            if (response.IsSuccessStatusCode)
            {
                Addresses = await response.Content.ReadFromJsonAsync<List<Address>>() ?? new List<Address>();
            }
        }
    }
}
