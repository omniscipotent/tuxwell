# Security

## What this project touches
- A **user** systemd service: it runs as you, never as root, with `NoNewPrivileges`.
- One **udev rule** that lets your logged-in desktop user open the Audeze HID interfaces (`uaccess`).
  This means any program you run can talk to the headset and dongle, including firmware tools. Remove
  `/etc/udev/rules.d/70-audeze-maxwell.rules` if you don't want that.
- The installer downloads one file over HTTPS (the SADIE II HRTF from Zenodo) and verifies its SHA-256 before installing it.
- `maxwell.conf` is parsed as data with a strict whitelist. It is never executed.
- The control panel can run a `maxwell_ctl.py` from audezeforlinux **if you point it at one**. It never fetches or installs that code itself.

## Reporting a vulnerability
Please open a private security advisory on GitHub (Security tab, "Report a vulnerability") rather than a public issue.
If that option is not available, open an issue that says only "security contact please" (no details) and a private channel will be arranged.
