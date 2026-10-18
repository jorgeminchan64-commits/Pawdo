using System.Collections;
using System.Collections.Generic;
using Pawdo.Characters;
using Pawdo.Garden;
using UnityEngine;
using UnityEngine.AI;

namespace Pawdo.Interior
{
    public sealed class PawdoInteriorSliceController : MonoBehaviour
    {
        private const string PrimaryId = "avatar.primary";
        private const string PartnerId = "avatar.partner";
        private const string PawdoId = "pawdo.pet";

        private readonly List<Material> runtimeMaterials = new List<Material>();
        private Camera sceneCamera;
        private NavMeshData navMeshData;
        private NavMeshDataInstance navMeshInstance;
        private AvatarBinding primary;
        private AvatarBinding partner;
        private PawdoBinding pawdo;
        private DoubleBedInteractable doubleBed;
        private PawdoBedInteractable pawdoBed;
        private SleepCycleAudit audit;
        private PairSleepState pairState = PairSleepState.Awake;
        private bool pairBusy;
        private bool pawdoBusy;
        private bool pawdoSleeping;
        private bool pointerConsumed;
        private bool qaRunning;
        private int qaTarget;
        private int pawdoCycles;
        private int supportViolations;
        private bool frameTrackingReady;
        private PawdoVoiceRepeatController voiceController;
        private Vector3 previousPrimaryPosition;
        private Vector3 previousPartnerPosition;
        private GUIStyle titleStyle;
        private GUIStyle bodyStyle;
        private GUIStyle metricStyle;
        private Rect topPanel;
        private Rect pairButton;
        private Rect pawdoButton;
        private Rect qaButton;

        public ProceduralAvatarMotor PrimaryAvatar => primary?.Motor;
        public ProceduralAvatarMotor PartnerAvatar => partner?.Motor;
        public ProceduralPawdoMotor Pawdo => pawdo?.Motor;
        public DoubleBedInteractable DoubleBed => doubleBed;
        public PawdoBedInteractable PawdoBed => pawdoBed;
        public PairSleepState PairState => pairState;
        public int CompletedCycles => audit?.CompletedCycles ?? 0;
        public int TeleportViolations => audit?.TeleportViolations ?? 0;
        public int CollisionViolations => audit?.CollisionViolations ?? 0;
        public int DuplicateViolations => audit?.DuplicateViolations ?? 0;
        public int PawdoCycles => pawdoCycles;
        public int SupportViolations => supportViolations;
        public bool QaRunning => qaRunning;
        public bool SleepingAvatarsSupportedByBed =>
            pairState == PairSleepState.Sleeping &&
            IsAvatarSupportedByDoubleBed(primary) &&
            IsAvatarSupportedByDoubleBed(partner);

        private void Awake()
        {
            Application.targetFrameRate = 60;
            QualitySettings.vSyncCount = 0;
            BuildInterior();
            BuildNavigation();
            SpawnCharacters();
            audit = new SleepCycleAudit(CountStableProps());
            previousPrimaryPosition = primary.Root.position;
            previousPartnerPosition = partner.Root.position;
            Debug.Log(
                $"PAWDO_VS3_READY scene=InteriorSlice doubleBed={doubleBed.IsConfigured} " +
                $"pawdoBed={pawdoBed.IsConfigured} stableProps={CountStableProps()} thirdPartyAssets=0");
        }

        private void Update()
        {
            UpdatePointerRects();
            if (voiceController != null)
                voiceController.InteractionAllowed = !pawdoBusy && !pawdoSleeping && !qaRunning;
            if (TryReadTriggeredPointer(out var screenPosition))
            {
                pointerConsumed = true;
                if (!IsPointerOverUi(screenPosition))
                {
                    HandleWorldTap(screenPosition);
                }
            }

            if (Input.touchCount == 0 && !Input.GetMouseButton(0))
            {
                pointerConsumed = false;
            }
        }

        private void LateUpdate()
        {
            if (primary == null || partner == null || audit == null)
            {
                return;
            }

            if (frameTrackingReady)
            {
                audit.ObserveFrameDelta(Vector3.Distance(previousPrimaryPosition, primary.Root.position));
                audit.ObserveFrameDelta(Vector3.Distance(previousPartnerPosition, partner.Root.position));
            }
            previousPrimaryPosition = primary.Root.position;
            previousPartnerPosition = partner.Root.position;
            frameTrackingReady = true;
        }

        private void OnDestroy()
        {
            if (navMeshInstance.valid)
            {
                navMeshInstance.Remove();
            }
            if (navMeshData != null)
            {
                Destroy(navMeshData);
            }
            foreach (var material in runtimeMaterials)
            {
                if (material != null)
                {
                    Destroy(material);
                }
            }
        }

        public bool BeginPairSleep()
        {
            if (pairBusy || qaRunning || pairState != PairSleepState.Awake)
            {
                return false;
            }
            StartCoroutine(RunNormalPairSleep());
            return true;
        }

        public bool BeginPairWake()
        {
            if (pairBusy || qaRunning || pairState != PairSleepState.Sleeping)
            {
                return false;
            }
            StartCoroutine(RunNormalPairWake());
            return true;
        }

        public bool BeginPawdoBedToggle()
        {
            if (pawdoBusy || qaRunning)
            {
                return false;
            }
            voiceController?.Cancel();
            StartCoroutine(pawdoSleeping ? WakePawdoSequence(1f) : SleepPawdoSequence(1f));
            return true;
        }

        public bool BeginQaCycles(int cycles = 25)
        {
            if (cycles <= 0 || qaRunning || pairBusy || pairState != PairSleepState.Awake)
            {
                return false;
            }
            voiceController?.Cancel();
            StartCoroutine(RunQaCycles(cycles));
            return true;
        }

        private IEnumerator RunNormalPairSleep()
        {
            pairBusy = true;
            yield return SleepPairSequence(1f);
            pairBusy = false;
        }

        private IEnumerator RunNormalPairWake()
        {
            pairBusy = true;
            yield return WakePairSequence(1f);
            pairBusy = false;
        }

        private IEnumerator RunQaCycles(int cycles)
        {
            qaRunning = true;
            qaTarget = cycles;
            for (var index = 0; index < cycles; index++)
            {
                yield return SleepPairSequence(2f);
                if (pairState != PairSleepState.Sleeping)
                {
                    break;
                }
                yield return new WaitForSeconds(0.04f);
                yield return WakePairSequence(2f);
                if (pairState != PairSleepState.Awake)
                {
                    break;
                }
            }
            qaRunning = false;
            qaTarget = 0;
            Debug.Log(
                $"PAWDO_VS3_QA_COMPLETE cycles={CompletedCycles} teleports={TeleportViolations} " +
                $"collisions={CollisionViolations} duplicates={DuplicateViolations} support={supportViolations}");
        }

        private IEnumerator SleepPairSequence(float speedMultiplier)
        {
            if (!doubleBed.TryReservePair(PrimaryId, PartnerId))
            {
                Debug.LogError("PAWDO_VS3_RESERVATION_FAILED phase=sleep");
                yield break;
            }

            pairState = PairSleepState.WalkingToEntries;
            var primaryAccepted = primary.Motor.MoveToInteraction(doubleBed.LeftSocket.EntryPoint.position);
            var partnerAccepted = partner.Motor.MoveToInteraction(doubleBed.RightSocket.EntryPoint.position);
            if (!primaryAccepted || !partnerAccepted)
            {
                AbortPairReservation();
                yield break;
            }

            SetAgentSpeed(primary.Agent, speedMultiplier);
            SetAgentSpeed(partner.Agent, speedMultiplier);
            yield return WaitForPairArrival(Mathf.Max(3f, 6f / Mathf.Max(1f, speedMultiplier)));
            if (!primary.Motor.HasArrived || !partner.Motor.HasArrived)
            {
                AbortPairReservation();
                yield break;
            }

            primary.Motor.Face(doubleBed.transform.position);
            partner.Motor.Face(doubleBed.transform.position);
            DisableAgentAtCurrentPose(primary);
            DisableAgentAtCurrentPose(partner);
            primary.Motor.StabilizeInteractionPose();
            partner.Motor.StabilizeInteractionPose();

            pairState = PairSleepState.SittingDown;
            yield return AnimatePairPose(
                doubleBed.LeftSocket,
                doubleBed.RightSocket,
                0.34f,
                34f,
                0.42f / speedMultiplier);
            pairState = PairSleepState.LyingDown;
            yield return AnimatePairPose(
                doubleBed.LeftSocket,
                doubleBed.RightSocket,
                1f,
                90f,
                0.68f / speedMultiplier);

            pairState = PairSleepState.Sleeping;
            var supported = SleepingAvatarsSupportedByBed;
            if (!supported)
            {
                supportViolations++;
            }
            Debug.Log(
                $"PAWDO_VS3_PAIR_SLEEPING left={doubleBed.LeftSocket.OccupantId} " +
                $"right={doubleBed.RightSocket.OccupantId} separation={Vector3.Distance(primary.Root.position, partner.Root.position):F3} " +
                $"supported={supported} bed={doubleBed.transform.position} leftSocket={doubleBed.LeftSocket.transform.position} " +
                $"primary={primary.Root.position}");
        }

        private IEnumerator WakePairSequence(float speedMultiplier)
        {
            if (pairState != PairSleepState.Sleeping ||
                doubleBed.LeftSocket.OccupantId != PrimaryId ||
                doubleBed.RightSocket.OccupantId != PartnerId)
            {
                yield break;
            }

            pairState = PairSleepState.Rising;
            yield return AnimatePairFromBed(
                doubleBed.LeftSocket,
                doubleBed.RightSocket,
                0.34f,
                34f,
                0.42f / speedMultiplier);
            yield return AnimatePairFromBed(
                doubleBed.LeftSocket,
                doubleBed.RightSocket,
                0f,
                0f,
                0.68f / speedMultiplier);

            EnableAgentAtEntry(primary, doubleBed.LeftSocket.EntryPoint.position);
            EnableAgentAtEntry(partner, doubleBed.RightSocket.EntryPoint.position);
            primary.Motor.FinishInteraction();
            partner.Motor.FinishInteraction();
            pairState = PairSleepState.WalkingToExits;
            SetAgentSpeed(primary.Agent, speedMultiplier);
            SetAgentSpeed(partner.Agent, speedMultiplier);
            var primaryAccepted = primary.Motor.MoveToInteraction(doubleBed.LeftSocket.ExitPoint.position);
            var partnerAccepted = partner.Motor.MoveToInteraction(doubleBed.RightSocket.ExitPoint.position);
            if (!primaryAccepted || !partnerAccepted)
            {
                AbortPairReservation();
                yield break;
            }
            yield return WaitForPairArrival(Mathf.Max(3f, 6f / Mathf.Max(1f, speedMultiplier)));
            primary.Motor.FinishInteraction();
            partner.Motor.FinishInteraction();
            ResetAgentSpeed(primary.Agent);
            ResetAgentSpeed(partner.Agent);
            doubleBed.ReleasePair(PrimaryId, PartnerId);
            pairState = PairSleepState.Awake;

            var clean = audit.CompleteCycle(
                CountStableProps(),
                Vector3.Distance(primary.Root.position, partner.Root.position));
            Debug.Log(
                $"PAWDO_VS3_CYCLE_COMPLETE cycle={CompletedCycles} clean={clean} " +
                $"teleports={TeleportViolations} collisions={CollisionViolations} duplicates={DuplicateViolations}");
        }

        private IEnumerator SleepPawdoSequence(float speedMultiplier)
        {
            pawdoBusy = true;
            var socket = pawdoBed.SleepSocket;
            if (!socket.TryReserve(PawdoId, SleepOccupantKind.Pawdo))
            {
                pawdoBusy = false;
                yield break;
            }

            SetAgentSpeed(pawdo.Agent, speedMultiplier);
            if (!MoveAgent(pawdo.Agent, socket.EntryPoint.position))
            {
                socket.Release(PawdoId);
                pawdoBusy = false;
                yield break;
            }
            yield return WaitForAgentArrival(
                pawdo.Agent,
                Mathf.Max(3f, 6f / Mathf.Max(1f, speedMultiplier)));
            if (!HasAgentArrived(pawdo.Agent))
            {
                socket.Release(PawdoId);
                pawdoBusy = false;
                yield break;
            }
            pawdo.Agent.ResetPath();
            pawdo.Agent.enabled = false;
            yield return AnimateTransform(
                pawdo.Root,
                pawdo.Root.position,
                socket.transform.position,
                pawdo.Root.rotation,
                socket.transform.rotation,
                0.55f / speedMultiplier);
            yield return AnimateLocalPose(
                pawdo.VisualRoot,
                pawdo.VisualRoot.localPosition,
                new Vector3(0f, -0.12f, 0f),
                pawdo.VisualRoot.localRotation,
                Quaternion.Euler(0f, 24f, 8f),
                0.35f / speedMultiplier);
            pawdoSleeping = true;
            pawdoBusy = false;
            Debug.Log("PAWDO_VS3_PAWDO_SLEEPING socket=pawdo-only");
        }

        private IEnumerator WakePawdoSequence(float speedMultiplier)
        {
            pawdoBusy = true;
            var socket = pawdoBed.SleepSocket;
            yield return AnimateLocalPose(
                pawdo.VisualRoot,
                pawdo.VisualRoot.localPosition,
                Vector3.zero,
                pawdo.VisualRoot.localRotation,
                Quaternion.identity,
                0.35f / speedMultiplier);
            yield return AnimateTransform(
                pawdo.Root,
                pawdo.Root.position,
                socket.EntryPoint.position,
                pawdo.Root.rotation,
                socket.EntryPoint.rotation,
                0.55f / speedMultiplier);
            pawdo.Agent.enabled = true;
            pawdo.Agent.Warp(socket.EntryPoint.position);
            ResetAgentSpeed(pawdo.Agent);
            MoveAgent(pawdo.Agent, socket.ExitPoint.position);
            yield return WaitForAgentArrival(pawdo.Agent, 6f);
            socket.Release(PawdoId);
            pawdoSleeping = false;
            pawdoBusy = false;
            pawdoCycles++;
            Debug.Log($"PAWDO_VS3_PAWDO_CYCLE_COMPLETE cycles={pawdoCycles}");
        }

        private IEnumerator WaitForPairArrival(float timeout)
        {
            while (timeout > 0f && (!primary.Motor.HasArrived || !partner.Motor.HasArrived))
            {
                timeout -= Time.deltaTime;
                yield return null;
            }
        }

        private static IEnumerator WaitForAgentArrival(NavMeshAgent agent, float timeout)
        {
            while (timeout > 0f && !HasAgentArrived(agent))
            {
                timeout -= Time.deltaTime;
                yield return null;
            }
        }

        private IEnumerator AnimatePairPose(
            SleepSocket left,
            SleepSocket right,
            float travelFraction,
            float poseAngle,
            float duration)
        {
            var leftTarget = Vector3.Lerp(left.EntryPoint.position, left.transform.position, travelFraction);
            var rightTarget = Vector3.Lerp(right.EntryPoint.position, right.transform.position, travelFraction);
            yield return AnimateAvatarBindings(
                leftTarget,
                rightTarget,
                Quaternion.Euler(poseAngle, 0f, 0f),
                duration);
        }

        private IEnumerator AnimatePairFromBed(
            SleepSocket left,
            SleepSocket right,
            float travelFraction,
            float poseAngle,
            float duration)
        {
            var leftTarget = Vector3.Lerp(left.EntryPoint.position, left.transform.position, travelFraction);
            var rightTarget = Vector3.Lerp(right.EntryPoint.position, right.transform.position, travelFraction);
            yield return AnimateAvatarBindings(
                leftTarget,
                rightTarget,
                Quaternion.Euler(poseAngle, 0f, 0f),
                duration);
        }

        private IEnumerator AnimateAvatarBindings(
            Vector3 primaryTarget,
            Vector3 partnerTarget,
            Quaternion visualTarget,
            float duration)
        {
            var primaryStart = primary.Root.position;
            var partnerStart = partner.Root.position;
            var primaryRotation = primary.Root.rotation;
            var partnerRotation = partner.Root.rotation;
            var primaryVisualStart = primary.VisualRoot.localRotation;
            var partnerVisualStart = partner.VisualRoot.localRotation;
            var elapsed = 0f;
            duration = Mathf.Max(0.02f, duration);
            while (elapsed < duration)
            {
                elapsed += Time.deltaTime;
                var t = Mathf.SmoothStep(0f, 1f, Mathf.Clamp01(elapsed / duration));
                primary.Root.position = Vector3.Lerp(primaryStart, primaryTarget, t);
                partner.Root.position = Vector3.Lerp(partnerStart, partnerTarget, t);
                primary.Root.rotation = Quaternion.Slerp(primaryRotation, Quaternion.identity, t);
                partner.Root.rotation = Quaternion.Slerp(partnerRotation, Quaternion.identity, t);
                primary.VisualRoot.localRotation = Quaternion.Slerp(primaryVisualStart, visualTarget, t);
                partner.VisualRoot.localRotation = Quaternion.Slerp(partnerVisualStart, visualTarget, t);
                yield return null;
            }
            primary.Root.position = primaryTarget;
            partner.Root.position = partnerTarget;
            primary.VisualRoot.localRotation = visualTarget;
            partner.VisualRoot.localRotation = visualTarget;
        }

        private static IEnumerator AnimateTransform(
            Transform target,
            Vector3 fromPosition,
            Vector3 toPosition,
            Quaternion fromRotation,
            Quaternion toRotation,
            float duration)
        {
            var elapsed = 0f;
            duration = Mathf.Max(0.02f, duration);
            while (elapsed < duration)
            {
                elapsed += Time.deltaTime;
                var t = Mathf.SmoothStep(0f, 1f, Mathf.Clamp01(elapsed / duration));
                target.position = Vector3.Lerp(fromPosition, toPosition, t);
                target.rotation = Quaternion.Slerp(fromRotation, toRotation, t);
                yield return null;
            }
            target.position = toPosition;
            target.rotation = toRotation;
        }

        private static IEnumerator AnimateLocalPose(
            Transform target,
            Vector3 fromPosition,
            Vector3 toPosition,
            Quaternion fromRotation,
            Quaternion toRotation,
            float duration)
        {
            var elapsed = 0f;
            duration = Mathf.Max(0.02f, duration);
            while (elapsed < duration)
            {
                elapsed += Time.deltaTime;
                var t = Mathf.SmoothStep(0f, 1f, Mathf.Clamp01(elapsed / duration));
                target.localPosition = Vector3.Lerp(fromPosition, toPosition, t);
                target.localRotation = Quaternion.Slerp(fromRotation, toRotation, t);
                yield return null;
            }
            target.localPosition = toPosition;
            target.localRotation = toRotation;
        }

        private void AbortPairReservation()
        {
            if (primary?.Agent != null && !primary.Agent.enabled)
            {
                primary.Agent.enabled = true;
            }
            if (partner?.Agent != null && !partner.Agent.enabled)
            {
                partner.Agent.enabled = true;
            }
            primary?.Motor.FinishInteraction();
            partner?.Motor.FinishInteraction();
            doubleBed?.ReleasePair(PrimaryId, PartnerId);
            pairState = PairSleepState.Awake;
            Debug.LogError("PAWDO_VS3_PAIR_ABORTED");
        }

        private void HandleWorldTap(Vector2 screenPosition)
        {
            var ray = sceneCamera.ScreenPointToRay(screenPosition);
            if (!Physics.Raycast(ray, out var hit, 100f, ~(1 << 2), QueryTriggerInteraction.Ignore))
            {
                return;
            }

            if (InteriorInteractionPolicy.ResolveDoubleBed(hit.collider) != null)
            {
                if (pairState == PairSleepState.Sleeping)
                {
                    BeginPairWake();
                }
                else
                {
                    BeginPairSleep();
                }
                return;
            }

            if (InteriorInteractionPolicy.ResolvePawdoBed(hit.collider) != null)
            {
                BeginPawdoBedToggle();
                return;
            }

            if (!pairBusy && !qaRunning && pairState == PairSleepState.Awake)
            {
                primary.Motor.MoveTo(hit.point);
            }
        }

        private void BuildInterior()
        {
            var palette = CreatePalette();
            RenderSettings.ambientMode = UnityEngine.Rendering.AmbientMode.Trilight;
            RenderSettings.ambientSkyColor = new Color(0.72f, 0.64f, 0.61f);
            RenderSettings.ambientEquatorColor = new Color(0.42f, 0.38f, 0.36f);
            RenderSettings.ambientGroundColor = new Color(0.16f, 0.14f, 0.14f);
            RenderSettings.fog = false;

            var cameraObject = new GameObject("Interior Camera · 40mm");
            cameraObject.tag = "MainCamera";
            cameraObject.transform.SetParent(transform);
            sceneCamera = cameraObject.AddComponent<Camera>();
            cameraObject.AddComponent<AudioListener>();
            sceneCamera.clearFlags = CameraClearFlags.SolidColor;
            sceneCamera.backgroundColor = Hex("B79C99");
            sceneCamera.fieldOfView = 37f;
            sceneCamera.nearClipPlane = 0.15f;
            sceneCamera.farClipPlane = 60f;
            sceneCamera.transform.position = new Vector3(0f, 9.4f, -14.8f);
            sceneCamera.transform.rotation = Quaternion.LookRotation(
                new Vector3(0f, 1.2f, 1.7f) - sceneCamera.transform.position);

            var keyObject = new GameObject("Warm window key");
            keyObject.transform.SetParent(transform);
            keyObject.transform.rotation = Quaternion.Euler(52f, -36f, 0f);
            var key = keyObject.AddComponent<Light>();
            key.type = LightType.Directional;
            key.color = new Color(1f, 0.83f, 0.72f);
            key.intensity = 1.18f;
            key.shadows = LightShadows.Soft;
            key.shadowStrength = 0.68f;

            var lampObject = new GameObject("Bedside practical light");
            lampObject.transform.SetParent(transform);
            lampObject.transform.position = new Vector3(6.0f, 3.1f, 4.6f);
            var lamp = lampObject.AddComponent<Light>();
            lamp.type = LightType.Point;
            lamp.color = new Color(1f, 0.68f, 0.48f);
            lamp.intensity = 2.0f;
            lamp.range = 9f;
            lamp.shadows = LightShadows.None;

            var floorMaterial = PawdoSurfaceLibrary.Create(PawdoSurfaceKind.Wood,
                "Oak flooring", new Color(0.94f, 0.90f, 0.86f), 0f, 0.30f, new Vector2(10.6f, 7.9f));
            runtimeMaterials.Add(floorMaterial);
            CreateWorldBox("Warm oak floor", new Vector3(0f, -0.11f, 0f), new Vector3(18f, 0.22f, 13.5f), floorMaterial, true);

            CreateWall("Back wall", new Vector3(0f, 2.2f, 6.75f), new Vector3(18f, 4.4f, 0.25f), palette.Cream);
            CreateWall("Left wall", new Vector3(-9f, 2.2f, 0f), new Vector3(0.25f, 4.4f, 13.5f), palette.Cream);
            CreateWall("Right wall", new Vector3(9f, 2.2f, 0f), new Vector3(0.25f, 4.4f, 13.5f), palette.Cream);
            BuildWindow(new Vector3(-3.2f, 2.55f, 6.56f), palette);
            BuildDoor(new Vector3(6.8f, 1.25f, 6.56f), palette);
            BuildRug(new Vector3(-2.3f, 0.04f, -0.2f), new Vector3(5.8f, 0.08f, 4.0f), palette);
            BuildSofa(new Vector3(-4.6f, 0f, 3.5f), palette);
            BuildCoffeeTable(new Vector3(-3.0f, 0f, 0.45f), palette);
            BuildTelevision(new Vector3(-7.65f, 0f, 1.35f), palette);
            BuildIndoorPlant(new Vector3(7.4f, 0f, 4.8f), palette);
            doubleBed = BuildDoubleBed(new Vector3(3.6f, 0f, 3.45f), palette);
            pawdoBed = BuildPawdoBed(new Vector3(6.7f, 0f, -2.8f), palette);
        }

        private void BuildNavigation()
        {
            var sources = new List<NavMeshBuildSource>
            {
                new NavMeshBuildSource
                {
                    shape = NavMeshBuildSourceShape.Box,
                    transform = Matrix4x4.TRS(Vector3.zero, Quaternion.identity, Vector3.one),
                    size = new Vector3(17.5f, 0.18f, 13f),
                    area = 0,
                },
            };
            var settings = NavMesh.GetSettingsCount() > 0
                ? NavMesh.GetSettingsByIndex(0)
                : NavMesh.CreateSettings();
            settings.agentRadius = 0.28f;
            settings.agentHeight = 1.72f;
            settings.agentClimb = 0.28f;
            settings.agentSlope = 38f;
            settings.overrideTileSize = true;
            settings.tileSize = 64;
            navMeshData = NavMeshBuilder.BuildNavMeshData(
                settings,
                sources,
                new Bounds(new Vector3(0f, 1f, 0f), new Vector3(20f, 5f, 16f)),
                Vector3.zero,
                Quaternion.identity);
            if (navMeshData == null)
            {
                Debug.LogError("PAWDO_VS3_NAVMESH_FAILED");
                return;
            }
            navMeshData.name = "Pawdo VS3 Interior Runtime NavMesh";
            navMeshInstance = NavMesh.AddNavMeshData(navMeshData);
        }

        private void SpawnCharacters()
        {
            primary = BuildAdultAvatar(
                "Avatar Jorge · interior adulto",
                new Vector3(-0.8f, 0.02f, -3.1f),
                new Color(0.52f, 0.30f, 0.23f),
                new Color(0.18f, 0.20f, 0.24f),
                new Color(0.39f, 0.18f, 0.23f),
                false);
            partner = BuildAdultAvatar(
                "Avatar pareja · interior adulto",
                new Vector3(1.0f, 0.02f, -3.0f),
                new Color(0.70f, 0.48f, 0.37f),
                new Color(0.16f, 0.10f, 0.08f),
                new Color(0.42f, 0.20f, 0.29f),
                true);
            pawdo = BuildPawdo(new Vector3(2.2f, 0.02f, -3.8f));
        }

        private DoubleBedInteractable BuildDoubleBed(Vector3 position, Palette palette)
        {
            var root = new GameObject("DoubleBed · one coherent prop");
            root.transform.SetParent(transform);
            root.transform.position = position;
            root.AddComponent<InteriorStableProp>().Configure("interior.double-bed.v1");
            var bed = root.AddComponent<DoubleBedInteractable>();
            var collider = root.AddComponent<BoxCollider>();
            collider.center = new Vector3(0f, 0.52f, 0f);
            collider.size = new Vector3(3.35f, 1.05f, 4.35f);
            AddBoxObstacle(root, collider.size, collider.center);

            CreateVisual("Bed frame", PrimitiveType.Cube, root.transform, new Vector3(0f, 0.34f, 0f), new Vector3(3.35f, 0.48f, 4.35f), palette.DarkWood);
            CreateVisual("Mattress", PrimitiveType.Cube, root.transform, new Vector3(0f, 0.70f, -0.05f), new Vector3(3.15f, 0.34f, 4.05f), palette.TextileCream);
            CreateVisual("Upholstered headboard", PrimitiveType.Cube, root.transform, new Vector3(0f, 1.25f, 2.05f), new Vector3(3.45f, 1.65f, 0.24f), palette.DustyRose);
            for (var index = -2; index <= 2; index++)
            {
                CreateVisual("Headboard seam " + index, PrimitiveType.Cube, root.transform, new Vector3(index * 0.55f, 1.25f, 1.91f), new Vector3(0.025f, 1.42f, 0.02f), palette.Wine);
            }
            var leftPillow = CreateVisual("Left pillow · unique", PrimitiveType.Cube, root.transform, new Vector3(-0.78f, 0.96f, 1.35f), new Vector3(1.25f, 0.22f, 0.75f), palette.Cream).gameObject;
            leftPillow.AddComponent<InteriorStableProp>().Configure("interior.pillow.left.v1");
            var rightPillow = CreateVisual("Right pillow · unique", PrimitiveType.Cube, root.transform, new Vector3(0.78f, 0.96f, 1.35f), new Vector3(1.25f, 0.22f, 0.75f), palette.Cream).gameObject;
            rightPillow.AddComponent<InteriorStableProp>().Configure("interior.pillow.right.v1");
            CreateVisual("Shared duvet", PrimitiveType.Cube, root.transform, new Vector3(0f, 0.94f, -0.42f), new Vector3(3.03f, 0.12f, 2.75f), palette.DustyRose);

            var left = BuildSleepSocket(root.transform, "SleepSocket.Left", SleepSocketKind.AvatarLeft, new Vector3(-0.58f, 1.30f, -1.55f), new Vector3(-0.72f, 0f, -2.82f), new Vector3(-2.15f, 0f, -2.25f));
            var right = BuildSleepSocket(root.transform, "SleepSocket.Right", SleepSocketKind.AvatarRight, new Vector3(0.58f, 1.30f, -1.55f), new Vector3(0.72f, 0f, -2.82f), new Vector3(2.15f, 0f, -2.25f));
            bed.Configure(left, right);
            return bed;
        }

        private PawdoBedInteractable BuildPawdoBed(Vector3 position, Palette palette)
        {
            var root = new GameObject("PawdoBed · pet only");
            root.transform.SetParent(transform);
            root.transform.position = position;
            root.AddComponent<InteriorStableProp>().Configure("interior.pawdo-bed.v1");
            var bed = root.AddComponent<PawdoBedInteractable>();
            var collider = root.AddComponent<BoxCollider>();
            collider.center = new Vector3(0f, 0.22f, 0f);
            collider.size = new Vector3(1.75f, 0.45f, 1.35f);
            AddBoxObstacle(root, collider.size, collider.center);
            CreateVisual("Pet bed outer", PrimitiveType.Cylinder, root.transform, new Vector3(0f, 0.18f, 0f), new Vector3(0.90f, 0.20f, 0.72f), palette.Wine);
            CreateVisual("Pet bed cushion", PrimitiveType.Cylinder, root.transform, new Vector3(0f, 0.32f, 0f), new Vector3(0.69f, 0.13f, 0.52f), palette.DustyRose);
            var socket = BuildSleepSocket(root.transform, "SleepSocket.Pawdo", SleepSocketKind.Pawdo, new Vector3(0f, 0.36f, 0f), new Vector3(0f, 0f, -1.15f), new Vector3(-1.35f, 0f, -1.25f));
            bed.Configure(socket);
            return bed;
        }

        private static SleepSocket BuildSleepSocket(
            Transform parent,
            string displayName,
            SleepSocketKind kind,
            Vector3 localPosition,
            Vector3 entryLocalPosition,
            Vector3 exitLocalPosition)
        {
            var target = new GameObject(displayName);
            target.transform.SetParent(parent);
            target.transform.localPosition = localPosition;
            target.transform.localRotation = Quaternion.identity;
            var entry = new GameObject(displayName + ".Entry").transform;
            entry.SetParent(parent);
            entry.localPosition = entryLocalPosition;
            entry.localRotation = Quaternion.identity;
            var exit = new GameObject(displayName + ".Exit").transform;
            exit.SetParent(parent);
            exit.localPosition = exitLocalPosition;
            exit.localRotation = Quaternion.identity;
            var socket = target.AddComponent<SleepSocket>();
            socket.Configure(kind, entry, exit);
            return socket;
        }

        private AvatarBinding BuildAdultAvatar(
            string displayName,
            Vector3 position,
            Color skinColor,
            Color hairColor,
            Color clothingColor,
            bool longHair)
        {
            var root = new GameObject(displayName);
            root.transform.SetParent(transform);
            root.transform.position = position;
            root.transform.rotation = Quaternion.Euler(0f, 180f, 0f);
            var agent = root.AddComponent<NavMeshAgent>();
            var motor = root.AddComponent<ProceduralAvatarMotor>();
            var poseRoot = new GameObject("Avatar Pose Root").transform;
            poseRoot.SetParent(root.transform);
            poseRoot.localPosition = Vector3.zero;
            poseRoot.localRotation = Quaternion.identity;

            var skin = CreateMaterial(displayName + " · skin", skinColor, 0f, 0.30f);
            var hair = CreateMaterial(displayName + " · hair", hairColor, 0.03f, 0.26f);
            var clothing = CreateMaterial(displayName + " · tailoring", clothingColor, 0.02f, 0.40f);
            var trouser = CreateMaterial(displayName + " · trousers", new Color(0.15f, 0.17f, 0.21f), 0f, 0.27f);
            var shoe = CreateMaterial(displayName + " · footwear", new Color(0.09f, 0.07f, 0.06f), 0.02f, 0.36f);
            var eye = CreateMaterial(displayName + " · eyes", new Color(0.045f, 0.03f, 0.025f), 0.02f, 0.54f);

            CreateVisual("Tailored torso", PrimitiveType.Capsule, poseRoot, new Vector3(0f, 1.20f, 0f), new Vector3(0.38f, 0.33f, 0.25f), clothing);
            CreateVisual("Waist", PrimitiveType.Capsule, poseRoot, new Vector3(0f, 0.91f, 0f), new Vector3(0.31f, 0.17f, 0.23f), trouser);
            CreateVisual("Neck", PrimitiveType.Cylinder, poseRoot, new Vector3(0f, 1.49f, 0f), new Vector3(0.09f, 0.10f, 0.09f), skin);
            CreateVisual("Adult head", PrimitiveType.Sphere, poseRoot, new Vector3(0f, 1.68f, 0f), new Vector3(0.21f, 0.25f, 0.20f), skin);
            CreateVisual("Hair cap", PrimitiveType.Sphere, poseRoot, new Vector3(0f, 1.82f, -0.018f), new Vector3(0.215f, 0.13f, 0.205f), hair);
            if (longHair)
            {
                CreateVisual("Long hair volume", PrimitiveType.Capsule, poseRoot, new Vector3(0f, 1.56f, -0.14f), new Vector3(0.23f, 0.25f, 0.14f), hair);
                CreateVisual("Wearable collar", PrimitiveType.Cube, poseRoot, new Vector3(0f, 1.43f, 0.13f), new Vector3(0.40f, 0.055f, 0.12f), clothing);
            }
            else
            {
                CreateVisual("Wearable overshirt", PrimitiveType.Cube, poseRoot, new Vector3(0f, 1.21f, 0.19f), new Vector3(0.42f, 0.40f, 0.055f), clothing);
            }
            CreateVisual("Left eye", PrimitiveType.Sphere, poseRoot, new Vector3(-0.073f, 1.70f, 0.187f), Vector3.one * 0.026f, eye);
            CreateVisual("Right eye", PrimitiveType.Sphere, poseRoot, new Vector3(0.073f, 1.70f, 0.187f), Vector3.one * 0.026f, eye);
            CreateVisual("Nose", PrimitiveType.Sphere, poseRoot, new Vector3(0f, 1.64f, 0.205f), new Vector3(0.028f, 0.024f, 0.026f), skin);

            var leftArm = CreateLimbPivot("Left arm pivot", poseRoot, new Vector3(-0.35f, 1.38f, 0f));
            CreateVisual("Left arm", PrimitiveType.Capsule, leftArm, new Vector3(0f, -0.28f, 0f), new Vector3(0.105f, 0.30f, 0.105f), clothing);
            CreateVisual("Left hand", PrimitiveType.Sphere, leftArm, new Vector3(0f, -0.57f, 0f), Vector3.one * 0.105f, skin);
            var rightArm = CreateLimbPivot("Right arm pivot", poseRoot, new Vector3(0.35f, 1.38f, 0f));
            CreateVisual("Right arm", PrimitiveType.Capsule, rightArm, new Vector3(0f, -0.28f, 0f), new Vector3(0.105f, 0.30f, 0.105f), clothing);
            CreateVisual("Right hand", PrimitiveType.Sphere, rightArm, new Vector3(0f, -0.57f, 0f), Vector3.one * 0.105f, skin);
            var leftLeg = CreateLimbPivot("Left leg pivot", poseRoot, new Vector3(-0.15f, 0.86f, 0f));
            CreateVisual("Left leg", PrimitiveType.Capsule, leftLeg, new Vector3(0f, -0.36f, 0f), new Vector3(0.125f, 0.38f, 0.125f), trouser);
            CreateVisual("Left shoe", PrimitiveType.Cube, leftLeg, new Vector3(0f, -0.73f, 0.075f), new Vector3(0.22f, 0.12f, 0.36f), shoe);
            var rightLeg = CreateLimbPivot("Right leg pivot", poseRoot, new Vector3(0.15f, 0.86f, 0f));
            CreateVisual("Right leg", PrimitiveType.Capsule, rightLeg, new Vector3(0f, -0.36f, 0f), new Vector3(0.125f, 0.38f, 0.125f), trouser);
            CreateVisual("Right shoe", PrimitiveType.Cube, rightLeg, new Vector3(0f, -0.73f, 0.075f), new Vector3(0.22f, 0.12f, 0.36f), shoe);

            motor.Configure(leftArm, rightArm, leftLeg, rightLeg);
            if (NavMesh.SamplePosition(position, out var sample, 1.2f, NavMesh.AllAreas))
            {
                agent.Warp(sample.position);
            }
            return new AvatarBinding(root.transform, poseRoot, agent, motor);
        }

        private PawdoBinding BuildPawdo(Vector3 position)
        {
            var root = new GameObject("Pawdo · interior pet");
            root.transform.SetParent(transform);
            root.transform.position = position;
            var agent = root.AddComponent<NavMeshAgent>();
            var motor = root.AddComponent<ProceduralPawdoMotor>();
            var visualRoot = new GameObject("Pawdo Pose Root").transform;
            visualRoot.SetParent(root.transform);
            visualRoot.localPosition = Vector3.zero;
            visualRoot.localRotation = Quaternion.identity;
            var coat = CreateMaterial("Pawdo warm coat", new Color(0.72f, 0.46f, 0.27f), 0f, 0.34f);
            var cream = CreateMaterial("Pawdo cream markings", new Color(0.87f, 0.78f, 0.63f), 0f, 0.40f);
            var dark = CreateMaterial("Pawdo eyes and nose", new Color(0.055f, 0.04f, 0.03f), 0.01f, 0.60f);
            var collar = CreateMaterial("Pawdo wine collar", new Color(0.39f, 0.12f, 0.20f), 0.08f, 0.46f);
            var body = CreateVisual("Athletic body", PrimitiveType.Capsule, visualRoot, new Vector3(0f, 0.43f, 0f), new Vector3(0.27f, 0.42f, 0.29f), coat);
            body.localRotation = Quaternion.Euler(90f, 0f, 0f);
            CreateVisual("Chest marking", PrimitiveType.Sphere, visualRoot, new Vector3(0f, 0.46f, 0.22f), new Vector3(0.20f, 0.24f, 0.16f), cream);
            var head = CreateVisual("Head", PrimitiveType.Sphere, visualRoot, new Vector3(0f, 0.64f, 0.36f), new Vector3(0.25f, 0.27f, 0.24f), coat);
            CreateVisual("Muzzle", PrimitiveType.Sphere, visualRoot, new Vector3(0f, 0.57f, 0.57f), new Vector3(0.17f, 0.13f, 0.14f), cream);
            var lowerJaw = CreateVisual("Lower jaw", PrimitiveType.Sphere, visualRoot, new Vector3(0f, 0.515f, 0.585f), new Vector3(0.13f, 0.05f, 0.105f), cream);
            CreateVisual("Nose", PrimitiveType.Sphere, visualRoot, new Vector3(0f, 0.59f, 0.69f), Vector3.one * 0.055f, dark);
            CreateVisual("Left eye", PrimitiveType.Sphere, visualRoot, new Vector3(-0.085f, 0.69f, 0.555f), Vector3.one * 0.035f, dark);
            CreateVisual("Right eye", PrimitiveType.Sphere, visualRoot, new Vector3(0.085f, 0.69f, 0.555f), Vector3.one * 0.035f, dark);
            var leftEar = CreateVisual("Left natural ear", PrimitiveType.Capsule, visualRoot, new Vector3(-0.22f, 0.66f, 0.31f), new Vector3(0.10f, 0.18f, 0.075f), coat);
            leftEar.localRotation = Quaternion.Euler(0f, 0f, -28f);
            var rightEar = CreateVisual("Right natural ear", PrimitiveType.Capsule, visualRoot, new Vector3(0.22f, 0.66f, 0.31f), new Vector3(0.10f, 0.18f, 0.075f), coat);
            rightEar.localRotation = Quaternion.Euler(0f, 0f, 28f);
            CreateVisual("Collar", PrimitiveType.Cylinder, visualRoot, new Vector3(0f, 0.47f, 0.31f), new Vector3(0.22f, 0.035f, 0.22f), collar);
            var legs = new Transform[4];
            var positions = new[]
            {
                new Vector3(-0.18f, 0.33f, 0.25f), new Vector3(0.18f, 0.33f, 0.25f),
                new Vector3(-0.18f, 0.33f, -0.25f), new Vector3(0.18f, 0.33f, -0.25f),
            };
            for (var index = 0; index < legs.Length; index++)
            {
                legs[index] = CreateLimbPivot("Pawdo leg pivot " + index, visualRoot, positions[index]);
                CreateVisual("Pawdo leg " + index, PrimitiveType.Capsule, legs[index], new Vector3(0f, -0.17f, 0f), new Vector3(0.075f, 0.18f, 0.075f), index < 2 ? cream : coat);
            }
            var tail = CreateLimbPivot("Pawdo tail pivot", visualRoot, new Vector3(0f, 0.53f, -0.43f));
            var tailVisual = CreateVisual("Pawdo tail", PrimitiveType.Capsule, tail, new Vector3(0f, 0.18f, -0.08f), new Vector3(0.075f, 0.24f, 0.075f), coat);
            tailVisual.localRotation = Quaternion.Euler(-28f, 0f, 0f);
            motor.Configure(tail, legs);
            var headRig = PawdoVoiceReactionController.CreateHeadRig(visualRoot, head);
            var voiceReaction = root.AddComponent<PawdoVoiceReactionController>();
            voiceReaction.Configure(headRig, lowerJaw, leftEar, rightEar);
            voiceController = root.AddComponent<PawdoVoiceRepeatController>();
            voiceController.Configure(voiceReaction);
            if (NavMesh.SamplePosition(position, out var sample, 1.2f, NavMesh.AllAreas))
            {
                agent.Warp(sample.position);
            }
            return new PawdoBinding(root.transform, visualRoot, agent, motor);
        }

        private void BuildWindow(Vector3 position, Palette palette)
        {
            var root = new GameObject("Architectural window");
            root.transform.SetParent(transform);
            root.transform.position = position;
            CreateVisual("Window glass", PrimitiveType.Cube, root.transform, Vector3.zero, new Vector3(4.2f, 2.3f, 0.08f), palette.Glass);
            CreateVisual("Window top", PrimitiveType.Cube, root.transform, new Vector3(0f, 1.25f, -0.08f), new Vector3(4.55f, 0.18f, 0.18f), palette.DarkWood);
            CreateVisual("Window bottom", PrimitiveType.Cube, root.transform, new Vector3(0f, -1.25f, -0.08f), new Vector3(4.55f, 0.18f, 0.18f), palette.DarkWood);
            CreateVisual("Window left", PrimitiveType.Cube, root.transform, new Vector3(-2.18f, 0f, -0.08f), new Vector3(0.18f, 2.65f, 0.18f), palette.DarkWood);
            CreateVisual("Window right", PrimitiveType.Cube, root.transform, new Vector3(2.18f, 0f, -0.08f), new Vector3(0.18f, 2.65f, 0.18f), palette.DarkWood);
            CreateVisual("Window mullion", PrimitiveType.Cube, root.transform, new Vector3(0f, 0f, -0.10f), new Vector3(0.12f, 2.4f, 0.12f), palette.DarkWood);
        }

        private void BuildDoor(Vector3 position, Palette palette)
        {
            var root = new GameObject("Interior door");
            root.transform.SetParent(transform);
            root.transform.position = position;
            CreateVisual("Door slab", PrimitiveType.Cube, root.transform, Vector3.zero, new Vector3(1.8f, 2.5f, 0.16f), palette.Wine);
            CreateVisual("Door frame top", PrimitiveType.Cube, root.transform, new Vector3(0f, 1.38f, -0.05f), new Vector3(2.15f, 0.18f, 0.24f), palette.DarkWood);
            CreateVisual("Door handle", PrimitiveType.Sphere, root.transform, new Vector3(0.62f, 0f, -0.15f), Vector3.one * 0.09f, palette.Gold);
        }

        private void BuildRug(Vector3 position, Vector3 size, Palette palette)
        {
            CreateVisual("Woven area rug", PrimitiveType.Cube, transform, position, size, palette.DustyRose);
            CreateVisual("Rug inset", PrimitiveType.Cube, transform, position + Vector3.up * 0.045f, new Vector3(size.x - 0.35f, 0.025f, size.z - 0.35f), palette.TextileCream);
        }

        private void BuildSofa(Vector3 position, Palette palette)
        {
            var root = CreateObstacleRoot("Sofa · adult scale", position, new Vector3(4.2f, 1.35f, 1.8f), new Vector3(0f, 0.68f, 0f));
            CreateVisual("Sofa base", PrimitiveType.Cube, root.transform, new Vector3(0f, 0.48f, 0f), new Vector3(4.0f, 0.65f, 1.65f), palette.Botanical);
            CreateVisual("Sofa back", PrimitiveType.Cube, root.transform, new Vector3(0f, 1.12f, 0.64f), new Vector3(4.05f, 1.05f, 0.35f), palette.Botanical);
            CreateVisual("Sofa arm left", PrimitiveType.Cube, root.transform, new Vector3(-2.0f, 0.78f, 0f), new Vector3(0.35f, 0.9f, 1.72f), palette.Botanical);
            CreateVisual("Sofa arm right", PrimitiveType.Cube, root.transform, new Vector3(2.0f, 0.78f, 0f), new Vector3(0.35f, 0.9f, 1.72f), palette.Botanical);
            CreateVisual("Sofa cushion left", PrimitiveType.Cube, root.transform, new Vector3(-0.92f, 0.86f, -0.15f), new Vector3(1.72f, 0.25f, 1.25f), palette.Cream);
            CreateVisual("Sofa cushion right", PrimitiveType.Cube, root.transform, new Vector3(0.92f, 0.86f, -0.15f), new Vector3(1.72f, 0.25f, 1.25f), palette.Cream);
        }

        private void BuildCoffeeTable(Vector3 position, Palette palette)
        {
            var root = CreateObstacleRoot("Coffee table", position, new Vector3(2.8f, 0.65f, 1.55f), new Vector3(0f, 0.35f, 0f));
            CreateVisual("Table top", PrimitiveType.Cube, root.transform, new Vector3(0f, 0.58f, 0f), new Vector3(2.8f, 0.18f, 1.55f), palette.LightWood);
            foreach (var x in new[] { -1.12f, 1.12f })
            {
                foreach (var z in new[] { -0.52f, 0.52f })
                {
                    CreateVisual("Table leg", PrimitiveType.Cylinder, root.transform, new Vector3(x, 0.27f, z), new Vector3(0.09f, 0.28f, 0.09f), palette.DarkWood);
                }
            }
        }

        private void BuildTelevision(Vector3 position, Palette palette)
        {
            var root = CreateObstacleRoot("Television console", position, new Vector3(1.1f, 1.9f, 3.4f), new Vector3(0f, 0.95f, 0f));
            CreateVisual("TV console", PrimitiveType.Cube, root.transform, new Vector3(0f, 0.42f, 0f), new Vector3(0.85f, 0.72f, 3.4f), palette.DarkWood);
            var screen = CreateVisual("Television screen", PrimitiveType.Cube, root.transform, new Vector3(0.38f, 1.45f, 0f), new Vector3(0.12f, 1.55f, 2.85f), palette.Charcoal);
            screen.localRotation = Quaternion.Euler(0f, 0f, 0f);
        }

        private void BuildIndoorPlant(Vector3 position, Palette palette)
        {
            var root = CreateObstacleRoot("Indoor botanical plant", position, new Vector3(1.25f, 2.4f, 1.25f), new Vector3(0f, 1.2f, 0f));
            CreateVisual("Ceramic planter", PrimitiveType.Cylinder, root.transform, new Vector3(0f, 0.38f, 0f), new Vector3(0.48f, 0.42f, 0.48f), palette.Cream);
            for (var index = 0; index < 8; index++)
            {
                var angle = index * Mathf.PI * 2f / 8f;
                var leaf = CreateVisual("Plant leaf " + index, PrimitiveType.Capsule, root.transform, new Vector3(Mathf.Cos(angle) * 0.28f, 1.12f + (index % 3) * 0.18f, Mathf.Sin(angle) * 0.28f), new Vector3(0.18f, 0.58f, 0.12f), palette.Botanical);
                leaf.localRotation = Quaternion.Euler(Mathf.Cos(angle) * 24f, angle * Mathf.Rad2Deg, Mathf.Sin(angle) * 20f);
            }
        }

        private GameObject CreateObstacleRoot(string name, Vector3 position, Vector3 size, Vector3 center)
        {
            var root = new GameObject(name);
            root.transform.SetParent(transform);
            root.transform.position = position;
            var collider = root.AddComponent<BoxCollider>();
            collider.size = size;
            collider.center = center;
            AddBoxObstacle(root, size, center);
            return root;
        }

        private GameObject CreateWorldBox(string name, Vector3 position, Vector3 scale, Material material, bool keepCollider)
        {
            var item = GameObject.CreatePrimitive(PrimitiveType.Cube);
            item.name = name;
            item.transform.SetParent(transform);
            item.transform.position = position;
            item.transform.localScale = scale;
            item.GetComponent<Renderer>().sharedMaterial = material;
            if (!keepCollider)
            {
                item.GetComponent<Collider>().enabled = false;
                item.layer = 2;
            }
            return item;
        }

        private void CreateWall(string name, Vector3 position, Vector3 scale, Material material)
        {
            var wall = CreateWorldBox(name, position, scale, material, true);
            AddBoxObstacle(wall, scale, Vector3.zero);
        }

        private Transform CreateVisual(string name, PrimitiveType primitive, Transform parent, Vector3 localPosition, Vector3 localScale, Material material)
        {
            var item = GameObject.CreatePrimitive(primitive);
            item.name = name;
            item.layer = 2;
            item.transform.SetParent(parent);
            item.transform.localPosition = localPosition;
            item.transform.localScale = localScale;
            item.GetComponent<Renderer>().sharedMaterial = material;
            var collider = item.GetComponent<Collider>();
            if (collider != null)
            {
                collider.enabled = false;
            }
            return item.transform;
        }

        private static Transform CreateLimbPivot(string name, Transform parent, Vector3 localPosition)
        {
            var pivot = new GameObject(name).transform;
            pivot.SetParent(parent);
            pivot.localPosition = localPosition;
            return pivot;
        }

        private static void AddBoxObstacle(GameObject root, Vector3 size, Vector3 center)
        {
            var obstacle = root.AddComponent<NavMeshObstacle>();
            obstacle.shape = NavMeshObstacleShape.Box;
            obstacle.size = size;
            obstacle.center = center;
            obstacle.carving = true;
            obstacle.carveOnlyStationary = true;
        }

        private Palette CreatePalette()
        {
            return new Palette
            {
                DustyRose = CreateMaterial("Dusty rose textile", Hex("C98D9C"), 0f, 0.24f, PawdoSurfaceKind.Linen),
                Wine = CreateMaterial("Pawdo wine accent", Hex("633347"), 0.04f, 0.44f),
                Cream = CreateMaterial("Architectural cream", Hex("F3EADF"), 0f, 0.34f),
                TextileCream = CreateMaterial("Linen cream", new Color(0.82f, 0.76f, 0.70f), 0f, 0.20f, PawdoSurfaceKind.Linen),
                LightWood = CreateMaterial("Warm oak", new Color(0.94f, 0.88f, 0.79f), 0f, 0.34f, PawdoSurfaceKind.Wood),
                DarkWood = CreateMaterial("Walnut", new Color(0.46f, 0.32f, 0.26f), 0f, 0.36f, PawdoSurfaceKind.Wood),
                Botanical = CreateMaterial("Botanical green", Hex("506B55"), 0f, 0.26f, PawdoSurfaceKind.Linen),
                Gold = CreateMaterial("Discreet brass", Hex("B89A62"), 0.48f, 0.60f),
                Charcoal = CreateMaterial("Charcoal", Hex("29252A"), 0.06f, 0.38f),
                Glass = CreateMaterial("Window glass", new Color(0.37f, 0.52f, 0.58f), 0.16f, 0.78f),
            };
        }

        private Material CreateMaterial(string name, Color color, float metallic, float smoothness,
            PawdoSurfaceKind surface = PawdoSurfaceKind.Plain)
        {
            var material = PawdoSurfaceLibrary.Create(surface, name, color, metallic, smoothness,
                surface == PawdoSurfaceKind.Linen ? new Vector2(6f, 6f) : Vector2.one);
            runtimeMaterials.Add(material);
            return material;
        }

        private static Color Hex(string hex)
        {
            return ColorUtility.TryParseHtmlString("#" + hex, out var color) ? color : Color.white;
        }

        private static bool MoveAgent(NavMeshAgent agent, Vector3 destination)
        {
            return agent != null && agent.enabled && agent.isOnNavMesh &&
                   NavMesh.SamplePosition(destination, out var sample, 1.25f, NavMesh.AllAreas) &&
                   agent.SetDestination(sample.position);
        }

        private static bool HasAgentArrived(NavMeshAgent agent)
        {
            return agent != null && agent.enabled && agent.isOnNavMesh &&
                   !agent.pathPending && agent.remainingDistance <= agent.stoppingDistance + 0.08f;
        }

        private static void DisableAgentAtCurrentPose(AvatarBinding binding)
        {
            binding.Agent.isStopped = true;
            binding.Agent.ResetPath();
            binding.Agent.enabled = false;
        }

        private static void EnableAgentAtEntry(AvatarBinding binding, Vector3 entry)
        {
            binding.Root.position = entry;
            binding.Root.rotation = Quaternion.identity;
            binding.VisualRoot.localPosition = Vector3.zero;
            binding.VisualRoot.localRotation = Quaternion.identity;
            binding.Agent.enabled = true;
            binding.Agent.Warp(entry);
            binding.Agent.isStopped = false;
        }

        private static void SetAgentSpeed(NavMeshAgent agent, float multiplier)
        {
            if (agent != null)
            {
                agent.speed = 2.25f * Mathf.Max(1f, multiplier);
                agent.acceleration = 8f * Mathf.Max(1f, multiplier);
            }
        }

        private static void ResetAgentSpeed(NavMeshAgent agent)
        {
            if (agent != null)
            {
                agent.speed = 2.25f;
                agent.acceleration = 8f;
            }
        }

        private int CountStableProps()
        {
            return FindObjectsByType<InteriorStableProp>(FindObjectsSortMode.None).Length;
        }

        private bool IsAvatarSupportedByDoubleBed(AvatarBinding binding)
        {
            if (binding?.VisualRoot == null || doubleBed == null)
            {
                return false;
            }
            foreach (var renderer in binding.VisualRoot.GetComponentsInChildren<Renderer>())
            {
                var bounds = renderer.bounds;
                foreach (var x in new[] { bounds.min.x, bounds.max.x })
                {
                    foreach (var z in new[] { bounds.min.z, bounds.max.z })
                    {
                        var local = doubleBed.transform.InverseTransformPoint(
                            new Vector3(x, bounds.center.y, z));
                        if (Mathf.Abs(local.x) > 1.66f || local.z < -2.12f || local.z > 2.12f)
                        {
                            Debug.LogWarning(
                                $"PAWDO_VS3_SUPPORT_FAILED renderer={renderer.name} reason=footprint " +
                                $"localX={local.x:F3} localZ={local.z:F3} minY={bounds.min.y:F3}");
                            return false;
                        }
                    }
                }
                if (bounds.min.y < doubleBed.transform.position.y + 0.96f)
                {
                    Debug.LogWarning(
                        $"PAWDO_VS3_SUPPORT_FAILED renderer={renderer.name} reason=height " +
                        $"minY={bounds.min.y:F3} required=0.960");
                    return false;
                }
            }
            return true;
        }

        private bool TryReadTriggeredPointer(out Vector2 position)
        {
            if (Input.touchCount > 0)
            {
                var touch = Input.GetTouch(0);
                position = touch.position;
                return PointerGesturePolicy.ShouldTrigger(touch.phase, pointerConsumed);
            }
            position = Input.mousePosition;
            return Input.GetMouseButtonDown(0) && !pointerConsumed;
        }

        private bool IsPointerOverUi(Vector2 screenPosition)
        {
            var guiPoint = new Vector2(screenPosition.x, Screen.height - screenPosition.y);
            return topPanel.Contains(guiPoint) || pairButton.Contains(guiPoint) ||
                   pawdoButton.Contains(guiPoint) ||
                   PawdoVoiceRepeatController.IsScreenPointOverControl(screenPosition);
        }

        private void UpdatePointerRects()
        {
            var safe = Screen.safeArea;
            var guiTop = Screen.height - safe.yMax;
            topPanel = new Rect(safe.x + 22f, guiTop + 18f, Mathf.Min(710f, safe.width * 0.52f), 148f);
            var width = 224f;
            pairButton = new Rect(safe.xMax - width - 24f, guiTop + 22f, width, 52f);
            pawdoButton = new Rect(safe.xMax - width - 24f, guiTop + 84f, width, 52f);
            qaButton = new Rect(safe.xMax - width - 24f, guiTop + 146f, width, 52f);
        }

        private void OnGUI()
        {
            EnsureStyles();
            UpdatePointerRects();
            var previous = GUI.color;
            GUI.color = new Color(0.08f, 0.07f, 0.08f, 0.84f);
            GUI.Box(topPanel, GUIContent.none);
            GUI.color = previous;
            GUI.Label(new Rect(topPanel.x + 22f, topPanel.y + 14f, topPanel.width - 44f, 34f), "Nuestra casa", titleStyle);
            GUI.Label(new Rect(topPanel.x + 22f, topPanel.y + 49f, topPanel.width - 44f, 31f), "Toca el suelo para caminar o la cama para descansar.", bodyStyle);
            GUI.Label(
                new Rect(topPanel.x + 22f, topPanel.y + 85f, topPanel.width - 44f, 48f),
                pairBusy ? "Buscando un lugar cómodo…" :
                    pairState == PairSleepState.Sleeping ? "Descansando juntos." : "Su espacio para compartir y desconectar.",
                metricStyle);

            GUI.enabled = !pairBusy && !qaRunning &&
                          (pairState == PairSleepState.Awake || pairState == PairSleepState.Sleeping);
            if (GUI.Button(pairButton, pairState == PairSleepState.Sleeping ? "LEVANTARSE JUNTOS" : "DORMIR JUNTOS"))
            {
                if (pairState == PairSleepState.Sleeping) BeginPairWake(); else BeginPairSleep();
            }
            GUI.enabled = !pawdoBusy && !qaRunning;
            if (GUI.Button(pawdoButton, pawdoSleeping ? "DESPERTAR A PAWDO" : "PAWDO A SU CAMA"))
            {
                BeginPawdoBedToggle();
            }
            GUI.enabled = true;
        }

        private void EnsureStyles()
        {
            if (titleStyle != null)
            {
                return;
            }
            titleStyle = new GUIStyle(GUI.skin.label)
            {
                fontSize = 24,
                fontStyle = FontStyle.Bold,
                normal = { textColor = new Color(0.96f, 0.93f, 0.89f) },
            };
            bodyStyle = new GUIStyle(GUI.skin.label)
            {
                fontSize = 16,
                normal = { textColor = new Color(0.86f, 0.83f, 0.80f) },
            };
            metricStyle = new GUIStyle(bodyStyle)
            {
                fontStyle = FontStyle.Bold,
                normal = { textColor = new Color(0.79f, 0.67f, 0.42f) },
            };
        }

        private sealed class AvatarBinding
        {
            public AvatarBinding(Transform root, Transform visualRoot, NavMeshAgent agent, ProceduralAvatarMotor motor)
            {
                Root = root;
                VisualRoot = visualRoot;
                Agent = agent;
                Motor = motor;
            }
            public Transform Root { get; }
            public Transform VisualRoot { get; }
            public NavMeshAgent Agent { get; }
            public ProceduralAvatarMotor Motor { get; }
        }

        private sealed class PawdoBinding
        {
            public PawdoBinding(Transform root, Transform visualRoot, NavMeshAgent agent, ProceduralPawdoMotor motor)
            {
                Root = root;
                VisualRoot = visualRoot;
                Agent = agent;
                Motor = motor;
            }
            public Transform Root { get; }
            public Transform VisualRoot { get; }
            public NavMeshAgent Agent { get; }
            public ProceduralPawdoMotor Motor { get; }
        }

        private sealed class Palette
        {
            public Material DustyRose;
            public Material Wine;
            public Material Cream;
            public Material TextileCream;
            public Material LightWood;
            public Material DarkWood;
            public Material Botanical;
            public Material Gold;
            public Material Charcoal;
            public Material Glass;
        }
    }
}
