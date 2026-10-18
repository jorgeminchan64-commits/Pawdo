using UnityEngine;

namespace Pawdo.Garden
{
    public static class PointerGesturePolicy
    {
        public static bool ShouldTrigger(TouchPhase phase, bool alreadyConsumed)
        {
            return phase == TouchPhase.Began && !alreadyConsumed;
        }
    }
}
