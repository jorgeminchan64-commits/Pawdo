using System;
using Pawdo.Characters;
using UnityEngine;
using UnityEngine.SceneManagement;

namespace Pawdo.Core.Bridge
{
    public sealed class PawdoBridgeHost : MonoBehaviour
    {
        [Serializable]
        private sealed class VoiceSignalPayload
        {
            public bool active;
            public float rms;
            public float peak;
        }

        public const string HostObjectName = "PawdoBridgeHost";
        private readonly PawdoBridgeRouter router = new PawdoBridgeRouter();
        private static PawdoBridgeHost instance;

        public PawdoBridgeLifecycle Lifecycle => router.Lifecycle;

        private void Awake()
        {
            if (instance != null && instance != this)
            {
                Destroy(gameObject);
                return;
            }

            instance = this;
            DontDestroyOnLoad(gameObject);
        }

        public void ReceiveFromFlutter(string rawJson)
        {
            var result = router.ReceiveFromFlutter(rawJson);
            if (!result.Accepted)
            {
                Debug.LogWarning($"Pawdo bridge rejected a message: {result.Code}");
                return;
            }

            Debug.Log($"Pawdo bridge accepted {result.Envelope.type}.");
            if (result.Envelope.type == "voice.level" ||
                result.Envelope.type == "voice.playback")
            {
                ApplyVoiceSignal(result.Envelope.PayloadJson);
            }
            if (result.Envelope.type == "scene.unload")
            {
                Application.Unload();
            }
        }

        private static void ApplyVoiceSignal(string payloadJson)
        {
            VoiceSignalPayload payload;
            try
            {
                payload = JsonUtility.FromJson<VoiceSignalPayload>(payloadJson);
            }
            catch (Exception)
            {
                Debug.LogWarning("Pawdo voice bridge rejected an invalid payload.");
                return;
            }

            if (payload == null) return;
            foreach (var reaction in FindObjectsByType<PawdoVoiceReactionController>(FindObjectsSortMode.None))
            {
                if (payload.active)
                {
                    reaction.SetVoiceLevel(payload.rms, payload.peak, true);
                }
                else
                {
                    reaction.StopVoice();
                }
            }
        }

        public void LoadSceneFromFlutter(string sceneName)
        {
            var unityScene = sceneName switch
            {
                "garden" => "GardenSlice",
                "interior" => "InteriorSlice",
                _ => "Bootstrap",
            };
            if (SceneManager.GetActiveScene().name == unityScene)
            {
                return;
            }

            Debug.Log($"PAWDO_SCENE_REQUEST wire={sceneName} unity={unityScene}");
            SceneManager.LoadSceneAsync(unityScene, LoadSceneMode.Single);
        }
    }
}
