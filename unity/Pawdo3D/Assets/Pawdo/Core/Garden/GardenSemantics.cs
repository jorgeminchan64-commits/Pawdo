using UnityEngine;

namespace Pawdo.Garden
{
    public enum GardenSemanticZone
    {
        FreeGrass,
        Walkway,
        FlowerBed,
        PlanterPlot,
        House,
        Tree,
        Furniture,
        Boundary,
    }

    public sealed class GardenSemanticSurface : MonoBehaviour
    {
        [SerializeField] private GardenSemanticZone zone = GardenSemanticZone.FreeGrass;
        [SerializeField] private bool acceptsPlantPlacement;

        public GardenSemanticZone Zone => zone;
        public bool AcceptsPlantPlacement => acceptsPlantPlacement;

        public void Configure(GardenSemanticZone semanticZone, bool acceptsPlacement)
        {
            zone = semanticZone;
            acceptsPlantPlacement = acceptsPlacement;
        }
    }
}
