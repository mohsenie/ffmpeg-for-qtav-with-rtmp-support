# QtAv android-ffmpeg-with-rtmp

This repository contains script(s) to build ffmpeg for QtAV with RTMP (and OpenSSL) support. Note that the build script only builds for
Android target and for any other platform you need to modify it.

## Instructions

1. Install the [Android NDK][android-ndk] (tested with version r10).
2. Ensure that [cURL][cURL] is installed.
3. Ensure that [pkg-config][pkg-config] is installed.
4. Clone this repository and `cd` into its directory.
5. Run `build_rtmp.sh`.
6. Look in `build/dist` for the resulting libraries and executables. Copy everything inside `/dist/bin` to `/Qt5.6.5/5.6/android_armv7`
7. Look in `build/build.log` if something goes wrong.
8. cd into `build_ffmpeg`
9. run `./build_ffmpeg.sh android        # android armv7`
10. look into `sdk_android_arm` and copy everything in it into `/Qt5.6.5/5.6/android_armv7`
11. build QtAv

<!-- external links -->
[openssl-android]:https://github.com/guardianproject/openssl-android
[FFmpeg-Android]:https://github.com/OnlyInAmerica/FFmpeg-Android
[android-ndk]:https://developer.android.com/tools/sdk/ndk/index.html
[cURL]:http://curl.haxx.se/
[pkg-config]:http://www.freedesktop.org/wiki/Software/pkg-config/
[QtAV]:https://github.com/wang-bin/QtAV.git
