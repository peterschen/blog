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

private static string SettingTenantId = "SCCMT_TENANTID";
private static string SettingClientId = "SCCMT_CLIENTID";
private static string SettingClientSecret = "SCCMT_CLIENTSECRET";
private static string SettingTargetAccount = "SCCMT_STORAGE";
private static string SettingTargetQueue = "SCCMT_QUEUE_CONTENT";

private static HttpClient client = new HttpClient(
    new HttpClientHandler { AutomaticDecompression = DecompressionMethods.GZip | DecompressionMethods.Deflate }
);

private static AuthenticationContext authentication = new AuthenticationContext($"https://login.microsoftonline.com/{GetSetting(SettingTenantId, true)}");

public static async Task Run(string data, ILogger log, Binder binder)
{
    log.LogInformation($"Processing item '{data}'");
    string result = await RetrieveData(data);
    var json = (JArray)JsonConvert.DeserializeObject(result);

    log.LogInformation($"Item contains {json.Count} records");
    foreach (var record in json)
    {
        log.LogInformation($"Writing data to Storage Queue");
        await WriteData(record.ToString(), binder);
    }
}

private static async Task<string> RetrieveData(string uri)
{
    var clientId = GetSetting(SettingClientId, true);
    var clientSecret = GetSetting(SettingClientSecret, true);

    ResetHttpClient();
    client.DefaultRequestHeaders.Authorization = await GetOfficeAuthenticationHeader(clientId, clientSecret);    

    var response = await client.GetAsync(uri);
    response.EnsureSuccessStatusCode();

    return await response.Content.ReadAsStringAsync();
}

private static async Task<AuthenticationHeaderValue> GetOfficeAuthenticationHeader(string clientId, string clientSecret)
{
    var credential = new ClientCredential(clientId, clientSecret);
    var result = await authentication.AcquireTokenAsync($"https://manage.office.com", credential);
    return new AuthenticationHeaderValue(result.AccessTokenType, result.AccessToken);
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

private static async Task WriteData(string data, Binder binder)
{
    var account = GetSetting($"{SettingTargetAccount}", true);
    var queue = GetSetting($"{SettingTargetQueue}", true);

    var attributes = new Attribute[]
    {
        new QueueAttribute(queue),
        new StorageAccountAttribute(account)
    };

    var output = await binder.BindAsync<CloudQueue>(attributes);
    await output.AddMessageAsync(new CloudQueueMessage(data));
}