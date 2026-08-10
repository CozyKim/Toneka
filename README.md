[English](README.md) | [한국어](README.ko.md)

# Toneka

A system-wide audio equaliser for macOS. Toneka captures whatever your Mac is
playing through a Core Audio process tap, applies its effects, and plays the
result back through the output device you choose. There is no audio driver to
install.

Toneka is an independent hard fork of [eqMac](https://github.com/bitgapp/eqMac).
It is not affiliated with, endorsed by, or supported by the eqMac authors — see
[Acknowledgements](#acknowledgements) and [NOTICE](NOTICE).

The application's interface is in Korean.

## Features

- **No driver.** System audio is captured with a Core Audio process tap. The tap
  and your output device are paired inside a private aggregate device that
  exists only while Toneka is running, so one clock drives capture and playback.
- **Output selection.** Choose which device the processed audio plays through.
- **Volume.** Gain, mute and left/right balance, plus a boost that lets the gain
  go past unity. Each output device remembers its own level.
- **Basic equaliser.** Bass, mids and treble, with presets.
- **Advanced equaliser.** Ten fixed bands from 32 Hz to 16 kHz, with presets. You
  can save your own and delete them again.
- **Spectrum analyser.** A live spectrum and the current response curve are drawn
  behind the advanced equaliser.
- **Settings.** Launch at login, always on top, menu bar or Dock icon, knob
  behaviour (drag or rotate), and a choice of skins.

## Requirements

To run it:

- macOS 14.2 or later. Toneka is built on the Core Audio process tap API, which
  earlier versions of macOS do not have.
- Audio Recording permission, granted under System Settings > Privacy &
  Security. See the [FAQ](#faq) for why.

To build it:

- Xcode, and [CocoaPods](https://cocoapods.org) for the native dependencies
- Node 24.18.1, pinned in `.mise.toml` and most easily installed with
  [mise](https://mise.jdx.dev)
- Yarn v1

## Installing a release

Releases carry a zipped `Toneka.app`. The build is ad-hoc signed rather than
signed with an Apple Developer certificate, so macOS quarantines it on download
and Gatekeeper refuses to open it — the warning claims the app is damaged, which
it is not. Clear the quarantine flag after moving it into `/Applications`:

```bash
xattr -dr com.apple.quarantine /Applications/Toneka.app
```

Then open it. Grant Audio Recording permission when asked, or the equaliser has
nothing to work on.

If you would rather not run an unsigned binary — a reasonable position — build
it yourself instead.

## Build

Build it yourself:

```bash
git clone https://github.com/CozyKim/Toneka.git
cd Toneka
(cd native && pod install)
(cd ui && yarn)
scripts/build-local.sh
```

`scripts/build-local.sh` builds the web interface, builds the Release
configuration of `native/Toneka.xcworkspace`, and copies the result to
`/Applications/Toneka.app`. Pass `--no-install` to build without copying
anything into `/Applications`.

The build is ad-hoc signed, which is enough to run it on the machine that built
it. It is not enough for a copy that arrives with a quarantine flag — see
[Installing a release](#installing-a-release).

For development, `scripts/run-debug.sh` builds and launches the Debug
configuration with its logs on stdout; Ctrl-C quits. It uses
`io.github.cozykim.toneka.debug`, again separate from anything installed. Pass
`--ui` after changing anything under `ui/` — the interface is bundled into the
app as a zip, so it has to be rebuilt and its unpacked copy cleared.

## Usage

Open Toneka. The first time it runs, macOS asks for permission to record system
audio; Toneka cannot process anything without it. If you dismissed the prompt,
grant it under System Settings > Privacy & Security and restart the app.

The toggle at the top left turns processing on and off. Below it, pick the
output device, set the volume, and switch between the basic and advanced
equaliser. Presets are chosen from the row above the equaliser and can be saved
and deleted there. The cog opens settings; the buttons at the bottom open this
FAQ and quit the app.

## FAQ

**Does Toneka install an audio driver?**
No. It uses the Core Audio process tap API that macOS 14.2 introduced. Nothing
is written outside the application bundle and Toneka's own preferences. eqMac,
which Toneka is forked from, used a HAL plug-in installed into
`/Library/Audio/Plug-Ins/HAL`; that driver is gone.

**Why does it ask for permission to record audio?**
A process tap reads the audio that other applications are playing, and macOS
classifies that as recording. Toneka uses it to read the system output stream
and nothing else. Without the permission there is no audio to process.

**Does Toneka leave an audio device behind?**
No. The aggregate device it creates is private to the running process and is
destroyed when Toneka quits, so it never appears in Audio MIDI Setup and there
is nothing to clean up there.

**Does Toneka update itself?**
No. There is no updater and the app never phones home. To move to a newer
version, pull this repository and build it again.

**Is this eqMac? Can I ask the eqMac authors about it?**
No, and please do not. Toneka is a separate project that happens to share
history with eqMac. Problems with Toneka belong in
[this repository's issues](https://github.com/CozyKim/Toneka/issues).

## Uninstall

1. Quit Toneka.
2. Delete the application — `/Applications/Toneka.app`, or wherever you put
   your build.
3. Remove the data it stored:

   ```bash
   rm -rf ~/Library/Application\ Support/io.github.cozykim.toneka*
   defaults delete io.github.cozykim.toneka
   ```

   The `defaults` line clears saved presets, volume levels and settings. If you
   also ran a debug build, repeat it for `io.github.cozykim.toneka.debug`.
4. If you had turned on "launch at login", check System Settings > General >
   Login Items and remove any entry left behind.
5. Optionally, revoke the Audio Recording permission under System Settings >
   Privacy & Security.

There is no driver, no kernel extension and no background service to remove, and
no audio device is left in Audio MIDI Setup.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for how to build and debug, and
[CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md). Security reports go through
[SECURITY.md](SECURITY.md) rather than a public issue.

Toneka is a hobby project maintained by one person, so please allow some time
for a response.

## Acknowledgements

Toneka is a hard fork of [eqMac](https://github.com/bitgapp/eqMac) by
[Roman Kisil](https://github.com/nodeful) and Bitgapp, Copyright 2017-2021,
used under the Apache License, Version 2.0. The audio pipeline, the state
handling and much of the native application still descend from that work.

[NOTICE](NOTICE) records the derivation and lists the changes made to the
original.

## License

[Apache License, Version 2.0](LICENSE).
