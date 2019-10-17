using System;
using System.Web;

namespace Ai4Sf.Common
{
    public static class StringExtensions
    {
        public static string UrlEncode(this string s)
        {
            return HttpUtility.UrlEncode(s);
        }

        public static string UrlEncode(this DateTime d)
        {
            return HttpUtility.UrlEncode(d.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ"));
        }
    }
}