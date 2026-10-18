using System.Collections;
using NUnit.Framework;
using Pawdo.Characters;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.TestTools;

namespace Pawdo.Tests.PlayMode
{
    public sealed class PawdoMaterialRenderingTests
    {
        [UnityTest]
        public IEnumerator RuntimeMaterialsKeepIndependentColorsOnTheGpu()
        {
            if (SystemInfo.graphicsDeviceType == GraphicsDeviceType.Null)
                Assert.Ignore("GPU regression: run PlayMode with -force-d3d11, without -nographics.");
            var root = new GameObject("Material render regression");
            var red = PawdoSurfaceLibrary.Create(PawdoSurfaceKind.Plain, "Red sample",
                Color.red, 0f, 0f, Vector2.one);
            var blue = PawdoSurfaceLibrary.Create(PawdoSurfaceKind.Plain, "Blue sample",
                Color.blue, 0f, 0f, Vector2.one);
            var target = new RenderTexture(64, 32, 24);
            var pixels = new Texture2D(64, 32, TextureFormat.RGB24, false);
            var previous = RenderTexture.active;
            try
            {
                for (var i = 0; i < 2; i++)
                {
                    var sample = GameObject.CreatePrimitive(PrimitiveType.Cube);
                    sample.transform.SetParent(root.transform);
                    sample.transform.position = new Vector3(i == 0 ? -1f : 1f, 0f, 0f);
                    sample.transform.localScale = new Vector3(1.5f, 1.5f, 0.2f);
                    sample.layer = 31;
                    sample.GetComponent<Renderer>().sharedMaterial = i == 0 ? red : blue;
                }
                var camera = new GameObject("Regression camera").AddComponent<Camera>();
                camera.transform.SetParent(root.transform);
                camera.transform.position = new Vector3(0f, 0f, -10f);
                camera.orthographic = true;
                camera.orthographicSize = 1f;
                camera.aspect = 2f;
                camera.cullingMask = 1 << 31;
                camera.clearFlags = CameraClearFlags.SolidColor;
                camera.backgroundColor = Color.black;
                var light = new GameObject("Regression light").AddComponent<Light>();
                light.transform.SetParent(root.transform);
                light.type = LightType.Directional;
                light.intensity = 2f;
                light.cullingMask = 1 << 31;
                yield return null;
                yield return null;
                RenderPipeline.SubmitRenderRequest(camera,
                    new UniversalRenderPipeline.SingleCameraRequest { destination = target });
                RenderTexture.active = target;
                pixels.ReadPixels(new Rect(0, 0, 64, 32), 0, 0);
                pixels.Apply();
                var left = pixels.GetPixel(16, 16);
                var right = pixels.GetPixel(48, 16);
                Assert.That(left.r, Is.GreaterThan(left.b + 0.2f), $"Red material bled: {left}");
                Assert.That(right.b, Is.GreaterThan(right.r + 0.2f), $"Blue material bled: {right}");
            }
            finally
            {
                RenderTexture.active = previous;
                target.Release();
                Object.Destroy(root);
                Object.Destroy(red);
                Object.Destroy(blue);
                Object.Destroy(target);
                Object.Destroy(pixels);
            }
            yield return null;
        }
    }
}
