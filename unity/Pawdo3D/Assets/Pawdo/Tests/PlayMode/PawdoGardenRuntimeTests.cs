using System.Collections;
using NUnit.Framework;
using Pawdo.Characters;
using Pawdo.Garden;
using UnityEngine;
using UnityEngine.TestTools;

namespace Pawdo.Tests.PlayMode
{
    public sealed class PawdoGardenRuntimeTests
    {
        [UnityTest]
        public IEnumerator GardenSliceBuildsTrueThreeDimensionalSceneWithRequiredSemantics()
        {
            PlayerPrefs.DeleteKey(PawdoGardenSliceController.LayoutStorageKey);
            var root = new GameObject("VS2 runtime test");
            var controller = root.AddComponent<PawdoGardenSliceController>();
            yield return null;

            Assert.That(controller.HeroPlant, Is.Not.Null);
            Assert.That(controller.HeroPlant.WateringSocket, Is.Not.Null);
            Assert.That(controller.PrimaryAvatar, Is.Not.Null);
            Assert.That(Object.FindObjectsByType<MeshRenderer>(FindObjectsSortMode.None).Length, Is.GreaterThan(80));
            Assert.That(Object.FindObjectsByType<GardenSemanticSurface>(FindObjectsSortMode.None).Length, Is.GreaterThanOrEqualTo(8));
            Assert.That(Object.FindObjectsByType<ProceduralAvatarMotor>(FindObjectsSortMode.None).Length, Is.EqualTo(2));
            Assert.That(Object.FindObjectsByType<ProceduralPawdoMotor>(FindObjectsSortMode.None).Length, Is.EqualTo(1));
            Assert.That(Object.FindObjectsByType<PawdoVoiceReactionController>(FindObjectsSortMode.None).Length, Is.EqualTo(1));
            Assert.That(Object.FindObjectsByType<PawdoVoiceRepeatController>(FindObjectsSortMode.None).Length, Is.EqualTo(1));
            Assert.That(Object.FindObjectsByType<AudioListener>(FindObjectsSortMode.None).Length, Is.EqualTo(1));
            Object.Destroy(root);
            yield return null;
        }

        [UnityTest]
        public IEnumerator EmptyPhysicsRaysCannotResolvePlantInteraction()
        {
            var ground = GameObject.CreatePrimitive(PrimitiveType.Cube);
            ground.name = "Empty ground";
            ground.transform.localScale = new Vector3(20f, 0.1f, 20f);
            ground.transform.position = new Vector3(0f, -0.05f, 0f);
            yield return new WaitForFixedUpdate();

            var resolved = 0;
            for (var index = 0; index < 100; index++)
            {
                var origin = new Vector3(-4.5f + index * 0.09f, 5f, 0f);
                Assert.That(Physics.Raycast(new Ray(origin, Vector3.down), out var hit, 10f), Is.True);
                if (GardenInteractionPolicy.ResolvePlant(hit.collider) != null)
                {
                    resolved++;
                }
            }
            Assert.That(resolved, Is.Zero);
            Object.Destroy(ground);
        }
    }
}
