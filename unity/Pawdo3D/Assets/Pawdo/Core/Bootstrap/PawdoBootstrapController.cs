using Pawdo.Core.Bridge;
using UnityEngine;

namespace Pawdo.Core.Bootstrap
{
    public sealed class PawdoBootstrapController : MonoBehaviour
    {
        private GUIStyle titleStyle;
        private GUIStyle bodyStyle;
        private PawdoBridgeHost bridgeHost;

        private void Awake()
        {
            Application.targetFrameRate = 60;
            QualitySettings.vSyncCount = 0;
            bridgeHost = FindFirstObjectByType<PawdoBridgeHost>();
        }

        private void Start()
        {
            var requestedScene = "garden";
#if UNITY_ANDROID && !UNITY_EDITOR
            using var unityPlayer = new AndroidJavaClass("com.unity3d.player.UnityPlayer");
            using var activity = unityPlayer.GetStatic<AndroidJavaObject>("currentActivity");
            using var intent = activity?.Call<AndroidJavaObject>("getIntent");
            var initialization = intent?.Call<string>(
                "getStringExtra",
                "pawdo.bridge.initialization");
            if (!string.IsNullOrWhiteSpace(initialization))
            {
                bridgeHost?.ReceiveFromFlutter(initialization);
            }
            requestedScene = intent?.Call<string>("getStringExtra", "pawdo.scene") ?? "garden";
#endif
            bridgeHost?.LoadSceneFromFlutter(requestedScene);
        }

        private void OnGUI()
        {
            EnsureStyles();
            var safe = Screen.safeArea;
            var panel = new Rect(safe.x + 32f, safe.y + 32f, Mathf.Min(720f, safe.width - 64f), 156f);
            GUI.Box(panel, GUIContent.none);
            GUI.Label(new Rect(panel.x + 24f, panel.y + 18f, panel.width - 48f, 42f), "PAWDO · 3D RUNTIME", titleStyle);
            var bridgeState = bridgeHost == null ? "host ausente" : bridgeHost.Lifecycle.ToString();
            GUI.Label(
                new Rect(panel.x + 24f, panel.y + 70f, panel.width - 48f, 64f),
                $"Unity 6.3 LTS · URP móvil · Bridge v1\nEscena técnica gris · Estado: {bridgeState}",
                bodyStyle);
        }

        private void EnsureStyles()
        {
            if (titleStyle != null)
            {
                return;
            }

            titleStyle = new GUIStyle(GUI.skin.label)
            {
                fontSize = 24,
                fontStyle = FontStyle.Bold,
                normal = { textColor = new Color(0.96f, 0.93f, 0.89f) },
            };
            bodyStyle = new GUIStyle(GUI.skin.label)
            {
                fontSize = 16,
                normal = { textColor = new Color(0.84f, 0.82f, 0.80f) },
            };
        }
    }
}
