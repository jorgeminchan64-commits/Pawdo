using System.IO;
using NUnit.Framework;
using Pawdo.Core.Bridge;
using UnityEngine;

namespace Pawdo.Tests.EditMode
{
    public sealed class PawdoBridgeContractTests
    {
        [Test]
        public void ValidFixtureParsesAndInitializesRouter()
        {
            var json = ReadFixture("runtime_initialize.valid.json");
            Assert.That(PawdoBridgeEnvelope.TryParse(json, out var envelope, out var error), Is.True, error);
            Assert.That(envelope.type, Is.EqualTo("runtime.initialize"));

            var router = new PawdoBridgeRouter();
            var result = router.ReceiveFromFlutter(json);
            Assert.That(result.Accepted, Is.True, result.Code);
            Assert.That(router.Lifecycle, Is.EqualTo(PawdoBridgeLifecycle.Ready));
        }

        [Test]
        public void DuplicateMessageIsRejected()
        {
            var json = ReadFixture("runtime_initialize.valid.json");
            var router = new PawdoBridgeRouter();
            Assert.That(router.ReceiveFromFlutter(json).Accepted, Is.True);
            Assert.That(router.ReceiveFromFlutter(json).Code, Is.EqualTo("duplicate-message"));
        }

        [Test]
        public void InitializedRouterAcceptsBoundedVoiceSignals()
        {
            var router = new PawdoBridgeRouter();
            Assert.That(router.ReceiveFromFlutter(ReadFixture("runtime_initialize.valid.json")).Accepted, Is.True);
            var voiceJson =
                "{\"schemaVersion\":1,\"messageId\":\"02e8af17-6917-4b40-9998-ff51d77890c8\",\"correlationId\":null," +
                "\"type\":\"voice.level\",\"sentAtEpochMs\":1787961600000," +
                "\"payload\":{\"active\":true,\"rms\":0.14,\"peak\":0.28}}";

            var result = router.ReceiveFromFlutter(voiceJson);

            Assert.That(result.Accepted, Is.True, result.Code);
            Assert.That(result.Envelope.type, Is.EqualTo("voice.level"));
        }

        [TestCase("unsupported_schema.invalid.json", "unsupported-schema-version")]
        [TestCase("unknown_type.invalid.json", "unknown-message-type")]
        [TestCase("missing_payload.invalid.json", "invalid-envelope-fields")]
        public void InvalidFixturesAreRejected(string fixtureName, string expectedError)
        {
            var json = ReadFixture(fixtureName);
            Assert.That(PawdoBridgeEnvelope.TryParse(json, out _, out var error), Is.False);
            Assert.That(error, Is.EqualTo(expectedError));
        }

        private static string ReadFixture(string name)
        {
            var path = Path.Combine(Application.dataPath, "StreamingAssets", "PawdoBridgeFixtures", name);
            return File.ReadAllText(path);
        }
    }
}
