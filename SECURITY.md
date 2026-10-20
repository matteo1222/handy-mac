# Security policy

Handy posts mouse and keyboard input on the user's behalf, so a bug that makes it act without the
user meaning to is a security issue as well as a correctness one.

## Reporting a vulnerability

Please report privately through GitHub's **Report a vulnerability** button on the Security tab
(private vulnerability reporting), not in a public issue. Include the macOS version, the Handy
version (`handyctl doctor`) and, if you can, a `.lmk` clip that reproduces it. Landmark clips hold
joint coordinates only, never camera images.

You should hear back within a week. Fixes ship in the next release, credited unless you ask
otherwise.

## Scope

- Input posted without an engaged hand, or after the stop hotkey
- The control socket (`handyctl`) being reachable by another user
- Any network traffic other than the Sparkle update check
- Camera frames leaving memory
