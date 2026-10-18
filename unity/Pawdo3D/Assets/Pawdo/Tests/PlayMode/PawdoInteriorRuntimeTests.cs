using System.Collections;
using NUnit.Framework;
using Pawdo.Characters;
using Pawdo.Interior;
using UnityEngine;
using UnityEngine.TestTools;

namespace Pawdo.Tests.PlayMode
{
    public sealed class PawdoInteriorRuntimeTests
    {
        [UnityTest]
        public IEnumerator InteriorSliceBuildsOneCoherentTrueThreeDimensionalRoom()
        {
            var root = new GameObject("VS3 runtime test");
            var controller = root.AddComponent<PawdoInteriorSliceController>();
            yield return null;

            Assert.That(controller.DoubleBed, Is.Not.Null);
            Assert.That(controller.DoubleBed.IsConfigured, Is.True);
            Assert.That(controller.DoubleBed.LeftSocket, Is.Not.SameAs(controller.DoubleBed.RightSocket));
            Assert.That(controller.PawdoBed, Is.Not.Null);
            Assert.That(controller.PawdoBed.IsConfigured, Is.True);
            Assert.That(controller.PawdoBed.SleepSocket.CanHost(SleepOccupantKind.Avatar), Is.False);
            Assert.That(Object.FindObjectsByType<ProceduralAvatarMotor>(FindObjectsSortMode.None).Length, Is.EqualTo(2));
            Assert.That(Object.FindObjectsByType<ProceduralPawdoMotor>(FindObjectsSortMode.None).Length, Is.EqualTo(1));
            Assert.That(Object.FindObjectsByType<PawdoVoiceReactionController>(FindObjectsSortMode.None).Length, Is.EqualTo(1));
            Assert.That(Object.FindObjectsByType<PawdoVoiceRepeatController>(FindObjectsSortMode.None).Length, Is.EqualTo(1));
            Assert.That(Object.FindObjectsByType<AudioListener>(FindObjectsSortMode.None).Length, Is.EqualTo(1));
            Assert.That(Object.FindObjectsByType<MeshRenderer>(FindObjectsSortMode.None).Length, Is.GreaterThan(75));
            Assert.That(Object.FindObjectsByType<InteriorStableProp>(FindObjectsSortMode.None).Length, Is.EqualTo(4));
            Object.Destroy(root);
            yield return null;
        }

        [UnityTest]
        [Timeout(120000)]
        public IEnumerator TwentyFiveRuntimeBedCyclesFinishWithoutTeleportCollisionOrDuplication()
        {
            var root = new GameObject("VS3 cycle runtime test");
            var controller = root.AddComponent<PawdoInteriorSliceController>();
            yield return null;
            yield return null;
            Assert.That(controller.BeginQaCycles(25), Is.True);

            var timeout = 105f;
            while (controller.QaRunning && timeout > 0f)
            {
                timeout -= Time.deltaTime;
                yield return null;
            }

            Assert.That(timeout, Is.GreaterThan(0f), "The 25-cycle QA sequence timed out.");
            Assert.That(controller.CompletedCycles, Is.EqualTo(25));
            Assert.That(controller.PairState, Is.EqualTo(PairSleepState.Awake));
            Assert.That(controller.TeleportViolations, Is.Zero);
            Assert.That(controller.CollisionViolations, Is.Zero);
            Assert.That(controller.DuplicateViolations, Is.Zero);
            Assert.That(controller.SupportViolations, Is.Zero);
            Assert.That(controller.DoubleBed.LeftSocket.IsReserved, Is.False);
            Assert.That(controller.DoubleBed.RightSocket.IsReserved, Is.False);
            Object.Destroy(root);
            yield return null;
        }

        [UnityTest]
        [Timeout(20000)]
        public IEnumerator SleepingAvatarsRemainFullySupportedByTheDoubleBed()
        {
            var root = new GameObject("VS3 bed support runtime test");
            var controller = root.AddComponent<PawdoInteriorSliceController>();
            yield return null;
            yield return null;
            Assert.That(controller.BeginPairSleep(), Is.True);

            var timeout = 12f;
            while (controller.PairState != PairSleepState.Sleeping && timeout > 0f)
            {
                timeout -= Time.deltaTime;
                yield return null;
            }

            Assert.That(timeout, Is.GreaterThan(0f), "The pair did not reach the sleeping pose.");
            Assert.That(controller.SleepingAvatarsSupportedByBed, Is.True);
            Assert.That(controller.SupportViolations, Is.Zero);
            Object.Destroy(root);
            yield return null;
        }
    }
}
