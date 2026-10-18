using System;
using UnityEngine;

namespace Pawdo.Interior
{
    public enum SleepOccupantKind
    {
        Avatar,
        Pawdo,
    }

    public enum SleepSocketKind
    {
        AvatarLeft,
        AvatarRight,
        Pawdo,
    }

    public enum PairSleepState
    {
        Awake,
        WalkingToEntries,
        SittingDown,
        LyingDown,
        Sleeping,
        Rising,
        WalkingToExits,
    }

    public sealed class SleepSocket : MonoBehaviour
    {
        [SerializeField] private SleepSocketKind kind;
        [SerializeField] private Transform entryPoint;
        [SerializeField] private Transform exitPoint;
        [SerializeField] private string occupantId = string.Empty;

        public SleepSocketKind Kind => kind;
        public Transform EntryPoint => entryPoint;
        public Transform ExitPoint => exitPoint;
        public string OccupantId => occupantId;
        public bool IsReserved => !string.IsNullOrEmpty(occupantId);

        public void Configure(
            SleepSocketKind socketKind,
            Transform entry,
            Transform exit)
        {
            kind = socketKind;
            entryPoint = entry;
            exitPoint = exit;
            occupantId = string.Empty;
        }

        public bool CanHost(SleepOccupantKind occupantKind)
        {
            return occupantKind == SleepOccupantKind.Pawdo
                ? kind == SleepSocketKind.Pawdo
                : kind == SleepSocketKind.AvatarLeft || kind == SleepSocketKind.AvatarRight;
        }

        public bool TryReserve(string id, SleepOccupantKind occupantKind)
        {
            if (string.IsNullOrWhiteSpace(id) || !CanHost(occupantKind))
            {
                return false;
            }

            if (IsReserved && !string.Equals(occupantId, id, StringComparison.Ordinal))
            {
                return false;
            }

            occupantId = id;
            return true;
        }

        public bool Release(string id)
        {
            if (!IsReserved || !string.Equals(occupantId, id, StringComparison.Ordinal))
            {
                return false;
            }

            occupantId = string.Empty;
            return true;
        }
    }

    public sealed class DoubleBedInteractable : MonoBehaviour
    {
        [SerializeField] private SleepSocket leftSocket;
        [SerializeField] private SleepSocket rightSocket;

        public SleepSocket LeftSocket => leftSocket;
        public SleepSocket RightSocket => rightSocket;
        public bool IsConfigured => leftSocket != null && rightSocket != null &&
                                    leftSocket != rightSocket &&
                                    leftSocket.Kind == SleepSocketKind.AvatarLeft &&
                                    rightSocket.Kind == SleepSocketKind.AvatarRight &&
                                    leftSocket.EntryPoint != null && rightSocket.EntryPoint != null &&
                                    leftSocket.ExitPoint != null && rightSocket.ExitPoint != null;

        public void Configure(SleepSocket left, SleepSocket right)
        {
            leftSocket = left;
            rightSocket = right;
        }

        public bool TryReservePair(string leftOccupantId, string rightOccupantId)
        {
            if (!IsConfigured || string.Equals(leftOccupantId, rightOccupantId, StringComparison.Ordinal))
            {
                return false;
            }

            if (!leftSocket.TryReserve(leftOccupantId, SleepOccupantKind.Avatar))
            {
                return false;
            }

            if (rightSocket.TryReserve(rightOccupantId, SleepOccupantKind.Avatar))
            {
                return true;
            }

            leftSocket.Release(leftOccupantId);
            return false;
        }

        public bool ReleasePair(string leftOccupantId, string rightOccupantId)
        {
            var leftReleased = leftSocket != null && leftSocket.Release(leftOccupantId);
            var rightReleased = rightSocket != null && rightSocket.Release(rightOccupantId);
            return leftReleased && rightReleased;
        }
    }

    public sealed class PawdoBedInteractable : MonoBehaviour
    {
        [SerializeField] private SleepSocket sleepSocket;

        public SleepSocket SleepSocket => sleepSocket;
        public bool IsConfigured => sleepSocket != null &&
                                    sleepSocket.Kind == SleepSocketKind.Pawdo &&
                                    sleepSocket.EntryPoint != null &&
                                    sleepSocket.ExitPoint != null;

        public void Configure(SleepSocket socket)
        {
            sleepSocket = socket;
        }
    }

    public sealed class InteriorStableProp : MonoBehaviour
    {
        [SerializeField] private string stableId = string.Empty;
        public string StableId => stableId;

        public void Configure(string id)
        {
            stableId = id ?? string.Empty;
        }
    }

    public static class InteriorInteractionPolicy
    {
        public static DoubleBedInteractable ResolveDoubleBed(Collider collider)
        {
            return collider == null ? null : collider.GetComponentInParent<DoubleBedInteractable>();
        }

        public static PawdoBedInteractable ResolvePawdoBed(Collider collider)
        {
            return collider == null ? null : collider.GetComponentInParent<PawdoBedInteractable>();
        }
    }

    public sealed class SleepCycleAudit
    {
        private readonly int baselineStableProps;

        public SleepCycleAudit(int stableProps)
        {
            baselineStableProps = stableProps;
        }

        public int CompletedCycles { get; private set; }
        public int TeleportViolations { get; private set; }
        public int CollisionViolations { get; private set; }
        public int DuplicateViolations { get; private set; }

        public void ObserveFrameDelta(float distance, float maximumAllowed = 0.55f)
        {
            if (distance > maximumAllowed)
            {
                TeleportViolations++;
            }
        }

        public bool CompleteCycle(
            int currentStableProps,
            float avatarSeparation,
            float minimumSeparation = 0.48f)
        {
            if (currentStableProps != baselineStableProps)
            {
                DuplicateViolations++;
            }
            if (avatarSeparation < minimumSeparation)
            {
                CollisionViolations++;
            }

            CompletedCycles++;
            return TeleportViolations == 0 && CollisionViolations == 0 && DuplicateViolations == 0;
        }
    }
}
