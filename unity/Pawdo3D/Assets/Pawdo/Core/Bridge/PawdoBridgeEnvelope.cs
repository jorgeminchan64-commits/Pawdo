using System;
using System.Collections.Generic;
using System.Text;
using UnityEngine;

namespace Pawdo.Core.Bridge
{
    [Serializable]
    public sealed class PawdoBridgeEnvelope
    {
        public const int CurrentSchemaVersion = 1;
        public const int MaximumUtf8Bytes = 64 * 1024;

        public int schemaVersion;
        public string messageId;
        public string correlationId;
        public string type;
        public long sentAtEpochMs;

        public string RawJson { get; private set; }
        public string PayloadJson { get; private set; }

        public static bool TryParse(string rawJson, out PawdoBridgeEnvelope envelope, out string error)
        {
            envelope = null;
            error = null;
            if (string.IsNullOrWhiteSpace(rawJson))
            {
                error = "empty-message";
                return false;
            }

            if (Encoding.UTF8.GetByteCount(rawJson) > MaximumUtf8Bytes)
            {
                error = "message-too-large";
                return false;
            }

            if (!PawdoJsonObjectReader.TryReadTopLevelValues(rawJson, out var values, out error))
            {
                return false;
            }

            var required = new HashSet<string>(StringComparer.Ordinal)
            {
                "schemaVersion",
                "messageId",
                "correlationId",
                "type",
                "sentAtEpochMs",
                "payload",
            };
            if (values.Count != required.Count || !required.SetEquals(values.Keys))
            {
                error = "invalid-envelope-fields";
                return false;
            }

            try
            {
                envelope = JsonUtility.FromJson<PawdoBridgeEnvelope>(rawJson);
            }
            catch (Exception)
            {
                error = "invalid-json";
                envelope = null;
                return false;
            }

            if (envelope == null || envelope.schemaVersion != CurrentSchemaVersion)
            {
                error = "unsupported-schema-version";
                envelope = null;
                return false;
            }

            if (!Guid.TryParseExact(envelope.messageId, "D", out _))
            {
                error = "invalid-message-id";
                envelope = null;
                return false;
            }

            if (!string.IsNullOrEmpty(envelope.correlationId) &&
                !Guid.TryParseExact(envelope.correlationId, "D", out _))
            {
                error = "invalid-correlation-id";
                envelope = null;
                return false;
            }

            if (!PawdoBridgeMessageTypes.IsKnown(envelope.type))
            {
                error = "unknown-message-type";
                envelope = null;
                return false;
            }

            if (envelope.sentAtEpochMs <= 0)
            {
                error = "invalid-sent-at";
                envelope = null;
                return false;
            }

            var payload = values["payload"];
            if (payload.Length < 2 || payload[0] != '{' || payload[payload.Length - 1] != '}')
            {
                error = "payload-must-be-object";
                envelope = null;
                return false;
            }

            envelope.RawJson = rawJson;
            envelope.PayloadJson = payload;
            return true;
        }
    }
}

