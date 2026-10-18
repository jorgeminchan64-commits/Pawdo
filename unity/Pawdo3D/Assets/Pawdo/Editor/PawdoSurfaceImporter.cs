using System.IO;
using UnityEditor;
using UnityEngine;

namespace Pawdo.Editor
{
    [InitializeOnLoad]
    public sealed class PawdoSurfaceImporter : AssetPostprocessor
    {
        private const string DirectoryPath = "Assets/Pawdo/Resources/Surfaces/";

        static PawdoSurfaceImporter()
        {
            EditorApplication.delayCall += EnsureMaterials;
        }

        private void OnPreprocessTexture()
        {
            if (!assetPath.StartsWith(DirectoryPath)) return;
            var importer = (TextureImporter)assetImporter;
            importer.textureType = assetPath.Contains("_normal")
                ? TextureImporterType.NormalMap : TextureImporterType.Default;
            importer.sRGBTexture = importer.textureType != TextureImporterType.NormalMap;
            importer.mipmapEnabled = true;
            importer.isReadable = false;
            importer.wrapMode = TextureWrapMode.Repeat;
            importer.anisoLevel = 4;
            importer.maxTextureSize = 1024;
            importer.SetPlatformTextureSettings(new TextureImporterPlatformSettings
            {
                name = "Android", overridden = true, maxTextureSize = 1024,
                format = TextureImporterFormat.ASTC_6x6, compressionQuality = 70,
            });
        }

        private static void OnPostprocessAllAssets(string[] imported, string[] deleted,
            string[] moved, string[] movedFrom)
        {
            foreach (var path in imported)
                if (path.StartsWith(DirectoryPath) && path.EndsWith(".jpg"))
                {
                    EditorApplication.delayCall += EnsureMaterials;
                    break;
                }
        }

        public static void EnsureMaterials()
        {
            if (EditorApplication.isCompiling || EditorApplication.isUpdating)
            {
                EditorApplication.delayCall += EnsureMaterials;
                return;
            }
            CreateIfMissing("Wood", "wood_floor_diff.jpg", "wood_floor_normal.jpg", 0.32f, 0.38f);
            CreateIfMissing("Linen", null, "linen_normal.jpg", 0.18f, 0.45f);
        }

        private static void CreateIfMissing(string name, string albedoName, string normalName,
            float smoothness, float normalStrength)
        {
            var path = DirectoryPath + name + ".mat";
            if (File.Exists(path)) return;
            var normal = AssetDatabase.LoadAssetAtPath<Texture2D>(DirectoryPath + normalName);
            var albedo = albedoName == null ? null : AssetDatabase.LoadAssetAtPath<Texture2D>(DirectoryPath + albedoName);
            if (normal == null || (albedoName != null && albedo == null)) return;
            var material = new Material(Shader.Find("Universal Render Pipeline/Lit")) { name = name };
            material.SetTexture("_BaseMap", albedo);
            material.SetTexture("_BumpMap", normal);
            material.SetFloat("_BumpScale", normalStrength);
            material.SetFloat("_Smoothness", smoothness);
            material.EnableKeyword("_NORMALMAP");
            AssetDatabase.CreateAsset(material, path);
        }
    }
}
