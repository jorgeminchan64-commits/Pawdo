using NUnit.Framework;
using Pawdo.Characters;
using UnityEngine;

namespace Pawdo.Tests.EditMode
{
    public sealed class PawdoVoiceReactionTests
    {
        [Test]
        public void RmsNormalizationRejectsInvalidValuesAndKeepsNoiseClosed()
        {
            Assert.That(PawdoVoiceReactionController.NormalizeRms(float.NaN), Is.Zero);
            Assert.That(PawdoVoiceReactionController.NormalizeRms(float.PositiveInfinity), Is.Zero);
            Assert.That(PawdoVoiceReactionController.NormalizeRms(0.01f), Is.Zero);
            Assert.That(PawdoVoiceReactionController.NormalizeRms(0.22f), Is.EqualTo(1f).Within(0.001f));
        }

        [Test]
        public void EmptyOrInvalidAudioNeverProducesSpeechOrNonFiniteLevels()
        {
            var empty = PawdoVoiceRepeatController.AnalyzeSamples(new float[0], 32);
            Assert.That(empty.Rms, Is.Zero);
            Assert.That(empty.HasVoice, Is.False);
            var invalid = PawdoVoiceRepeatController.AnalyzeSamples(
                new[] { float.NaN, float.PositiveInfinity, 0f }, 3);
            Assert.That(invalid.Rms, Is.Zero);
            Assert.That(invalid.Peak, Is.Zero);
        }

        [Test]
        public void IsolatedClickIsNotSpeechButSustainedVoiceIs()
        {
            var click = new float[1024];
            click[64] = 0.08f;
            Assert.That(PawdoVoiceRepeatController.AnalyzeSamples(click, click.Length).HasVoice, Is.False);
            var voice = new[] { 0.12f, -0.12f, 0.12f, -0.12f };
            Assert.That(PawdoVoiceRepeatController.AnalyzeSamples(voice, 4).Rms,
                Is.EqualTo(0.12f).Within(0.0001f));
            Assert.That(PawdoVoiceRepeatController.AnalyzeSamples(voice, 4).HasVoice, Is.True);
        }

        [Test]
        public void ActiveVoiceMovesJawAndStopReturnsToRest()
        {
            var root = new GameObject("Pawdo voice test");
            var head = new GameObject("Head").transform;
            var jaw = new GameObject("Lower jaw").transform;
            var leftEar = new GameObject("Left ear").transform;
            var rightEar = new GameObject("Right ear").transform;
            head.SetParent(root.transform);
            jaw.SetParent(root.transform);
            leftEar.SetParent(root.transform);
            rightEar.SetParent(root.transform);
            var jawRest = jaw.localRotation;
            var reaction = root.AddComponent<PawdoVoiceReactionController>();
            reaction.Configure(head, jaw, leftEar, rightEar);

            reaction.SetVoiceLevel(0.16f, 0.20f, true);
            reaction.SimulatePose(0.2f, 0.8f);

            Assert.That(reaction.VoiceActive, Is.True);
            Assert.That(reaction.CurrentJawOpen, Is.GreaterThan(0.4f));
            Assert.That(Quaternion.Angle(jawRest, jaw.localRotation), Is.GreaterThan(5f));

            reaction.StopVoice();
            for (var step = 0; step < 10; step++)
            {
                reaction.SimulatePose(0.1f, 1f + step * 0.1f);
            }

            Assert.That(reaction.CurrentJawOpen, Is.Zero.Within(0.001f));
            Assert.That(Quaternion.Angle(jawRest, jaw.localRotation), Is.LessThan(0.1f));
            Object.DestroyImmediate(root);
        }

        [Test]
        public void SilenceDuringPlaybackDoesNotMakePawdoSpeak()
        {
            var root = new GameObject("Silent playback");
            try
            {
                var reaction = root.AddComponent<PawdoVoiceReactionController>();
                reaction.SetVoiceLevel(0f, 0f, true);
                reaction.SimulatePose(0.3f, 1.4f);
                Assert.That(reaction.CurrentJawOpen, Is.Zero);
            }
            finally { Object.DestroyImmediate(root); }
        }

        [Test]
        public void HeadMovementCarriesMuzzleAndEyesWithoutChangingTheirRestPositions()
        {
            var root = new GameObject("Pawdo rig");
            try
            {
                var head = new GameObject("Head").transform;
                head.SetParent(root.transform);
                head.localPosition = new Vector3(0f, 0.6f, 0.3f);
                head.localScale = new Vector3(0.25f, 0.27f, 0.24f);
                var eye = new GameObject("Left eye").transform;
                eye.SetParent(root.transform);
                eye.localPosition = new Vector3(-0.08f, 0.7f, 0.5f);
                var before = eye.position;
                var pivot = PawdoVoiceReactionController.CreateHeadRig(root.transform, head);
                Assert.That(Vector3.Distance(eye.position, before), Is.LessThan(0.0001f));
                pivot.localRotation = Quaternion.Euler(15f, 0f, 0f);
                Assert.That(Vector3.Distance(eye.position, before), Is.GreaterThan(0.02f));
                Assert.That(Vector3.Distance(eye.position, pivot.position),
                    Is.EqualTo(Vector3.Distance(before, pivot.position)).Within(0.0001f));
            }
            finally { Object.DestroyImmediate(root); }
        }
    }
}
