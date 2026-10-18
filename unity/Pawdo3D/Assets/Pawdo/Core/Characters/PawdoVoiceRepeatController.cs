using System;
using System.Collections;
using UnityEngine;

namespace Pawdo.Characters
{
    public enum PawdoVoiceRepeatState
    {
        Idle,
        AwaitingPermission,
        Recording,
        Playing,
        Error,
    }

    public readonly struct PawdoVoiceMetrics
    {
        public PawdoVoiceMetrics(float rms, float peak)
        {
            Rms = rms;
            Peak = peak;
        }

        public float Rms { get; }
        public float Peak { get; }
        public bool HasVoice => Rms >= PawdoVoiceRepeatController.VoiceActivityThreshold;
    }

    [DisallowMultipleComponent]
    public sealed class PawdoVoiceRepeatController : MonoBehaviour
    {
        public const int SampleRate = 22050;
        public const float MaximumRecordSeconds = 10f;
        public const float MinimumRecordSeconds = 0.55f;
        public const float VoiceActivityThreshold = 0.018f;

        private const int AnalysisWindowSamples = 1024;
        private const float PermissionTimeoutSeconds = 8f;
        private const float ErrorVisibleSeconds = 3f;

        private readonly float[] analysisBuffer = new float[AnalysisWindowSamples];
        private PawdoVoiceReactionController reaction;
        private AudioSource playbackSource;
        private AudioClip recordingClip;
        private string microphoneDevice;
        private PawdoVoiceRepeatState state;
        private float recordingStartedAt;
        private float stateChangedAt;
        private int voiceFrames;
        private bool controlPointerActive;
        private int permissionGeneration;
        private int recordedFrames;
        private int lastAnalyzedFrame;
        private int pointerId = -1;
        private GUIStyle labelStyle;
        private string statusMessage;
        public bool InteractionAllowed { get; set; } = true;
        public bool IsBusy => IsRecording || IsPlaying;

        public PawdoVoiceRepeatState State => state;
        public bool IsRecording => state == PawdoVoiceRepeatState.Recording;
        public bool IsPlaying => state == PawdoVoiceRepeatState.Playing;
        public string StatusMessage => statusMessage;

        public void Configure(PawdoVoiceReactionController voiceReaction)
        {
            reaction = voiceReaction;
        }

        public static PawdoVoiceMetrics AnalyzeSamples(float[] samples, int count)
        {
            if (samples == null || count <= 0)
            {
                return new PawdoVoiceMetrics(0f, 0f);
            }

            var safeCount = Mathf.Min(count, samples.Length);
            if (safeCount == 0) return new PawdoVoiceMetrics(0f, 0f);
            var squareSum = 0f;
            var peak = 0f;
            for (var index = 0; index < safeCount; index++)
            {
                var sample = float.IsNaN(samples[index]) || float.IsInfinity(samples[index])
                    ? 0f
                    : Mathf.Clamp(samples[index], -1f, 1f);
                squareSum += sample * sample;
                peak = Mathf.Max(peak, Mathf.Abs(sample));
            }
            return new PawdoVoiceMetrics(Mathf.Sqrt(squareSum / safeCount), peak);
        }

        public static bool IsScreenPointOverControl(Vector2 screenPosition)
        {
            var guiPoint = new Vector2(screenPosition.x, Screen.height - screenPosition.y);
            return GetControlRect().Contains(guiPoint);
        }

        public bool BeginRecording()
        {
            if (!InteractionAllowed) return false;
            if (state == PawdoVoiceRepeatState.Recording ||
                state == PawdoVoiceRepeatState.Playing ||
                state == PawdoVoiceRepeatState.AwaitingPermission)
            {
                return false;
            }

            statusMessage = string.Empty;
            if (!HasMicrophonePermission())
            {
                SetState(PawdoVoiceRepeatState.AwaitingPermission, "Solicitando acceso al micrófono…");
                StartCoroutine(RequestMicrophonePermission());
                return true;
            }

            return BeginRecordingWithPermission();
        }

        public bool FinishRecording()
        {
            if (state != PawdoVoiceRepeatState.Recording)
            {
                return false;
            }

            UpdateMicrophoneSignal();
            EndMicrophoneCapture();
            if (recordingClip == null || recordedFrames < Mathf.CeilToInt(MinimumRecordSeconds * recordingClip.frequency) ||
                voiceFrames < 2)
            {
                ReleaseRecordingClip();
                reaction?.StopVoice();
                SetState(PawdoVoiceRepeatState.Error, "No se detectó una voz clara. Inténtalo de nuevo.");
                return false;
            }

            float[] sourceSamples = null;
            AudioClip playbackClip = null;
            try
            {
                sourceSamples = new float[recordedFrames * recordingClip.channels];
                if (!recordingClip.GetData(sourceSamples, 0)) throw new InvalidOperationException();
                playbackClip = AudioClip.Create(
                    "pawdo_voice_memory",
                    recordedFrames,
                    recordingClip.channels,
                    recordingClip.frequency,
                    false);
                if (!playbackClip.SetData(sourceSamples, 0)) throw new InvalidOperationException();
                Destroy(recordingClip);
                recordingClip = playbackClip;

                playbackSource.clip = recordingClip;
                playbackSource.pitch = 1.16f;
                playbackSource.Play();
                reaction?.SetVoiceLevel(0.12f, 0.20f, true);
                SetState(PawdoVoiceRepeatState.Playing, "Pawdo está repitiendo tu voz…");
                return true;
            }
            catch (Exception)
            {
                playbackSource.Stop();
                playbackSource.clip = null;
                if (playbackClip != null && playbackClip != recordingClip) Destroy(playbackClip);
                ReleaseRecordingClip();
                reaction?.StopVoice();
                SetState(PawdoVoiceRepeatState.Error, "No se pudo reproducir la voz local.");
                return false;
            }
            finally
            {
                if (sourceSamples != null) Array.Clear(sourceSamples, 0, sourceSamples.Length);
            }
        }

        public void Cancel()
        {
            controlPointerActive = false;
            pointerId = -1;
            permissionGeneration++;
            EndMicrophoneCapture();
            if (playbackSource != null)
            {
                playbackSource.Stop();
                playbackSource.clip = null;
            }
            ReleaseRecordingClip();
            Array.Clear(analysisBuffer, 0, analysisBuffer.Length);
            reaction?.StopVoice();
            SetState(PawdoVoiceRepeatState.Idle, string.Empty);
        }

        private void Awake()
        {
            playbackSource = gameObject.AddComponent<AudioSource>();
            playbackSource.playOnAwake = false;
            playbackSource.loop = false;
            playbackSource.spatialBlend = 0f;
            playbackSource.volume = 0.92f;
            playbackSource.priority = 64;
            SetState(PawdoVoiceRepeatState.Idle, string.Empty);
        }

        private void Update()
        {
            HandleVoiceControlPointer();

            if (state == PawdoVoiceRepeatState.AwaitingPermission)
            {
                if (HasMicrophonePermission())
                {
                    // Permission approval is not a held gesture. Require a fresh press.
                    controlPointerActive = false;
                    SetState(PawdoVoiceRepeatState.Idle, string.Empty);
                }
                else if (Time.unscaledTime - stateChangedAt >= PermissionTimeoutSeconds)
                {
                    permissionGeneration++;
                    SetState(PawdoVoiceRepeatState.Error, "Se necesita permiso de micrófono para que Pawdo repita tu voz.");
                }
                return;
            }

            if (state == PawdoVoiceRepeatState.Recording)
            {
                UpdateMicrophoneSignal();
                if (!IsRecording) return;
                if (Time.realtimeSinceStartup - recordingStartedAt >= MaximumRecordSeconds)
                {
                    FinishRecording();
                }
                return;
            }

            if (state == PawdoVoiceRepeatState.Playing)
            {
                UpdatePlaybackSignal();
                if (!playbackSource.isPlaying && Time.unscaledTime - stateChangedAt > 0.12f)
                {
                    playbackSource.clip = null;
                    ReleaseRecordingClip();
                    reaction?.StopVoice();
                    SetState(PawdoVoiceRepeatState.Idle, string.Empty);
                }
                return;
            }

            if (state == PawdoVoiceRepeatState.Error &&
                Time.unscaledTime - stateChangedAt >= ErrorVisibleSeconds)
            {
                SetState(PawdoVoiceRepeatState.Idle, string.Empty);
            }
        }

        private IEnumerator RequestMicrophonePermission()
        {
#if UNITY_ANDROID && !UNITY_EDITOR
            var generation = ++permissionGeneration;
            var callbacks = new UnityEngine.Android.PermissionCallbacks();
            callbacks.PermissionDenied += _ =>
            {
                if (this != null && generation == permissionGeneration &&
                    state == PawdoVoiceRepeatState.AwaitingPermission)
                    SetState(PawdoVoiceRepeatState.Error, "Activa el micrófono en Ajustes para hablar con Pawdo.");
            };
            UnityEngine.Android.Permission.RequestUserPermission(
                UnityEngine.Android.Permission.Microphone, callbacks);
            yield break;
#else
            yield return Application.RequestUserAuthorization(UserAuthorization.Microphone);
#endif
        }

        private static bool HasMicrophonePermission()
        {
#if UNITY_ANDROID && !UNITY_EDITOR
            return UnityEngine.Android.Permission.HasUserAuthorizedPermission(UnityEngine.Android.Permission.Microphone);
#else
            return Application.HasUserAuthorization(UserAuthorization.Microphone);
#endif
        }

        private bool BeginRecordingWithPermission()
        {
            var devices = Microphone.devices;
            if (devices == null || devices.Length == 0)
            {
                SetState(PawdoVoiceRepeatState.Error, "No se encontró un micrófono disponible en este dispositivo.");
                return false;
            }

            ReleaseRecordingClip();
            microphoneDevice = devices[0];
            try
            {
                recordingClip = Microphone.Start(
                    microphoneDevice,
                    false,
                    Mathf.CeilToInt(MaximumRecordSeconds) + 1,
                    SampleRate);
                if (recordingClip == null)
                {
                    SetState(PawdoVoiceRepeatState.Error, "Pawdo no pudo iniciar el micrófono.");
                    return false;
                }
                recordingStartedAt = Time.realtimeSinceStartup;
                voiceFrames = 0;
                recordedFrames = 0;
                lastAnalyzedFrame = 0;
                reaction?.StopVoice();
                SetState(PawdoVoiceRepeatState.Recording, "Suelta para que Pawdo repita tu voz.");
                return true;
            }
            catch (Exception)
            {
                ReleaseRecordingClip();
                SetState(PawdoVoiceRepeatState.Error, "Pawdo no pudo iniciar el micrófono.");
                return false;
            }
        }

        private void UpdateMicrophoneSignal()
        {
            if (recordingClip == null || string.IsNullOrWhiteSpace(microphoneDevice))
            {
                SetState(PawdoVoiceRepeatState.Error, "La captura de voz se interrumpió.");
                return;
            }
            var position = Microphone.GetPosition(microphoneDevice);
            if (position <= 0)
            {
                if (Time.realtimeSinceStartup - recordingStartedAt > 2f)
                {
                    Cancel();
                    SetState(PawdoVoiceRepeatState.Error, "El micrófono está ocupado o no está recibiendo audio.");
                }
                return;
            }
            recordedFrames = Mathf.Min(position, Mathf.FloorToInt(MaximumRecordSeconds * recordingClip.frequency));
            var windowFrames = AnalysisWindowSamples / recordingClip.channels;
            if (position - lastAnalyzedFrame < windowFrames) return;
            lastAnalyzedFrame = position;
            if (!recordingClip.GetData(analysisBuffer, position - windowFrames))
            {
                return;
            }
            var metrics = AnalyzeSamples(analysisBuffer, analysisBuffer.Length);
            if (metrics.HasVoice)
            {
                voiceFrames++;
            }
            // Listening does not articulate words. The mouth follows playback only.
            reaction?.StopVoice();
        }

        private void UpdatePlaybackSignal()
        {
            if (playbackSource == null || !playbackSource.isPlaying)
            {
                return;
            }
            playbackSource.GetOutputData(analysisBuffer, 0);
            var metrics = AnalyzeSamples(analysisBuffer, analysisBuffer.Length);
            reaction?.SetVoiceLevel(metrics.Rms, metrics.Peak, true);
        }

        private void HandleVoiceControlPointer()
        {
            if (Input.touchCount > 0)
            {
                for (var index = 0; index < Input.touchCount; index++)
                {
                    var touch = Input.GetTouch(index);
                    if (touch.phase == TouchPhase.Began && !controlPointerActive && IsScreenPointOverControl(touch.position))
                    {
                        if (IsPlaying) { Cancel(); return; }
                        pointerId = touch.fingerId;
                        controlPointerActive = BeginRecording();
                    }
                    else if (controlPointerActive && touch.fingerId == pointerId &&
                             (touch.phase == TouchPhase.Ended || touch.phase == TouchPhase.Canceled))
                    {
                        controlPointerActive = false;
                        pointerId = -1;
                        if (touch.phase == TouchPhase.Canceled) Cancel(); else FinishRecording();
                    }
                }
                return;
            }

            if (controlPointerActive && pointerId >= 0) { Cancel(); return; }

            if (Input.GetMouseButtonDown(0) && IsScreenPointOverControl(Input.mousePosition))
            {
                if (IsPlaying) { Cancel(); return; }
                pointerId = -1;
                controlPointerActive = BeginRecording();
            }
            else if (controlPointerActive && Input.GetMouseButtonUp(0))
            {
                controlPointerActive = false;
                FinishRecording();
            }
        }

        private void EndMicrophoneCapture()
        {
            if (!string.IsNullOrWhiteSpace(microphoneDevice) && Microphone.IsRecording(microphoneDevice))
            {
                Microphone.End(microphoneDevice);
            }
            microphoneDevice = null;
        }

        private void ReleaseRecordingClip()
        {
            if (recordingClip != null)
            {
                Destroy(recordingClip);
                recordingClip = null;
            }
            Array.Clear(analysisBuffer, 0, analysisBuffer.Length);
        }

        private void SetState(PawdoVoiceRepeatState nextState, string message)
        {
            state = nextState;
            statusMessage = message;
            stateChangedAt = Time.unscaledTime;
        }

        private void OnGUI()
        {
            var controlRect = GetControlRect();
            var previousColor = GUI.color;
            GUI.color = state == PawdoVoiceRepeatState.Recording
                ? new Color(0.57f, 0.18f, 0.26f, 0.96f)
                : new Color(0.12f, 0.10f, 0.12f, 0.92f);
            GUI.Box(controlRect, GUIContent.none);
            GUI.color = previousColor;

            var label = state switch
            {
                PawdoVoiceRepeatState.Recording => "●  SUELTA PARA QUE PAWDO REPITA",
                PawdoVoiceRepeatState.Playing => "Pawdo repite tu voz · toca para detener",
                PawdoVoiceRepeatState.AwaitingPermission => "MICRÓFONO · ACTIVANDO…",
                PawdoVoiceRepeatState.Error => statusMessage,
                _ => InteractionAllowed ? "Mantén para hablar · audio privado en este teléfono" : "Pawdo está descansando",
            };
            labelStyle ??= new GUIStyle(GUI.skin.label)
            {
                alignment = TextAnchor.MiddleCenter,
                fontSize = Mathf.RoundToInt(Mathf.Clamp(Screen.width / 40f, 15f, 23f)),
                fontStyle = FontStyle.Bold,
                wordWrap = true,
                normal = { textColor = Color.white },
            };
            GUI.Label(controlRect, label, labelStyle);
            if (IsRecording)
            {
                var progress = Mathf.Clamp01((Time.realtimeSinceStartup - recordingStartedAt) / MaximumRecordSeconds);
                GUI.color = new Color(0.85f, 0.69f, 0.48f);
                GUI.DrawTexture(new Rect(controlRect.x, controlRect.yMax - 4f, controlRect.width * progress, 4f), Texture2D.whiteTexture);
                GUI.color = previousColor;
            }
        }

        private static Rect GetControlRect()
        {
            var safe = Screen.safeArea;
            var width = Mathf.Min(620f, Mathf.Max(0f, safe.width - 48f));
            var height = 58f;
            var guiSafeBottom = Screen.height - safe.yMin;
            return new Rect(safe.center.x - width * 0.5f, guiSafeBottom - height - 22f, width, height);
        }

        private void OnDisable()
        {
            Cancel();
        }

        private void OnApplicationPause(bool paused)
        {
            if (paused) Cancel();
        }

        private void OnApplicationFocus(bool focused)
        {
            if (!focused) Cancel();
        }

        private void OnDestroy()
        {
            Cancel();
        }
    }
}
