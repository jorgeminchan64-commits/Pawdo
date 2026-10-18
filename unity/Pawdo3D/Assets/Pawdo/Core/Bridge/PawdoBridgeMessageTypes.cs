using System.Collections.Generic;

namespace Pawdo.Core.Bridge
{
    public static class PawdoBridgeMessageTypes
    {
        private static readonly HashSet<string> FlutterToUnityTypes = new HashSet<string>
        {
            "runtime.initialize",
            "session.context",
            "scene.load",
            "scene.pause",
            "scene.resume",
            "scene.unload",
            "avatar.appearance",
            "pet.snapshot",
            "inventory.snapshot",
            "layout.snapshot",
            "interaction.result",
            "voice.permission",
            "voice.level",
            "voice.playback",
        };

        private static readonly HashSet<string> UnityToFlutterTypes = new HashSet<string>
        {
            "runtime.ready",
            "runtime.error",
            "scene.ready",
            "interaction.request",
            "layout.save.request",
            "voice.start.request",
            "voice.stop.request",
            "navigation.exit",
            "telemetry.sample",
        };

        public static bool IsKnown(string messageType)
        {
            return IsFlutterToUnity(messageType) || IsUnityToFlutter(messageType);
        }

        public static bool IsFlutterToUnity(string messageType)
        {
            return messageType != null && FlutterToUnityTypes.Contains(messageType);
        }

        public static bool IsUnityToFlutter(string messageType)
        {
            return messageType != null && UnityToFlutterTypes.Contains(messageType);
        }
    }
}
