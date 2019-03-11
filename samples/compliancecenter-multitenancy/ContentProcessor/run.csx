#r "Microsoft.WindowsAzure.Storage"
#r "Newtonsoft.Json"

using System;
using System.Net;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Security.Cryptography;
using System.Text;
using Microsoft.Azure.WebJobs;
using Microsoft.WindowsAzure.Storage.Queue;
using Microsoft.IdentityModel.Clients.ActiveDirectory;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

private static string SettingLoganalyticsId = "PROCESSOR_LOGANALYTICSID";
private static string SettingLoganalyticsKey = "PROCESSOR_LOGANALYTICSKEY";
private static string SettingTargetAccount = "PROCESSOR_TARGETACCOUNT_";
private static string SettingTargetQueue = "PROCESSOR_TARGETQUEUE_";

private static HttpClient client = new HttpClient(
    new HttpClientHandler { AutomaticDecompression = DecompressionMethods.GZip | DecompressionMethods.Deflate }
);

private static AuthenticationContext authentication = new AuthenticationContext($"https://login.microsoftonline.com/{GetSetting(SettingTenantId, true)}");

public static async Task Run(string data, ILogger log, Binder binder)
{
    log.LogInformation($"Processing item");

    var json = (JToken)JsonConvert.DeserializeObject(data);
    var user = record["UserId"].ToString();
    var domain = "none";
    
    log.LogInformation($"Processing record for {user}");
    
    if(user.IndexOf("@") > -1)
    {
        domain = user.Split('@')[1];
    }

    domain = CleanDomain(domain);

    var account = GetTargetAccount(domain);
    if (account == null)
    {
        log.LogInformation($"Writing data to Log Analytics table {domain}_CL");

        var laId = GetSetting(SettingLoganalyticsId, true);
        var laKey = GetSetting(SettingLoganalyticsKey, true);

        await PostData(laId, laKey, domain, record.ToString());
    }
    else
    {
        log.LogInformation($"Writing data to Storage Queue");
        await WriteData(domain, record.ToString(), binder);
    }
}

private static async Task PostData(string id, string key, string domain, string data)
{
    ResetHttpClient();

    var date = DateTime.UtcNow.ToString("r");

    client.DefaultRequestHeaders.Authorization = GetLogAnalyticsAuthenticationHeader(id, key, date, data);
    client.DefaultRequestHeaders.Add("Log-Type", domain);
    client.DefaultRequestHeaders.Add("x-ms-date", date);
    client.DefaultRequestHeaders.Add("time-generated-field", "CreationTime");

    var content = new StringContent(data, Encoding.UTF8);
    content.Headers.ContentType = new MediaTypeHeaderValue("application/json");

    var response = await client.PostAsync($"https://{id}.ods.opinsights.azure.com/api/logs?api-version=2016-04-01", content);
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
    return GetSetting($"{SettingTargetAccount}{domain}");
}

private static string GetTargetQueue(string domain)
{
    return GetSetting($"{SettingTargetQueue}{domain}", true);
}

private static string GetSetting(string name, bool isRequired = false)
{
    var setting = Environment.GetEnvironmentVariable(name, EnvironmentVariableTarget.Process);

    if(isRequired && string.IsNullOrEmpty(setting))
    {
        throw new ArgumentNullException($"{name} is missing in Application Settings");
    }

    return string.IsNullOrEmpty(setting) ? null : setting;
}

private static void ResetHttpClient()
{
    client.DefaultRequestHeaders.Clear();
    client.DefaultRequestHeaders.Add("Accept", "application/json");
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