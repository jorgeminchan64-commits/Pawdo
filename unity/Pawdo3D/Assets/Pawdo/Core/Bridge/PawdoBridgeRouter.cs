using System.Collections.Generic;

namespace Pawdo.Core.Bridge
{
    public enum PawdoBridgeLifecycle
    {
        WaitingForInitialize,
        Ready,
        SceneActive,
        Paused,
        Unloaded,
    }

    public readonly struct PawdoBridgeReceiveResult
    {
        private PawdoBridgeReceiveResult(bool accepted, string code, PawdoBridgeEnvelope envelope)
        {
            Accepted = accepted;
            Code = code;
            Envelope = envelope;
        }

        public bool Accepted { get; }
        public string Code { get; }
        public PawdoBridgeEnvelope Envelope { get; }

        public static PawdoBridgeReceiveResult Accept(PawdoBridgeEnvelope envelope)
        {
            return new PawdoBridgeReceiveResult(true, "accepted", envelope);
        }

        public static PawdoBridgeReceiveResult Reject(string code)
        {
            return new PawdoBridgeReceiveResult(false, code, null);
        }
    }

    public sealed class PawdoBridgeRouter
    {
        private const int MaximumRememberedMessages = 512;
        private readonly HashSet<string> seenMessageIds = new HashSet<string>();
        private readonly Queue<string> seenMessageOrder = new Queue<string>();

        public PawdoBridgeLifecycle Lifecycle { get; private set; } = PawdoBridgeLifecycle.WaitingForInitialize;

        public PawdoBridgeReceiveResult ReceiveFromFlutter(string rawJson)
        {
            if (!PawdoBridgeEnvelope.TryParse(rawJson, out var envelope, out var error))
            {
                return PawdoBridgeReceiveResult.Reject(error);
            }

            if (!PawdoBridgeMessageTypes.IsFlutterToUnity(envelope.type))
            {
                return PawdoBridgeReceiveResult.Reject("wrong-message-direction");
            }

            if (seenMessageIds.Contains(envelope.messageId))
            {
                return PawdoBridgeReceiveResult.Reject("duplicate-message");
            }

            if (Lifecycle == PawdoBridgeLifecycle.WaitingForInitialize && envelope.type != "runtime.initialize")
            {
                return PawdoBridgeReceiveResult.Reject("runtime-not-initialized");
            }

            if (Lifecycle == PawdoBridgeLifecycle.Unloaded && envelope.type != "runtime.initialize")
            {
                return PawdoBridgeReceiveResult.Reject("runtime-unloaded");
            }

            Remember(envelope.messageId);
            switch (envelope.type)
            {
                case "runtime.initialize":
                    Lifecycle = PawdoBridgeLifecycle.Ready;
                    break;
                case "scene.load":
                    Lifecycle = PawdoBridgeLifecycle.SceneActive;
                    break;
                case "scene.pause":
                    Lifecycle = PawdoBridgeLifecycle.Paused;
                    break;
                case "scene.resume":
                    Lifecycle = PawdoBridgeLifecycle.SceneActive;
                    break;
                case "scene.unload":
                    Lifecycle = PawdoBridgeLifecycle.Unloaded;
                    break;
            }

            return PawdoBridgeReceiveResult.Accept(envelope);
        }

        private void Remember(string messageId)
        {
            seenMessageIds.Add(messageId);
            seenMessageOrder.Enqueue(messageId);
            if (seenMessageOrder.Count <= MaximumRememberedMessages)
            {
                return;
            }

            seenMessageIds.Remove(seenMessageOrder.Dequeue());
        }
    }
}

