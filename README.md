# Gamescope Custom Session for any openSUSE Tumbleweed Installation

This repository includes a configuration script to enable the gamescope-custom session on any openSUSE Tumbleweed installation. It is designed for a clean installation without any modifications, such as a Display Manager or a custom file system structure.

## Prerequisites
- Create a user named `gamer`.
- Grant administrative privileges to the user `gamer`.
- Ensure that core system packages, such as Mesa, are updated. Upgrade the Kernel if necessary.
- Wayland must be enabled and supported.
- All set!

## Validation
This script was validated with following configuration:
- **Kernel:** 6.7.1-1-default
- **Mesa:** 23.1 (also tested with Mesa 23.3.3)
- **AMDGPU:** Navi 31
- **HDR (and HDR10):** OK (with Proton feature-enabled games)
- **VRR:** OK (120Hz) supported panel
- **RayTracing:** OK (with Proton feature-enabled games)

## Installation
Simply execute the following command in the terminal:

```bash
sh -c "$(wget -qO- https://raw.githubusercontent.com/morissonmaciel/gamescope-session/main/configure-gamescope.script)"
```

## Known Issues
- Exit to Desktop does not work (working on this)
- Installing Decky Loader isn't possible, due to different file structure
- Even with mangoapp/mangohud installed, overlay isn't working either
- Custom resolutions and framerates on gamemode UI isn't appearing (working on this)

## Remarks
By default, gamemode will boot in first connected panel (refers to your GPU spec for 0 indexed display) using max resolution and default 60fps framerate.

You can change it in `/usr/share/gamescope-custom/gamescope-script` file setting `-W <screen width pixels > -H <screen height pixels>` and `-r <refresh rate>` arguments, each one stored in `RESOLUTION` and `VRR_ARGS` variables.

## References
- Gamescope [Valve Gamescope](https://github.com/ValveSoftware/gamescope)
- [@DoomedSouls] [Gamescope embedded script](https://gist.github.com/DoomedSouls/e4015dffc08963a57c6adf3066f5a486)
- [@ChimeraOS] [ChimeraOS Gamescope Session]()https://github.com/ChimeraOS/gamescope-session
