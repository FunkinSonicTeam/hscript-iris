package funkin.scripting;

/**
 * Defines where a script plugin is active.
 * Scripts are loaded with a context and can be unloaded by context group.
 *
 * Folder convention:
 *   mods/myMod/scripts/global/     -> GLOBAL
 *   mods/myMod/scripts/stages/     -> STAGE
 *   mods/myMod/scripts/characters/ -> CHARACTER
 *   mods/myMod/scripts/songs/      -> SONG
 *   mods/myMod/scripts/events/     -> EVENT
 *   mods/myMod/scripts/cutscenes/  -> CUTSCENE
 *   mods/myMod/scripts/menus/      -> MENU
 */
enum ScriptContext {
    /** Always active across all states. */
    GLOBAL;

    /** Active only during PlayState, for stage logic. */
    STAGE;

    /** Active for a specific character during PlayState. */
    CHARACTER;

    /** Active during a specific song. */
    SONG;

    /** Handles a named chart event (e.g. "Camera Zoom"). */
    EVENT;

    /** Active during cutscenes. */
    CUTSCENE;

    /** Active in menus (MainMenuState, FreeplayState, etc). */
    MENU;
}
