using System.Collections;
using System.Reflection;
using NUnit.Framework;
using Pawdo.Characters;
using UnityEngine;
using UnityEngine.TestTools;

namespace Pawdo.Tests.PlayMode
{
    public sealed class PawdoVoicePrivacyTests
    {
        [UnityTest]
        public IEnumerator BackgroundingReleasesAudioAndStopsFacialReaction()
        {
            var root = new GameObject("Voice privacy regression");
            var reaction = root.AddComponent<PawdoVoiceReactionController>();
            var controller = root.AddComponent<PawdoVoiceRepeatController>();
            controller.Configure(reaction);
            var clip = AudioClip.Create("synthetic-test-audio", 22050, 1, 22050, false);
            var flags = BindingFlags.NonPublic | BindingFlags.Instance;
            typeof(PawdoVoiceRepeatController).GetField("recordingClip", flags).SetValue(controller, clip);
            typeof(PawdoVoiceRepeatController).GetField("state", flags)
                .SetValue(controller, PawdoVoiceRepeatState.Playing);
            root.GetComponent<AudioSource>().clip = clip;
            reaction.SetVoiceLevel(0.2f, 0.3f, true);

            root.SendMessage("OnApplicationPause", true, SendMessageOptions.DontRequireReceiver);

            Assert.That(controller.State, Is.EqualTo(PawdoVoiceRepeatState.Idle));
            Assert.That(root.GetComponent<AudioSource>().clip, Is.Null);
            Assert.That(reaction.VoiceActive, Is.False);
            yield return null;
            Assert.That(clip == null, Is.True, "Audio memory must be released after leaving the app.");
            Object.Destroy(root);
            yield return null;
        }
    }
}
