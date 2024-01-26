# Gamescope Custom Session for any openSUSE Tumbleweed Installation

This repository includes a configuration script to enable the gamescope-custom session on any openSUSE Tumbleweed installation. It is designed for a clean installation without any modifications, such as a Display Manager or a custom file system structure.

## Prerequisites:
- Create a user named `gamer`.
- Grant administrative privileges to the user `gamer`.
- Ensure that core system packages, such as Mesa, are updated. Upgrade the Kernel if necessary.
- Wayland must be enabled and supported.
- All set!

## Validation:
This script has been validated against the following criteria:
- **Kernel:** 6.7.1-1-default
- **Mesa:** 23.1 (also tested with Mesa 23.3.3)
- **AMDGPU:** Navi 31

## Installation:
Simply execute the following command in the terminal:

```bash
sh -c "$(wget -qO- https://raw.githubusercontent.com/morissonmaciel/gamescope-session/main/configure-gamescope.script)"
```

## References
- Gamescope [Valve Gamescope](https://github.com/ValveSoftware/gamescope)
- [@DoomedSouls] [Gamescope embedded script](https://gist.github.com/DoomedSouls/e4015dffc08963a57c6adf3066f5a486)
- [@ChimeraOS] [ChimeraOS Gamescope Session]()https://github.com/ChimeraOS/gamescope-session
