# react-native-video-manager

[![npm](https://img.shields.io/npm/v/react-native-video-manager)](https://www.npmjs.com/package/react-native-video-manager) ![Supports Android, iOS](https://img.shields.io/badge/platforms-android%20%7C%20ios-lightgrey.svg) ![MIT License](https://img.shields.io/npm/l/react-native-safe-area-context.svg)

Module cross platform to merge multiple videos.

This tool based on [`react-native-video-editor`](https://www.npmjs.com/package/react-native-video-editor), with working example, support to newer React Native versions, and more improvements.

**Temporary note**: This fork is being migrated to support Swift & Kotlin, and updated to support new functionality. Android is not yet at feature parity with iOS, and therefore it may not function as expected. Once feature parity has been reached, we'll look to contribute the changes here back to the community ✨

## Installation

```sh
yarn add react-native-video-manager
```

or

```sh
npm install react-native-video-manager
```

You then need to link the native parts of the library for the platforms you are using.

- **iOS Platform:**

`$ npx pod-install`

- **Android Platform:**

`no additional steps required`

## Usage

```js
import { VideoManager } from "react-native-video-manager";

// ...
const videos = ["file:///video1.mp4", "file:///video2.mp4"];

try {
  const { uri } = await VideoManager.merge(videos);

  console.log("merged video path", uri);
} catch (error) {
  console.log(error);
}
// ...
```

You can also check a complete example in `/example` folder.

## New changes!

### iOS

- Migrated all native code to use Swift, with a single obj-c file to bridge across.
- Updated incoming data models to map to Swift `struct`s for better typing & handling of data
- Updated outgoing data models to map from Swift `struct`s for better typing & handling of data
- Added `getDurationOf(video: string)` function - this takes a video path and returns the duration of it (in seconds) and whether the video is playable (to handle corrupted videos).
- Added `generateThumbnailFor(video: string, options: ThumbnailOptions)` function - this takes a video path (and options) and generates a `.png` thumbnail at a given point from that video:
  - `writeDirectory`: `string` - allows the implementing app to provide a write location. Use `react-native-fs` or an equivalent library to find & construct these directories.
  - `fileName`: `string` - the name of the thumbnail. This should not include the file extension.
  - `timestamp`: `number` - the point in the video to collect the thumbnail at.
- Updated `merge(videos: string[])` to support options:
  - `writeDirectory`: `string` - rather than always writing to documents, this allows the implementing app to provide a different location (i.e., cache directory). Use `react-native-fs` or an equivalent library to find & construct these directories.
  - `fileName`: `string` - rather than using the same file name, this allows the implementing app to provide a different / unique file name.
  - `ignoreSound`: `boolean` - for when you know your videos will not have an audio track, setting this allows the merge logic to operate - ignoring any audio.
    - Note: I may remove this, and instead update the logic to automatically handle this.
  - `actionKey`: `string` - setting this allows progress events to be emitted to JS. If multiple merge operations have been requested in a batch, this allows the progress to be matched to a given video
  - All options (where replacing a previous hardcoded value) use the old value as a fallback, if options is not provided
- Updated `merge(videos: string[])` to support returning `duration` alongside the `uri`.

Still in progress:

- Tidying up new Swift code
- Ensuring `VideoManagerError`s thrown throughout have detailed error messages that are surfaced to JS
- Use of turbo-modules?

### Android

Nothing yet - our project has a sole iOS focus for the initial launch. But, Android is on the way!

## Contributing

See the [contributing guide](CONTRIBUTING.md) to learn how to contribute to the repository and the development workflow.

## License

MIT
