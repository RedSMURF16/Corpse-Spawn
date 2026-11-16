<h1 align="center">Corpse Spawn</h1>

<p align="center">
  <a href="https://www.youtube.com/watch?v=pctIpSI1R7M">
    <img src="https://img.youtube.com/vi/pctIpSI1R7M/maxresdefault.jpg" alt="Watch on YouTube" width="600">
  </a>
</p>

## 📝 Description
This plugin adds dynamic, fully configurable corpse entities to Counter-Strike 1.6.
Corpses can be placed anywhere on the map with their own model, bounding box, team restriction and respawn chance.
Custom setups are saved per map and automatically loaded on every map start.
- Create and remove corpses during gameplay via an in-game menu
- Comes with a rich set of preconfigured corpses ready to use out of the box
- Each corpse supports its own animation sequence and framerate
- Corpses can display interactive messages when approached or used
- Corpses can emit randomized ambient sounds with configurable cooldowns
- Team access configurable for Terrorists, CTs, both or disabled
- Configurable respawn chance per corpse
- Noclip support for easier placement

## 💬 Commands
- `say /cs` - Opens the Corpse Spawn menu.
- `say_team /cs` - Opens the Corpse Spawn menu.
- `say /corpse` - Opens the Corpse Spawn menu.
- `say_team /corpse` - Opens the Corpse Spawn menu.
- `cs_reload` - Reloads the configuration file.
- `corpse_reload` - Reloads the configuration file.

## ⚙️ Configuration
```ini
# [Main Settings]
# SETTING_DEFAULT_MODEL           = Default corpse model path
# SETTING_DEFAULT_FLAGS           = Default flags (a - Solid, b - Anim, c - Message, d - Sound)
# SETTING_DEFAULT_TEAM            = Default team (0 - Disabled, 1 - T, 2 - CT, 3 - Both)
# SETTING_DEFAULT_FRAMERATE       = Default animation frame rate
# SETTING_DEFAULT_SEQUENCE        = Default animation sequence
# SETTING_DEFAULT_SPAWN_CHANCE    = Default respawn probability (0.0 - 1.0)
# SETTING_DEFAULT_MESSAGE         = Default message(s) shown when interacted with
# SETTING_DEFAULT_MESSAGE_TIMEOUT = Default minimum - maximum delay between messages
# SETTING_DEFAULT_SOUND           = Default sound(s) played when interacted with
# SETTING_DEFAULT_SOUND_COOLDOWN  = Default minimum - maximum cooldown between sounds
# SETTING_DEFAULT_SOUND_DISTANCE  = Default maximum distance for sound to be heard
# Per-corpse settings (defined under each [Corpse Name] section):
# CORPSE_FLAGS         = a - Solid    b - Anim    c - Message    d - Sound
# CORPSE_TEAM          = 0 - Disabled    1 - Terrorist Only    2 - CT Only    3 - Both Teams
# CORPSE_MINS/MAXS     = Bounding box for the corpse model
# CORPSE_SEQUENCE      = Animation sequence override
# CORPSE_SPAWN_CHANCE  = Respawn probability override
# CORPSE_MESSAGE       = Message(s) shown when interacted with
# CORPSE_SOUND         = Sound(s) played when interacted with
# CORPSE_SOUND_COOLDOWN = Minimum - maximum cooldown between sounds
```

## 🔄 Changelog
```text
* v1.0: Initial release.
* v1.1: Added corpse regeneration effect, improved some logic.
* v1.3: Added interactive messages and ambient sounds per corpse, config improvements.
```

[![Watch on YouTube](https://img.shields.io/badge/YouTube-Watch%20video-FF0000?logo=youtube&logoColor=white)](https://www.youtube.com/watch?v=https://www.youtube.com/watch?v=lSsZbdHcaFE)
