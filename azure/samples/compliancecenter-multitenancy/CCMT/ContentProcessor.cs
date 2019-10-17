using System;
using System.Collections.Generic;
using System.IO;
using System.Net;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Security.Cryptography;
using System.Text;
using System.Threading.Tasks;
using Microsoft.Azure.WebJobs;
using Microsoft.Extensions.Logging;
using Microsoft.IdentityModel.Clients.ActiveDirectory;
using Microsoft.WindowsAzure.Storage.Queue;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace CCMT
{
    public static class ContentProcessor
    {
        private static string SettingTargetAccount = "CP_TARGETACCOUNT_";
        private static string SettingTargetQueue = "CP_TARGETQUEUE_";

        private static Dictionary<string, (string, string)> workspaces = new Dictionary<string, (string, string)>();

        [FunctionName("ContentProcessor")]
        public static async void Run(
            [QueueTrigger("content", Connection = "SCCMT_STORAGE")]
            string data,
            ILogger log,
            Binder binder)
        {
            log.LogInformation($"Processing item");

            var record = JObject.Parse(data);
            var user = record["UserId"].ToString();
            var domain = "none";

            log.LogInformation($"Processing record for {user}");

            if (user.IndexOf("@") > -1)
            {
                domain = user.Split('@')[1];
            }

            domain = CleanDomain(domain);

            var account = GetTargetAccount(domain);
            if (account == null)
            {
                if (!workspaces.ContainsKey(domain))
                {
                    log.LogInformation($"Workspace credentials not available in cache");
                    if (Settings.ContentProcessorDomains.Contains(domain))
                    {
                        // Retrieve workspace credentials and add to cache
                        // throws exeption if workspace was not found
                        log.LogInformation($"Retrieving workspace credentials through Azure REST API");
                        workspaces.Add(domain, await GetWorkspace(domain));
                    }
                    else
                    {
                        // Not a group domain, data should go to the default workspace
                        log.LogInformation($"Writing data to default Log Analytics workspace");
                        workspaces.Add(domain, (Settings.ContentProcessorWorkspaceId, Settings.ContentProcessorWorkspaceKey));
                    }
                }

                var workspace = workspaces[domain];
                log.LogInformation($"Writing data to Log Analytics workspace '{workspace.Item1}'");
                await PostData(workspace.Item1, workspace.Item2, domain, record.ToString());
            }
            else
            {
                log.LogInformation($"Writing data to Queue");
                await WriteData(domain, record.ToString(), binder);
            }
        }

        private static async Task<(string, string)> GetWorkspace(string domain)
        {
            var clientId = Settings.ClientId;
            var clientSecret = Settings.ClientSecret;
            var subscriptionId = Settings.SubscriptionId;
            var resourceGroupName = Settings.ResourceGroupName;
            var workspaceName = $"{Settings.ContentProcessorWorkspacePrefix}-{domain}";

            await Common.GetAzureAuthenticationHeader(clientId, clientSecret);

            var response = await Common.http.GetAsync($"https://management.azure.com/subscriptions/{subscriptionId}/resourcegroups/{resourceGroupName}/providers/Microsoft.OperationalInsights/workspaces/{workspaceName}?api-version=2015-11-01-preview");
            if (response.StatusCode == HttpStatusCode.NotFound)
            {
                throw new NotSupportedException($"Workspace {domain} has not been created yet");
            }

            var json = JObject.Parse(await response.Content.ReadAsStringAsync());
            string id = json["properties"]["customerId"].ToString();

            response = await Common.http.PostAsJsonAsync($"https://management.azure.com/subscriptions/{subscriptionId}/resourcegroups/{resourceGroupName}/providers/Microsoft.OperationalInsights/workspaces/{workspaceName}/sharedKeys?api-version=2015-03-20", "");
            response.EnsureSuccessStatusCode();

            json = JObject.Parse(await response.Content.ReadAsStringAsync());
            string key = json["primarySharedKey"].ToString();

            return (id, key);
        }

        private static async Task PostData(string id, string key, string domain, string data)
        {
            Common.ResetHttpClient();

            var date = DateTime.UtcNow.ToString("r");

            Common.http.DefaultRequestHeaders.Authorization = GetLogAnalyticsAuthenticationHeader(id, key, date, data);
            Common.http.DefaultRequestHeaders.Add("Log-Type", domain);
            Common.http.DefaultRequestHeaders.Add("x-ms-date", date);
            Common.http.DefaultRequestHeaders.Add("time-generated-field", "CreationTime");

            var content = new StringContent(data, Encoding.UTF8);
            content.Headers.ContentType = new MediaTypeHeaderValue("application/json");

            var response = await Common.http.PostAsync($"https://{id}.ods.opinsights.azure.com/api/logs?api-version=2016-04-01", content);
            response.EnsureSuccessStatusCode();
        }

        private static AuthenticationHeaderValue GetLogAnalyticsAuthenticationHeader(string id, string key, string date, string data)
        {
            string message = $"POST\n{Encoding.UTF8.GetBytes(data).Length}\napplication/json\nx-ms-date:{date}\n/api/logs";
            var keyBytes = Convert.FromBase64String(key);
            var payload = ASCIIEncoding.ASCII.GetBytes(message);
            using (var hmacsha256 = new HMACSHA256(keyBytes))
            {
                var signature = Convert.ToBase64String(hmacsha256.ComputeHash(payload));
                return new AuthenticationHeaderValue("SharedKey", $"{id}:{signature}");
            }
        }

        private static string GetTargetAccount(string domain)
        {
            return Settings.GetSetting($"{SettingTargetAccount}{domain}");
        }

        private static string GetTargetQueue(string domain)
        {
            return Settings.GetSetting($"{SettingTargetQueue}{domain}", true);
        }

        private static string CleanDomain(string domain)
        {
            return domain.Replace(".", "").Replace("-", "");
        }

        private static async Task WriteData(string domain, string data, Binder binder)
        {
            var queue = GetTargetQueue(domain);
            var attributes = new Attribute[]
            {
                new QueueAttribute(queue),
                new StorageAccountAttribute($"{SettingTargetAccount}{domain}")
            };

            var output = await binder.BindAsync<CloudQueue>(attributes);
            await output.AddMessageAsync(new CloudQueueMessage(data));
        }
    }
}