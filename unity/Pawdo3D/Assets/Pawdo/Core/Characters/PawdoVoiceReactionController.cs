using UnityEngine;

namespace Pawdo.Characters
{
    public sealed class PawdoVoiceReactionController : MonoBehaviour
    {
        private const float NoiseFloor = 0.018f;
        private const float FullOpenRms = 0.22f;

        [SerializeField] private Transform head;
        [SerializeField] private Transform lowerJaw;
        [SerializeField] private Transform leftEar;
        [SerializeField] private Transform rightEar;
        private Quaternion headRest;
        private Quaternion jawRest;
        private Quaternion leftEarRest;
        private Quaternion rightEarRest;
        private Vector3 jawRestPosition;
        private float requestedRms;
        private float requestedPeak;
        private bool voiceActive;

        public float CurrentJawOpen { get; private set; }
        public bool VoiceActive => voiceActive;

        public static Transform CreateHeadRig(Transform visualRoot, Transform headMesh)
        {
            var pivot = new GameObject("Pawdo head rig").transform;
            pivot.SetParent(visualRoot, false);
            pivot.position = headMesh.position;
            var parts = new[] { "Head", "Muzzle", "Lower jaw", "Nose", "Left eye", "Right eye", "Left natural ear", "Right natural ear" };
            foreach (var partName in parts)
            {
                var part = visualRoot.Find(partName);
                if (part != null) part.SetParent(pivot, true);
            }
            return pivot;
        }

        public void Configure(
            Transform headTransform,
            Transform jawTransform,
            Transform leftEarTransform,
            Transform rightEarTransform)
        {
            head = headTransform;
            lowerJaw = jawTransform;
            leftEar = leftEarTransform;
            rightEar = rightEarTransform;
            headRest = head != null ? head.localRotation : Quaternion.identity;
            jawRest = lowerJaw != null ? lowerJaw.localRotation : Quaternion.identity;
            jawRestPosition = lowerJaw != null ? lowerJaw.localPosition : Vector3.zero;
            leftEarRest = leftEar != null ? leftEar.localRotation : Quaternion.identity;
            rightEarRest = rightEar != null ? rightEar.localRotation : Quaternion.identity;
        }

        public void SetVoiceLevel(float rms, float peak, bool active)
        {
            requestedRms = Sanitize(rms);
            requestedPeak = Sanitize(peak);
            voiceActive = active;
        }

        public void StopVoice()
        {
            requestedRms = 0f;
            requestedPeak = 0f;
            voiceActive = false;
        }

        public static float NormalizeRms(float rms)
        {
            if (float.IsNaN(rms) || float.IsInfinity(rms)) return 0f;
            return Mathf.Clamp01(Mathf.InverseLerp(NoiseFloor, FullOpenRms, Mathf.Max(0f, rms)));
        }

        public void SimulatePose(float deltaTime, float clock)
        {
            EvaluatePose(Mathf.Max(0f, deltaTime), clock);
        }

        private void Update()
        {
            EvaluatePose(Time.deltaTime, Time.unscaledTime);
        }

        private void EvaluatePose(float deltaTime, float clock)
        {
            var amplitude = voiceActive
                ? Mathf.Max(NormalizeRms(requestedRms), NormalizeRms(requestedPeak) * 0.72f)
                : 0f;
            var articulation = amplitude * (0.78f + Mathf.Abs(Mathf.Sin(clock * 23f)) * 0.22f);
            CurrentJawOpen = Mathf.MoveTowards(CurrentJawOpen, articulation, deltaTime * 8f);
            if (lowerJaw != null)
            {
                lowerJaw.localRotation = jawRest * Quaternion.Euler(22f * CurrentJawOpen, 0f, 0f);
                lowerJaw.localPosition = jawRestPosition + Vector3.down * (0.035f * CurrentJawOpen);
            }
            if (head != null)
            {
                head.localRotation = headRest * Quaternion.Euler(
                    Mathf.Sin(clock * 7f) * CurrentJawOpen * 2.4f,
                    0f,
                    0f);
            }
            if (leftEar != null)
            {
                leftEar.localRotation = leftEarRest * Quaternion.Euler(0f, 0f, -5f * CurrentJawOpen);
            }
            if (rightEar != null)
            {
                rightEar.localRotation = rightEarRest * Quaternion.Euler(0f, 0f, 5f * CurrentJawOpen);
            }
        }

        private static float Sanitize(float value)
        {
            return float.IsNaN(value) || float.IsInfinity(value) ? 0f : Mathf.Clamp01(value);
        }
    }
}
