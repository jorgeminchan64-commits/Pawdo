using System.IO;
using Pawdo.Interior;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Pawdo.Editor
{
    [InitializeOnLoad]
    public static class PawdoRenderPreview
    {
        private const string PendingKey = "Pawdo.RenderPreview.Pending";
        private static int readyFrame;

        static PawdoRenderPreview()
        {
            EditorApplication.playModeStateChanged += OnPlayModeChanged;
        }

        // Actual scene geometry/materials, rendered by Unity for visual review.
        public static void CaptureInterior()
        {
            PawdoSurfaceImporter.EnsureMaterials();
            EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
            SessionState.SetBool(PendingKey, true);
            EditorApplication.EnterPlaymode();
        }

        private static void OnPlayModeChanged(PlayModeStateChange change)
        {
            if (change != PlayModeStateChange.EnteredPlayMode || !SessionState.GetBool(PendingKey, false)) return;
            var root = new GameObject("Interior render review");
            root.AddComponent<PawdoInteriorSliceController>();
            readyFrame = Time.frameCount + 12;
            EditorApplication.update += CaptureWhenReady;
        }

        private static void CaptureWhenReady()
        {
            if (Time.frameCount < readyFrame) return;
            EditorApplication.update -= CaptureWhenReady;
            SessionState.SetBool(PendingKey, false);
            try
            {
                SaveImage("current");
                EditorApplication.Exit(0);
            }
            catch (System.Exception error) { Debug.LogException(error); EditorApplication.Exit(1); }
        }

        private static void SaveImage(string suffix)
        {
            var camera = Camera.main;
            if (camera == null) throw new System.InvalidOperationException("Scene camera missing.");
            var target = new RenderTexture(1600, 900, 24, RenderTextureFormat.ARGB32);
            var request = new UniversalRenderPipeline.SingleCameraRequest { destination = target };
            if (!RenderPipeline.SupportsRenderRequest(camera, request))
                throw new System.InvalidOperationException("The active pipeline cannot render the review camera.");
            RenderPipeline.SubmitRenderRequest(camera, request);
            var previous = RenderTexture.active;
            RenderTexture.active = target;
            var image = new Texture2D(1600, 900, TextureFormat.RGB24, false);
            image.ReadPixels(new Rect(0, 0, 1600, 900), 0, 0);
            image.Apply();
            var destination = Path.GetFullPath(Path.Combine(Application.dataPath,
                "../../../docs/3d/evidence/interior-materials-" + suffix + ".png"));
            Directory.CreateDirectory(Path.GetDirectoryName(destination));
            File.WriteAllBytes(destination, image.EncodeToPNG());
            RenderTexture.active = previous;
            camera.targetTexture = null;
            target.Release();
            Object.Destroy(image);
            Object.Destroy(target);
            Debug.Log("PAWDO_PREVIEW_SAVED " + destination);
        }
    }
}
