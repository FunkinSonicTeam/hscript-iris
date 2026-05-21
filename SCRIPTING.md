# FunkinSonic Scripting System

Advanced plugin-based scripting system for FunkinSonic Engine.  
Built on top of **HScript-Iris** by crowplexus, extended with a full event system, context groups, and a rich API.

---

## Architecture

```
ScriptManager          — loads, routes, and manages all plugins
  └── ScriptPlugin     — wraps a single .hx file (via HScript-Iris)
        └── ScriptAPI  — injects all classes/functions into each plugin
ScriptEvent            — cancelable event passed to script callbacks
ScriptContext          — enum that groups scripts by where they run
```

---

## Quick Start

### 1. Load scripts at engine startup

```haxe
import funkin.scripting.ScriptManager;
import funkin.scripting.ScriptContext;

// In your init / preloader
ScriptManager.instance.loadFolder('mods/myMod/scripts/global', GLOBAL);
```

### 2. Fire events from your game states

```haxe
import funkin.scripting.ScriptEvents;

// In PlayState.update()
var ev = ScriptEvents.update(elapsed);
ScriptManager.instance.dispatch('onUpdate', ev);

// In PlayState.beatHit()
var ev = ScriptEvents.beatHit(curBeat);
ScriptManager.instance.dispatch('onBeatHit', ev);
if (ev.cancelled) return; // script prevented default behavior
```

### 3. Load/unload by context

```haxe
// When entering a song
ScriptManager.instance.loadFolder('mods/myMod/scripts/songs/$songName', SONG);
ScriptManager.instance.loadFolder('mods/myMod/scripts/stages/$stageName', STAGE);

// When leaving a song
ScriptManager.instance.unloadContext(SONG);
ScriptManager.instance.unloadContext(STAGE);
```

---

## Writing Scripts

Scripts are plain `.hx` files. Place them in your mod's `scripts/` folder.

### Basic structure

```haxe
// scripts/global/myPlugin.hx

function onCreate() {
    trace('Plugin loaded!');
}

function onUpdate(event:ScriptEvent) {
    // event.get('elapsed') -> Float
}

function onBeatHit(event:ScriptEvent) {
    var beat:Int = event.get('beat');
    if (beat % 4 == 0) trace('4-beat mark: ' + beat);
}

function onNoteHit(event:ScriptEvent) {
    var note = event.get('note');
    trace('Hit note direction: ' + note.noteData);
    // event.cancel() would prevent the default note-hit behavior
}

function onDestroy() {
    trace('Plugin unloaded!');
}
```

### Canceling events

```haxe
function onNoteMiss(event:ScriptEvent) {
    // Prevent the miss from counting
    event.cancel();
}
```

### Using engine classes

All major engine and HaxeFlixel classes are pre-injected:

```haxe
function onCreate() {
    // FlxSprite
    var spr = new FlxSprite(100, 200);
    spr.loadGraphic(Paths.image('mySprite'));
    addToGame(spr);

    // Tweening
    tween(spr, {x: 500}, 0.8, {ease: FlxEase.expoOut});

    // Timer
    timer(2.0, () -> trace('2 seconds passed!'));

    // Color
    spr.color = FlxColor.fromString('#FF4455');

    // Sound
    playSound('data/soundEffect', 0.8);
}
```

### Defining classes inside scripts (HScript-Iris)

```haxe
// Full class support — runs inside the script's scope

class SpinningIcon extends FlxSprite {
    var rotateSpeed:Float = 90;

    public function new(x:Float, y:Float, icon:String) {
        super(x, y);
        loadGraphic(Paths.image('icons/' + icon));
        setGraphicSize(100, 100);
        updateHitbox();
    }

    override public function update(elapsed:Float) {
        super.update(elapsed);
        angle += rotateSpeed * elapsed;
    }
}

var icon:SpinningIcon;

function onCreate() {
    icon = new SpinningIcon(300, 300, 'bf');
    addToGame(icon);
}

function onDestroy() {
    removeFromGame(icon);
    icon.destroy();
}
```

---

## Available Callbacks

| Callback | Event Data | Cancellable |
|---|---|---|
| `onCreate()` | — | no |
| `onDestroy()` | — | no |
| `onReload()` | — | no |
| `onUpdate(event)` | `elapsed:Float` | no |
| `onBeatHit(event)` | `beat:Int` | yes |
| `onStepHit(event)` | `step:Int` | yes |
| `onSectionHit(event)` | `section:Int` | yes |
| `onNoteHit(event)` | `note:Note` | yes |
| `onNoteMiss(event)` | `note:Note`, `direction:Int` | yes |
| `onSongStart(event)` | — | no |
| `onSongEnd(event)` | — | no |
| `onCountdownTick(event)` | `tick:Int` | yes |
| `onKeyPress(event)` | `key:Int`, `action:String` | yes |
| `onKeyRelease(event)` | `key:Int`, `action:String` | yes |
| `onHealthChange(event)` | `health:Float`, `delta:Float` | yes |
| `onDialogueLine(event)` | `speaker:String`, `text:String` | yes |
| `onStageEvent(event)` | `name:String`, `value:Dynamic` | yes |

---

## Built-in Script Utilities

These are available in every script without any import:

| Name | Description |
|---|---|
| `trace(v)` | Prints with the script name prefix |
| `makeSprite(x, y, w?, h?, color?)` | Creates a quick `FlxSprite` |
| `tween(target, props, duration, opts?)` | Shorthand for `FlxTween.tween` |
| `timer(seconds, callback)` | Shorthand for `FlxTimer` |
| `colorFromHex('RRGGBB')` | Parses a hex string to `FlxColor` |
| `playSound(path, volume?)` | Plays a sound via `Paths.sound` |
| `addToGame(sprite)` | Adds to `PlayState` |
| `removeFromGame(sprite)` | Removes from `PlayState` |
| `shakeCamera(intensity, duration)` | Shakes the main camera |
| `flashCamera(color, duration)` | Flashes the main camera |
| `fadeCamera(color, duration, fadeIn)` | Fades the main camera |
| `getField(obj, field, fallback?)` | Safe field read via Reflect |
| `setField(obj, field, value)` | Safe field write via Reflect |

---

## Registering Custom Classes

From engine code, before loading scripts:

```haxe
import funkin.scripting.ScriptAPI;

// Make a class available to all scripts
ScriptAPI.registerClass('DialogueBox', objects.DialogueBox);
ScriptAPI.registerClass('VideoSprite', objects.VideoSprite);

// Register a helper function
ScriptAPI.registerFunction('lerp', (a:Float, b:Float, t:Float) -> a + (b - a) * t);

// Remove when no longer needed
ScriptAPI.unregister('VideoSprite');
```

Inside a script:

```haxe
function onCreate() {
    var dlg = new DialogueBox(0, 0, 'Hello!');
    addToGame(dlg);
}
```

---

## Context Reference

| Context | When active | Load folder convention |
|---|---|---|
| `GLOBAL` | Always, all states | `scripts/global/` |
| `STAGE` | During PlayState, stage logic | `scripts/stages/<name>/` |
| `CHARACTER` | For a specific character | `scripts/characters/<name>/` |
| `SONG` | During a specific song | `scripts/songs/<name>/` |
| `EVENT` | Named chart events | `scripts/events/<name>/` |
| `CUTSCENE` | Cutscene player | `scripts/cutscenes/<name>/` |
| `MENU` | Menu states | `scripts/menus/` |

---

## Folder Structure Example

```
mods/
└── myMod/
    └── scripts/
        ├── global/
        │   └── hud.hx           <- always active
        ├── songs/
        │   └── eggman/
        │       └── main.hx      <- active during "eggman"
        ├── stages/
        │   └── greenhill/
        │       └── props.hx     <- active on green hill stage
        ├── characters/
        │   └── sonic/
        │       └── animations.hx
        └── events/
            └── cameraZoom.hx    <- handles "Camera Zoom" chart event
```

---

## Error Handling

- Each plugin has an independent error counter.
- After **5 consecutive errors**, a plugin auto-disables itself.
- Errors in one plugin **never crash other plugins or the game**.
- Change the threshold: `ScriptPlugin.MAX_ERRORS = 10;`
