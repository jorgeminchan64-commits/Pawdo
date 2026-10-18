using UnityEngine;
using UnityEngine.AI;

namespace Pawdo.Characters
{
    [RequireComponent(typeof(NavMeshAgent))]
    public sealed class ProceduralAvatarMotor : MonoBehaviour
    {
        [SerializeField] private Transform leftArmPivot;
        [SerializeField] private Transform rightArmPivot;
        [SerializeField] private Transform leftLegPivot;
        [SerializeField] private Transform rightLegPivot;
        private NavMeshAgent agent;
        private float strideClock;
        private bool interactionLocked;
        private Quaternion leftArmRest;
        private Quaternion rightArmRest;
        private Quaternion leftLegRest;
        private Quaternion rightLegRest;

        public int AcceptedMoves { get; private set; }
        public int HorizontalFacingChecks { get; private set; }
        public int HorizontalFacingFailures { get; private set; }
        public bool HasArrived => agent != null && agent.isOnNavMesh &&
                                  !agent.pathPending &&
                                  agent.remainingDistance <= agent.stoppingDistance + 0.08f;

        public void Configure(
            Transform leftArm,
            Transform rightArm,
            Transform leftLeg,
            Transform rightLeg,
            float radius = 0.28f)
        {
            leftArmPivot = leftArm;
            rightArmPivot = rightArm;
            leftLegPivot = leftLeg;
            rightLegPivot = rightLeg;
            agent = GetComponent<NavMeshAgent>();
            agent.radius = radius;
            agent.height = 1.72f;
            agent.speed = 2.25f;
            agent.acceleration = 8f;
            agent.angularSpeed = 0f;
            agent.stoppingDistance = 0.12f;
            agent.autoBraking = true;
            agent.obstacleAvoidanceType = ObstacleAvoidanceType.HighQualityObstacleAvoidance;
            agent.updateRotation = false;
            CacheRestPose();
        }

        private void Awake()
        {
            agent = GetComponent<NavMeshAgent>();
        }

        private void Start()
        {
            CacheRestPose();
        }

        private void Update()
        {
            if (agent == null || !agent.isOnNavMesh)
            {
                return;
            }

            var velocity = agent.velocity;
            if (AvatarFacingPolicy.TryGetForward(velocity, out var forward))
            {
                var desired = Quaternion.LookRotation(forward, Vector3.up);
                transform.rotation = Quaternion.RotateTowards(
                    transform.rotation,
                    desired,
                    540f * Time.deltaTime);
                AnimateWalk(velocity.magnitude);
            }
            else
            {
                ReturnToRestPose();
            }
        }

        public bool MoveTo(Vector3 destination)
        {
            if (interactionLocked || agent == null || !agent.isOnNavMesh ||
                !NavMesh.SamplePosition(destination, out var sample, 1.25f, NavMesh.AllAreas))
            {
                return false;
            }

            var delta = sample.position - transform.position;
            if (delta.sqrMagnitude < 0.01f || !agent.SetDestination(sample.position))
            {
                return false;
            }

            AcceptedMoves++;
            if (Mathf.Abs(delta.x) > Mathf.Abs(delta.z) * 1.5f)
            {
                HorizontalFacingChecks++;
                var resolved = AvatarFacingPolicy.ResolveRotation(delta, transform.rotation);
                if (!AvatarFacingPolicy.FacesMovement(resolved, delta))
                {
                    HorizontalFacingFailures++;
                }
            }

            if (AcceptedMoves % 10 == 0)
            {
                Debug.Log(
                    $"PAWDO_VS2_MOVE accepted={AcceptedMoves} horizontal={HorizontalFacingChecks} " +
                    $"facingFailures={HorizontalFacingFailures}");
            }

            return true;
        }

        public bool MoveToInteraction(Vector3 destination)
        {
            interactionLocked = false;
            var accepted = MoveTo(destination);
            interactionLocked = accepted;
            return accepted;
        }

        public void Face(Vector3 worldPoint)
        {
            var direction = worldPoint - transform.position;
            transform.rotation = AvatarFacingPolicy.ResolveRotation(direction, transform.rotation);
        }

        public void FinishInteraction()
        {
            interactionLocked = false;
            ReturnToRestPose();
        }

        public void StabilizeInteractionPose()
        {
            interactionLocked = true;
            if (leftArmPivot != null) leftArmPivot.localRotation = leftArmRest;
            if (rightArmPivot != null) rightArmPivot.localRotation = rightArmRest;
            if (leftLegPivot != null) leftLegPivot.localRotation = leftLegRest;
            if (rightLegPivot != null) rightLegPivot.localRotation = rightLegRest;
        }

        public void PoseWatering(float normalizedTime)
        {
            if (leftArmPivot == null || rightArmPivot == null)
            {
                return;
            }

            var pulse = Mathf.Sin(normalizedTime * Mathf.PI) * 8f;
            leftArmPivot.localRotation = leftArmRest * Quaternion.Euler(58f + pulse, 0f, -12f);
            rightArmPivot.localRotation = rightArmRest * Quaternion.Euler(64f + pulse, 0f, 12f);
        }

        private void AnimateWalk(float speed)
        {
            strideClock += Time.deltaTime * Mathf.Lerp(4.5f, 7f, Mathf.Clamp01(speed / 2.25f));
            var swing = Mathf.Sin(strideClock) * 24f;
            if (leftArmPivot != null) leftArmPivot.localRotation = leftArmRest * Quaternion.Euler(-swing, 0f, 0f);
            if (rightArmPivot != null) rightArmPivot.localRotation = rightArmRest * Quaternion.Euler(swing, 0f, 0f);
            if (leftLegPivot != null) leftLegPivot.localRotation = leftLegRest * Quaternion.Euler(swing, 0f, 0f);
            if (rightLegPivot != null) rightLegPivot.localRotation = rightLegRest * Quaternion.Euler(-swing, 0f, 0f);
        }

        private void CacheRestPose()
        {
            if (leftArmPivot != null) leftArmRest = leftArmPivot.localRotation;
            if (rightArmPivot != null) rightArmRest = rightArmPivot.localRotation;
            if (leftLegPivot != null) leftLegRest = leftLegPivot.localRotation;
            if (rightLegPivot != null) rightLegRest = rightLegPivot.localRotation;
        }

        private void ReturnToRestPose()
        {
            if (leftArmPivot != null) leftArmPivot.localRotation = Quaternion.Slerp(leftArmPivot.localRotation, leftArmRest, Time.deltaTime * 8f);
            if (rightArmPivot != null) rightArmPivot.localRotation = Quaternion.Slerp(rightArmPivot.localRotation, rightArmRest, Time.deltaTime * 8f);
            if (leftLegPivot != null) leftLegPivot.localRotation = Quaternion.Slerp(leftLegPivot.localRotation, leftLegRest, Time.deltaTime * 8f);
            if (rightLegPivot != null) rightLegPivot.localRotation = Quaternion.Slerp(rightLegPivot.localRotation, rightLegRest, Time.deltaTime * 8f);
        }
    }

    [RequireComponent(typeof(NavMeshAgent))]
    public sealed class ProceduralPawdoMotor : MonoBehaviour
    {
        [SerializeField] private Transform tailPivot;
        [SerializeField] private Transform[] legPivots;
        private NavMeshAgent agent;
        private float gaitClock;
        private Vector3 home;

        public void Configure(Transform tail, Transform[] legs)
        {
            tailPivot = tail;
            legPivots = legs;
            agent = GetComponent<NavMeshAgent>();
            agent.radius = 0.22f;
            agent.height = 0.62f;
            agent.speed = 1.85f;
            agent.acceleration = 6f;
            agent.angularSpeed = 0f;
            agent.stoppingDistance = 0.18f;
            agent.updateRotation = false;
            home = transform.position;
        }

        private void Awake()
        {
            agent = GetComponent<NavMeshAgent>();
            home = transform.position;
        }

        private void Update()
        {
            if (agent == null || !agent.isOnNavMesh)
            {
                return;
            }

            gaitClock += Time.deltaTime * (agent.velocity.sqrMagnitude > 0.03f ? 8f : 3f);
            if (AvatarFacingPolicy.TryGetForward(agent.velocity, out var forward))
            {
                transform.rotation = Quaternion.RotateTowards(
                    transform.rotation,
                    Quaternion.LookRotation(forward),
                    480f * Time.deltaTime);
                for (var index = 0; index < legPivots.Length; index++)
                {
                    if (legPivots[index] == null) continue;
                    var phase = index % 2 == 0 ? 1f : -1f;
                    legPivots[index].localRotation = Quaternion.Euler(Mathf.Sin(gaitClock) * 16f * phase, 0f, 0f);
                }
            }

            if (tailPivot != null)
            {
                tailPivot.localRotation = Quaternion.Euler(-20f, Mathf.Sin(gaitClock * 1.6f) * 28f, 24f);
            }
        }

        public void Follow(Vector3 destination)
        {
            if (agent != null && agent.isOnNavMesh &&
                NavMesh.SamplePosition(destination, out var sample, 1.5f, NavMesh.AllAreas))
            {
                agent.SetDestination(sample.position);
            }
        }

        public void ReturnHome()
        {
            Follow(home);
        }
    }
}
