using System;
using UnityEngine;

namespace Pawdo.Garden
{
    public enum GardenPlacementStatus
    {
        Valid,
        MissingSurface,
        OutsideEditableBounds,
        WrongSemanticZone,
        Blocked,
    }

    public readonly struct GardenPlacementDecision
    {
        public GardenPlacementDecision(GardenPlacementStatus status)
        {
            Status = status;
        }

        public GardenPlacementStatus Status { get; }
        public bool IsValid => Status == GardenPlacementStatus.Valid;
    }

    public sealed class GardenPlacementPolicy
    {
        private readonly Bounds editableBounds;

        public GardenPlacementPolicy(Bounds editableBounds)
        {
            this.editableBounds = editableBounds;
        }

        public GardenPlacementDecision Evaluate(
            Vector3 position,
            GardenSemanticSurface surface,
            bool blocked)
        {
            if (surface == null)
            {
                return new GardenPlacementDecision(GardenPlacementStatus.MissingSurface);
            }

            if (!editableBounds.Contains(position))
            {
                return new GardenPlacementDecision(GardenPlacementStatus.OutsideEditableBounds);
            }

            if (surface.Zone != GardenSemanticZone.PlanterPlot || !surface.AcceptsPlantPlacement)
            {
                return new GardenPlacementDecision(GardenPlacementStatus.WrongSemanticZone);
            }

            return new GardenPlacementDecision(
                blocked ? GardenPlacementStatus.Blocked : GardenPlacementStatus.Valid);
        }
    }

    [Serializable]
    public sealed class GardenLayoutSnapshot
    {
        public int schemaVersion = 1;
        public int baseRevision;
        public GardenPlacedItem[] items = Array.Empty<GardenPlacedItem>();
    }

    [Serializable]
    public sealed class GardenPlacedItem
    {
        public string instanceId;
        public string assetId;
        public float x;
        public float y;
        public float z;
        public float yaw;
        public string semanticZone;
    }
}
