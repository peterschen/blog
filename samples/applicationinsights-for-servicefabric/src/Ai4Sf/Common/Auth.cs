using System;
using System.Threading.Tasks;
using Microsoft.IdentityModel.Clients.ActiveDirectory;

namespace Ai4Sf.Common
{
    public sealed class Auth
    {
        public static async Task<string> GetToken(string tenantId, string appId, string password, string resourceId)
        {
            string context = $"https://login.windows.net/{tenantId}";
            var authenticationContext = new AuthenticationContext(context);
            var credential = new ClientCredential(clientId: appId, clientSecret: password);
            var result = await authenticationContext.AcquireTokenAsync(resourceId, credential);
            return result.AccessToken;
        }
    }
}