using UnityEngine;

namespace Pawdo.Garden
{
    public sealed class PlantInteractable : MonoBehaviour
    {
        [SerializeField] private Transform wateringSocket;
        [SerializeField] private bool needsWater = true;
        private bool wateringInProgress;

        public Transform WateringSocket => wateringSocket;
        public bool NeedsWater => needsWater;
        public bool WateringInProgress => wateringInProgress;
        public int CompletedWaterings { get; private set; }

        public void Configure(Transform socket, bool initiallyNeedsWater = true)
        {
            wateringSocket = socket;
            needsWater = initiallyNeedsWater;
            wateringInProgress = false;
            CompletedWaterings = 0;
        }

        public bool TryBeginWatering()
        {
            if (!needsWater || wateringInProgress || wateringSocket == null)
            {
                return false;
            }

            wateringInProgress = true;
            return true;
        }

        public void CompleteWatering()
        {
            if (!wateringInProgress)
            {
                return;
            }

            wateringInProgress = false;
            needsWater = false;
            CompletedWaterings++;
        }

        public void CancelWatering()
        {
            wateringInProgress = false;
        }

        public void ResetHydrationForTesting()
        {
            needsWater = true;
            wateringInProgress = false;
        }
    }

    public static class GardenInteractionPolicy
    {
        public static PlantInteractable ResolvePlant(Collider hitCollider)
        {
            return hitCollider == null
                ? null
                : hitCollider.GetComponentInParent<PlantInteractable>();
        }
    }
}
