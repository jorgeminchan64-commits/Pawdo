using UnityEngine;

namespace Pawdo.Characters
{
    public static class AvatarFacingPolicy
    {
        public const float MovementEpsilon = 0.0001f;

        public static bool TryGetForward(Vector3 movement, out Vector3 forward)
        {
            movement.y = 0f;
            if (movement.sqrMagnitude <= MovementEpsilon)
            {
                forward = Vector3.forward;
                return false;
            }

            forward = movement.normalized;
            return true;
        }

        public static Quaternion ResolveRotation(Vector3 movement, Quaternion fallback)
        {
            return TryGetForward(movement, out var forward)
                ? Quaternion.LookRotation(forward, Vector3.up)
                : fallback;
        }

        public static bool FacesMovement(Quaternion rotation, Vector3 movement, float minimumDot = 0.98f)
        {
            if (!TryGetForward(movement, out var forward))
            {
                return true;
            }

            var facing = rotation * Vector3.forward;
            facing.y = 0f;
            return Vector3.Dot(facing.normalized, forward) >= minimumDot;
        }
    }
}
