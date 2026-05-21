package funkin.scripting;

import crowplexus.iris.Iris;
import crowplexus.iris.IrisConfig;
import funkin.scripting.ScriptAPI;
import funkin.scripting.ScriptContext;
import funkin.scripting.ScriptEvent;

/**
 * A single script plugin loaded from a .hx file.
 *
 * Each file in a scripts folder is wrapped in a ScriptPlugin.
 * Supports full HScript-Iris class definitions, cancelable events,
 * per-plugin variable scope, and safe error recovery.
 *
 * Lifecycle callbacks fired automatically:
 *   onCreate()    - after the plugin loads and API is applied
 *   onDestroy()   - before the plugin is unloaded
 *   onReload()    - after a hot-reload from disk
 *
 * Minimal example script (scripts/global/myPlugin.hx):
 * ```haxe
 * function onCreate() {
 *     trace('Hello from myPlugin!');
 * }
 *
 * function onBeatHit(event:ScriptEvent) {
 *     if (event.get('beat') % 4 == 0)
 *         trace('Every 4 beats!');
 * }
 * ```
 *
 * Advanced – defining a class inside a script:
 * ```haxe
 * class BouncingSprite extends FlxSprite {
 *     var speed:Float = 200;
 *     public function new(x:Float, y:Float) {
 *         super(x, y);
 *         makeGraphic(32, 32, FlxColor.RED);
 *         velocity.y = speed;
 *     }
 * }
 *
 * var sprite:BouncingSprite;
 *
 * function onCreate() {
 *     sprite = new BouncingSprite(100, 100);
 *     game.add(sprite);
 * }
 * ```
 */
class ScriptPlugin {
    /** Unique identifier — typically the absolute file path. */
    public var id(default, null):String;

    /** Display name derived from the filename without extension. */
    public var name(default, null):String;

    /** Whether this plugin processes calls and events. */
    public var active:Bool = true;

    /** Context group this plugin belongs to. */
    public var context(default, null):ScriptContext;

    /** How many errors this plugin has produced (auto-disables at threshold). */
    public var errorCount(default, null):Int = 0;

    /** Maximum errors before the plugin auto-disables itself. */
    public static var MAX_ERRORS:Int = 5;

    var _script:Iris;
    var _code:String;
    var _filePath:String;

    // -----------------------------------------------------------------------
    // Construction
    // -----------------------------------------------------------------------

    /**
     * @param id      Unique identifier (usually the file path).
     * @param code    Raw HScript source code.
     * @param context Which context this plugin runs in.
     */
    public function new(id:String, code:String, context:ScriptContext = GLOBAL) {
        this.id       = id;
        this.name     = haxe.io.Path.withoutDirectory(haxe.io.Path.withoutExtension(id));
        this._code     = code;
        this._filePath = id;
        this.context  = context;
        _boot();
    }

    // -----------------------------------------------------------------------
    // Public API
    // -----------------------------------------------------------------------

    /**
     * Call a function defined in this script.
     * Returns the function's return value, or `null` on error / not found.
     *
     * @param func Function name to call.
     * @param args Arguments to pass (optional).
     */
    public function call(func:String, ?args:Array<Dynamic>):Dynamic {
        if (!active || _script == null) return null;
        try {
            var result = _script.call(func, args ?? []);
            return (result != null) ? result.returnValue : null;
        } catch (e:haxe.Exception) {
            _handleError('call("$func")', e.message);
            return null;
        }
    }

    /**
     * Dispatch a cancelable `ScriptEvent` to a callback in this script.
     * The event object is injected as both a named variable and the first argument.
     *
     * Returns the event (which may be cancelled).
     */
    public function dispatch(func:String, event:ScriptEvent):ScriptEvent {
        if (!active || _script == null) return event;
        try {
            set('event', event);
            _script.call(func, [event]);
        } catch (e:haxe.Exception) {
            _handleError('dispatch("$func")', e.message);
        }
        return event;
    }

    /**
     * Expose a variable to this script's scope.
     *
     * @param varName Variable name accessible inside the script.
     * @param value   The value to expose.
     */
    public function set(varName:String, value:Dynamic):Void {
        if (_script == null) return;
        _script.set(varName, value);
    }

    /**
     * Read a variable from this script's scope.
     */
    public function get(varName:String):Dynamic {
        if (_script == null) return null;
        return _script.get(varName);
    }

    /**
     * Re-read the file from disk and restart the script.
     * Useful for hot-reloading during development.
     */
    public function reload():Void {
        #if sys
        try {
            _code  = sys.io.File.getContent(_filePath);
            active = true;
            errorCount = 0;
            _boot();
            call('onReload', []);
            trace('[ScriptPlugin] Reloaded: $id');
        } catch (e:haxe.Exception) {
            trace('[ScriptPlugin] Reload failed for "$id": ${e.message}');
        }
        #end
    }

    /**
     * Fire `onDestroy` and permanently deactivate this plugin.
     */
    public function unload():Void {
        call('onDestroy', []);
        active  = false;
        _script = null;
    }

    public function toString():String {
        return 'ScriptPlugin(id=$name, context=$context, active=$active, errors=$errorCount)';
    }

    // -----------------------------------------------------------------------
    // Internal
    // -----------------------------------------------------------------------

    function _boot():Void {
        try {
            _script = new Iris(_code, {
                name:    id,
                autoRun: false,
                preset:  false
            });
            // Apply engine API before executing so scripts can use it at top level
            ScriptAPI.apply(this);
            _script.execute();
        } catch (e:haxe.Exception) {
            trace('[ScriptPlugin] Failed to load "$id": ${e.message}');
            active = false;
        }
    }

    function _handleError(location:String, message:String):Void {
        errorCount++;
        trace('[ScriptPlugin] Error in "$name" @ $location: $message ($errorCount/$MAX_ERRORS)');
        if (errorCount >= MAX_ERRORS) {
            trace('[ScriptPlugin] Auto-disabling "$name" (too many errors).');
            active = false;
        }
    }
}
