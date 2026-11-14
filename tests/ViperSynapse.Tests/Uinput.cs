using ViperSynapse.Hardware.Linux;

namespace ViperSynapse.Tests;

/// <summary>
/// Whether the loopback tests can run here: /dev/uinput opens, and the event node a new uinput device gets is
/// readable. The second needs the user in the input group (the udev rule only gives Razer devices an ACL), so
/// without it the tests are skipped instead of timing out. Checked once per run.
/// </summary>
static class Uinput
{
    public const string SkipReason =
        "needs /dev/uinput and readable uinput event nodes (the user in the input group)";

    static readonly Lazy<bool> s_usable = new(Check);

    public static bool Usable => s_usable.Value;

    static bool Check()
    {
        try
        {
            using var device = UinputDevice.Create("viper-synapse-probe");
            var deadline = DateTime.UtcNow + TimeSpan.FromSeconds(2);
            while (DateTime.UtcNow < deadline)
            {
                if (device.EventNode is { } node && File.Exists(node))
                {
                    try { EvdevDevice.Open(node).Dispose(); return true; }
                    catch (UnauthorizedAccessException) { }   // no access yet: udev may still be applying an ACL
                }
                Thread.Sleep(10);
            }
            return false;
        }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException) { return false; }
    }
}
