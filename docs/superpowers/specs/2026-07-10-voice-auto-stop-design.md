# Voice Auto-stop Design

## Goal

Automatically finish voice expense recording after the user has spoken and the microphone input remains silent for 1.8 seconds, while preserving manual stop.

## Design

An iOS-local detector consumes PCM16 RMS levels and buffer durations. Initial silence never stops recording. A level above the speech threshold arms the detector; once armed, continuous audio below the silence threshold accumulates until 1.8 seconds, while audible input resets the timer. The detector is reset for every recording.

Audio-level calculation happens beside PCM conversion. State and `stop()` remain on the main actor, keeping UI and session mutations off the audio callback thread. Automatic stopping reuses the existing stop message and draft-generation flow. The status changes to indicate detected silence.

The deprecated Bluetooth option is replaced with `allowBluetoothHFP`, preserving Bluetooth microphone routing for the existing `playAndRecord` category.

## Testing

Unit tests cover initial silence, speech followed by 1.8 seconds of silence, interruption/reset, and PCM RMS calculation. Full iOS unit/UI tests and a simulator build are required.
