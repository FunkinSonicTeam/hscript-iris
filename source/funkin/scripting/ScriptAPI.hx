package funkin.scripting;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxAngle;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.sound.FlxSound;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxStringUtil;
import flixel.util.FlxTimer;
import funkin.scripting.ScriptPlugin;

/**
 * Defines every class and function available to script plugins.
 *
 * Applied automatically when a ScriptPlugin boots.
 * Use `registerClass` / `registerFunction` to add your own entries
 * before loading scripts.
 *
 * Custom registration example (in your engine init code):
 * ```haxe
 * ScriptAPI.registerClass('DialogueBox', objects.DialogueBox);
 * ScriptAPI.registerFunction('shake', (intensity:Float) -> {
 *     FlxG.cameras.list[0].shake(intensity, 0.5);
 * });
 * ```
 */
class ScriptAPI {

    // Custom entries registered at runtime
    static var _classes:Map<String, Dynamic>   = new Map();
    static var _functions:Map<String, Dynamic> = new Map();

    // -----------------------------------------------------------------------
    // Apply to a plugin
    // -----------------------------------------------------------------------

    /**
     * Injects all API entries into a plugin's script scope.
     * Called automatically by `ScriptPlugin` on boot.
     */
    public static function apply(plugin:ScriptPlugin):Void {
        _applyStdLib(plugin);
        _applyFlixel(plugin);
        _applyEngine(plugin);
        _applyScriptUtils(plugin);
        _applyCustom(plugin);
    }

    // -----------------------------------------------------------------------
    // Registration
    // -----------------------------------------------------------------------

    /**
     * Register a class to be available in ALL future and existing script reloads.
     *
     * @param name  The name scripts will use (e.g. `'MyHelper'`).
     * @param cls   The class reference (e.g. `MyHelper`).
     */
    public static function registerClass(name:String, cls:Dynamic):Void {
        _classes.set(name, cls);
    }

    /**
     * Register a callable function available in ALL scripts.
     *
     * @param name  The name scripts will use.
     * @param fn    The function (can be a lambda).
     */
    public static function registerFunction(name:String, fn:Dynamic):Void {
        _functions.set(name, fn);
    }

    /**
     * Remove a previously registered class or function by name.
     */
    public static function unregister(name:String):Void {
        _classes.remove(name);
        _functions.remove(name);
    }

    /** Returns all registered class names. */
    public static function registeredClasses():Array<String> {
        return [for (k in _classes.keys()) k];
    }

    /** Returns all registered function names. */
    public static function registeredFunctions():Array<String> {
        return [for (k in _functions.keys()) k];
    }

    // -----------------------------------------------------------------------
    // Internals
    // -----------------------------------------------------------------------

    static function _applyStdLib(p:ScriptPlugin):Void {
        // Core Haxe
        p.set('Math',        Math);
        p.set('Std',         Std);
        p.set('Type',        Type);
        p.set('Reflect',     Reflect);
        p.set('StringTools', StringTools);
        p.set('Lambda',      Lambda);
        p.set('Json',        haxe.Json);
        p.set('Date',        Date);
        p.set('DateTools',   DateTools);
        p.set('EReg',        EReg);

        // Data structures
        p.set('Array',       Array);
        p.set('Map',         haxe.ds.StringMap);
        p.set('IntMap',      haxe.ds.IntMap);

        #if sys
        p.set('Sys',         Sys);
        p.set('File',        sys.io.File);
        p.set('FileSystem',  sys.FileSystem);
        p.set('Path',        haxe.io.Path);
        #end
    }

    static function _applyFlixel(p:ScriptPlugin):Void {
        // Core
        p.set('FlxG',            FlxG);
        p.set('FlxSprite',       FlxSprite);
        p.set('FlxCamera',       FlxCamera);
        p.set('FlxText',         FlxText);
        p.set('FlxSound',        FlxSound);

        // Groups
        p.set('FlxGroup',        FlxGroup);
        p.set('FlxSpriteGroup',  FlxSpriteGroup);
        p.set('FlxTypedGroup',   flixel.group.FlxGroup.FlxTypedGroup);

        // Math & Geometry
        p.set('FlxMath',         FlxMath);
        p.set('FlxPoint',        FlxPoint);
        p.set('FlxRect',         FlxRect);
        p.set('FlxAngle',        FlxAngle);

        // Animation
        p.set('FlxTween',        FlxTween);
        p.set('FlxEase',         FlxEase);
        p.set('FlxTimer',        FlxTimer);

        // Utility
        p.set('FlxColor',        FlxColor);
        p.set('FlxStringUtil',   FlxStringUtil);

        // Particle (if used)
        p.set('FlxEmitter',      flixel.effects.particles.FlxEmitter);
        p.set('FlxParticle',     flixel.effects.particles.FlxParticle);

        // Input
        p.set('FlxKey',          flixel.input.keyboard.FlxKey);
    }

    static function _applyEngine(p:ScriptPlugin):Void {
        // States
        p.set('PlayState',       states.PlayState);
        p.set('game',            states.PlayState.instance);

        // Backend
        p.set('Conductor',       backend.Conductor);
        p.set('ClientPrefs',     backend.ClientPrefs);
        p.set('Paths',           backend.Paths);
        p.set('CoolUtil',        backend.CoolUtil);

        // Objects
        p.set('Note',            objects.Note);
        p.set('Character',       objects.Character);
        p.set('HealthIcon',      objects.HealthIcon);
        p.set('Alphabet',        objects.Alphabet);
        p.set('AttachedSprite',  objects.AttachedSprite);

        // Scripting system itself
        p.set('ScriptManager',   ScriptManager.instance);
        p.set('ScriptEvent',     ScriptEvent);
    }

    static function _applyScriptUtils(p:ScriptPlugin):Void {
        // Override trace so it shows the script name
        p.set('trace', (v:Dynamic) -> haxe.Log.trace('[${p.name}] $v', null));

        // Quick sprite helper
        p.set('makeSprite', (x:Float, y:Float, ?width:Int, ?height:Int, ?color:Int) -> {
            var spr = new FlxSprite(x, y);
            if (width != null && height != null)
                spr.makeGraphic(width, height, color ?? FlxColor.WHITE);
            return spr;
        });

        // Quick tween shorthand
        p.set('tween', (target:Dynamic, props:Dynamic, duration:Float, ?options:Dynamic) -> {
            return FlxTween.tween(target, props, duration, options);
        });

        // Quick timer shorthand
        p.set('timer', (seconds:Float, callback:Dynamic) -> {
            return new FlxTimer().start(seconds, (_) -> callback());
        });

        // Color from hex string: colorFromHex('FF0000')
        p.set('colorFromHex', (hex:String) -> FlxColor.fromString('#$hex'));

        // Load a sound by name
        p.set('playSound', (path:String, ?volume:Float) -> {
            FlxG.sound.play(backend.Paths.sound(path), volume ?? 1.0);
        });

        // Add/remove from PlayState
        p.set('addToGame', (obj:FlxSprite)  -> states.PlayState.instance?.add(obj));
        p.set('removeFromGame', (obj:FlxSprite) -> states.PlayState.instance?.remove(obj));

        // Camera shake shorthand
        p.set('shakeCamera', (intensity:Float, duration:Float) -> {
            FlxG.camera.shake(intensity, duration);
        });

        // Flash camera
        p.set('flashCamera', (color:FlxColor, duration:Float) -> {
            FlxG.camera.flash(color, duration);
        });

        // Fade camera
        p.set('fadeCamera', (color:FlxColor, duration:Float, fadeIn:Bool) -> {
            if (fadeIn) FlxG.camera.fade(color, duration, true);
            else FlxG.camera.fade(color, duration, false);
        });

        // Null-safe reflection helper (no crashes on missing fields)
        p.set('getField', (obj:Dynamic, field:String, ?fallback:Dynamic) -> {
            return Reflect.hasField(obj, field) ? Reflect.field(obj, field) : fallback;
        });

        p.set('setField', (obj:Dynamic, field:String, value:Dynamic) -> {
            Reflect.setField(obj, field, value);
        });
    }

    static function _applyCustom(p:ScriptPlugin):Void {
        for (name => cls in _classes)   p.set(name, cls);
        for (name => fn in _functions)  p.set(name, fn);
    }
}
