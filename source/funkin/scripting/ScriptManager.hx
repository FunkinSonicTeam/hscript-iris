package funkin.scripting;

import haxe.io.Path;
import funkin.scripting.ScriptContext;
import funkin.scripting.ScriptEvent;
import funkin.scripting.ScriptPlugin;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

/**
 * Central manager for all script plugins.
 *
 * Access via `ScriptManager.instance` anywhere in the engine.
 *
 * --- Loading scripts ---
 * ```haxe
 * // Load a whole folder (recursive) into GLOBAL context
 * ScriptManager.instance.loadFolder('mods/myMod/scripts/global', GLOBAL);
 *
 * // Load a single script
 * var plugin = ScriptManager.instance.loadScript('mods/myMod/scripts/stage/greenHill.hx', STAGE);
 * ```
 *
 * --- Calling functions ---
 * ```haxe
 * // Call on ALL active plugins
 * ScriptManager.instance.call('onSongStart', []);
 *
 * // Call on a specific context only
 * ScriptManager.instance.callInContext(STAGE, 'onUpdate', [elapsed]);
 * ```
 *
 * --- Dispatching cancelable events ---
 * ```haxe
 * var event = ScriptEvents.noteHit(note);
 * ScriptManager.instance.dispatch('onNoteHit', event);
 * if (!event.cancelled) {
 *     // default note-hit behavior
 * }
 * ```
 *
 * --- Cleanup ---
 * ```haxe
 * // When leaving PlayState, unload song/stage scripts
 * ScriptManager.instance.unloadContext(SONG);
 * ScriptManager.instance.unloadContext(STAGE);
 * ```
 */
class ScriptManager {

    /** Global singleton. */
    public static var instance(default, null):ScriptManager = new ScriptManager();

    /** All currently loaded plugins, keyed by their ID. */
    var _plugins:Map<String, ScriptPlugin> = new Map();

    /** Plugins grouped by context for fast context dispatching. */
    var _groups:Map<String, Array<ScriptPlugin>> = new Map();

    function new() {}

    // =========================================================================
    // Loading
    // =========================================================================

    /**
     * Load a single `.hx` script file as a plugin.
     *
     * @param path    Absolute or relative path to the .hx file.
     * @param context Context this plugin belongs to.
     * @return        The loaded plugin, or `null` if loading failed.
     */
    public function loadScript(path:String, context:ScriptContext = GLOBAL):ScriptPlugin {
        #if sys
        if (!FileSystem.exists(path)) {
            trace('[ScriptManager] File not found: $path');
            return null;
        }
        if (_plugins.exists(path)) {
            trace('[ScriptManager] Already loaded: $path — skipping.');
            return _plugins.get(path);
        }

        var code   = File.getContent(path);
        var plugin = new ScriptPlugin(path, code, context);
        _register(plugin);
        plugin.call('onCreate', []);
        trace('[ScriptManager] Loaded plugin: ${plugin.name} [$context]');
        return plugin;
        #else
        trace('[ScriptManager] loadScript not supported on this platform.');
        return null;
        #end
    }

    /**
     * Recursively load all `.hx` scripts inside a folder.
     *
     * @param folder  Root folder path.
     * @param context Context applied to every script found.
     */
    public function loadFolder(folder:String, context:ScriptContext = GLOBAL):Void {
        #if sys
        if (!FileSystem.exists(folder) || !FileSystem.isDirectory(folder)) return;
        for (entry in FileSystem.readDirectory(folder)) {
            var full = Path.join([folder, entry]);
            if (FileSystem.isDirectory(full))
                loadFolder(full, context);
            else if (Path.extension(entry) == 'hx')
                loadScript(full, context);
        }
        #end
    }

    /**
     * Load scripts from every folder in the given list.
     * Useful for loading multiple mod folders at once.
     */
    public function loadFolders(folders:Array<String>, context:ScriptContext = GLOBAL):Void {
        for (f in folders) loadFolder(f, context);
    }

    // =========================================================================
    // Calling
    // =========================================================================

    /**
     * Call a function on **all** active plugins.
     */
    public function call(func:String, ?args:Array<Dynamic>):Void {
        for (plugin in _plugins)
            if (plugin.active) plugin.call(func, args);
    }

    /**
     * Call a function only on plugins in a specific context.
     */
    public function callInContext(context:ScriptContext, func:String, ?args:Array<Dynamic>):Void {
        for (plugin in _getGroup(context))
            if (plugin.active) plugin.call(func, args);
    }

    /**
     * Call a function and collect all non-null return values.
     */
    public function callCollect(func:String, ?args:Array<Dynamic>):Array<Dynamic> {
        var results:Array<Dynamic> = [];
        for (plugin in _plugins) {
            if (!plugin.active) continue;
            var r = plugin.call(func, args);
            if (r != null) results.push(r);
        }
        return results;
    }

    // =========================================================================
    // Dispatching events
    // =========================================================================

    /**
     * Dispatch a `ScriptEvent` to **all** active plugins.
     *
     * @param func          Callback name (e.g. `'onBeatHit'`).
     * @param event         The event to dispatch.
     * @param stopOnCancel  Stop propagation as soon as any plugin cancels.
     * @return The final state of the event.
     */
    public function dispatch(func:String, event:ScriptEvent, stopOnCancel:Bool = false):ScriptEvent {
        for (plugin in _plugins) {
            if (!plugin.active) continue;
            plugin.dispatch(func, event);
            if (stopOnCancel && event.cancelled) break;
        }
        return event;
    }

    /**
     * Dispatch a `ScriptEvent` only to plugins in a specific context.
     */
    public function dispatchInContext(context:ScriptContext, func:String, event:ScriptEvent, stopOnCancel:Bool = false):ScriptEvent {
        for (plugin in _getGroup(context)) {
            if (!plugin.active) continue;
            plugin.dispatch(func, event);
            if (stopOnCancel && event.cancelled) break;
        }
        return event;
    }

    // =========================================================================
    // Unloading
    // =========================================================================

    /**
     * Unload a single plugin by its ID (file path).
     */
    public function unload(id:String):Void {
        var plugin = _plugins.get(id);
        if (plugin == null) return;
        plugin.unload();
        _deregister(plugin);
        trace('[ScriptManager] Unloaded: $id');
    }

    /**
     * Unload all plugins in a context.
     * Call this when leaving a state (e.g. `unloadContext(SONG)` at song end).
     */
    public function unloadContext(context:ScriptContext):Void {
        for (plugin in _getGroup(context).copy()) {
            plugin.unload();
            _plugins.remove(plugin.id);
        }
        _groups.remove(Std.string(context));
        trace('[ScriptManager] Unloaded context: $context');
    }

    /**
     * Unload everything. Useful on full game reset.
     */
    public function unloadAll():Void {
        for (plugin in _plugins) plugin.unload();
        _plugins.clear();
        _groups.clear();
        trace('[ScriptManager] Unloaded all plugins.');
    }

    // =========================================================================
    // Reloading
    // =========================================================================

    /**
     * Reload a plugin from disk by its ID.
     */
    public function reload(id:String):Void {
        _plugins.get(id)?.reload();
    }

    /**
     * Reload all plugins in a context from disk.
     */
    public function reloadContext(context:ScriptContext):Void {
        for (plugin in _getGroup(context)) plugin.reload();
    }

    /**
     * Reload every loaded plugin from disk.
     */
    public function reloadAll():Void {
        for (plugin in _plugins) plugin.reload();
    }

    // =========================================================================
    // Querying
    // =========================================================================

    /**
     * Get a specific plugin by its ID.
     */
    public function get(id:String):ScriptPlugin {
        return _plugins.get(id);
    }

    /**
     * Check whether a plugin is loaded.
     */
    public function has(id:String):Bool {
        return _plugins.exists(id);
    }

    /**
     * Returns all currently loaded plugin IDs.
     */
    public function getLoadedIds():Array<String> {
        return [for (k in _plugins.keys()) k];
    }

    /**
     * Returns all plugins in a given context.
     */
    public function getByContext(context:ScriptContext):Array<ScriptPlugin> {
        return _getGroup(context).copy();
    }

    /**
     * Total number of loaded plugins.
     */
    public function count():Int {
        var n = 0;
        for (_ in _plugins) n++;
        return n;
    }

    // =========================================================================
    // Internal helpers
    // =========================================================================

    function _register(plugin:ScriptPlugin):Void {
        _plugins.set(plugin.id, plugin);
        _getGroup(plugin.context).push(plugin);
    }

    function _deregister(plugin:ScriptPlugin):Void {
        _plugins.remove(plugin.id);
        _getGroup(plugin.context).remove(plugin);
    }

    function _getGroup(context:ScriptContext):Array<ScriptPlugin> {
        var key = Std.string(context);
        if (!_groups.exists(key)) _groups.set(key, []);
        return _groups.get(key);
    }
}
