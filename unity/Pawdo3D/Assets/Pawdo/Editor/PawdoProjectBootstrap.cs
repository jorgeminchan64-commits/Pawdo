using System.IO;
using Pawdo.Core.Bootstrap;
using Pawdo.Core.Bridge;
using Pawdo.Garden;
using Pawdo.Interior;
using UnityEditor;
using UnityEditor.AddressableAssets;
using UnityEditor.AddressableAssets.Settings;
using UnityEditor.Build;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.SceneManagement;

namespace Pawdo.Editor
{
    public static class PawdoProjectBootstrap
    {
        private const string SceneDirectory = "Assets/Pawdo/Scenes";
        private const string BootstrapScenePath = SceneDirectory + "/Bootstrap.unity";
        private const string GardenScenePath = SceneDirectory + "/GardenSlice.unity";
        private const string InteriorScenePath = SceneDirectory + "/InteriorSlice.unity";
        private const string RenderingDirectory = "Assets/Pawdo/Rendering";
        private const string PipelineAssetPath = RenderingDirectory + "/PawdoMobileURP.asset";

        [MenuItem("Pawdo/Configure project and Bootstrap scene")]
        public static void Configure()
        {
            ConfigurePlayer();
            ConfigureRendering();
            ConfigureAddressables();
            CreateBootstrapScene();
            CreateGardenScene();
            CreateInteriorScene();
            AssetDatabase.SaveAssets();
            AssetDatabase.Refresh();
            Debug.Log("PAWDO_BOOTSTRAP_OK");
        }

        private static void ConfigurePlayer()
        {
            PlayerSettings.companyName = "Jorge Luis Minchan Huaman";
            PlayerSettings.productName = "Pawdo 3D";
            PlayerSettings.colorSpace = ColorSpace.Linear;
            PlayerSettings.defaultInterfaceOrientation = UIOrientation.LandscapeLeft;
            PlayerSettings.SetApplicationIdentifier(NamedBuildTarget.Android, "com.pawdo.app");

            if (!BuildPipeline.IsBuildTargetSupported(BuildTargetGroup.Android, BuildTarget.Android))
            {
                Debug.LogWarning("Android Build Support is not installed yet; Android player settings were deferred.");
                return;
            }

            PlayerSettings.SetScriptingBackend(NamedBuildTarget.Android, ScriptingImplementation.IL2CPP);
            PlayerSettings.Android.targetArchitectures = AndroidArchitecture.ARM64;
            PlayerSettings.Android.minSdkVersion = AndroidSdkVersions.AndroidApiLevel26;
        }

        private static void ConfigureRendering()
        {
            EnsureDirectory(RenderingDirectory);
            var pipeline = AssetDatabase.LoadAssetAtPath<UniversalRenderPipelineAsset>(PipelineAssetPath);
            if (pipeline == null)
            {
                pipeline = ScriptableObject.CreateInstance<UniversalRenderPipelineAsset>();
                AssetDatabase.CreateAsset(pipeline, PipelineAssetPath);
                var rendererData = pipeline.LoadBuiltinRendererData(RendererType.UniversalRenderer);
                if (rendererData != null && !AssetDatabase.Contains(rendererData))
                {
                    rendererData.name = "PawdoMobileRenderer";
                    AssetDatabase.AddObjectToAsset(rendererData, pipeline);
                }
            }

            pipeline.renderScale = 1f;
            pipeline.shadowDistance = 28f;
            pipeline.shadowCascadeCount = 2;
            pipeline.supportsHDR = false;
            pipeline.supportsCameraDepthTexture = false;
            pipeline.supportsCameraOpaqueTexture = false;
            // Unity 6000.3.20: procedural material instances bleed GPU properties
            // across draws in this project. Keep the verified non-batched path
            // until RuntimeMaterialsKeepIndependentColorsOnTheGpu passes with it.
            pipeline.useSRPBatcher = false;
            GraphicsSettings.defaultRenderPipeline = pipeline;
            QualitySettings.renderPipeline = pipeline;
            EditorUtility.SetDirty(pipeline);
        }

        private static void ConfigureAddressables()
        {
            AddressableAssetSettingsDefaultObject.GetSettings(true);
        }

        private static void CreateBootstrapScene()
        {
            EnsureDirectory(SceneDirectory);
            var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);

            var bridgeObject = new GameObject(PawdoBridgeHost.HostObjectName);
            bridgeObject.AddComponent<PawdoBridgeHost>();

            var bootstrapObject = new GameObject("PawdoBootstrapController");
            bootstrapObject.AddComponent<PawdoBootstrapController>();

            var cameraObject = new GameObject("Main Camera");
            cameraObject.tag = "MainCamera";
            var camera = cameraObject.AddComponent<Camera>();
            camera.clearFlags = CameraClearFlags.SolidColor;
            camera.backgroundColor = new Color(0.12f, 0.13f, 0.15f);
            camera.transform.SetPositionAndRotation(new Vector3(8f, 7f, -8f), Quaternion.Euler(28f, -43f, 0f));
            cameraObject.AddComponent<AudioListener>();

            var lightObject = new GameObject("Warm Key Light");
            var light = lightObject.AddComponent<Light>();
            light.type = LightType.Directional;
            light.color = new Color(1f, 0.90f, 0.80f);
            light.intensity = 1.1f;
            light.shadows = LightShadows.Soft;
            lightObject.transform.rotation = Quaternion.Euler(48f, -32f, 0f);

            var ground = GameObject.CreatePrimitive(PrimitiveType.Plane);
            ground.name = "Technical Ground";
            ground.transform.localScale = new Vector3(1.4f, 1f, 1.4f);
            var material = new Material(Shader.Find("Universal Render Pipeline/Lit"));
            material.name = "Technical Gray";
            material.color = new Color(0.27f, 0.29f, 0.32f);
            ground.GetComponent<MeshRenderer>().sharedMaterial = material;

            var marker = GameObject.CreatePrimitive(PrimitiveType.Cube);
            marker.name = "Bridge Ready Marker";
            marker.transform.position = new Vector3(0f, 0.65f, 0f);
            marker.transform.localScale = new Vector3(2.4f, 1.3f, 2.4f);
            var markerMaterial = new Material(Shader.Find("Universal Render Pipeline/Lit"));
            markerMaterial.name = "Pawdo Wine Marker";
            markerMaterial.color = new Color(0.34f, 0.08f, 0.16f);
            marker.GetComponent<MeshRenderer>().sharedMaterial = markerMaterial;

            EditorSceneManager.SaveScene(scene, BootstrapScenePath);
            EditorBuildSettings.scenes = new[]
            {
                new EditorBuildSettingsScene(BootstrapScenePath, true),
                new EditorBuildSettingsScene(GardenScenePath, true),
                new EditorBuildSettingsScene(InteriorScenePath, true),
            };
            SceneManager.SetActiveScene(scene);
        }

        private static void CreateGardenScene()
        {
            EnsureDirectory(SceneDirectory);
            var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
            var root = new GameObject("Pawdo GardenSlice VS-2");
            root.AddComponent<PawdoGardenSliceController>();
            EditorSceneManager.SaveScene(scene, GardenScenePath);
        }

        private static void CreateInteriorScene()
        {
            EnsureDirectory(SceneDirectory);
            var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
            var root = new GameObject("Pawdo InteriorSlice VS-3");
            root.AddComponent<PawdoInteriorSliceController>();
            EditorSceneManager.SaveScene(scene, InteriorScenePath);
        }

        private static void EnsureDirectory(string assetPath)
        {
            var absolutePath = Path.Combine(Directory.GetCurrentDirectory(), assetPath);
            Directory.CreateDirectory(absolutePath);
        }
    }
}
