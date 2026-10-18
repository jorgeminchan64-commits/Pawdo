using System;
using System.Collections.Generic;

namespace Pawdo.Core.Bridge
{
    internal static class PawdoJsonObjectReader
    {
        internal static bool TryReadTopLevelValues(
            string json,
            out Dictionary<string, string> values,
            out string error)
        {
            values = new Dictionary<string, string>(StringComparer.Ordinal);
            error = null;
            if (string.IsNullOrWhiteSpace(json))
            {
                error = "empty-json";
                return false;
            }

            var index = 0;
            SkipWhitespace(json, ref index);
            if (!Consume(json, ref index, '{'))
            {
                error = "root-must-be-object";
                return false;
            }

            SkipWhitespace(json, ref index);
            if (Consume(json, ref index, '}'))
            {
                return true;
            }

            while (index < json.Length)
            {
                if (!TryReadString(json, ref index, out var propertyName))
                {
                    error = "invalid-property-name";
                    return false;
                }

                SkipWhitespace(json, ref index);
                if (!Consume(json, ref index, ':'))
                {
                    error = "missing-property-separator";
                    return false;
                }

                SkipWhitespace(json, ref index);
                var valueStart = index;
                if (!TrySkipValue(json, ref index))
                {
                    error = "invalid-property-value";
                    return false;
                }

                if (values.ContainsKey(propertyName))
                {
                    error = "duplicate-property";
                    return false;
                }

                values[propertyName] = json.Substring(valueStart, index - valueStart).Trim();
                SkipWhitespace(json, ref index);
                if (Consume(json, ref index, '}'))
                {
                    SkipWhitespace(json, ref index);
                    if (index != json.Length)
                    {
                        error = "trailing-content";
                        return false;
                    }

                    return true;
                }

                if (!Consume(json, ref index, ','))
                {
                    error = "missing-property-comma";
                    return false;
                }

                SkipWhitespace(json, ref index);
            }

            error = "unterminated-object";
            return false;
        }

        private static bool TrySkipValue(string json, ref int index)
        {
            if (index >= json.Length)
            {
                return false;
            }

            if (json[index] == '"')
            {
                return TryReadString(json, ref index, out _);
            }

            if (json[index] == '{' || json[index] == '[')
            {
                var opening = json[index];
                var closing = opening == '{' ? '}' : ']';
                var depth = 0;
                var inString = false;
                var escaped = false;
                while (index < json.Length)
                {
                    var current = json[index++];
                    if (inString)
                    {
                        if (escaped)
                        {
                            escaped = false;
                        }
                        else if (current == '\\')
                        {
                            escaped = true;
                        }
                        else if (current == '"')
                        {
                            inString = false;
                        }

                        continue;
                    }

                    if (current == '"')
                    {
                        inString = true;
                    }
                    else if (current == opening)
                    {
                        depth++;
                    }
                    else if (current == closing && --depth == 0)
                    {
                        return true;
                    }
                }

                return false;
            }

            var start = index;
            while (index < json.Length && json[index] != ',' && json[index] != '}')
            {
                index++;
            }

            return index > start;
        }

        private static bool TryReadString(string json, ref int index, out string value)
        {
            value = null;
            SkipWhitespace(json, ref index);
            if (!Consume(json, ref index, '"'))
            {
                return false;
            }

            var start = index;
            var escaped = false;
            while (index < json.Length)
            {
                var current = json[index++];
                if (escaped)
                {
                    escaped = false;
                    continue;
                }

                if (current == '\\')
                {
                    escaped = true;
                    continue;
                }

                if (current == '"')
                {
                    value = json.Substring(start, index - start - 1);
                    return value.IndexOf('\\') < 0;
                }
            }

            return false;
        }

        private static void SkipWhitespace(string json, ref int index)
        {
            while (index < json.Length && char.IsWhiteSpace(json[index]))
            {
                index++;
            }
        }

        private static bool Consume(string json, ref int index, char expected)
        {
            if (index >= json.Length || json[index] != expected)
            {
                return false;
            }

            index++;
            return true;
        }
    }
}

