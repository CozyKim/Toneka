## Contribution
Toneka is a young fork and large parts of it are still moving, so big features are hard to coordinate — but I'm open to try anyway. Please create an issue on GitHub (please check if your issue is already being discussed) to agree on a piece of work first. Once it's agreed - fork, build, debug, fix and create a Pull Request to get your work merged in :)
Check the documentation below to understand how to build and debug Toneka.

## Development
Fork the repository, then run these commands in Terminal.app:

``` 
git clone https://github.com/YOUR_USERNAME/Toneka.git
cd Toneka/
```

### Web User Interface
If you want to run the web based User Interface locally then you need to follow these steps to make that happen:

#### Prerequisites
Install Node.js 24.18.1. The version is pinned in `.mise.toml`, so [mise](https://mise.jdx.dev) will pick it up on its own; the build scripts expect to find it there.

Install [Yarn](https://classic.yarnpkg.com/en/) v1 globally: `npm i -g yarn`

#### Building and running the Web UI
1. Go into the ui/ directory by `cd ui/`
2. Install dependencies with `yarn`
3. Start local development server with `yarn start`

### Native app
#### Prerequisites

1. Download [Xcode](https://apps.apple.com/us/app/xcode/id497799835?mt=12)
2. Install [CocoaPods](https://cocoapods.org/) by `sudo gem install cocoapods`

#### Building and running the App

1. Go into the native directory from root of the repo by: `cd native/`
2. Install Cocoapod dependencies: `pod install`
3. Go back to the root of the repo and run `scripts/run-debug.sh`. It builds the **Toneka** scheme in the Debug configuration and launches the app with its logs on stdout; Ctrl-C quits. Pass `--ui` after changing anything under `ui/`, and `--help` for the rest of the options.

If you would rather work in Xcode, open `native/Toneka.xcworkspace` and run the **Toneka** scheme. It bundles the `native/app/Embedded/ui.zip` that is committed to the repository, so it builds without touching the web UI at all — but it will keep using that committed interface until you rebuild the zip, which `scripts/run-debug.sh --ui` does for you.

Debug builds use the bundle identifier `io.github.cozykim.toneka.debug`, so they never share preferences, permission grants or the unpacked UI with an installed release.
