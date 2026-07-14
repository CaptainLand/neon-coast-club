# Rhythm UI integration

`res://scenes/rhythm/rhythm_ui.tscn` is a self-contained presentation layer for the 4K game.
It is mounted under `RhythmLayer` in the main scene and opens when the arcade cabinet is used.

## Public API

- `open_song_select()`
- `open_settings()`
- `open_game(song, difficulty)`
- `show_result(result_dictionary)`
- `close()`
- `set_song_library(song_dictionaries)`

## Signals

- `song_confirmed(song, difficulty)`: start chart loading and the rhythm engine here.
- `settings_changed(settings)`: persist speed, offset, volume, lane opacity, and FPS preference.
- `retry_requested`: restart the selected chart.
- `closed`: restore the surrounding game state if additional state is managed outside this scene.

The game view runs the Godot rhythm core in `scripts/rhythm/rhythm_game.gd`. It loads the original
AiAe chart text and audio, uses D/F/J/K input, judges tap and hold notes, and emits real result data.

Expected result fields are `score`, `accuracy`, `max_combo`, `critical`, `perfect`, `great`, `good`,
and `miss`. Song dictionaries should provide `title`, `artist`, `bpm`, `length`, `accent`, and a
`difficulties` array containing `name` and `level`.
