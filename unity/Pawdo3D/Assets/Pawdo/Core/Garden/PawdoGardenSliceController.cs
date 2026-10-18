using System;
using System.Collections;
using System.Collections.Generic;
using Pawdo.Characters;
using UnityEngine;
using UnityEngine.AI;

namespace Pawdo.Garden
{
    public sealed class PawdoGardenSliceController : MonoBehaviour
    {
        public const string LayoutStorageKey = "pawdo.garden.vs2.layout.v1";
        private static readonly Bounds EditableBounds = new Bounds(
            new Vector3(0f, 0.2f, 1f),
            new Vector3(21.4f, 1.2f, 15.4f));

        private readonly List<Material> runtimeMaterials = new List<Material>();
        private readonly List<GameObject> placementInstances = new List<GameObject>();
        private Camera sceneCamera;
        private ProceduralAvatarMotor primaryAvatar;
        private ProceduralAvatarMotor partnerAvatar;
        private ProceduralPawdoMotor pawdo;
        private PlantInteractable heroPlant;
        private GardenPlacementPolicy placementPolicy;
        private GardenLayoutSnapshot layoutSnapshot;
        private NavMeshData navMeshData;
        private NavMeshDataInstance navMeshInstance;
        private Material previewValidMaterial;
        private Material previewInvalidMaterial;
        private GameObject placementPreview;
        private GardenSemanticSurface previewSurface;
        private Vector3 previewPosition;
        private bool previewBlocked;
        private bool placementMode;
        private bool previewHasHit;
        private bool pointerConsumed;
        private GUIStyle titleStyle;
        private GUIStyle bodyStyle;
        private GUIStyle metricStyle;
        private GUIStyle hintStyle;
        private Rect topPanel;
        private Rect editButton;
        private Rect saveButton;
        private Rect cancelButton;
        private int emptyTapCount;
        private int wateringsCompleted;
        private int invalidPlacementSaves;
        private int validPlacementSaves;

        public int EmptyTapCount => emptyTapCount;
        public int WateringsCompleted => wateringsCompleted;
        public int InvalidPlacementSaves => invalidPlacementSaves;
        public int ValidPlacementSaves => validPlacementSaves;
        public ProceduralAvatarMotor PrimaryAvatar => primaryAvatar;
        public PlantInteractable HeroPlant => heroPlant;

        private void Awake()
        {
            Application.targetFrameRate = 60;
            QualitySettings.vSyncCount = 0;
            Screen.sleepTimeout = SleepTimeout.NeverSleep;
            placementPolicy = new GardenPlacementPolicy(EditableBounds);
            BuildVisualEnvironment();
            BuildNavigation();
            SpawnCharacters();
            heroPlant = CreatePottedPlant(
                "HeroPlant · Lavanda",
                new Vector3(5.7f, 0.18f, 0.6f),
                true,
                transform);
            LoadSavedLayout();
            Debug.Log(
                "PAWDO_VS2_READY scene=GardenSlice assets=procedural-original " +
                "thirdPartyAssets=0 navMesh=ready heroPlant=ready");
        }

        private void Update()
        {
            UpdatePointerRects();
            if (TryReadTriggeredPointer(out var screenPosition))
            {
                if (IsPointerOverUi(screenPosition))
                {
                    pointerConsumed = true;
                }
                else if (placementMode)
                {
                    UpdatePlacementPreview(screenPosition);
                    pointerConsumed = true;
                }
                else
                {
                    HandleWorldTap(screenPosition);
                    pointerConsumed = true;
                }
            }
            else
            {
                pointerConsumed = false;
            }

            if (placementMode && TryReadHeldPointer(out var heldPosition) &&
                !IsPointerOverUi(heldPosition))
            {
                UpdatePlacementPreview(heldPosition);
            }
        }

        private void OnDestroy()
        {
            Screen.sleepTimeout = SleepTimeout.SystemSetting;
            if (navMeshInstance.valid)
            {
                navMeshInstance.Remove();
            }

            foreach (var material in runtimeMaterials)
            {
                if (material != null)
                {
                    Destroy(material);
                }
            }
        }

        private void BuildVisualEnvironment()
        {
            var palette = CreatePalette();
            RenderSettings.ambientMode = UnityEngine.Rendering.AmbientMode.Trilight;
            RenderSettings.ambientSkyColor = new Color(0.78f, 0.70f, 0.68f);
            RenderSettings.ambientEquatorColor = new Color(0.49f, 0.46f, 0.42f);
            RenderSettings.ambientGroundColor = new Color(0.18f, 0.20f, 0.17f);
            RenderSettings.fog = true;
            RenderSettings.fogColor = new Color(0.82f, 0.73f, 0.68f);
            RenderSettings.fogMode = FogMode.Linear;
            RenderSettings.fogStartDistance = 23f;
            RenderSettings.fogEndDistance = 42f;

            var cameraObject = new GameObject("Garden Camera · 40mm");
            cameraObject.tag = "MainCamera";
            cameraObject.transform.SetParent(transform);
            sceneCamera = cameraObject.AddComponent<Camera>();
            cameraObject.AddComponent<AudioListener>();
            sceneCamera.clearFlags = CameraClearFlags.SolidColor;
            sceneCamera.backgroundColor = new Color(0.73f, 0.62f, 0.60f);
            sceneCamera.fieldOfView = 36f;
            sceneCamera.nearClipPlane = 0.15f;
            sceneCamera.farClipPlane = 80f;
            sceneCamera.transform.position = new Vector3(0f, 10.8f, -15.7f);
            sceneCamera.transform.rotation = Quaternion.LookRotation(
                new Vector3(0f, 1.0f, 2.2f) - sceneCamera.transform.position);

            var key = new GameObject("Warm Afternoon Key");
            key.transform.SetParent(transform);
            key.transform.rotation = Quaternion.Euler(48f, -34f, 0f);
            var keyLight = key.AddComponent<Light>();
            keyLight.type = LightType.Directional;
            keyLight.color = new Color(1f, 0.83f, 0.70f);
            keyLight.intensity = 1.25f;
            keyLight.shadows = LightShadows.Soft;
            keyLight.shadowStrength = 0.75f;

            var fill = new GameObject("Botanical Fill");
            fill.transform.SetParent(transform);
            fill.transform.position = new Vector3(-6f, 5f, -3f);
            var fillLight = fill.AddComponent<Light>();
            fillLight.type = LightType.Point;
            fillLight.color = new Color(0.72f, 0.82f, 0.70f);
            fillLight.range = 14f;
            fillLight.intensity = 2.2f;
            fillLight.shadows = LightShadows.None;

            CreateSemanticBox(
                "Garden Ground · FreeGrass",
                new Vector3(0f, -0.12f, 1f),
                new Vector3(22f, 0.24f, 16f),
                palette.Grass,
                GardenSemanticZone.FreeGrass,
                false,
                transform);

            CreateSemanticBox(
                "Main Walkway",
                new Vector3(0f, 0.025f, -1.6f),
                new Vector3(4.2f, 0.07f, 10.2f),
                palette.Stone,
                GardenSemanticZone.Walkway,
                false,
                transform);
            CreateSemanticBox(
                "House Terrace",
                new Vector3(0f, 0.03f, 5.2f),
                new Vector3(9f, 0.08f, 2.1f),
                palette.LightWood,
                GardenSemanticZone.Walkway,
                false,
                transform);

            BuildHouse(palette);
            BuildFlowerBed("West contained border", new Vector3(-7.6f, 0.08f, 1.3f), new Vector3(3.2f, 0.22f, 6.8f), palette);
            BuildFlowerBed("East contained border", new Vector3(7.6f, 0.08f, 2.2f), new Vector3(3.2f, 0.22f, 5.4f), palette);
            BuildTree("Olive tree", new Vector3(-6.0f, 0f, 5.0f), 1.1f, palette);
            BuildOutdoorFurniture(palette);

            var plot = CreateSemanticBox(
                "Editable Planter Plot",
                new Vector3(5.6f, 0.04f, -3.8f),
                new Vector3(4.0f, 0.10f, 2.3f),
                palette.Soil,
                GardenSemanticZone.PlanterPlot,
                true,
                transform);
            CreateBorder(plot.transform, new Vector3(4.15f, 0.18f, 2.45f), palette.LightWood);

            CreateBoundary(new Vector3(0f, 0.8f, 9.1f), new Vector3(22f, 1.6f, 0.3f));
            CreateBoundary(new Vector3(-11.1f, 0.8f, 1f), new Vector3(0.3f, 1.6f, 16f));
            CreateBoundary(new Vector3(11.1f, 0.8f, 1f), new Vector3(0.3f, 1.6f, 16f));

            previewValidMaterial = CreateMaterial("Placement valid", new Color(0.20f, 0.78f, 0.42f, 0.76f), 0.05f, 0.28f, true);
            previewInvalidMaterial = CreateMaterial("Placement invalid", new Color(0.82f, 0.20f, 0.24f, 0.76f), 0.05f, 0.24f, true);
        }

        private void BuildNavigation()
        {
            var sources = new List<NavMeshBuildSource>
            {
                new NavMeshBuildSource
                {
                    shape = NavMeshBuildSourceShape.Box,
                    transform = Matrix4x4.TRS(new Vector3(0f, 0f, 1f), Quaternion.identity, Vector3.one),
                    size = new Vector3(21.6f, 0.18f, 15.6f),
                    area = 0,
                },
            };
            var settings = NavMesh.GetSettingsCount() > 0
                ? NavMesh.GetSettingsByIndex(0)
                : NavMesh.CreateSettings();
            settings.agentRadius = 0.28f;
            settings.agentHeight = 1.72f;
            settings.agentClimb = 0.30f;
            settings.agentSlope = 42f;
            settings.overrideTileSize = true;
            settings.tileSize = 64;
            navMeshData = NavMeshBuilder.BuildNavMeshData(
                settings,
                sources,
                new Bounds(new Vector3(0f, 1f, 1f), new Vector3(24f, 5f, 19f)),
                Vector3.zero,
                Quaternion.identity);
            if (navMeshData == null)
            {
                Debug.LogError("PAWDO_VS2_NAVMESH_FAILED");
                return;
            }

            navMeshData.name = "Pawdo VS2 Runtime NavMesh";
            navMeshInstance = NavMesh.AddNavMeshData(navMeshData);
        }

        private void SpawnCharacters()
        {
            primaryAvatar = BuildAdultAvatar(
                "Avatar Jorge · adulto",
                new Vector3(-1.4f, 0.02f, -1.2f),
                new Color(0.52f, 0.30f, 0.23f),
                new Color(0.18f, 0.20f, 0.24f),
                new Color(0.39f, 0.18f, 0.23f),
                false);
            partnerAvatar = BuildAdultAvatar(
                "Avatar pareja · adulto",
                new Vector3(1.1f, 0.02f, -0.8f),
                new Color(0.70f, 0.48f, 0.37f),
                new Color(0.16f, 0.10f, 0.08f),
                new Color(0.42f, 0.20f, 0.29f),
                true);
            pawdo = BuildPawdo(new Vector3(0.1f, 0.02f, -2.3f));
        }

        private void HandleWorldTap(Vector2 screenPosition)
        {
            var ray = sceneCamera.ScreenPointToRay(screenPosition);
            if (!Physics.Raycast(ray, out var hit, 100f, ~(1 << 2), QueryTriggerInteraction.Ignore))
            {
                RegisterEmptyTap("miss");
                return;
            }

            var plant = GardenInteractionPolicy.ResolvePlant(hit.collider);
            if (plant != null)
            {
                if (plant.TryBeginWatering())
                {
                    StartCoroutine(WaterPlant(plant));
                }
                else
                {
                    Debug.Log("PAWDO_VS2_PLANT_REJECTED reason=hydrated-or-busy");
                }
                return;
            }

            RegisterEmptyTap(hit.collider.name);
            var destination = hit.point;
            primaryAvatar.MoveTo(destination);
            partnerAvatar.MoveTo(destination + new Vector3(0.82f, 0f, 0.38f));
            pawdo.Follow(destination + new Vector3(-0.68f, 0f, -0.48f));
        }

        private IEnumerator WaterPlant(PlantInteractable plant)
        {
            var socket = plant.WateringSocket;
            if (socket == null || !primaryAvatar.MoveToInteraction(socket.position))
            {
                plant.CancelWatering();
                yield break;
            }

            var deadline = Time.time + 8f;
            while (!primaryAvatar.HasArrived && Time.time < deadline)
            {
                yield return null;
            }

            if (!primaryAvatar.HasArrived)
            {
                plant.CancelWatering();
                primaryAvatar.FinishInteraction();
                Debug.LogWarning("PAWDO_VS2_WATER_REJECTED reason=socket-unreachable");
                yield break;
            }

            primaryAvatar.Face(plant.transform.position);
            var can = CreateWateringCan(primaryAvatar.transform);
            var started = Time.time;
            var duration = 1.45f;
            var dropletsEmitted = false;
            while (Time.time - started < duration)
            {
                var normalized = (Time.time - started) / duration;
                primaryAvatar.PoseWatering(normalized);
                if (!dropletsEmitted && normalized >= 0.28f)
                {
                    dropletsEmitted = true;
                    StartCoroutine(AnimateWaterDroplets(can.transform.position + primaryAvatar.transform.forward * 0.34f, plant.transform.position + Vector3.up * 0.42f));
                }
                yield return null;
            }

            Destroy(can);
            plant.CompleteWatering();
            primaryAvatar.FinishInteraction();
            wateringsCompleted++;
            Debug.Log(
                $"PAWDO_VS2_WATER_COMPLETED total={wateringsCompleted} plant={plant.name} " +
                $"emptyTaps={emptyTapCount}");
        }

        private IEnumerator AnimateWaterDroplets(Vector3 origin, Vector3 destination)
        {
            var water = CreateMaterial("Water droplets", new Color(0.34f, 0.68f, 0.82f), 0.05f, 0.72f);
            var droplets = new List<GameObject>();
            for (var index = 0; index < 14; index++)
            {
                var drop = GameObject.CreatePrimitive(PrimitiveType.Sphere);
                drop.name = "Water drop";
                drop.layer = 2;
                drop.transform.localScale = Vector3.one * 0.035f;
                drop.GetComponent<Renderer>().sharedMaterial = water;
                Destroy(drop.GetComponent<Collider>());
                droplets.Add(drop);
            }

            var start = Time.time;
            const float duration = 0.78f;
            while (Time.time - start < duration)
            {
                var time = (Time.time - start) / duration;
                for (var index = 0; index < droplets.Count; index++)
                {
                    var offsetTime = Mathf.Clamp01(time * 1.4f - index * 0.03f);
                    var point = Vector3.Lerp(origin, destination, offsetTime);
                    point.y += Mathf.Sin(offsetTime * Mathf.PI) * 0.55f;
                    point += Vector3.right * Mathf.Sin(index * 2.1f) * 0.025f;
                    droplets[index].transform.position = point;
                }
                yield return null;
            }

            foreach (var droplet in droplets)
            {
                Destroy(droplet);
            }
        }

        private void RegisterEmptyTap(string target)
        {
            emptyTapCount++;
            if (emptyTapCount % 10 == 0)
            {
                Debug.Log(
                    $"PAWDO_VS2_EMPTY_TAPS count={emptyTapCount} waterings={wateringsCompleted} " +
                    $"lastTarget={target}");
            }
        }

        private void BeginPlacement()
        {
            if (placementMode)
            {
                return;
            }

            placementMode = true;
            previewHasHit = false;
            placementPreview = CreatePottedPlant(
                "Placement Preview",
                new Vector3(5.6f, 0.18f, -3.8f),
                false,
                transform).gameObject;
            foreach (var itemCollider in placementPreview.GetComponentsInChildren<Collider>())
            {
                itemCollider.enabled = false;
            }
            SetLayerRecursively(placementPreview, 2);
            ApplyPreviewMaterial(previewInvalidMaterial);
        }

        private void CancelPlacement()
        {
            placementMode = false;
            previewHasHit = false;
            previewSurface = null;
            if (placementPreview != null)
            {
                Destroy(placementPreview);
                placementPreview = null;
            }
        }

        private void UpdatePlacementPreview(Vector2 screenPosition)
        {
            if (placementPreview == null)
            {
                return;
            }

            var ray = sceneCamera.ScreenPointToRay(screenPosition);
            if (!Physics.Raycast(ray, out var hit, 100f, ~(1 << 2), QueryTriggerInteraction.Ignore))
            {
                previewHasHit = false;
                previewSurface = null;
                ApplyPreviewMaterial(previewInvalidMaterial);
                return;
            }

            previewPosition = hit.point;
            previewPosition.y = 0.18f;
            previewSurface = hit.collider.GetComponentInParent<GardenSemanticSurface>();
            previewBlocked = IsPlacementBlocked(previewPosition);
            previewHasHit = true;
            placementPreview.transform.position = previewPosition;
            var decision = placementPolicy.Evaluate(previewPosition, previewSurface, previewBlocked);
            ApplyPreviewMaterial(decision.IsValid ? previewValidMaterial : previewInvalidMaterial);
        }

        private void SavePlacement()
        {
            var decision = placementPolicy.Evaluate(
                previewPosition,
                previewHasHit ? previewSurface : null,
                previewBlocked);
            if (!decision.IsValid)
            {
                invalidPlacementSaves++;
                Debug.Log(
                    $"PAWDO_VS2_PLACEMENT_REJECTED status={decision.Status} " +
                    $"rejected={invalidPlacementSaves}");
                return;
            }

            var instance = CreatePottedPlant(
                "Placed planter · " + (layoutSnapshot.baseRevision + 1),
                previewPosition,
                false,
                transform).gameObject;
            placementInstances.Add(instance);
            var items = new List<GardenPlacedItem>(layoutSnapshot.items)
            {
                new GardenPlacedItem
                {
                    instanceId = Guid.NewGuid().ToString("N"),
                    assetId = "pawdo.vs2.planter.lavender.original",
                    x = previewPosition.x,
                    y = previewPosition.y,
                    z = previewPosition.z,
                    yaw = placementPreview.transform.eulerAngles.y,
                    semanticZone = GardenSemanticZone.PlanterPlot.ToString(),
                },
            };
            layoutSnapshot.baseRevision++;
            layoutSnapshot.items = items.ToArray();
            PlayerPrefs.SetString(LayoutStorageKey, JsonUtility.ToJson(layoutSnapshot));
            PlayerPrefs.Save();
            validPlacementSaves++;
            Debug.Log(
                $"PAWDO_VS2_PLACEMENT_SAVED revision={layoutSnapshot.baseRevision} " +
                $"items={layoutSnapshot.items.Length}");
            CancelPlacement();
        }

        private bool IsPlacementBlocked(Vector3 position)
        {
            var overlaps = Physics.OverlapBox(
                position + Vector3.up * 0.28f,
                new Vector3(0.42f, 0.30f, 0.42f),
                Quaternion.identity,
                ~(1 << 2),
                QueryTriggerInteraction.Ignore);
            foreach (var overlap in overlaps)
            {
                if (overlap == null)
                {
                    continue;
                }

                if (overlap.GetComponentInParent<GardenSemanticSurface>() != null)
                {
                    continue;
                }

                if (overlap.GetComponentInParent<ProceduralAvatarMotor>() != null ||
                    overlap.GetComponentInParent<ProceduralPawdoMotor>() != null)
                {
                    continue;
                }

                return true;
            }
            return false;
        }

        private void LoadSavedLayout()
        {
            layoutSnapshot = new GardenLayoutSnapshot();
            var raw = PlayerPrefs.GetString(LayoutStorageKey, string.Empty);
            if (string.IsNullOrWhiteSpace(raw))
            {
                return;
            }

            try
            {
                var loaded = JsonUtility.FromJson<GardenLayoutSnapshot>(raw);
                if (loaded == null || loaded.schemaVersion != 1 || loaded.items == null)
                {
                    return;
                }

                layoutSnapshot = loaded;
                foreach (var item in loaded.items)
                {
                    if (item == null || item.assetId != "pawdo.vs2.planter.lavender.original")
                    {
                        continue;
                    }
                    var instance = CreatePottedPlant(
                        "Restored planter · " + item.instanceId,
                        new Vector3(item.x, item.y, item.z),
                        false,
                        transform).gameObject;
                    instance.transform.rotation = Quaternion.Euler(0f, item.yaw, 0f);
                    placementInstances.Add(instance);
                }
            }
            catch (Exception error)
            {
                Debug.LogWarning("PAWDO_VS2_LAYOUT_IGNORED " + error.GetType().Name);
                layoutSnapshot = new GardenLayoutSnapshot();
            }
        }

        private ProceduralAvatarMotor BuildAdultAvatar(
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

            var skin = CreateMaterial(displayName + " · skin", skinColor, 0f, 0.28f);
            var hair = CreateMaterial(displayName + " · hair", hairColor, 0.03f, 0.24f);
            var clothing = CreateMaterial(displayName + " · tailoring", clothingColor, 0.02f, 0.38f);
            var trouser = CreateMaterial(displayName + " · trousers", new Color(0.16f, 0.18f, 0.22f), 0f, 0.25f);
            var shoe = CreateMaterial(displayName + " · footwear", new Color(0.10f, 0.08f, 0.07f), 0.02f, 0.34f);
            var eye = CreateMaterial(displayName + " · eyes", new Color(0.05f, 0.035f, 0.03f), 0.02f, 0.52f);

            CreateVisual("Tailored torso", PrimitiveType.Capsule, root.transform, new Vector3(0f, 1.20f, 0f), new Vector3(0.38f, 0.33f, 0.25f), clothing);
            CreateVisual("Waist", PrimitiveType.Capsule, root.transform, new Vector3(0f, 0.91f, 0f), new Vector3(0.31f, 0.17f, 0.23f), trouser);
            CreateVisual("Neck", PrimitiveType.Cylinder, root.transform, new Vector3(0f, 1.49f, 0f), new Vector3(0.09f, 0.10f, 0.09f), skin);
            CreateVisual("Adult head", PrimitiveType.Sphere, root.transform, new Vector3(0f, 1.68f, 0f), new Vector3(0.21f, 0.25f, 0.20f), skin);
            CreateVisual("Hair cap", PrimitiveType.Sphere, root.transform, new Vector3(0f, 1.82f, -0.018f), new Vector3(0.215f, 0.13f, 0.205f), hair);
            if (longHair)
            {
                CreateVisual("Long hair volume", PrimitiveType.Capsule, root.transform, new Vector3(0f, 1.56f, -0.14f), new Vector3(0.23f, 0.25f, 0.14f), hair);
                CreateVisual("Wearable collar", PrimitiveType.Cube, root.transform, new Vector3(0f, 1.43f, 0.13f), new Vector3(0.40f, 0.055f, 0.12f), clothing);
            }
            else
            {
                CreateVisual("Wearable overshirt", PrimitiveType.Cube, root.transform, new Vector3(0f, 1.21f, 0.19f), new Vector3(0.42f, 0.40f, 0.055f), clothing);
            }

            CreateVisual("Left eye", PrimitiveType.Sphere, root.transform, new Vector3(-0.073f, 1.70f, 0.187f), Vector3.one * 0.026f, eye);
            CreateVisual("Right eye", PrimitiveType.Sphere, root.transform, new Vector3(0.073f, 1.70f, 0.187f), Vector3.one * 0.026f, eye);
            CreateVisual("Nose", PrimitiveType.Sphere, root.transform, new Vector3(0f, 1.64f, 0.205f), new Vector3(0.028f, 0.024f, 0.026f), skin);

            var leftArm = CreateLimbPivot("Left arm pivot", root.transform, new Vector3(-0.35f, 1.38f, 0f));
            CreateVisual("Left arm", PrimitiveType.Capsule, leftArm, new Vector3(0f, -0.28f, 0f), new Vector3(0.105f, 0.30f, 0.105f), clothing);
            CreateVisual("Left hand", PrimitiveType.Sphere, leftArm, new Vector3(0f, -0.57f, 0f), Vector3.one * 0.105f, skin);
            var rightArm = CreateLimbPivot("Right arm pivot", root.transform, new Vector3(0.35f, 1.38f, 0f));
            CreateVisual("Right arm", PrimitiveType.Capsule, rightArm, new Vector3(0f, -0.28f, 0f), new Vector3(0.105f, 0.30f, 0.105f), clothing);
            CreateVisual("Right hand", PrimitiveType.Sphere, rightArm, new Vector3(0f, -0.57f, 0f), Vector3.one * 0.105f, skin);

            var leftLeg = CreateLimbPivot("Left leg pivot", root.transform, new Vector3(-0.15f, 0.86f, 0f));
            CreateVisual("Left leg", PrimitiveType.Capsule, leftLeg, new Vector3(0f, -0.36f, 0f), new Vector3(0.125f, 0.38f, 0.125f), trouser);
            CreateVisual("Left shoe", PrimitiveType.Cube, leftLeg, new Vector3(0f, -0.73f, 0.075f), new Vector3(0.22f, 0.12f, 0.36f), shoe);
            var rightLeg = CreateLimbPivot("Right leg pivot", root.transform, new Vector3(0.15f, 0.86f, 0f));
            CreateVisual("Right leg", PrimitiveType.Capsule, rightLeg, new Vector3(0f, -0.36f, 0f), new Vector3(0.125f, 0.38f, 0.125f), trouser);
            CreateVisual("Right shoe", PrimitiveType.Cube, rightLeg, new Vector3(0f, -0.73f, 0.075f), new Vector3(0.22f, 0.12f, 0.36f), shoe);

            motor.Configure(leftArm, rightArm, leftLeg, rightLeg);
            if (NavMesh.SamplePosition(position, out var navPosition, 1.2f, NavMesh.AllAreas))
            {
                agent.Warp(navPosition.position);
            }
            return motor;
        }

        private ProceduralPawdoMotor BuildPawdo(Vector3 position)
        {
            var root = new GameObject("Pawdo · perro mestizo pequeño adulto");
            root.transform.SetParent(transform);
            root.transform.position = position;
            var agent = root.AddComponent<NavMeshAgent>();
            var motor = root.AddComponent<ProceduralPawdoMotor>();
            var coat = CreateMaterial("Pawdo warm coat", new Color(0.72f, 0.46f, 0.27f), 0f, 0.32f);
            var cream = CreateMaterial("Pawdo cream markings", new Color(0.87f, 0.78f, 0.63f), 0f, 0.38f);
            var dark = CreateMaterial("Pawdo eyes and nose", new Color(0.055f, 0.04f, 0.03f), 0.01f, 0.58f);
            var collar = CreateMaterial("Pawdo wine collar", new Color(0.39f, 0.12f, 0.20f), 0.08f, 0.45f);

            var body = CreateVisual("Athletic body", PrimitiveType.Capsule, root.transform, new Vector3(0f, 0.43f, 0f), new Vector3(0.27f, 0.42f, 0.29f), coat);
            body.localRotation = Quaternion.Euler(90f, 0f, 0f);
            CreateVisual("Chest marking", PrimitiveType.Sphere, root.transform, new Vector3(0f, 0.46f, 0.22f), new Vector3(0.20f, 0.24f, 0.16f), cream);
            var head = CreateVisual("Head", PrimitiveType.Sphere, root.transform, new Vector3(0f, 0.64f, 0.36f), new Vector3(0.25f, 0.27f, 0.24f), coat);
            CreateVisual("Muzzle", PrimitiveType.Sphere, root.transform, new Vector3(0f, 0.57f, 0.57f), new Vector3(0.17f, 0.13f, 0.14f), cream);
            var lowerJaw = CreateVisual("Lower jaw", PrimitiveType.Sphere, root.transform, new Vector3(0f, 0.515f, 0.585f), new Vector3(0.13f, 0.05f, 0.105f), cream);
            CreateVisual("Nose", PrimitiveType.Sphere, root.transform, new Vector3(0f, 0.59f, 0.69f), Vector3.one * 0.055f, dark);
            CreateVisual("Left eye", PrimitiveType.Sphere, root.transform, new Vector3(-0.085f, 0.69f, 0.555f), Vector3.one * 0.035f, dark);
            CreateVisual("Right eye", PrimitiveType.Sphere, root.transform, new Vector3(0.085f, 0.69f, 0.555f), Vector3.one * 0.035f, dark);
            var leftEar = CreateVisual("Left natural ear", PrimitiveType.Capsule, root.transform, new Vector3(-0.22f, 0.66f, 0.31f), new Vector3(0.10f, 0.18f, 0.075f), coat);
            leftEar.localRotation = Quaternion.Euler(0f, 0f, -28f);
            var rightEar = CreateVisual("Right natural ear", PrimitiveType.Capsule, root.transform, new Vector3(0.22f, 0.66f, 0.31f), new Vector3(0.10f, 0.18f, 0.075f), coat);
            rightEar.localRotation = Quaternion.Euler(0f, 0f, 28f);
            CreateVisual("Collar", PrimitiveType.Cylinder, root.transform, new Vector3(0f, 0.47f, 0.31f), new Vector3(0.22f, 0.035f, 0.22f), collar);

            var legs = new Transform[4];
            var legPositions = new[]
            {
                new Vector3(-0.18f, 0.33f, 0.25f), new Vector3(0.18f, 0.33f, 0.25f),
                new Vector3(-0.18f, 0.33f, -0.25f), new Vector3(0.18f, 0.33f, -0.25f),
            };
            for (var index = 0; index < legs.Length; index++)
            {
                legs[index] = CreateLimbPivot("Pawdo leg pivot " + index, root.transform, legPositions[index]);
                CreateVisual("Pawdo leg " + index, PrimitiveType.Capsule, legs[index], new Vector3(0f, -0.17f, 0f), new Vector3(0.075f, 0.18f, 0.075f), index < 2 ? cream : coat);
            }
            var tail = CreateLimbPivot("Pawdo tail pivot", root.transform, new Vector3(0f, 0.53f, -0.43f));
            var tailVisual = CreateVisual("Pawdo tail", PrimitiveType.Capsule, tail, new Vector3(0f, 0.18f, -0.08f), new Vector3(0.075f, 0.24f, 0.075f), coat);
            tailVisual.localRotation = Quaternion.Euler(-28f, 0f, 0f);
            motor.Configure(tail, legs);
            var headRig = PawdoVoiceReactionController.CreateHeadRig(root.transform, head);
            var voiceReaction = root.AddComponent<PawdoVoiceReactionController>();
            voiceReaction.Configure(headRig, lowerJaw, leftEar, rightEar);
            root.AddComponent<PawdoVoiceRepeatController>().Configure(voiceReaction);
            if (NavMesh.SamplePosition(position, out var navPosition, 1.2f, NavMesh.AllAreas))
            {
                agent.Warp(navPosition.position);
            }
            return motor;
        }

        private PlantInteractable CreatePottedPlant(
            string displayName,
            Vector3 position,
            bool interactive,
            Transform parent)
        {
            var root = new GameObject(displayName);
            root.transform.SetParent(parent);
            root.transform.position = position;
            var terracotta = FindOrCreateMaterial("Terracotta", new Color(0.57f, 0.28f, 0.21f), 0f, 0.30f);
            var green = FindOrCreateMaterial("Lavender foliage", new Color(0.24f, 0.39f, 0.27f), 0f, 0.28f);
            var bloom = FindOrCreateMaterial("Lavender bloom", new Color(0.47f, 0.29f, 0.47f), 0f, 0.34f);
            CreateVisual("Planter", PrimitiveType.Cylinder, root.transform, new Vector3(0f, 0.20f, 0f), new Vector3(0.38f, 0.24f, 0.38f), terracotta);
            for (var index = 0; index < 9; index++)
            {
                var angle = index * Mathf.PI * 2f / 9f;
                var radius = index % 2 == 0 ? 0.18f : 0.10f;
                var stem = CreateVisual(
                    "Stem " + index,
                    PrimitiveType.Cylinder,
                    root.transform,
                    new Vector3(Mathf.Cos(angle) * radius, 0.52f + (index % 3) * 0.035f, Mathf.Sin(angle) * radius),
                    new Vector3(0.025f, 0.24f, 0.025f),
                    green);
                stem.localRotation = Quaternion.Euler(Mathf.Sin(angle) * 8f, 0f, Mathf.Cos(angle) * 8f);
                CreateVisual(
                    "Bloom " + index,
                    PrimitiveType.Sphere,
                    root.transform,
                    new Vector3(Mathf.Cos(angle) * radius, 0.76f + (index % 3) * 0.035f, Mathf.Sin(angle) * radius),
                    new Vector3(0.09f, 0.12f, 0.09f),
                    bloom);
            }

            var socket = new GameObject("WateringSocket").transform;
            socket.SetParent(root.transform);
            socket.localPosition = new Vector3(0f, -0.16f, -1.05f);
            socket.localRotation = Quaternion.LookRotation(Vector3.forward);
            var interactable = root.AddComponent<PlantInteractable>();
            interactable.Configure(socket, interactive);
            var collider = root.AddComponent<CapsuleCollider>();
            collider.center = new Vector3(0f, 0.42f, 0f);
            collider.radius = 0.47f;
            collider.height = 1.06f;
            return interactable;
        }

        private GameObject CreateWateringCan(Transform avatar)
        {
            var root = new GameObject("Watering can · original procedural");
            root.transform.SetParent(avatar);
            root.transform.localPosition = new Vector3(0f, 1.08f, 0.48f);
            root.transform.localRotation = Quaternion.Euler(18f, 0f, 0f);
            var metal = FindOrCreateMaterial("Watering can botanical", new Color(0.23f, 0.35f, 0.28f), 0.32f, 0.42f);
            CreateVisual("Can body", PrimitiveType.Cylinder, root.transform, Vector3.zero, new Vector3(0.20f, 0.20f, 0.20f), metal);
            var spout = CreateVisual("Can spout", PrimitiveType.Cylinder, root.transform, new Vector3(0f, 0.05f, 0.32f), new Vector3(0.055f, 0.30f, 0.055f), metal);
            spout.localRotation = Quaternion.Euler(68f, 0f, 0f);
            return root;
        }

        private void BuildHouse(Palette palette)
        {
            var houseRoot = new GameObject("Contemporary Garden House");
            houseRoot.transform.SetParent(transform);
            houseRoot.transform.position = new Vector3(0f, 0f, 6.4f);
            CreateVisual("House volume", PrimitiveType.Cube, houseRoot.transform, new Vector3(0f, 2.0f, 0f), new Vector3(7.4f, 4.0f, 3.5f), palette.Cream);
            var leftRoof = CreateVisual("Left roof", PrimitiveType.Cube, houseRoot.transform, new Vector3(-1.72f, 4.22f, 0f), new Vector3(4.15f, 0.28f, 3.9f), palette.Wine);
            leftRoof.localRotation = Quaternion.Euler(0f, 0f, -25f);
            var rightRoof = CreateVisual("Right roof", PrimitiveType.Cube, houseRoot.transform, new Vector3(1.72f, 4.22f, 0f), new Vector3(4.15f, 0.28f, 3.9f), palette.Wine);
            rightRoof.localRotation = Quaternion.Euler(0f, 0f, 25f);
            CreateVisual("Front door", PrimitiveType.Cube, houseRoot.transform, new Vector3(0f, 1.18f, -1.78f), new Vector3(1.1f, 2.35f, 0.12f), palette.LightWood);
            CreateVisual("Door inset", PrimitiveType.Cube, houseRoot.transform, new Vector3(0f, 1.22f, -1.86f), new Vector3(0.78f, 1.98f, 0.05f), palette.Wine);
            CreateWindow(houseRoot.transform, new Vector3(-2.25f, 2.15f, -1.83f), palette);
            CreateWindow(houseRoot.transform, new Vector3(2.25f, 2.15f, -1.83f), palette);
            AddObstacle(houseRoot, new Vector3(7.6f, 4.2f, 3.6f), new Vector3(0f, 2.1f, 0f));
        }

        private void CreateWindow(Transform parent, Vector3 position, Palette palette)
        {
            CreateVisual("Window frame", PrimitiveType.Cube, parent, position, new Vector3(1.65f, 1.50f, 0.10f), palette.LightWood);
            CreateVisual("Window glass", PrimitiveType.Cube, parent, position + new Vector3(0f, 0f, -0.07f), new Vector3(1.38f, 1.23f, 0.04f), palette.Glass);
            CreateVisual("Window mullion V", PrimitiveType.Cube, parent, position + new Vector3(0f, 0f, -0.12f), new Vector3(0.055f, 1.27f, 0.04f), palette.Cream);
            CreateVisual("Window mullion H", PrimitiveType.Cube, parent, position + new Vector3(0f, 0f, -0.12f), new Vector3(1.42f, 0.055f, 0.04f), palette.Cream);
        }

        private void BuildFlowerBed(string displayName, Vector3 position, Vector3 size, Palette palette)
        {
            var bed = CreateSemanticBox(
                displayName,
                position,
                size,
                palette.Soil,
                GardenSemanticZone.FlowerBed,
                false,
                transform);
            CreateBorder(bed.transform, size + new Vector3(0.18f, 0.12f, 0.18f), palette.LightWood);
            AddObstacle(bed, size + new Vector3(0.1f, 0.5f, 0.1f), new Vector3(0f, 0.25f, 0f));
            var rows = Mathf.Max(2, Mathf.FloorToInt(size.z / 0.82f));
            for (var row = 0; row < rows; row++)
            {
                for (var column = 0; column < 2; column++)
                {
                    var x = (column - 0.5f) * size.x * 0.42f;
                    var z = -size.z * 0.38f + row * (size.z * 0.76f / Mathf.Max(1, rows - 1));
                    var colorIndex = (row + column) % 3;
                    var flowerColor = colorIndex == 0 ? palette.DustyRose : colorIndex == 1 ? palette.Cream : palette.Wine;
                    CreateContainedFlower(bed.transform, new Vector3(x, size.y * 0.5f, z), flowerColor, palette.Botanical);
                }
            }
        }

        private void CreateContainedFlower(Transform parent, Vector3 localPosition, Material blossom, Material foliage)
        {
            var root = new GameObject("Contained perennial");
            root.layer = 2;
            root.transform.SetParent(parent);
            root.transform.localPosition = localPosition;
            CreateVisual("Stem", PrimitiveType.Cylinder, root.transform, new Vector3(0f, 0.24f, 0f), new Vector3(0.025f, 0.24f, 0.025f), foliage);
            for (var petal = 0; petal < 5; petal++)
            {
                var angle = petal * Mathf.PI * 2f / 5f;
                CreateVisual(
                    "Petal",
                    PrimitiveType.Sphere,
                    root.transform,
                    new Vector3(Mathf.Cos(angle) * 0.10f, 0.50f, Mathf.Sin(angle) * 0.10f),
                    new Vector3(0.12f, 0.055f, 0.09f),
                    blossom);
            }
            SetLayerRecursively(root, 2);
        }

        private void BuildTree(string displayName, Vector3 position, float scale, Palette palette)
        {
            var root = new GameObject(displayName);
            root.transform.SetParent(transform);
            root.transform.position = position;
            CreateVisual("Trunk", PrimitiveType.Cylinder, root.transform, new Vector3(0f, 1.6f, 0f), new Vector3(0.42f * scale, 1.6f * scale, 0.42f * scale), palette.Trunk);
            var crownOffsets = new[]
            {
                new Vector3(0f, 3.4f, 0f), new Vector3(-0.75f, 3.2f, 0.15f),
                new Vector3(0.75f, 3.25f, -0.10f), new Vector3(0f, 3.75f, 0.25f),
            };
            foreach (var offset in crownOffsets)
            {
                CreateVisual("Olive crown", PrimitiveType.Sphere, root.transform, offset * scale, new Vector3(1.05f, 0.76f, 0.90f) * scale, palette.Botanical);
            }
            SetLayerRecursively(root, 2);
            AddObstacle(root, new Vector3(1.2f, 4.2f, 1.2f), new Vector3(0f, 2.1f, 0f));
        }

        private void BuildOutdoorFurniture(Palette palette)
        {
            var root = new GameObject("Outdoor conversation corner");
            root.transform.SetParent(transform);
            root.transform.position = new Vector3(-4.7f, 0f, -3.8f);
            CreateVisual("Table top", PrimitiveType.Cylinder, root.transform, new Vector3(0f, 0.67f, 0f), new Vector3(0.78f, 0.09f, 0.78f), palette.LightWood);
            CreateVisual("Table base", PrimitiveType.Cylinder, root.transform, new Vector3(0f, 0.34f, 0f), new Vector3(0.16f, 0.34f, 0.16f), palette.Charcoal);
            CreateVisual("Bench seat", PrimitiveType.Cube, root.transform, new Vector3(-1.65f, 0.56f, 0f), new Vector3(1.3f, 0.16f, 0.50f), palette.LightWood);
            CreateVisual("Bench back", PrimitiveType.Cube, root.transform, new Vector3(-1.98f, 1.02f, 0f), new Vector3(0.16f, 0.95f, 1.35f), palette.LightWood);
            AddObstacle(root, new Vector3(3.2f, 1.2f, 2.0f), new Vector3(-0.65f, 0.6f, 0f));
        }

        private GameObject CreateSemanticBox(
            string displayName,
            Vector3 position,
            Vector3 scale,
            Material material,
            GardenSemanticZone zone,
            bool acceptsPlacement,
            Transform parent)
        {
            var item = new GameObject(displayName);
            item.name = displayName;
            item.transform.SetParent(parent);
            item.transform.position = position;
            item.AddComponent<GardenSemanticSurface>().Configure(zone, acceptsPlacement);
            var geometry = GameObject.CreatePrimitive(PrimitiveType.Cube);
            geometry.name = displayName + " · geometry";
            geometry.transform.SetParent(item.transform);
            geometry.transform.localPosition = Vector3.zero;
            geometry.transform.localScale = scale;
            geometry.GetComponent<Renderer>().sharedMaterial = material;
            return item;
        }

        private void CreateBorder(Transform parent, Vector3 size, Material material)
        {
            var thickness = 0.10f;
            var height = Mathf.Max(0.18f, size.y);
            CreateVisual("Border north", PrimitiveType.Cube, parent, new Vector3(0f, height * 0.5f, size.z * 0.5f), new Vector3(size.x, height, thickness), material);
            CreateVisual("Border south", PrimitiveType.Cube, parent, new Vector3(0f, height * 0.5f, -size.z * 0.5f), new Vector3(size.x, height, thickness), material);
            CreateVisual("Border east", PrimitiveType.Cube, parent, new Vector3(size.x * 0.5f, height * 0.5f, 0f), new Vector3(thickness, height, size.z), material);
            CreateVisual("Border west", PrimitiveType.Cube, parent, new Vector3(-size.x * 0.5f, height * 0.5f, 0f), new Vector3(thickness, height, size.z), material);
        }

        private void CreateBoundary(Vector3 position, Vector3 size)
        {
            var boundary = new GameObject("Invisible garden boundary");
            boundary.transform.SetParent(transform);
            boundary.transform.position = position;
            var collider = boundary.AddComponent<BoxCollider>();
            collider.size = size;
            boundary.AddComponent<GardenSemanticSurface>().Configure(GardenSemanticZone.Boundary, false);
            AddObstacle(boundary, size, Vector3.zero);
        }

        private static void AddObstacle(GameObject item, Vector3 size, Vector3 center)
        {
            var obstacle = item.AddComponent<NavMeshObstacle>();
            obstacle.shape = NavMeshObstacleShape.Box;
            obstacle.size = size;
            obstacle.center = center;
            obstacle.carving = true;
            obstacle.carveOnlyStationary = true;
        }

        private Transform CreateVisual(
            string displayName,
            PrimitiveType primitive,
            Transform parent,
            Vector3 localPosition,
            Vector3 localScale,
            Material material)
        {
            var item = GameObject.CreatePrimitive(primitive);
            item.name = displayName;
            item.layer = 2;
            item.transform.SetParent(parent);
            item.transform.localPosition = localPosition;
            item.transform.localScale = localScale;
            item.GetComponent<Renderer>().sharedMaterial = material;
            var itemCollider = item.GetComponent<Collider>();
            if (itemCollider != null)
            {
                itemCollider.enabled = false;
            }
            return item.transform;
        }

        private static Transform CreateLimbPivot(string displayName, Transform parent, Vector3 localPosition)
        {
            var pivot = new GameObject(displayName).transform;
            pivot.SetParent(parent);
            pivot.localPosition = localPosition;
            return pivot;
        }

        private void ApplyPreviewMaterial(Material material)
        {
            if (placementPreview == null)
            {
                return;
            }

            foreach (var renderer in placementPreview.GetComponentsInChildren<Renderer>())
            {
                renderer.sharedMaterial = material;
            }
        }

        private static void SetLayerRecursively(GameObject root, int layer)
        {
            root.layer = layer;
            foreach (Transform child in root.transform)
            {
                SetLayerRecursively(child.gameObject, layer);
            }
        }

        private Palette CreatePalette()
        {
            return new Palette
            {
                DustyRose = CreateMaterial("Dusty rose", Hex("C98D9C"), 0f, 0.36f),
                Wine = CreateMaterial("Pawdo wine", Hex("633347"), 0.04f, 0.40f),
                Cream = CreateMaterial("Warm cream", Hex("F3EADF"), 0f, 0.32f),
                LightWood = CreateMaterial("Light wood", Hex("A97855"), 0f, 0.30f),
                Botanical = CreateMaterial("Botanical green", Hex("506B55"), 0f, 0.28f),
                Gold = CreateMaterial("Discreet gold", Hex("B89A62"), 0.36f, 0.50f),
                Charcoal = CreateMaterial("Charcoal", Hex("29252A"), 0.05f, 0.32f),
                Grass = CreateMaterial("Mature lawn", new Color(0.26f, 0.39f, 0.27f), 0f, 0.22f),
                Stone = CreateMaterial("Cream limestone", new Color(0.70f, 0.65f, 0.56f), 0f, 0.28f),
                Soil = CreateMaterial("Cultivated soil", new Color(0.21f, 0.13f, 0.09f), 0f, 0.18f),
                Trunk = CreateMaterial("Olive wood", new Color(0.30f, 0.20f, 0.12f), 0f, 0.28f),
                Glass = CreateMaterial("Warm window glass", new Color(0.36f, 0.50f, 0.55f), 0.12f, 0.76f),
            };
        }

        private Material FindOrCreateMaterial(string displayName, Color color, float metallic, float smoothness)
        {
            foreach (var item in runtimeMaterials)
            {
                if (item != null && item.name == displayName)
                {
                    return item;
                }
            }
            return CreateMaterial(displayName, color, metallic, smoothness);
        }

        private Material CreateMaterial(
            string displayName,
            Color color,
            float metallic,
            float smoothness,
            bool transparent = false)
        {
            var shader = Shader.Find("Universal Render Pipeline/Lit") ?? Shader.Find("Standard");
            var material = new Material(shader) { name = displayName, color = color };
            if (material.HasProperty("_BaseColor")) material.SetColor("_BaseColor", color);
            if (material.HasProperty("_Metallic")) material.SetFloat("_Metallic", metallic);
            if (material.HasProperty("_Smoothness")) material.SetFloat("_Smoothness", smoothness);
            if (transparent)
            {
                if (material.HasProperty("_Surface")) material.SetFloat("_Surface", 1f);
                material.renderQueue = 3000;
            }
            runtimeMaterials.Add(material);
            return material;
        }

        private static Color Hex(string hex)
        {
            return ColorUtility.TryParseHtmlString("#" + hex, out var color)
                ? color
                : Color.white;
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

        private static bool TryReadHeldPointer(out Vector2 position)
        {
            if (Input.touchCount > 0)
            {
                var touch = Input.GetTouch(0);
                position = touch.position;
                return touch.phase == TouchPhase.Moved || touch.phase == TouchPhase.Stationary;
            }

            position = Input.mousePosition;
            return Input.GetMouseButton(0);
        }

        private bool IsPointerOverUi(Vector2 screenPosition)
        {
            var guiPoint = new Vector2(screenPosition.x, Screen.height - screenPosition.y);
            return topPanel.Contains(guiPoint) || editButton.Contains(guiPoint) ||
                   saveButton.Contains(guiPoint) || cancelButton.Contains(guiPoint) ||
                   PawdoVoiceRepeatController.IsScreenPointOverControl(screenPosition);
        }

        private void UpdatePointerRects()
        {
            var safe = Screen.safeArea;
            var guiTop = Screen.height - safe.yMax;
            topPanel = new Rect(safe.x + 22f, guiTop + 18f, Mathf.Min(650f, safe.width * 0.48f), 142f);
            var buttonWidth = 188f;
            editButton = new Rect(safe.xMax - buttonWidth - 24f, guiTop + 22f, buttonWidth, 54f);
            saveButton = new Rect(safe.xMax - buttonWidth - 24f, guiTop + 22f, buttonWidth, 54f);
            cancelButton = new Rect(safe.xMax - buttonWidth - 24f, guiTop + 88f, buttonWidth, 50f);
        }

        private void OnGUI()
        {
            EnsureStyles();
            UpdatePointerRects();
            var previousColor = GUI.color;
            GUI.color = new Color(0.08f, 0.07f, 0.08f, 0.84f);
            GUI.Box(topPanel, GUIContent.none);
            GUI.color = previousColor;
            GUI.Label(new Rect(topPanel.x + 22f, topPanel.y + 15f, topPanel.width - 44f, 34f), "Nuestro jardín", titleStyle);
            GUI.Label(
                new Rect(topPanel.x + 22f, topPanel.y + 51f, topPanel.width - 44f, 32f),
                "Toca el suelo para caminar o la lavanda para cuidarla.",
                bodyStyle);
            GUI.Label(
                new Rect(topPanel.x + 22f, topPanel.y + 88f, topPanel.width - 44f, 32f),
                wateringsCompleted > 0 ? "La lavanda está hidratada." : "Un momento para cuidar lo que crece juntos.",
                metricStyle);

            if (!placementMode)
            {
                if (GUI.Button(editButton, "EDITAR JARDÍN"))
                {
                    BeginPlacement();
                }
            }
            else
            {
                var decision = placementPolicy.Evaluate(
                    previewPosition,
                    previewHasHit ? previewSurface : null,
                    previewBlocked);
                GUI.enabled = decision.IsValid;
                if (GUI.Button(saveButton, decision.IsValid ? "GUARDAR UBICACIÓN" : "UBICACIÓN NO VÁLIDA"))
                {
                    SavePlacement();
                }
                GUI.enabled = true;
                if (GUI.Button(cancelButton, "CANCELAR"))
                {
                    CancelPlacement();
                }
                GUI.Label(
                    new Rect(topPanel.x, Screen.height - 84f, topPanel.width + 110f, 44f),
                    "Vista previa verde: cantero editable · roja: vacío, obstáculo o zona protegida",
                    hintStyle);
            }
        }

        private void EnsureStyles()
        {
            if (titleStyle != null)
            {
                return;
            }
            titleStyle = new GUIStyle(GUI.skin.label)
            {
                fontSize = 23,
                fontStyle = FontStyle.Bold,
                normal = { textColor = Hex("F3EADF") },
            };
            bodyStyle = new GUIStyle(GUI.skin.label)
            {
                fontSize = 15,
                normal = { textColor = new Color(0.86f, 0.82f, 0.78f) },
            };
            metricStyle = new GUIStyle(GUI.skin.label)
            {
                fontSize = 15,
                fontStyle = FontStyle.Bold,
                normal = { textColor = new Color(0.74f, 0.67f, 0.43f) },
            };
            hintStyle = new GUIStyle(GUI.skin.label)
            {
                fontSize = 16,
                alignment = TextAnchor.MiddleLeft,
                normal = { textColor = Color.white },
            };
        }

        private sealed class Palette
        {
            public Material DustyRose;
            public Material Wine;
            public Material Cream;
            public Material LightWood;
            public Material Botanical;
            public Material Gold;
            public Material Charcoal;
            public Material Grass;
            public Material Stone;
            public Material Soil;
            public Material Trunk;
            public Material Glass;
        }
    }
}
