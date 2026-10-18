using NUnit.Framework;
using Pawdo.Interior;
using UnityEngine;

namespace Pawdo.Tests.EditMode
{
    public sealed class PawdoInteriorSleepTests
    {
        [Test]
        public void DoubleBedRequiresTwoDistinctConfiguredAvatarSockets()
        {
            var bedObject = new GameObject("Double bed");
            var bed = bedObject.AddComponent<DoubleBedInteractable>();
            var left = BuildSocket(bedObject.transform, "Left", SleepSocketKind.AvatarLeft);
            var right = BuildSocket(bedObject.transform, "Right", SleepSocketKind.AvatarRight);
            bed.Configure(left, right);

            Assert.That(bed.IsConfigured, Is.True);
            bed.Configure(left, left);
            Assert.That(bed.IsConfigured, Is.False);
            Object.DestroyImmediate(bedObject);
        }

        [Test]
        public void PairReservationIsAtomicUniqueAndReleasable()
        {
            var bedObject = new GameObject("Double bed");
            var bed = bedObject.AddComponent<DoubleBedInteractable>();
            var left = BuildSocket(bedObject.transform, "Left", SleepSocketKind.AvatarLeft);
            var right = BuildSocket(bedObject.transform, "Right", SleepSocketKind.AvatarRight);
            bed.Configure(left, right);

            Assert.That(bed.TryReservePair("jorge", "pareja"), Is.True);
            Assert.That(left.OccupantId, Is.EqualTo("jorge"));
            Assert.That(right.OccupantId, Is.EqualTo("pareja"));
            Assert.That(bed.TryReservePair("otro", "pareja"), Is.False);
            Assert.That(bed.ReleasePair("jorge", "pareja"), Is.True);
            Assert.That(left.IsReserved || right.IsReserved, Is.False);
            Object.DestroyImmediate(bedObject);
        }

        [Test]
        public void PawdoAndAvatarSocketsRejectWrongOccupantKind()
        {
            var root = new GameObject("Sockets");
            var avatar = BuildSocket(root.transform, "Avatar", SleepSocketKind.AvatarLeft);
            var pawdo = BuildSocket(root.transform, "Pawdo", SleepSocketKind.Pawdo);

            Assert.That(avatar.TryReserve("pawdo", SleepOccupantKind.Pawdo), Is.False);
            Assert.That(pawdo.TryReserve("jorge", SleepOccupantKind.Avatar), Is.False);
            Assert.That(avatar.TryReserve("jorge", SleepOccupantKind.Avatar), Is.True);
            Assert.That(pawdo.TryReserve("pawdo", SleepOccupantKind.Pawdo), Is.True);
            Object.DestroyImmediate(root);
        }

        [Test]
        public void ExactColliderHierarchyResolvesOnlyItsOwnBed()
        {
            var doubleRoot = new GameObject("Double bed");
            doubleRoot.AddComponent<DoubleBedInteractable>();
            var doubleChild = new GameObject("Mattress collider");
            doubleChild.transform.SetParent(doubleRoot.transform);
            var doubleCollider = doubleChild.AddComponent<BoxCollider>();
            var pawdoRoot = new GameObject("Pawdo bed");
            pawdoRoot.AddComponent<PawdoBedInteractable>();
            var pawdoCollider = pawdoRoot.AddComponent<BoxCollider>();
            var empty = new GameObject("Empty floor").AddComponent<BoxCollider>();

            Assert.That(InteriorInteractionPolicy.ResolveDoubleBed(doubleCollider), Is.Not.Null);
            Assert.That(InteriorInteractionPolicy.ResolvePawdoBed(doubleCollider), Is.Null);
            Assert.That(InteriorInteractionPolicy.ResolvePawdoBed(pawdoCollider), Is.Not.Null);
            Assert.That(InteriorInteractionPolicy.ResolveDoubleBed(empty), Is.Null);
            Object.DestroyImmediate(doubleRoot);
            Object.DestroyImmediate(pawdoRoot);
            Object.DestroyImmediate(empty.gameObject);
        }

        [Test]
        public void TwentyFiveCyclesPreservePropsSeparationAndContinuousMotion()
        {
            var audit = new SleepCycleAudit(4);
            for (var cycle = 0; cycle < 25; cycle++)
            {
                for (var frame = 0; frame < 20; frame++)
                {
                    audit.ObserveFrameDelta(0.11f);
                    audit.ObserveFrameDelta(0.13f);
                }
                Assert.That(audit.CompleteCycle(4, 1.44f), Is.True);
            }

            Assert.That(audit.CompletedCycles, Is.EqualTo(25));
            Assert.That(audit.TeleportViolations, Is.Zero);
            Assert.That(audit.CollisionViolations, Is.Zero);
            Assert.That(audit.DuplicateViolations, Is.Zero);
        }

        [Test]
        public void AuditDetectsTeleportCollisionAndDuplicateRegression()
        {
            var audit = new SleepCycleAudit(4);
            audit.ObserveFrameDelta(0.9f);
            Assert.That(audit.CompleteCycle(5, 0.20f), Is.False);
            Assert.That(audit.TeleportViolations, Is.EqualTo(1));
            Assert.That(audit.CollisionViolations, Is.EqualTo(1));
            Assert.That(audit.DuplicateViolations, Is.EqualTo(1));
        }

        private static SleepSocket BuildSocket(
            Transform parent,
            string name,
            SleepSocketKind kind)
        {
            var root = new GameObject(name);
            root.transform.SetParent(parent);
            var entry = new GameObject(name + " entry").transform;
            entry.SetParent(parent);
            var exit = new GameObject(name + " exit").transform;
            exit.SetParent(parent);
            var socket = root.AddComponent<SleepSocket>();
            socket.Configure(kind, entry, exit);
            return socket;
        }
    }
}
