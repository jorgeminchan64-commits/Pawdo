using System;
using System.IO;
using System.Xml;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
using UnityEngine;

namespace Pawdo.Editor
{
    public static class PawdoAndroidLibraryExporter
    {
        private const string BootstrapScenePath = "Assets/Pawdo/Scenes/Bootstrap.unity";
        private const string GardenScenePath = "Assets/Pawdo/Scenes/GardenSlice.unity";
        private const string InteriorScenePath = "Assets/Pawdo/Scenes/InteriorSlice.unity";
        private const string PawdoUnityActivityClass = "com.pawdo.app.PawdoUnityActivity";
        private const string PawdoUnityActivitySource = @"package com.pawdo.app;

import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.content.Intent;
import android.view.KeyEvent;
import android.window.OnBackInvokedCallback;
import android.window.OnBackInvokedDispatcher;

import com.unity3d.player.UnityPlayerGameActivity;
import com.unity3d.player.UnityPlayer;

public final class PawdoUnityActivity extends UnityPlayerGameActivity {
    private OnBackInvokedCallback backCallback;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            backCallback = this::returnToFlutter;
            getOnBackInvokedDispatcher().registerOnBackInvokedCallback(
                OnBackInvokedDispatcher.PRIORITY_DEFAULT,
                backCallback);
        }
        Intent launchIntent = getIntent();
        if (launchIntent != null) {
            new Handler(Looper.getMainLooper()).postDelayed(
                () -> forwardIntent(launchIntent),
                750);
        }
    }

    @Override
    public boolean onKeyDown(int keyCode, KeyEvent event) {
        if (keyCode == KeyEvent.KEYCODE_BACK) {
            return true;
        }
        return super.onKeyDown(keyCode, event);
    }

    @Override
    public boolean onKeyUp(int keyCode, KeyEvent event) {
        if (keyCode == KeyEvent.KEYCODE_BACK) {
            returnToFlutter();
            return true;
        }
        return super.onKeyUp(keyCode, event);
    }

    @SuppressWarnings(""deprecation"")
    @Override
    public void onBackPressed() {
        returnToFlutter();
    }

    @Override
    public void onUnityPlayerUnloaded() {
        returnToFlutter();
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        forwardIntent(intent);
    }

    private void forwardIntent(Intent intent) {
        String initialization = intent.getStringExtra(""pawdo.bridge.initialization"");
        if (initialization != null && !initialization.isEmpty()) {
            UnityPlayer.UnitySendMessage(
                ""PawdoBridgeHost"",
                ""ReceiveFromFlutter"",
                initialization);
        }
        String scene = intent.getStringExtra(""pawdo.scene"");
        if (scene != null && !scene.isEmpty()) {
            UnityPlayer.UnitySendMessage(
                ""PawdoBridgeHost"",
                ""LoadSceneFromFlutter"",
                scene);
        }
    }

    @Override
    protected void onDestroy() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU && backCallback != null) {
            getOnBackInvokedDispatcher().unregisterOnBackInvokedCallback(backCallback);
            backCallback = null;
        }
        super.onDestroy();
    }

    private void returnToFlutter() {
        Intent intent = new Intent();
        intent.setClassName(this, ""com.pawdo.app.MainActivity"");
        intent.addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT | Intent.FLAG_ACTIVITY_SINGLE_TOP);
        runOnUiThread(() -> startActivity(intent));
    }
}
";

        [MenuItem("Pawdo/Export Android Unity Library")]
        public static void Export()
        {
            PawdoProjectBootstrap.Configure();

            if (!BuildPipeline.IsBuildTargetSupported(BuildTargetGroup.Android, BuildTarget.Android))
            {
                throw new BuildFailedException(
                    "Android Build Support is required before exporting the Pawdo Unity library.");
            }

            if (!EditorUserBuildSettings.SwitchActiveBuildTarget(
                    BuildTargetGroup.Android,
                    BuildTarget.Android))
            {
                throw new BuildFailedException("Unity could not activate the Android build target.");
            }

            EditorUserBuildSettings.exportAsGoogleAndroidProject = true;

            var exportDirectory = GetExportDirectory();
            Directory.CreateDirectory(exportDirectory);
            var originalBackend = PlayerSettings.GetScriptingBackend(NamedBuildTarget.Android);
            var originalArchitectures = PlayerSettings.Android.targetArchitectures;
            var useQaMonoBackend = string.Equals(
                Environment.GetEnvironmentVariable("PAWDO_UNITY_ANDROID_BACKEND"),
                "mono",
                StringComparison.OrdinalIgnoreCase);
            BuildReport report;
            try
            {
                if (useQaMonoBackend)
                {
                    PlayerSettings.SetScriptingBackend(
                        NamedBuildTarget.Android,
                        ScriptingImplementation.Mono2x);
                    PlayerSettings.Android.targetArchitectures = AndroidArchitecture.ARMv7;
                    Debug.LogWarning(
                        "PAWDO_ANDROID_QA_MONO_BACKEND active for local device validation only.");
                }

                report = BuildPipeline.BuildPlayer(new BuildPlayerOptions
                {
                    scenes = new[] { BootstrapScenePath, GardenScenePath, InteriorScenePath },
                    locationPathName = exportDirectory,
                    target = BuildTarget.Android,
                    options = BuildOptions.AcceptExternalModificationsToPlayer,
                });
            }
            finally
            {
                if (useQaMonoBackend)
                {
                    PlayerSettings.SetScriptingBackend(NamedBuildTarget.Android, originalBackend);
                    PlayerSettings.Android.targetArchitectures = originalArchitectures;
                    AssetDatabase.SaveAssets();
                }
            }

            if (report.summary.result != BuildResult.Succeeded)
            {
                throw new BuildFailedException(
                    $"Pawdo Android Unity Library export failed: {report.summary.result} " +
                    $"({report.summary.totalErrors} errors). See the Unity build log.");
            }

            var unityLibraryDirectory = Path.Combine(exportDirectory, "unityLibrary");
            if (!Directory.Exists(unityLibraryDirectory))
            {
                throw new BuildFailedException(
                    $"Unity reported success but did not create {unityLibraryDirectory}.");
            }

            NormalizeLibraryManifest(unityLibraryDirectory);
            AddPawdoUnityActivity(unityLibraryDirectory);
            AddEmbeddedGradleProperties(unityLibraryDirectory, exportDirectory);

            Debug.Log(
                $"PAWDO_ANDROID_LIBRARY_EXPORT_OK path={exportDirectory} " +
                $"sizeBytes={report.summary.totalSize} duration={report.summary.totalTime}");
        }

        private static string GetExportDirectory()
        {
            var repositoryRoot = Path.GetFullPath(
                Path.Combine(Application.dataPath, "..", "..", ".."));
            return Path.Combine(repositoryRoot, "unity-export", "android");
        }

        private static void NormalizeLibraryManifest(string unityLibraryDirectory)
        {
            const string androidNamespace = "http://schemas.android.com/apk/res/android";
            var manifestPath = Path.Combine(
                unityLibraryDirectory,
                "src",
                "main",
                "AndroidManifest.xml");
            var document = new XmlDocument { PreserveWhitespace = true };
            document.Load(manifestPath);

            var namespaces = new XmlNamespaceManager(document.NameTable);
            namespaces.AddNamespace("android", androidNamespace);
            var activity = document.SelectSingleNode(
                "//activity[@android:name='com.unity3d.player.UnityPlayerGameActivity']",
                namespaces) as XmlElement;
            if (activity == null)
            {
                throw new BuildFailedException(
                    "The exported UnityPlayerGameActivity was not found in the library manifest.");
            }

            activity.SetAttribute("exported", androidNamespace, "false");
            var intentFilters = activity.SelectNodes("intent-filter");
            if (intentFilters != null)
            {
                for (var index = intentFilters.Count - 1; index >= 0; index--)
                {
                    activity.RemoveChild(intentFilters[index]);
                }
            }

            document.Save(manifestPath);
        }

        private static void AddPawdoUnityActivity(string unityLibraryDirectory)
        {
            const string androidNamespace = "http://schemas.android.com/apk/res/android";
            var manifestPath = Path.Combine(
                unityLibraryDirectory,
                "src",
                "main",
                "AndroidManifest.xml");
            var document = new XmlDocument { PreserveWhitespace = true };
            document.Load(manifestPath);

            var namespaces = new XmlNamespaceManager(document.NameTable);
            namespaces.AddNamespace("android", androidNamespace);
            var baseActivity = document.SelectSingleNode(
                "//activity[@android:name='com.unity3d.player.UnityPlayerGameActivity']",
                namespaces) as XmlElement;
            if (baseActivity == null)
            {
                throw new BuildFailedException(
                    "The UnityPlayerGameActivity template was not found for the Pawdo host activity.");
            }

            var pawdoActivity = document.SelectSingleNode(
                $"//activity[@android:name='{PawdoUnityActivityClass}']",
                namespaces) as XmlElement;
            if (pawdoActivity == null)
            {
                pawdoActivity = (XmlElement)baseActivity.CloneNode(true);
                pawdoActivity.SetAttribute("name", androidNamespace, PawdoUnityActivityClass);
                baseActivity.ParentNode?.AppendChild(pawdoActivity);
            }
            pawdoActivity.SetAttribute("launchMode", androidNamespace, "singleTop");
            pawdoActivity.SetAttribute("taskAffinity", androidNamespace, string.Empty);
            document.Save(manifestPath);

            var javaDirectory = Path.Combine(
                unityLibraryDirectory,
                "src",
                "main",
                "java",
                "com",
                "pawdo",
                "app");
            Directory.CreateDirectory(javaDirectory);
            File.WriteAllText(
                Path.Combine(javaDirectory, "PawdoUnityActivity.java"),
                PawdoUnityActivitySource);
        }

        private static void AddEmbeddedGradleProperties(
            string unityLibraryDirectory,
            string exportDirectory)
        {
            const string applyLine = "apply from: 'pawdo-unity-properties.gradle'";
            var propertiesScriptPath = Path.Combine(
                unityLibraryDirectory,
                "pawdo-unity-properties.gradle");
            File.WriteAllText(
                propertiesScriptPath,
                "def pawdoUnityProperties = new Properties()\n" +
                "file('../gradle.properties').withInputStream { pawdoUnityProperties.load(it) }\n" +
                "pawdoUnityProperties.each { key, value -> project.ext.set(key.toString(), value) }\n");

            var buildScriptPath = Path.Combine(unityLibraryDirectory, "build.gradle");
            var buildScript = File.ReadAllText(buildScriptPath);
            if (!buildScript.StartsWith(applyLine, StringComparison.Ordinal))
            {
                File.WriteAllText(
                    buildScriptPath,
                    applyLine + Environment.NewLine + buildScript);
            }

            var rootPropertiesPath = Path.Combine(exportDirectory, "gradle.properties");
            if (!File.Exists(rootPropertiesPath))
            {
                throw new BuildFailedException(
                    "Unity did not export the Gradle properties required by unityLibrary.");
            }
        }
    }
}
