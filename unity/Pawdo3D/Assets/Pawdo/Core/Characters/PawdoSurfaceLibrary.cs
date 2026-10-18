using UnityEngine;

namespace Pawdo.Characters
{
    public enum PawdoSurfaceKind { Plain, Wood, Linen }

    public static class PawdoSurfaceLibrary
    {
        // Serialized source materials preserve normal-map variants in Android builds.
        // The caller releases the clone with its other scene materials.
        public static Material Create(PawdoSurfaceKind kind, string name, Color color,
            float metallic, float smoothness, Vector2 tiling)
        {
            var source = kind == PawdoSurfaceKind.Plain ? null :
                Resources.Load<Material>("Surfaces/" + (kind == PawdoSurfaceKind.Wood ? "Wood" : "Linen"));
            var material = source != null ? new Material(source) :
                new Material(Shader.Find("Universal Render Pipeline/Lit") ?? Shader.Find("Standard"));
            material.name = name;
            material.color = color;
            if (material.HasProperty("_BaseColor")) material.SetColor("_BaseColor", color);
            if (material.HasProperty("_Metallic")) material.SetFloat("_Metallic", metallic);
            if (material.HasProperty("_Smoothness")) material.SetFloat("_Smoothness", smoothness);
            if (material.HasProperty("_BaseMap")) material.SetTextureScale("_BaseMap", tiling);
            return material;
        }
    }
}
