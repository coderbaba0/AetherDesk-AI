using System;
using System.Diagnostics;
using System.IO;
using System.Windows.Forms;

namespace AetherDeskAI
{
    internal static class Launcher
    {
        [STAThread]
        private static void Main()
        {
            string baseDir = AppDomain.CurrentDomain.BaseDirectory;
            string uiScript = Path.Combine(baseDir, "AetherDeskAI-UI.ps1");

            if (!File.Exists(uiScript))
            {
                MessageBox.Show(
                    "AetherDeskAI-UI.ps1 was not found next to the executable.\n\nExpected:\n" + uiScript,
                    "AetherDesk AI",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Error
                );
                return;
            }

            string powershell = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.Windows),
                @"System32\WindowsPowerShell\v1.0\powershell.exe"
            );

            if (!File.Exists(powershell))
            {
                powershell = "powershell.exe";
            }

            ProcessStartInfo startInfo = new ProcessStartInfo
            {
                FileName = powershell,
                Arguments = "-NoProfile -ExecutionPolicy Bypass -STA -File \"" + uiScript + "\"",
                WorkingDirectory = baseDir,
                UseShellExecute = false,
                CreateNoWindow = true,
                WindowStyle = ProcessWindowStyle.Hidden
            };

            try
            {
                Process.Start(startInfo);
            }
            catch (Exception ex)
            {
                MessageBox.Show(
                    "Could not start AetherDesk AI UI.\n\n" + ex.Message,
                    "AetherDesk AI",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Error
                );
            }
        }
    }
}
