
---
## Overview

AudioDriver is a high-level driver for managing the Retro Gadgets audio chip. It provides a multi-channel audio management system with priority-based channel eviction, master and per-channel volume/pitch control, spectral analysis, and a full-featured event system powered by BetterEvents.

The driver abstracts the low-level `AudioChip` component API by adding a **claim** system on top of it: before playing any sound, a channel must first be "claimed" (`Claim`). This prevents conflicts between different modules that might try to use the same channels simultaneously. When no free channels are available, the driver supports **priority-based eviction** — a channel with a lower priority is freed in favor of one with a higher priority.
---

## Architecture

### Channel System

The audio chip provides a fixed number of channels (`instance.ChannelsCount`), each capable of playing one `AudioSample` at a time. The driver splits channel interaction into two phases:

1. **Claim** — a channel is reserved for a specific audio sample and settings. Playback is not possible without a claim.
2. **Playback** — once claimed, the channel can be started, stopped, and paused.

### Priority-Based Eviction

Each channel claim can receive a `Priority` parameter (default `0`). If a channel is already occupied and a new request has a higher priority, the previous owner is evicted (playback is stopped and the channel is transferred to the new request). If the new request's priority is lower than or equal to the existing one, the claim is rejected.

### Channel States

The driver tracks internal state for each channel via the `ChannelStates` table:

| Field | Type | Description |
|-------|------|-------------|
| `playing` | `boolean` | Whether the channel is currently playing |
| `playtime` | `number` | Current playback time in seconds |

---

## Channel Management (Claim / Free)

### `Driver:Claim(ChannelID: number, Audio: AudioSample, Settings: { [string]: any }?) -> boolean`

Claims the specified channel for playback of the given audio sample.

| Parameter | Type | Description |
|-----------|------|-------------|
| `ChannelID` | `number` | Channel index (`0` to `ChannelsCount - 1`) |
| `Audio` | `AudioSample` | Audio sample to play |
| `Settings` | `{ [string]: any }?` | Optional settings |

**`Settings` fields:**

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `Priority` | `number` | `0` | Channel priority for eviction |
| `AutoFree` | `boolean` | `nil` / `false` | Automatically free the channel on completion |

**Priority eviction logic:**
If the channel is already claimed, the new request's priority is compared against the existing one. If `newPriority > existPriority` — the current sound is stopped and the channel is transferred to the new owner. Otherwise, the claim is rejected with a warning in the log.

**Returns:** `true` if the channel was successfully claimed, `false` on error (invalid channel or insufficient priority).

### `Driver:ClaimAny(Audio: AudioSample, Settings: { [string]: any }?) -> number?`

Automatically finds a free channel and claims it. If none are free, it attempts to evict the channel with the lowest priority.

| Parameter | Type | Description |
|-----------|------|-------------|
| `Audio` | `AudioSample` | Audio sample |
| `Settings` | `{ [string]: any }?` | Settings (including `Priority`) |

**Algorithm:**
1. Linear search for a free channel (from `0` to `ChannelsCount - 1`). The first one found is claimed and its ID is returned.
2. If all are occupied — searches for the channel with the lowest priority.
3. If `newPriority > lowestPriority` — evicts and returns that channel's ID.
4. Otherwise — logs a warning and returns `nil`.

**Returns:** `number?` — the claimed channel's ID, or `nil` if no channel is available.

### `Driver:Free(ChannelID: number, Force: boolean?) -> boolean`

Releases a claimed channel.

| Parameter | Type | Description |
|-----------|------|-------------|
| `ChannelID` | `number` | Channel index |
| `Force` | `boolean?` | If `true`, stops playback before releasing |

If `Force` is not specified or is `false`, the channel is removed from the driver's internal table, but hardware-level playback continues until natural completion. For immediate stop, use `Force = true` or call `:Stop(ChannelID)` beforehand.

**Returns:** `false` if the channel is invalid or was not claimed.

### `Driver:IsClaimed(ChannelID: number) -> boolean`

Checks whether the specified channel is currently claimed.

### `Driver:GetClaimedChannels() -> { number }`

Returns a sorted array of IDs of all claimed channels.

---

## Playback

### `Driver:Play(ChannelID: number, StartTime: number?) -> boolean`

Starts one-shot playback on the specified channel.

| Parameter | Type | Description |
|-----------|------|-------------|
| `ChannelID` | `number` | Channel index (must be claimed) |
| `StartTime` | `number?` | DSP time for scheduled start. Defaults to current DSP time |

Uses `instance:PlayScheduled()` for synchronized launch. Sets `entry.IsLoop = false`.

### `Driver:PlayRelative(ChannelID: number, Delay: number) -> boolean`

Starts playback with a delay relative to the current DSP time.

| Parameter | Type | Description |
|-----------|------|-------------|
| `ChannelID` | `number` | Channel index |
| `Delay` | `number` | Delay in seconds (default `0`) |

Equivalent to: `Play(ChannelID, GetDSPTime() + Delay)`.

### `Driver:PlayLoop(ChannelID: number, StartTime: number?) -> boolean`

Starts looped playback on the specified channel.

| Parameter | Type | Description |
|-----------|------|-------------|
| `ChannelID` | `number` | Channel index |
| `StartTime` | `number?` | DSP time for scheduled start |

Uses `instance:PlayLoopScheduled()`. Sets `entry.IsLoop = true`. Looping channels do not fire `ChannelFinished`, but do fire `ChannelLooped` on each new cycle.

### `Driver:Stop(ChannelID: number) -> boolean`

Fully stops playback on the channel.

### `Driver:Pause(ChannelID: number) -> boolean`

Pauses playback. Position is preserved.

### `Driver:UnPause(ChannelID: number) -> boolean`

Resumes playback from the paused position.

### `Driver:IsPlaying(ChannelID: number) -> boolean`

Checks whether sound is currently playing on the channel.

### `Driver:IsPaused(ChannelID: number) -> boolean`

Checks whether the channel is paused.

### `Driver:GetPlayTime(ChannelID: number) -> number`

Returns the current playback time of the channel in seconds.

### `Driver:SeekPlayTime(ChannelID: number, Time: number) -> boolean`

Seeks playback to the specified position.

| Parameter | Type | Description |
|-----------|------|-------------|
| `ChannelID` | `number` | Channel index |
| `Time` | `number` | Target position in seconds |

---

## Volume and Pitch

### Master Control

#### `Driver:SetMasterVolume(Volume: number)`

Sets the overall volume for all channels.

| Parameter | Type | Range | Description |
|-----------|------|-------|-------------|
| `Volume` | `number` | `0–100` | Volume in percent |

The value is clamped to the range `0–100` and immediately applied to `instance.Volume`.

#### `Driver:GetMasterVolume() -> number`

Returns the current master volume (`0–100`).

#### `Driver:SetMasterPitch(Pitch: number)`

Sets the overall pitch for all currently claimed channels.

The value is applied to each claimed channel via `instance:SetChannelPitch()`. Channels claimed after this call do not inherit the master pitch automatically — they must have their pitch set individually.

#### `Driver:GetMasterPitch() -> number`

Returns the current master pitch.

### Per-Channel Control

#### `Driver:SetVolume(ChannelID: number, Volume: number) -> boolean`

Sets the volume of an individual channel (`0–100`). Clamped.

#### `Driver:GetVolume(ChannelID: number) -> number`

Returns the volume of the channel.

#### `Driver:SetPitch(ChannelID: number, Pitch: number) -> boolean`

Sets the pitch (playback speed) of an individual channel.

#### `Driver:GetPitch(ChannelID: number) -> number`

Returns the pitch of the channel.

---

## Spectrum Analysis

The driver provides two levels of spectral analysis: per-channel and master level. The `SpectrumAnalyzer` utility is used to process raw data.

### `Driver:GetDSPTime() -> number`

Returns the current DSP time of the audio system. Useful for synchronized playback scheduling.

### `Driver:GetSpectrumData(ChannelID: number, BandsCount: number?) -> { number }`

Retrieves spectrum data for a single channel.

| Parameter | Type | Description |
|-----------|------|-------------|
| `ChannelID` | `number` | Channel index |
| `BandsCount` | `number?` | Number of frequency bands. If omitted — returns raw 128 values |

Raw data (128 bins) can be grouped into the specified number of bands via `SpectrumAnalyzer.ToBands()`.

### `Driver:GetLevel(ChannelID: number) -> number`

Returns the RMS volume level of the channel via `SpectrumAnalyzer.GetRMS()`. Useful for VU-meter visualizations.

### `Driver:GetMasterSpectrumData(BandsCount: number?) -> { number }`

Retrieves the averaged spectrum across all actively playing claimed channels.

**Algorithm:**
1. For each claimed and playing channel, obtains 128 spectrum bins.
2. Sums values for each bin.
3. Divides by the number of active channels (arithmetic mean).
4. If `BandsCount` is specified — groups via `SpectrumAnalyzer.ToBands()`.

If no active channels exist, returns an array of zeros.

### `Driver:GetMasterLevel() -> number`

Returns the averaged RMS level across all active channels.

---

## Event System

All events are created via BetterEvents at driver initialization. Event names include the driver name for uniqueness (e.g., `audio_ChannelFinished`).

### `Driver.ChannelFinished`

Fired when a **non-looping** channel finishes playback naturally or is force-stopped.

**Payload:**

```lua
{
    channel = number,       -- Channel ID
    entry = {               -- Channel claim data
        Audio = AudioSample,
        Settings = { [string]: any },
        IsLoop = boolean,
    }
}
```

If the channel's settings specify `AutoFree = true`, the driver automatically frees the channel **before** firing the `ChannelFinished` event. This means the event handler cannot control this channel — it is already free.

### `Driver.ChannelStarted`

Fired when playback begins on a channel (transition from "not playing" to "playing").

**Payload:** identical to `ChannelFinished`.

### `Driver.ChannelStopped`

Fired when playback stops (the channel is no longer playing and is not paused). Called **after** `ChannelFinished` for non-looping channels, or independently for looping channels that are force-stopped.

### `Driver.ChannelLooped`

Fired when a looping track starts a new playback cycle.

**Detection mechanism:** `_update()` compares `playtime` between ticks. If the channel was playing on both ticks and the current time is less than the previous time by more than `0.1` seconds — this indicates a rewind to the beginning (a loop).

> **Note:** The `0.1s` threshold prevents false positives from DSP synchronization jitter.

---

## Error Handling

| Situation | Response |
|-----------|----------|
| Component is not `AudioChip` | `logWarning`, returns `nil` from `AddDriver` |
| Driver not found | `logWarning`, returns `nil` from `GetDriver` |
| `ChannelID` out of range | `logWarning`, returns `false` |
| Claiming an occupied channel (low priority) | `logWarning`, returns `false` |
| Claiming an occupied channel (high priority) | Sound stopped, channel transferred to new owner, `log` |
| Playing on an unclaimed channel | `logWarning`, returns `false` |
| `ClaimAny` — no available channels | `logWarning`, returns `nil` |
| Freeing an unclaimed channel | `logWarning`, returns `false` |

All non-critical errors are logged via `logWarning` with the `[AUDIO DRIVER]:` prefix. Critical errors (invalid component type) prevent the driver from being created entirely.

---

## Usage Examples

### Basic Playback

```lua
local audio = KRNL.GetDriver("audio")
local sample = KRNL.ROM.LoadAudio("User", "explosion.wav")

-- Claim channel 0 and play
audio:Claim(0, sample)
audio:Play(0)

-- Free after completion
audio.ChannelFinished:Connect(function(data)
    print(string.format("Channel %d finished", data.channel))
    audio:Free(data.channel)
end)
```

### Auto-Free

```lua
audio:Claim(0, sample, { Priority = 1, AutoFree = true })
audio:Play(0)

-- The channel will be automatically freed after playback ends.
-- The ChannelFinished handler will still fire, but the channel will already be free.
```

### Priority-Based Eviction

```lua
-- Background music with low priority
local music = KRNL.ROM.LoadAudio("User", "music.mp3")
audio:Claim(0, music, { Priority = 0 })
audio:PlayLoop(0)

-- Sound effect with high priority — evicts the music
local sfx = KRNL.ROM.LoadAudio("User", "alert.wav")
local ch = audio:ClaimAny(sfx, { Priority = 10, AutoFree = true })
if ch then
    audio:Play(ch)
    -- Channel 0 was occupied by music with priority 0.
    -- The sound effect (priority 10) evicted it.
end
```

### Delayed and Synchronized Playback

```lua
-- Start sound after 0.5 seconds
audio:PlayRelative(0, 0.5)

-- Synchronized start across multiple channels
local dsp = audio:GetDSPTime() + 1.0  -- in 1 second
audio:Play(0, dsp)
audio:Play(1, dsp)
audio:Play(2, dsp)
-- All three channels will start playback simultaneously
```

### Per-Channel Volume and Pitch

```lua
audio:SetMasterVolume(75)

audio:Claim(0, sample1)
audio:Claim(1, sample2)

audio:SetVolume(0, 50)     -- Half volume on channel 0
audio:SetVolume(1, 100)    -- Full volume on channel 1

audio:SetPitch(0, 1.5)     -- Speed up by 50%
audio:SetPitch(1, 0.75)    -- Slow down by 25%
```

### Spectrum Analysis and VU-Meter

```lua
-- Get 8 frequency bands for channel 0
local bands = audio:GetSpectrumData(0, 8)
for i, level in ipairs(bands) do
    print(string.format("Band %d: %.2f", i, level))
end

-- Get RMS level (VU-meter)
local level = audio:GetLevel(0)
print(string.format("Level: %.1f%%", level * 100))

-- Master spectrum (averaged across all channels)
local masterBands = audio:GetMasterSpectrumData(16)
local masterLevel = audio:GetMasterLevel()
```

---

## Method Reference

### Channel Management

| Method | Returns | Description |
|--------|---------|-------------|
| `Claim(ch, audio, settings?)` | `boolean` | Claim a channel with priority |
| `ClaimAny(audio, settings?)` | `number?` | Automatically find and claim a channel |
| `Free(ch, force?)` | `boolean` | Release a channel |
| `IsClaimed(ch)` | `boolean` | Check if a channel is claimed |
| `GetClaimedChannels()` | `{ number }` | List of all claimed channels |

### Playback

| Method | Returns | Description |
|--------|---------|-------------|
| `Play(ch, startTime?)` | `boolean` | One-shot playback |
| `PlayRelative(ch, delay)` | `boolean` | Playback with delay |
| `PlayLoop(ch, startTime?)` | `boolean` | Looped playback |
| `Stop(ch)` | `boolean` | Stop playback |
| `Pause(ch)` | `boolean` | Pause playback |
| `UnPause(ch)` | `boolean` | Resume from pause |
| `IsPlaying(ch)` | `boolean` | Check if channel is playing |
| `IsPaused(ch)` | `boolean` | Check if channel is paused |
| `GetPlayTime(ch)` | `number` | Current playback time |
| `SeekPlayTime(ch, time)` | `boolean` | Seek to position |

### Volume and Pitch

| Method | Returns | Description |
|--------|---------|-------------|
| `SetMasterVolume(vol)` | `void` | Master volume (`0–100`) |
| `GetMasterVolume()` | `number` | Current master volume |
| `SetMasterPitch(pitch)` | `void` | Master pitch for all channels |
| `GetMasterPitch()` | `number` | Current master pitch |
| `SetVolume(ch, vol)` | `boolean` | Channel volume (`0–100`) |
| `GetVolume(ch)` | `number` | Channel volume |
| `SetPitch(ch, pitch)` | `boolean` | Channel pitch |
| `GetPitch(ch)` | `number` | Channel pitch |

### Analysis

| Method | Returns | Description |
|--------|---------|-------------|
| `GetDSPTime()` | `number` | Current DSP time |
| `GetSpectrumData(ch, bands?)` | `{ number }` | Channel spectrum |
| `GetLevel(ch)` | `number` | Channel RMS level |
| `GetMasterSpectrumData(bands?)` | `{ number }` | Averaged master spectrum |
| `GetMasterLevel()` | `number` | Averaged master level |

---

## Limitations

- **MasterPitch** is applied only to channels that are **already claimed** at the time of the call. Channels claimed afterwards do not inherit the master pitch automatically — you must set the pitch manually via `SetPitch()`.
- **AutoFree** releases the channel **before** the `ChannelFinished` handler is invoked. The channel will already be unavailable inside the handler.
- **Loop detection threshold** is `0.1` seconds — very short looping tracks may not be detected correctly.
- **Spectral data** is always fetched at 128-bin resolution; `SpectrumAnalyzer.ToBands()` performs downsampling to the specified `BandsCount`.
- **`GetMasterSpectrumData` and `GetMasterLevel`** only consider channels that are **claimed and actively playing**. Free channels, or claimed but silent channels, do not affect the master level.
