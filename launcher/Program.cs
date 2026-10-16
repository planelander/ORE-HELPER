using System;
using System.IO;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Windows.Forms;

[assembly: AssemblyTitle("ORE//OPS Mining Helper")]
[assembly: AssemblyProduct("ORE//OPS Mining Helper")]
[assembly: AssemblyCompany("Adonis Anubis - BLACKSHIELDS")]
[assembly: AssemblyDescription("Portable Star Citizen mining companion")]
[assembly: AssemblyVersion("1.1.0.0")]
[assembly: AssemblyFileVersion("1.1.0.0")]

namespace OreOpsLauncher
{
    internal static class Program
    {
        [DllImport("user32.dll")] private static extern bool SetProcessDpiAwarenessContext(IntPtr context);
        [DllImport("user32.dll")] private static extern bool SetProcessDPIAware();
        private const string ScriptResource = "OreOps.MiningHelper.ps1";
        private const string DataResource = "OreOps.MiningData.json";
        private const string SnapshotResource = "OreOps.MiningSnapshot.json";
        private const string GroundLocationsResource = "OreOps.GroundMiningLocations.json";
        private const string TradeShipsResource = "OreOps.TradeShips.json";

        [STAThread]
        private static void Main()
        {
            // Use physical screen pixels for HUD capture even at 125%/150% scaling.
            try { SetProcessDpiAwarenessContext(new IntPtr(-4)); }
            catch (EntryPointNotFoundException) { SetProcessDPIAware(); }
            bool isFirstInstance;
            using (var singleInstance = new System.Threading.Mutex(
                true,
                @"Local\OreOpsMiningHelper",
                out isFirstInstance))
            {
                if (!isFirstInstance)
                {
                    MessageBox.Show(
                        "ORE//OPS is already running.",
                        "ORE//OPS",
                        MessageBoxButtons.OK,
                        MessageBoxIcon.Information);
                    return;
                }

                RunApplication();
            }
        }

        private static void RunApplication()
        {
            try
            {
                string localData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
                string appDirectory = Path.Combine(localData, "OreOps", "App");
                string sourceDirectory = Path.Combine(appDirectory, "src");
                string dataDirectory = Path.Combine(appDirectory, "data");
                string scriptPath = Path.Combine(sourceDirectory, "MiningHelper.ps1");
                string dataPath = Path.Combine(dataDirectory, "mining-data.json");
                string snapshotPath = Path.Combine(dataDirectory, "mining-compiled.json");
                string groundLocationsPath = Path.Combine(dataDirectory, "ground-mining-locations.json");
                string tradeShipsPath = Path.Combine(dataDirectory, "trade-ships.json");

                ExtractResource(ScriptResource, scriptPath, true);
                ExtractResource("OreOps.ScanOverlay.ps1", Path.Combine(sourceDirectory, "ScanOverlay.ps1"), true);
                ExtractResource(DataResource, dataPath, true);
                ExtractResource("OreOps.OreBuyers.json", Path.Combine(dataDirectory, "ore-buyers.json"), true);
                ExtractResource(SnapshotResource, snapshotPath, false);
                ExtractResource(GroundLocationsResource, groundLocationsPath, true);
                ExtractResource(TradeShipsResource, tradeShipsPath, true);

                InitialSessionState sessionState = InitialSessionState.CreateDefault();
                sessionState.ExecutionPolicy = Microsoft.PowerShell.ExecutionPolicy.Bypass;
                using (Runspace runspace = RunspaceFactory.CreateRunspace(sessionState))
                {
                    runspace.ApartmentState = System.Threading.ApartmentState.STA;
                    runspace.ThreadOptions = PSThreadOptions.UseCurrentThread;
                    runspace.Open();
                    using (PowerShell powerShell = PowerShell.Create())
                    {
                        powerShell.Runspace = runspace;
                        powerShell.AddScript("& '" + scriptPath.Replace("'", "''") + "'");
                        powerShell.Invoke();
                        if (powerShell.HadErrors)
                        {
                            throw new InvalidOperationException(powerShell.Streams.Error[0].ToString());
                        }
                    }
                }
            }
            catch (Exception exception)
            {
                try
                {
                    string logDirectory = Path.Combine(
                        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                        "OreOps");
                    Directory.CreateDirectory(logDirectory);
                    File.WriteAllText(Path.Combine(logDirectory, "launch-error.txt"), exception.ToString());
                }
                catch
                {
                    // The message box below remains the fallback when logging is unavailable.
                }
                MessageBox.Show(
                    "Mining Helper could not start.\n\n" + exception.Message,
                    "ORE//OPS",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Error);
            }
        }

        private static void ExtractResource(string resourceName, string destinationPath, bool overwrite)
        {
            if (!overwrite && File.Exists(destinationPath))
            {
                return;
            }

            string directory = Path.GetDirectoryName(destinationPath);
            Directory.CreateDirectory(directory);

            Assembly assembly = Assembly.GetExecutingAssembly();
            using (Stream input = assembly.GetManifestResourceStream(resourceName))
            {
                if (input == null)
                {
                    throw new InvalidOperationException("Embedded application resource is missing: " + resourceName);
                }

                string temporaryPath = destinationPath + ".new";
                using (var output = new FileStream(temporaryPath, FileMode.Create, FileAccess.Write, FileShare.None))
                {
                    input.CopyTo(output);
                }

                if (File.Exists(destinationPath))
                {
                    File.Delete(destinationPath);
                }
                File.Move(temporaryPath, destinationPath);
            }
        }
    }
}
