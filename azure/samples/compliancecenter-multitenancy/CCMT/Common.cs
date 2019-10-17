using System;
using System.Net;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Threading.Tasks;
using Microsoft.IdentityModel.Clients.ActiveDirectory;

namespace CCMT
{
    public static class Common
    {
        public static HttpClient http = new HttpClient(
            new HttpClientHandler { AutomaticDecompression = DecompressionMethods.GZip | DecompressionMethods.Deflate }
        );

        public static AuthenticationContext authentication = new AuthenticationContext($"https://login.microsoftonline.com/{Settings.TenantId}");

        public static async Task GetAzureAuthenticationHeader(string clientId, string clientSecret)
        {
            await GetAuthenticationHeader(clientId, clientSecret, "https://management.azure.com");
        }

        public static async Task GetOfficeAuthenticationHeader(string clientId, string clientSecret)
        {
            await GetAuthenticationHeader(clientId, clientSecret, "https://manage.office.com");
        }

        public static async Task GetStorageAuthenticationHeader(string clientId, string clientSecret)
        {
            await GetAuthenticationHeader(clientId, clientSecret, "https://storage.azure.com/");
            http.DefaultRequestHeaders.Add("x-ms-version", "2017-11-09");
        }

        private static async Task GetAuthenticationHeader(string clientId, string clientSecret, string realm)
        {
            ResetHttpClient();
            var credential = new ClientCredential(clientId, clientSecret);
            var result = await Common.authentication.AcquireTokenAsync(realm, credential);
            http.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(result.AccessTokenType, result.AccessToken);
        }

        public static void ResetHttpClient()
        {
            Common.http.DefaultRequestHeaders.Clear();
            Common.http.DefaultRequestHeaders.Add("Accept", "application/json");
        }
    }
}