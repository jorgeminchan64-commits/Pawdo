using NUnit.Framework;
using Pawdo.Characters;
using Pawdo.Garden;
using UnityEngine;

namespace Pawdo.Tests.EditMode
{
    public sealed class PawdoGardenPolicyTests
    {
        [Test]
        public void OneHundredEmptyCollidersResolveZeroPlantsAndZeroWaterings()
        {
            var completedWaterings = 0;
            for (var index = 0; index < 100; index++)
            {
                var empty = new GameObject("Empty surface " + index);
                var collider = empty.AddComponent<BoxCollider>();
                var resolved = GardenInteractionPolicy.ResolvePlant(collider);
                if (resolved != null && resolved.TryBeginWatering())
                {
                    resolved.CompleteWatering();
                    completedWaterings++;
                }
                Object.DestroyImmediate(empty);
            }

            Assert.That(completedWaterings, Is.Zero);
        }

        [Test]
        public void PlantResolvesOnlyThroughItsOwnColliderHierarchy()
        {
            var plantObject = new GameObject("Plant");
            var socket = new GameObject("WateringSocket").transform;
            socket.SetParent(plantObject.transform);
            var plant = plantObject.AddComponent<PlantInteractable>();
            plant.Configure(socket);
            var child = new GameObject("Collider");
            child.transform.SetParent(plantObject.transform);
            var collider = child.AddComponent<BoxCollider>();

            Assert.That(GardenInteractionPolicy.ResolvePlant(collider), Is.SameAs(plant));
            Assert.That(plant.TryBeginWatering(), Is.True);
            plant.CompleteWatering();
            Assert.That(plant.CompletedWaterings, Is.EqualTo(1));
            Assert.That(plant.TryBeginWatering(), Is.False);
            Object.DestroyImmediate(plantObject);
        }

        [Test]
        public void OneHundredHorizontalMovesAlwaysFaceTheirRealDirection()
        {
            var fallback = Quaternion.Euler(0f, 37f, 0f);
            for (var index = 0; index < 100; index++)
            {
                var direction = index % 2 == 0 ? Vector3.right : Vector3.left;
                var resolved = AvatarFacingPolicy.ResolveRotation(direction, fallback);
                Assert.That(
                    AvatarFacingPolicy.FacesMovement(resolved, direction, 0.999f),
                    Is.True,
                    "Horizontal movement failed at index " + index);
            }
        }

        [Test]
        public void OneHundredEmptyPlacementsAreRejected()
        {
            var policy = new GardenPlacementPolicy(new Bounds(Vector3.zero, Vector3.one * 10f));
            for (var index = 0; index < 100; index++)
            {
                var decision = policy.Evaluate(Vector3.zero, null, false);
                Assert.That(decision.IsValid, Is.False);
                Assert.That(decision.Status, Is.EqualTo(GardenPlacementStatus.MissingSurface));
            }
        }

        [Test]
        public void RepeatedEndedFramesNeverDuplicateOneAndroidGesture()
        {
            for (var index = 0; index < 100; index++)
            {
                Assert.That(PointerGesturePolicy.ShouldTrigger(TouchPhase.Ended, false), Is.False);
            }
            Assert.That(PointerGesturePolicy.ShouldTrigger(TouchPhase.Began, false), Is.True);
            Assert.That(PointerGesturePolicy.ShouldTrigger(TouchPhase.Began, true), Is.False);
        }

        [Test]
        public void PlacementRequiresPlanterZoneInsideBoundsWithoutOverlap()
        {
            var surfaceObject = new GameObject("Planter plot");
            var surface = surfaceObject.AddComponent<GardenSemanticSurface>();
            surface.Configure(GardenSemanticZone.PlanterPlot, true);
            var policy = new GardenPlacementPolicy(new Bounds(Vector3.zero, Vector3.one * 10f));

            Assert.That(policy.Evaluate(Vector3.zero, surface, false).IsValid, Is.True);
            Assert.That(policy.Evaluate(Vector3.zero, surface, true).Status, Is.EqualTo(GardenPlacementStatus.Blocked));
            Assert.That(policy.Evaluate(Vector3.one * 12f, surface, false).Status, Is.EqualTo(GardenPlacementStatus.OutsideEditableBounds));
            surface.Configure(GardenSemanticZone.FreeGrass, false);
            Assert.That(policy.Evaluate(Vector3.zero, surface, false).Status, Is.EqualTo(GardenPlacementStatus.WrongSemanticZone));
            Object.DestroyImmediate(surfaceObject);
        }
    }
}
