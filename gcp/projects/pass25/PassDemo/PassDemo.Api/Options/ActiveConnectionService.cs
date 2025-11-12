using System.Threading;

namespace PassDemo.Api.Options
{
    public class ActiveConnectionService
    {
        // Default to DEMO1
        public string ActiveConnectionName { get; private set; } = "DEMO1";

        private readonly ReaderWriterLockSlim _lock = new ReaderWriterLockSlim();

        public void SetActiveConnection(string connectionName)
        {
            _lock.EnterWriteLock();
            try
            {
                ActiveConnectionName = connectionName;
            }
            finally
            {
                _lock.ExitWriteLock();
            }
        }
    }
}