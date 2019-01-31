using System;
using System.Net;
using System.Net.Http;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

private static HttpClient client = new HttpClient(
    new HttpClientHandler { AutomaticDecompression = DecompressionMethods.GZip | DecompressionMethods.Deflate }
);

public static async Task Run(string data, ILogger log)
{
    log.LogInformation($"Processing item '{data}'");

    var response = await client.GetAsync(data);
    response.EnsureSuccessStatusCode();

    var result = await response.Content.ReadAsStringAsync();
    var json = JsonConvert.DeserializeObject(result);

    foreach(var record in (JArray) json)
    {
        var user = record["UserId"].ToString();
        var domain = user.Split("@")[1];

        log.LogInformation($"Processing record for {user} in {domain}");

        var target = GetDataTarget(domain);
        if(target == null)
        {
            log.LogInformation($"Writing data to Log Analytics");
        }
        else
        {
            log.LogInformation($"Writing data to Storage Account {target}");
        }
    }
}

private static string GetDataTarget(string domain)
{
    var target = Environment.GetEnvironmentVariable($"PROCESSOR_TARGET_{domain.Replace(".", "")}", EnvironmentVariableTarget.Process);
    return string.IsNullOrEmpty(target) ? null : target;
}