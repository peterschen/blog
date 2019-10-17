using System;

namespace Ai4Sf.Common.Models
{
    public class TelemetryItem
    {
        public TelemetryItem()
        {
        }

        public TelemetryItem(DateTime timestamp, int records)
        {
            Timestamp = timestamp;
            Records = records;
        }

        public long Id { get; set; }

        public DateTime Timestamp { get; set; }

        public long Records { get; set; }
    }
}