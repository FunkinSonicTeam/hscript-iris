package funkin.scripting;

/**
 * A cancelable event dispatched to script plugins.
 *
 * Scripts receive the event as a parameter and can call `event.cancel()`
 * to prevent the engine from executing default behavior.
 *
 * Example in a script:
 * ```haxe
 * function onBeatHit(event:ScriptEvent) {
 *     trace('Beat: ' + event.get('beat'));
 *     event.cancel(); // stops the default beat behavior
 * }
 * ```
 */
class ScriptEvent {
    /** Whether a script has cancelled this event. */
    public var cancelled(default, null):Bool = false;

    /** Identifier for this event type (e.g. "beatHit", "noteHit"). */
    public var type(default, null):String;

    /** Whether this event can be cancelled at all. */
    public var cancellable(default, null):Bool;

    var _data:Map<String, Dynamic> = new Map();

    /**
     * @param type        Event name.
     * @param data        Key-value pairs of event data.
     * @param cancellable Whether scripts are allowed to cancel this event.
     */
    public function new(type:String, ?data:Map<String, Dynamic>, cancellable:Bool = true) {
        this.type = type;
        this.cancellable = cancellable;
        if (data != null)
            for (k => v in data) _data.set(k, v);
    }

    /**
     * Cancel this event, preventing default engine behavior.
     * Has no effect if `cancellable` is false.
     */
    public function cancel():Void {
        if (cancellable) cancelled = true;
    }

    /** Resume a previously cancelled event. */
    public function resume():Void {
        cancelled = false;
    }

    /**
     * Read an event data field.
     *
     * Example: `var beat:Int = event.get('beat');`
     */
    public function get(key:String):Dynamic {
        return _data.get(key);
    }

    /**
     * Write to an event data field (useful for script->engine communication).
     *
     * Example: `event.set('volume', 0.5);`
     */
    public function set(key:String, value:Dynamic):Void {
        _data.set(key, value);
    }

    /** Returns all data keys available on this event. */
    public function keys():Array<String> {
        return [for (k in _data.keys()) k];
    }

    public function toString():String {
        return 'ScriptEvent($type, cancelled=$cancelled)';
    }
}

// ---------------------------------------------------------------------------
// Pre-built events used throughout the engine.
// Construct them with ScriptEvents.beatHit(beat) etc.
// ---------------------------------------------------------------------------

/**
 * Factory class for all standard engine events.
 * Import this and call e.g. `ScriptEvents.update(elapsed)`.
 */
class ScriptEvents {
    public static inline function update(elapsed:Float):ScriptEvent {
        return new ScriptEvent('update', ['elapsed' => elapsed], false);
    }

    public static inline function beatHit(beat:Int):ScriptEvent {
        return new ScriptEvent('beatHit', ['beat' => beat]);
    }

    public static inline function stepHit(step:Int):ScriptEvent {
        return new ScriptEvent('stepHit', ['step' => step]);
    }

    public static inline function sectionHit(section:Int):ScriptEvent {
        return new ScriptEvent('sectionHit', ['section' => section]);
    }

    public static inline function noteHit(note:Dynamic):ScriptEvent {
        return new ScriptEvent('noteHit', ['note' => note]);
    }

    public static inline function noteMiss(note:Dynamic, direction:Int):ScriptEvent {
        return new ScriptEvent('noteMiss', ['note' => note, 'direction' => direction]);
    }

    public static inline function songStart():ScriptEvent {
        return new ScriptEvent('songStart', null, false);
    }

    public static inline function songEnd():ScriptEvent {
        return new ScriptEvent('songEnd', null, false);
    }

    public static inline function countdownTick(tick:Int):ScriptEvent {
        return new ScriptEvent('countdownTick', ['tick' => tick]);
    }

    public static inline function stageEvent(name:String, value:Dynamic):ScriptEvent {
        return new ScriptEvent('stageEvent', ['name' => name, 'value' => value]);
    }

    public static inline function keyPress(key:Int, action:String):ScriptEvent {
        return new ScriptEvent('keyPress', ['key' => key, 'action' => action]);
    }

    public static inline function keyRelease(key:Int, action:String):ScriptEvent {
        return new ScriptEvent('keyRelease', ['key' => key, 'action' => action]);
    }

    public static inline function healthChange(health:Float, delta:Float):ScriptEvent {
        return new ScriptEvent('healthChange', ['health' => health, 'delta' => delta]);
    }

    public static inline function dialogueLine(speaker:String, text:String):ScriptEvent {
        return new ScriptEvent('dialogueLine', ['speaker' => speaker, 'text' => text]);
    }
}
