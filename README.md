# RPG Survivor (local workspace)

This repository is currently checked out in a local workspace; nothing here is automatically pushed to GitHub or any other remote. If you want the latest changes to appear in a remote repository, you will need to push them yourself (for example with `git push origin <branch>` after configuring a remote).

## How to try the new player loadout flow
1. Open the project in Godot (the project file is `project.godot`).
2. Run the main scene you already use for gameplay. The player scene (`Scenes/player.tscn`) now instantiates the `DefaultPlayer` script, which delegates to `Scripts/Player/PlayerBase.gd` and loads its configuration from `Resources/PlayerLoadout/Default.tres`.
3. Q/E/R still trigger the respective skill slots defined in the loadout; the base script handles movement, auto-aim, and autoshooting using the configured projectile resource.

## Working with the loadout assets
- **Loadouts** live under `Resources/PlayerLoadout/`. The default resource is `Default.tres` and can be duplicated to create variants with different skill scenes or projectile setups.
- **Skills** are Godot scenes under `Scenes/Skills/` with corresponding scripts in `Scripts/Player/`. Each skill script derives from `SkillBase.gd` and is instantiated by `PlayerBase` based on the loadout.

If you want to tweak values (damage, cooldowns, skill scenes), edit the loadout resource and the skill scenes/scripts. Those changes will take effect the next time you run the game locally.

## How to bring these files into your own project
If you are starting from an older copy of your project and want to adopt the new loadout-driven player code, here is the simplest manual approach:

1. **Make a safety copy** of your project folder (or a Git branch) in case you want to roll back.
2. In your working project directory, create the following folders if they do not exist yet: `Scripts/Player/`, `Scenes/Skills/`, and `Resources/PlayerLoadout/`.
3. Copy the new files from this workspace into those folders, preserving their names:
   - Scripts: `Scripts/Player/PlayerBase.gd`, `DefaultPlayer.gd`, `SkillBase.gd`, `SkillFrostField.gd`, `SkillEzrealProjectile.gd`, `SkillTower.gd`, `PlayerLoadout.gd`
   - Scenes: `Scenes/player.tscn`, `Scenes/Skills/skill_frost_field.tscn`, `Scenes/Skills/skill_ezreal_projectile.tscn`, `Scenes/Skills/skill_tower.tscn`
   - Resource: `Resources/PlayerLoadout/Default.tres`
4. Open `Scenes/player.tscn` in Godot and confirm the player node uses `Scripts/Player/DefaultPlayer.gd` as its script.
5. Run the game. Movement, auto-aim shooting, and Q/E/R skill slots should work the same as before, now powered by the loadout resource.

If you prefer Git, you can also add this workspace as a remote and cherry-pick or merge the commit containing these files into your own repository instead of manual copying.

## About follow-up tasks
Only the loadout/player refactor described above is included here. No additional follow-up tasks have been merged yet, so you do not need to reconcile any other pending changes.
