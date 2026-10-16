# Windows executable security status

As of October 16, 2026, Microsoft Defender reports the distributed
`Ops Helper.exe` as **Trojan:Win32/Sabsik.FL.A!ml** (threat ID 2147780195).
The detection occurred on both a GitHub-downloaded copy and the local build.
Windows blocked access to the executable during verification.

This has not been confirmed as a false positive. No clean antivirus result or
Microsoft review clearance is available. Distribution of the executable is
paused, and the file has been removed from the current repository branch.
Older commits may still contain the flagged executable; those copies should
not be used. Source availability is not a security certification.

The developer reports submitting the executable to Microsoft Security Intelligence
on October 16, 2026, requesting review as a suspected false positive.
Submission reference: `c42d1021-28d0-419e-a539-454612461956`.
The developer believes the app is not malware; Microsoft clearance has not yet
been verified. Submission does not mean the detection has been removed.
A replacement should only be published after
the detection is resolved and the exact release binary has been checked.

Code signing identifies the publisher but does not remove a malware detection.
Do not disable Defender, add exclusions, or restore the flagged file merely to
run this app.
