namespace Ai4Sf.Common
{
    using System;
    using System.Diagnostics.Tracing;
    using System.Fabric;
    using Microsoft.ServiceFabric.Services.Runtime;

    /// <summary>
    /// Implements methods for logging service related events.
    /// </summary>
    public class ServiceEventSource : EventSource
    {
        private const int MessageEventId = 1;
        private const int ServiceTypeRegisteredEventId = 3;
        private const int ServiceHostInitializationFailedEventId = 4;
        private const int ServiceWebHostBuilderFailedEventId = 5;

        public static ServiceEventSource Current = new ServiceEventSource();

        // Define an instance method for each event you want to record and apply an [Event] attribute to it.
        // The method name is the name of the event.
        // Pass any parameters you want to record with the event (only primitive integer types, DateTime, Guid & string are allowed).
        // Each event method implementation should check whether the event source is enabled, and if it is, call WriteEvent() method to raise the event.
        // The number and types of arguments passed to every event method must exactly match what is passed to WriteEvent().
        // Put [NonEvent] attribute on all methods that do not define an event.
        // For more information see https://msdn.microsoft.com/en-us/library/system.diagnostics.tracing.eventsource.aspx

        [NonEvent]
        public void Message(string message, params object[] args)
        {
            if (this.IsEnabled())
            {
                string finalMessage = string.Format(message, args);
                this.Message(finalMessage);
            }
        }

        [Event(MessageEventId, Level = EventLevel.Informational, Message = "{0}")]
        public void Message(string message)
        {
            if (this.IsEnabled())
            {
                this.WriteEvent(MessageEventId, message);
            }
        }

        [NonEvent]
        public void ServiceMessage(ServiceContext serviceContext, string message, params object[] args)
        {
            if (this.IsEnabled())
            {
                string finalMessage = string.Format(message, args);
                this.ServiceMessage(
                    serviceContext.ServiceName.ToString(),
                    serviceContext.ServiceTypeName,
                    GetReplicaOrInstanceId(serviceContext),
                    serviceContext.PartitionId,
                    serviceContext.CodePackageActivationContext.ApplicationName,
                    serviceContext.CodePackageActivationContext.ApplicationTypeName,
                    serviceContext.NodeContext.NodeName,
                    finalMessage);
            }
        }

        // For very high-frequency events it might be advantageous to raise events using WriteEventCore API.
        // This results in more efficient parameter handling, but requires explicit allocation of EventData structure and unsafe code.
        // To enable this code path, define UNSAFE conditional compilation symbol and turn on unsafe code support in project properties.
        private const int ServiceMessageEventId = 2;

        [Event(ServiceMessageEventId, Level = EventLevel.Informational, Message = "{7}")]
        private void ServiceMessage(string serviceName, string serviceTypeName, long replicaOrInstanceId,
            Guid partitionId, string applicationName, string applicationTypeName, string nodeName, string message)
        {
            this.WriteEvent(ServiceMessageEventId, serviceName, serviceTypeName, replicaOrInstanceId, 
                partitionId, applicationName, applicationTypeName, nodeName, message);
        }

        [Event(ServiceTypeRegisteredEventId, Level = EventLevel.Informational, Message = "Service host process {0} registered service type {1}")]
        public void ServiceTypeRegistered(int hostProcessId, string serviceType)
        {
            this.WriteEvent(ServiceTypeRegisteredEventId, hostProcessId, serviceType);
        }

        [NonEvent]
        public void ServiceHostInitializationFailed(Exception e)
        {
            this.ServiceHostInitializationFailed(e.ToString());
        }

        [Event(ServiceHostInitializationFailedEventId, Level = EventLevel.Error, Message = "Service host initialization failed: {0}")]
        private void ServiceHostInitializationFailed(string exception)
        {
            this.WriteEvent(ServiceHostInitializationFailedEventId, exception);
        }

        [NonEvent]
        public void ServiceWebHostBuilderFailed(Exception e)
        {
            this.ServiceWebHostBuilderFailed(e.ToString());
        }

        [Event(ServiceWebHostBuilderFailedEventId, Level = EventLevel.Error, Message = "Service Owin Web Host Builder Failed: {0}")]
        private void ServiceWebHostBuilderFailed(string exception)
        {
            this.WriteEvent(ServiceWebHostBuilderFailedEventId, exception);
        }

        private static long GetReplicaOrInstanceId(ServiceContext context)
        {
            StatelessServiceContext stateless = context as StatelessServiceContext;
            if (stateless != null)
            {
                return stateless.InstanceId;
            }

            StatefulServiceContext stateful = context as StatefulServiceContext;
            if (stateful != null)
            {
                return stateful.ReplicaId;
            }

            throw new NotSupportedException("Context type not supported.");
        }
    }
}