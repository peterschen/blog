using System;

namespace CCMT
{
    public class Settings
    {
        private static string _tenantId = "SCCMT_TENANTID";
        private static string _clientId = "SCCMT_CLIENTID";
        private static string _clientSecret = "SCCMT_CLIENTSECRET";
        private static string _subscriptionId = "SCCMT_SUBSCRIPTIONID";
        private static string _resourceGroupName = "SCCMT_RESOURCEGROUPNAME";

        private static string _cp_Domains = "CP_DOMAINS";
        private static string _cp_WorkspaceId = "CP_WORKSPACEID";
        private static string _cp_WorkspaceKey = "CP_WORKSPACEKEY";
        private static string _cp_WorkspacePrefix = "CP_WORKSPACEPREFIX";

        public static string TenantId
        {
            get
            {
                return GetSetting(_tenantId, true);
            }
        }

        public static string ClientId
        {
            get
            {
                return GetSetting(_clientId, true);
            }
        }

        public static string ClientSecret
        {
            get
            {
                return GetSetting(_clientSecret, true);
            }
        }

        public static string SubscriptionId
        {
            get
            {
                return GetSetting(_subscriptionId, true);
            }
        }

        public static string ResourceGroupName
        {
            get
            {
                return GetSetting(_resourceGroupName, true);
            }
        }

        public static string ContentProcessorDomains
        {
            get
            {
                return GetSetting(_cp_Domains, true);
            }
        }

        public static string ContentProcessorWorkspaceId
        {
            get
            {
                return GetSetting(_cp_WorkspaceId, true);
            }
        }

        public static string ContentProcessorWorkspaceKey
        {
            get
            {
                return GetSetting(_cp_WorkspaceKey, true);
            }
        }

        public static string ContentProcessorWorkspacePrefix
        {
            get
            {
                return GetSetting(_cp_WorkspacePrefix, true);
            }
        }

        public static string GetSetting(string name, bool isRequired = false)
        {
            var setting = Environment.GetEnvironmentVariable(name, EnvironmentVariableTarget.Process);

            if (isRequired && string.IsNullOrEmpty(setting))
            {
                throw new ArgumentNullException($"{name} is missing in Application Settings");
            }

            return string.IsNullOrEmpty(setting) ? null : setting;
        }
    }
}