namespace Ai4Sf.TelemetryCrawler
{
    using System.Fabric;
    using Microsoft.ServiceFabric.Services.Runtime;
    using System.Threading.Tasks;
    using System.Threading;
    using System;
    using System.Web;
    using System.Linq;
    using Ai4Sf.Common;
    using System.Net.Http;
    using System.Net.Http.Headers;
    using Ai4Sf.Common.Models;
    using Newtonsoft.Json;
    using Newtonsoft.Json.Linq;
    using System.Text;

    /// <summary>
    /// An instance of this class is created for each service instance by the Service Fabric runtime.
    /// </summary>
    internal sealed class TelemetryCrawler : StatelessService
    {
        private string uriTelemetryApi = "http://{0}:8081/api/Telemetry";

        public TelemetryCrawler(StatelessServiceContext context)
            : base(context)
        {
            uriTelemetryApi = string.Format(uriTelemetryApi, context.ListenAddress);
        }

        protected override async Task RunAsync(CancellationToken cancellationToken)
        {
            string spTenantId = Environment.GetEnvironmentVariable("spTenantId");
            string spAppId = Environment.GetEnvironmentVariable("spAppId");
            string spPassword = Environment.GetEnvironmentVariable("spPassword");

            string resourceId = Environment.GetEnvironmentVariable("resourceId");
            string resourceMetric = Environment.GetEnvironmentVariable("resourceMetric");

            string resourceUri = "https://management.azure.com";

            DateTime lastRetrieval = DateTime.MinValue;

            while (!cancellationToken.IsCancellationRequested)
            {
                var token = await Auth.GetToken(spTenantId, spAppId, spPassword, resourceUri);

                // Get historic data on first run
                if (lastRetrieval == DateTime.MinValue)
                {
                    lastRetrieval = DateTime.Now.AddDays(-5);
                }

                string metricsUri = $"{resourceUri}/{resourceId.UrlEncode()}/providers/microsoft.insights/metrics?api-version=2018-01-01&metricnames={resourceMetric}&timespan={lastRetrieval.UrlEncode()}%2F{DateTime.Now.UrlEncode()}";

                using (var client = new HttpClient())
                {
                    client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
                    client.DefaultRequestHeaders.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));

                    using (HttpResponseMessage response = await client.GetAsync(metricsUri))
                    {
                        if (response.IsSuccessStatusCode)
                        {
                            var content = await response.Content.ReadAsStringAsync();
                            ProcessTelemetry(content);
                            lastRetrieval = DateTime.Now;
                        }
                    }
                }

                Thread.Sleep(new TimeSpan(0, 0, 30));
            }
        }

        private async void ProcessTelemetry(string jsonString)
        {
            var json = JObject.Parse(jsonString);
            // var name = json.name.value;

            // foreach(var item in json.value.timeseries.data)
            // {
            //     var telemetry = new TelemetryItem(name, item.timeStamp, item.average);
            // }

            var telemetry = new TelemetryItem(DateTime.Now.ToUniversalTime(), ((JArray)json["value"][0]["timeseries"][0]["data"]).Count);

            using (var client = new HttpClient())
            {
                client.DefaultRequestHeaders.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));

                var content = new StringContent(JsonConvert.SerializeObject(telemetry), Encoding.UTF8, "application/json");
                using (HttpResponseMessage response = await client.PostAsync(uriTelemetryApi, content))
                {
                    if (!response.IsSuccessStatusCode)
                    {
                        // WHAHAHHAHAAA!!!
                    }
                }
            }
        }
    }
}
