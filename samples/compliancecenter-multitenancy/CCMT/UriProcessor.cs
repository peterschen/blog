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
    public static class UriProcessor
    {
        [FunctionName("UriProcessor")]
        public static async void Run(
            [QueueTrigger("uris", Connection = "SCCMT_STORAGE")]
            string data,
            ILogger log,
            Binder binder)
        {
            log.LogInformation($"Processing item '{data}'");
            string result = await RetrieveData(data);
            var json = JArray.Parse(result);

            log.LogInformation($"Item contains {json.Count} records");
            foreach (var record in json)
            {
                log.LogInformation($"Writing data to Queue");
                await WriteData(record.ToString(), binder);
            }
        }

        private static async Task<string> RetrieveData(string uri)
        {
            var clientId = Settings.ClientId;
            var clientSecret = Settings.ClientSecret;

            // await Common.GetOfficeAuthenticationHeader(clientId, clientSecret);
            await Common.GetStorageAuthenticationHeader(clientId, clientSecret);

            var response = await Common.http.GetAsync(uri);
            response.EnsureSuccessStatusCode();

            return await response.Content.ReadAsStringAsync();
        }

        private static string GetSetting(string name, bool isRequired = false)
        {
            var setting = Environment.GetEnvironmentVariable(name, EnvironmentVariableTarget.Process);

            if (isRequired && string.IsNullOrEmpty(setting))
            {
                throw new ArgumentNullException($"{name} is missing in Application Settings");
            }

            return string.IsNullOrEmpty(setting) ? null : setting;
        }

        private static async Task WriteData(string data, Binder binder)
        {
            var account = "SCCMT_STORAGE";
            var queue = "content";

            var attributes = new Attribute[]
            {
                new QueueAttribute(queue),
                new StorageAccountAttribute(account)
            };

            var output = await binder.BindAsync<CloudQueue>(attributes);
            await output.AddMessageAsync(new CloudQueueMessage(data));
        }
    }
}