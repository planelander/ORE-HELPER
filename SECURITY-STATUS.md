# Windows executable security status

As of October 20, 2026, the current `dist/Ops Helper.exe` was rebuilt using
`launcher/Build-Windows.ps1` and scanned with Microsoft Defender's
`MpCmdRun.exe -Scan -ScanType 3 -File` command. The scan completed successfully
and reported **no threats found**. The current executable download is available.

SHA-256: `D93E8CFD5D988F1E15E0A797869BACD9BAC71E57FEB9919D6312820E1161983F`.

On October 16, Defender detected an earlier executable as
**Trojan:Win32/Sabsik.FL.A!ml** (threat ID 2147780195), and downloads were paused.
The developer reported submitting that executable to Microsoft as a suspected
false positive. Submission reference: `c42d1021-28d0-419e-a539-454612461956`.

Microsoft's analyst determination has not been verified: the submission page
requires sign-in. The current clean scan is not confirmation of submission
approval or a guarantee that every antivirus product will accept the file.
Do not disable Defender or add exclusions to run a blocked copy.
