using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Text;
using System.Web.Script.Serialization;

namespace AetherDeskAI.NativeHost
{
    internal static class Program
    {
        private static readonly JavaScriptSerializer Json = new JavaScriptSerializer { MaxJsonLength = 1024 * 1024 * 10 };

        private static void Main()
        {
            try
            {
                Dictionary<string, object> message = ReadMessage();
                if (message == null)
                {
                    WriteMessage(new Dictionary<string, object> { { "ok", false }, { "error", "No message received" } });
                    return;
                }

                WriteMessage(HandleMessage(message));
            }
            catch (Exception ex)
            {
                WriteMessage(new Dictionary<string, object> {
                    { "ok", false },
                    { "error", ex.Message }
                });
            }
        }

        private static Dictionary<string, object> ReadMessage()
        {
            Stream input = Console.OpenStandardInput();
            byte[] lengthBytes = new byte[4];
            int read = input.Read(lengthBytes, 0, 4);

            if (read == 0)
            {
                return null;
            }

            if (read != 4)
            {
                throw new InvalidDataException("Invalid native message length.");
            }

            int length = BitConverter.ToInt32(lengthBytes, 0);
            if (length <= 0 || length > 1024 * 1024 * 10)
            {
                throw new InvalidDataException("Native message length out of range.");
            }

            byte[] buffer = new byte[length];
            int offset = 0;

            while (offset < length)
            {
                int chunk = input.Read(buffer, offset, length - offset);
                if (chunk <= 0)
                {
                    throw new EndOfStreamException("Unexpected end of native message.");
                }

                offset += chunk;
            }

            string json = Encoding.UTF8.GetString(buffer);
            return Json.Deserialize<Dictionary<string, object>>(json);
        }

        private static void WriteMessage(Dictionary<string, object> response)
        {
            string json = Json.Serialize(response);
            byte[] bytes = Encoding.UTF8.GetBytes(json);
            byte[] length = BitConverter.GetBytes(bytes.Length);
            Stream output = Console.OpenStandardOutput();
            output.Write(length, 0, 4);
            output.Write(bytes, 0, bytes.Length);
            output.Flush();
        }

        private static Dictionary<string, object> HandleMessage(Dictionary<string, object> message)
        {
            string command = GetString(message, "command");

            switch (command)
            {
                case "ping":
                    return Ok("AetherDesk native host connected");
                case "getStats":
                    return GetStats();
                case "getLatestReport":
                    return GetLatestReport();
                case "openLatestReport":
                    return OpenLatestReport();
                case "openReportsFolder":
                    return OpenReportsFolder();
                case "savePage":
                    return SavePage(message);
                case "saveSource":
                    return SaveSource(message);
                case "saveScreenshot":
                    return SaveScreenshot(message);
                case "logActivity":
                    return LogActivity(message);
                case "runTrendRadar":
                    return RunTrendRadar(message);
                default:
                    return Error("Unknown command: " + command);
            }
        }

        private static Dictionary<string, object> SavePage(Dictionary<string, object> message)
        {
            string date = DateTime.Now.ToString("yyyy-MM-dd");
            string path = Path.Combine(ProjectRoot(), "social-data", "browser-saved-pages-" + date + ".jsonl");
            EnsureParent(path);

            Dictionary<string, object> row = new Dictionary<string, object>
            {
                { "type", "browserSavedPage" },
                { "savedAt", DateTime.Now.ToString("s") },
                { "title", GetString(message, "title") },
                { "url", GetString(message, "url") },
                { "domain", GetString(message, "domain") },
                { "topic", GetString(message, "topic") },
                { "note", GetString(message, "note") }
            };

            File.AppendAllText(path, Json.Serialize(row) + Environment.NewLine, Encoding.UTF8);
            return Ok("Page saved", new Dictionary<string, object> { { "path", path } });
        }

        private static Dictionary<string, object> LogActivity(Dictionary<string, object> message)
        {
            string date = DateTime.Now.ToString("yyyy-MM-dd");
            string path = Path.Combine(ProjectRoot(), "activity-data", "browser-activity-" + date + ".jsonl");
            EnsureParent(path);

            Dictionary<string, object> row = new Dictionary<string, object>
            {
                { "type", "browserActivity" },
                { "loggedAt", DateTime.Now.ToString("s") },
                { "title", GetString(message, "title") },
                { "url", GetString(message, "url") },
                { "domain", GetString(message, "domain") },
                { "startedAt", GetString(message, "startedAt") },
                { "endedAt", GetString(message, "endedAt") },
                { "durationSeconds", GetInt(message, "durationSeconds") },
                { "reason", GetString(message, "reason") }
            };

            File.AppendAllText(path, Json.Serialize(row) + Environment.NewLine, Encoding.UTF8);
            return Ok("Activity logged", new Dictionary<string, object> { { "path", path } });
        }

        private static Dictionary<string, object> RunTrendRadar(Dictionary<string, object> message)
        {
            string topic = GetString(message, "topic");
            if (string.IsNullOrWhiteSpace(topic))
            {
                return Error("Topic is required.");
            }

            string script = Path.Combine(ProjectRoot(), "social-trend-report.ps1");
            if (!File.Exists(script))
            {
                return Error("social-trend-report.ps1 was not found.");
            }

            string powershell = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows), @"System32\WindowsPowerShell\v1.0\powershell.exe");
            ProcessStartInfo startInfo = new ProcessStartInfo
            {
                FileName = powershell,
                Arguments = "-NoProfile -ExecutionPolicy Bypass -File \"" + script + "\" -Topic \"" + topic.Replace("\"", "\\\"") + "\"",
                WorkingDirectory = ProjectRoot(),
                UseShellExecute = false,
                CreateNoWindow = true,
                WindowStyle = ProcessWindowStyle.Hidden
            };

            Process.Start(startInfo);

            return Ok("TrendRadar started", new Dictionary<string, object> {
                { "topic", topic },
                { "startedAt", DateTime.Now.ToString("o") }
            });
        }

        private static Dictionary<string, object> SaveSource(Dictionary<string, object> message)
        {
            string date = DateTime.Now.ToString("yyyy-MM-dd");
            string title = GetString(message, "title");
            string slug = Slugify(string.IsNullOrWhiteSpace(title) ? "browser-page" : title);
            string folder = Path.Combine(ProjectRoot(), "social-data", "browser-sources", date);
            Directory.CreateDirectory(folder);

            string htmlPath = UniquePath(Path.Combine(folder, slug + ".html"));
            string metaPath = Path.ChangeExtension(htmlPath, ".json");

            File.WriteAllText(htmlPath, GetString(message, "html"), Encoding.UTF8);

            Dictionary<string, object> meta = new Dictionary<string, object>
            {
                { "type", "browserPageSource" },
                { "savedAt", DateTime.Now.ToString("s") },
                { "title", title },
                { "url", GetString(message, "url") },
                { "domain", GetString(message, "domain") },
                { "text", GetString(message, "text") },
                { "selectedText", GetString(message, "selectedText") },
                { "htmlPath", htmlPath }
            };

            File.WriteAllText(metaPath, Json.Serialize(meta), Encoding.UTF8);
            return Ok("Source saved", new Dictionary<string, object> { { "path", htmlPath }, { "metaPath", metaPath } });
        }

        private static Dictionary<string, object> SaveScreenshot(Dictionary<string, object> message)
        {
            string dataUrl = GetString(message, "dataUrl");
            if (string.IsNullOrWhiteSpace(dataUrl) || !dataUrl.StartsWith("data:image/png;base64,", StringComparison.OrdinalIgnoreCase))
            {
                return Error("PNG data URL is required.");
            }

            string date = DateTime.Now.ToString("yyyy-MM-dd");
            string title = GetString(message, "title");
            string selector = GetString(message, "selector");
            string slug = Slugify((string.IsNullOrWhiteSpace(title) ? "browser-capture" : title) + "-" + selector);
            string folder = Path.Combine(ProjectRoot(), "screenshots", "browser-captures", date);
            Directory.CreateDirectory(folder);

            string imagePath = UniquePath(Path.Combine(folder, slug + ".png"));
            string metaPath = Path.ChangeExtension(imagePath, ".json");
            string base64 = dataUrl.Substring("data:image/png;base64,".Length);
            File.WriteAllBytes(imagePath, Convert.FromBase64String(base64));

            Dictionary<string, object> meta = new Dictionary<string, object>
            {
                { "type", "browserScreenshot" },
                { "savedAt", DateTime.Now.ToString("s") },
                { "title", title },
                { "url", GetString(message, "url") },
                { "domain", GetString(message, "domain") },
                { "selector", selector },
                { "imagePath", imagePath }
            };

            File.WriteAllText(metaPath, Json.Serialize(meta), Encoding.UTF8);
            return Ok("Screenshot saved", new Dictionary<string, object> { { "path", imagePath }, { "metaPath", metaPath } });
        }

        private static Dictionary<string, object> GetStats()
        {
            string root = ProjectRoot();
            string reports = Path.Combine(root, "reports");
            string activity = Path.Combine(root, "activity-data");
            string social = Path.Combine(root, "social-data");

            return Ok("Stats loaded", new Dictionary<string, object> {
                { "reportCount", CountFiles(reports, "*.html", false) },
                { "browserActivityCount", CountLines(activity, "browser-activity-*.jsonl") },
                { "savedPageCount", CountLines(social, "browser-saved-pages-*.jsonl") },
                { "browserSourceCount", CountFiles(Path.Combine(social, "browser-sources"), "*.html", true) },
                { "browserScreenshotCount", CountFiles(Path.Combine(root, "screenshots", "browser-captures"), "*.png", true) },
                { "projectRoot", root }
            });
        }

        private static Dictionary<string, object> GetLatestReport()
        {
            FileInfo latest = LatestReport();
            if (latest == null)
            {
                return Error("No HTML report found.");
            }

            return Ok("Latest report loaded", new Dictionary<string, object> {
                { "path", latest.FullName },
                { "name", latest.Name },
                { "lastWriteTime", latest.LastWriteTime.ToString("o") }
            });
        }

        private static Dictionary<string, object> OpenLatestReport()
        {
            FileInfo latest = LatestReport();
            if (latest == null)
            {
                return Error("No HTML report found.");
            }

            OpenPath(latest.FullName);
            return Ok("Latest report opened", new Dictionary<string, object> {
                { "path", latest.FullName },
                { "name", latest.Name }
            });
        }

        private static Dictionary<string, object> OpenReportsFolder()
        {
            string reports = Path.Combine(ProjectRoot(), "reports");
            Directory.CreateDirectory(reports);
            OpenPath(reports);
            return Ok("Reports folder opened", new Dictionary<string, object> { { "path", reports } });
        }

        private static FileInfo LatestReport()
        {
            string reports = Path.Combine(ProjectRoot(), "reports");
            if (!Directory.Exists(reports)) return null;

            return Directory.GetFiles(reports, "*.html", SearchOption.TopDirectoryOnly)
                .Select(path => new FileInfo(path))
                .OrderByDescending(file => file.LastWriteTime)
                .FirstOrDefault();
        }

        private static void OpenPath(string path)
        {
            ProcessStartInfo info = new ProcessStartInfo
            {
                FileName = path,
                UseShellExecute = true
            };
            Process.Start(info);
        }

        private static int CountFiles(string folder, string pattern, bool recursive)
        {
            if (!Directory.Exists(folder)) return 0;
            return Directory.GetFiles(folder, pattern, recursive ? SearchOption.AllDirectories : SearchOption.TopDirectoryOnly).Length;
        }

        private static int CountLines(string folder, string pattern)
        {
            if (!Directory.Exists(folder)) return 0;
            int count = 0;
            foreach (string file in Directory.GetFiles(folder, pattern, SearchOption.AllDirectories))
            {
                count += File.ReadLines(file).Count();
            }
            return count;
        }

        private static string ProjectRoot()
        {
            string baseDir = AppDomain.CurrentDomain.BaseDirectory.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
            DirectoryInfo dir = new DirectoryInfo(baseDir);

            if (dir.Parent != null && dir.Parent.Parent != null)
            {
                return dir.Parent.Parent.FullName;
            }

            return baseDir;
        }

        private static void EnsureParent(string path)
        {
            string parent = Path.GetDirectoryName(path);
            if (!Directory.Exists(parent))
            {
                Directory.CreateDirectory(parent);
            }
        }

        private static string Slugify(string value)
        {
            if (string.IsNullOrWhiteSpace(value)) return "item";

            StringBuilder builder = new StringBuilder();
            foreach (char c in value.ToLowerInvariant())
            {
                if ((c >= 'a' && c <= 'z') || (c >= '0' && c <= '9'))
                {
                    builder.Append(c);
                }
                else if (builder.Length > 0 && builder[builder.Length - 1] != '-')
                {
                    builder.Append('-');
                }
            }

            string slug = builder.ToString().Trim('-');
            if (string.IsNullOrWhiteSpace(slug)) return "item";
            return slug.Length > 90 ? slug.Substring(0, 90).Trim('-') : slug;
        }

        private static string UniquePath(string path)
        {
            if (!File.Exists(path)) return path;

            string folder = Path.GetDirectoryName(path);
            string name = Path.GetFileNameWithoutExtension(path);
            string ext = Path.GetExtension(path);
            int i = 2;

            while (true)
            {
                string next = Path.Combine(folder, name + "-" + i + ext);
                if (!File.Exists(next)) return next;
                i++;
            }
        }

        private static string GetString(Dictionary<string, object> message, string key)
        {
            if (!message.ContainsKey(key) || message[key] == null) return "";
            return Convert.ToString(message[key]);
        }

        private static int GetInt(Dictionary<string, object> message, string key)
        {
            if (!message.ContainsKey(key) || message[key] == null) return 0;
            int value;
            return int.TryParse(Convert.ToString(message[key]), out value) ? value : 0;
        }

        private static Dictionary<string, object> Ok(string message, Dictionary<string, object> extra = null)
        {
            Dictionary<string, object> response = new Dictionary<string, object>
            {
                { "ok", true },
                { "message", message }
            };

            if (extra != null)
            {
                foreach (KeyValuePair<string, object> item in extra)
                {
                    response[item.Key] = item.Value;
                }
            }

            return response;
        }

        private static Dictionary<string, object> Error(string message)
        {
            return new Dictionary<string, object>
            {
                { "ok", false },
                { "error", message }
            };
        }
    }
}
