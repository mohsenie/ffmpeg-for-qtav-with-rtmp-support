#/bin/bash
echo
echo "FFmpeg build tool for all platforms. Author: wbsecg1@gmail.com 2013-2016"

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PARENT_DIR="$(dirname "${DIR}")"

#loading config file for NDK variable
config_file=${PARENT_DIR}/.build-config.sh
source ${config_file}
NDK_ROOT=$NDK

LIB_RTMP="${PARENT_DIR}/src/rtmpdump/librtmp"
LIB_OPEN_SSL="${PARENT_DIR}/src/openssl-android"
FFSRC="${PARENT_DIR}/src/ffmpeg"


PLATFORMS="ios|android|maemo5|maemo6|vc|x86|winstore|winpc|winphone"
echo "Usage:"
test -d $PWD/ffmpeg || echo "  export FFSRC=/path/to/ffmpeg"
echo "  ./build_ffmpeg.sh [${PLATFORMS} [arch]]"
echo "(optional) set var in config-xxx.sh, xxx is ${PLATFORMS//\|/, }"
echo "var can be: INSTALL_DIR, NDK_ROOT, MAEMO5_SYSROOT, MAEMO6_SYSROOT"
TAGET_FLAG=$1
TAGET_ARCH_FLAG=$2 #${2:-$1}

if [ -n "$TAGET_FLAG" ]; then
  USER_CONFIG=config-${TAGET_FLAG}.sh
  test -f $USER_CONFIG &&  . $USER_CONFIG
fi

: ${INSTALL_DIR:=sdk}
# set NDK_ROOT if compile for android
: ${NDK_ROOT:="/devel/android/android-ndk-r10e"}
: ${MAEMO5_SYSROOT:=/opt/QtSDK/Maemo/4.6.2/sysroots/fremantle-arm-sysroot-20.2010.36-2-slim}
: ${MAEMO6_SYSROOT:=/opt/QtSDK/Madde/sysroots/harmattan_sysroot_10.2011.34-1_slim}
: ${LIB_OPT:="--enable-shared --disable-static"}
: ${MISC_OPT="--enable-hwaccels"}#--enable-gpl --enable-version3

: ${FFSRC:=$PWD/ffmpeg}
echo FFSRC=$FFSRC
[ -f $FFSRC/configure ] && {
  export PATH=$PATH:$FFSRC
} || {
  which configure &>/dev/null || {
    echo 'ffmpeg configure script can not be found in "$PATH"'
    exit 0
  }
  FFSRC=`which configure`
  FFSRC=${FFSRC%/configure}
}

toupper(){
    echo "$@" | tr abcdefghijklmnopqrstuvwxyz ABCDEFGHIJKLMNOPQRSTUVWXYZ
}

tolower(){
    echo "$@" | tr ABCDEFGHIJKLMNOPQRSTUVWXYZ abcdefghijklmnopqrstuvwxyz
}

host_is() {
  local name=$1
#TODO: osx=>darwin
  local line=`uname -a |grep -i $name`
  test -n "$line" && return 0 || return 1
}
target_is() {
  test "$TAGET_FLAG" = "$1" && return 0 || return 1
}
target_arch_is() {
  test "$TAGET_ARCH_FLAG" = "$1" && return 0 || return 1
}
is_libav() {
  test "${PWD/libav*/}" = "$PWD" && return 1 || return 0
}
host_is MinGW || host_is MSYS && {
  echo "msys2: change target_os detect in configure: mingw32)=>mingw*|msys*)"
  echo "       pacman -Sy --needed diffutils pkg-config"
  echo 'export PATH=$PATH:$MINGW_BIN:$PWD # make.exe in mingw_builds can not deal with windows driver dir. use msys2 make instead'
}

enable_opt() {
  local OPT=$1
  # grep -m1
  grep "\-\-enable\-$OPT" $FFSRC/configure && eval ${OPT}_opt="--enable-$OPT" &>/dev/null
}
#CPU_FLAGS=-mmmx -msse -mfpmath=sse
#ffmpeg 1.2 autodetect dxva, vaapi, vdpau. manually enable vda before 2.3
enable_opt dxva2
host_is Linux && {
  enable_opt vaapi
  enable_opt vdpau
}
host_is Darwin && {
  enable_opt vda
  enable_opt videotoolbox
}
# clock_gettime in librt instead of glibc>=2.17
grep "LIBRT" $FFSRC/configure &>/dev/null && {
  # TODO: cc test
  host_is Linux && ! target_is android && EXTRALIBS="$EXTRALIBS -lrt"
}
#avr >= ffmpeg0.11
#FFMAJOR=`pwd |sed 's,.*-\(.*\)\..*\..*,\1,'`
#FFMINOR=`pwd |sed 's,.*\.\(.*\)\..*,\1,'`
# n1.2.8, 2.5.1, 2.5
cd $FFSRC
FFMAJOR=`./version.sh |sed 's,[a-zA-Z]*\([0-9]*\)\..*,\1,'`
FFMINOR=`./version.sh |sed 's,[a-zA-Z]*[0-9]*\.\([0-9]*\).*,\1,'`
cd -
echo "FFmpeg/Libav version: $FFMAJOR.$FFMINOR"

setup_icc_env() {
  #TOOLCHAIN_OPT=
  PLATFORM_OPT="--toolchain=icl"
}

setup_android_env() {
  local ANDROID_ARCH=$1
  test -n "$ANDROID_ARCH" || ANDROID_ARCH=arm
  local ANDROID_TOOLCHAIN_PREFIX="${ANDROID_ARCH}-linux-android"
  local CROSS_PREFIX=${ANDROID_TOOLCHAIN_PREFIX}-
  local FFARCH=$ANDROID_ARCH
  local PLATFORM=android-9 #ensure do not use log2f in libm
  if [ "$ANDROID_ARCH" = "x86" -o "$ANDROID_ARCH" = "i686" ]; then
    ANDROID_TOOLCHAIN_PREFIX="x86"
    CROSS_PREFIX=i686-linux-android-
  elif [ ! "${ANDROID_ARCH/arm/}" = "arm" ]; then
#https://wiki.debian.org/ArmHardFloatPort/VfpComparison
    
    LIB_RTMP="${LIB_RTMP}/android/arm"
    #exporting path for ffmpeg config
    export LIB_RTMP_PATH=${LIB_RTMP} 

    ANDROID_TOOLCHAIN_PREFIX="arm-linux-androideabi"
    CROSS_PREFIX=${ANDROID_TOOLCHAIN_PREFIX}-
    FFARCH=arm
    EXTRA_CFLAGS="$EXTRA_CFLAGS -ffast-math -fstrict-aliasing -Werror=strict-aliasing -Wa,--noexecstack -I$LIB_OPEN_SSL/include -I$LIB_RTMP/include"
    TOOLCHAIN_OPT="$TOOLCHAIN_OPT --enable-thumb"
    if [ ! "${ANDROID_ARCH/armv5/}" = "$ANDROID_ARCH" ]; then
      echo "armv5"
      #EXTRA_CFLAGS="$EXTRA_CFLAGS -march=armv5te -mtune=arm9tdmi -msoft-float"
    elif [ ! "${ANDROID_ARCH/neon/}" = "$ANDROID_ARCH" ]; then
      echo "neon. can not run on Marvell and nVidia"
      TOOLCHAIN_OPT="$TOOLCHAIN_OPT --enable-neon" #--cpu=cortex-a8
      EXTRA_CFLAGS="$EXTRA_CFLAGS -march=armv7-a -mfloat-abi=softfp -mfpu=neon -mvectorize-with-neon-quad"
      EXTRA_LDFLAGS="$EXTRA_LDFLAGS -Wl,--fix-cortex-a8 -L$LIB_OPEN_SSL/libs/armeabi -L$LIB_RTMP/lib -lrtmp"
    else
      TOOLCHAIN_OPT="$TOOLCHAIN_OPT --enable-neon"
      EXTRA_CFLAGS="$EXTRA_CFLAGS -march=armv7-a -mfloat-abi=softfp -mfpu=vfpv3-d16"
    fi
  elif [ "$ANDROID_ARCH" = "aarch64" ]; then
    PLATFORM=android-21
  fi
  local TOOLCHAIN=${ANDROID_TOOLCHAIN_PREFIX}-4.9
  [ -d $NDK_ROOT/toolchains/${TOOLCHAIN} ] || TOOLCHAIN=${ANDROID_TOOLCHAIN_PREFIX}-4.8
  local ANDROID_TOOLCHAIN_DIR="/tmp/ndk-$TOOLCHAIN"
  echo "ANDROID_TOOLCHAIN_DIR=${ANDROID_TOOLCHAIN_DIR}"
  local ANDROID_SYSROOT="$ANDROID_TOOLCHAIN_DIR/sysroot"
# --enable-libstagefright-h264
  ANDROIDOPT="--enable-cross-compile --cross-prefix=$CROSS_PREFIX --sysroot=$ANDROID_SYSROOT --target-os=linux --arch=${FFARCH}"
  test -d $ANDROID_TOOLCHAIN_DIR || $NDK_ROOT/build/tools/make-standalone-toolchain.sh --platform=$PLATFORM --toolchain=$TOOLCHAIN --install-dir=$ANDROID_TOOLCHAIN_DIR #--system=linux-x86_64
  export PATH=$ANDROID_TOOLCHAIN_DIR/bin:$PATH
  rm -rf $ANDROID_SYSROOT/usr/include/{libsw*,libav*}
  rm -rf $ANDROID_SYSROOT/usr/lib/{libsw*,libav*}
  MISC_OPT="--enable-protocol=http --enable-protocol=rtmp --enable-decoder=h264 --enable-librtmp --enable-network"
  PLATFORM_OPT="$ANDROIDOPT"
  INSTALL_DIR=sdk-android-$ANDROID_ARCH
  # more flags see: https://github.com/yixia/FFmpeg-Vitamio/blob/vitamio/build_android.sh
}

if target_is android; then
  setup_android_env $TAGET_ARCH_FLAG
elif target_is ios; then
  setup_ios_env $TAGET_ARCH_FLAG
elif target_is vc; then
  setup_vc_env
elif target_is winpc; then
  setup_winrt_env
elif target_is winphone; then
  setup_winrt_env
elif target_is winstore; then
  setup_winrt_env
elif target_is maemo5; then
  setup_maemo5_env
elif target_is maemo6; then
  setup_maemo6_env
elif target_is x86; then
  if [ "`uname -m`" = "x86_64" ]; then
    #TOOLCHAIN_OPT="$TOOLCHAIN_OPT --enable-cross-compile --target-os=$(tolower $(uname -s)) --arch=x86"
    EXTRA_LDFLAGS="$EXTRA_LDFLAGS -m32"
    EXTRA_CFLAGS="$EXTRA_CFLAGS -m32"
    INSTALL_DIR=sdk-x86
  fi
else
  if host_is Sailfish; then
    echo "Build in Sailfish SDK"
    MISC_OPT=$MISC_OPT --disable-avdevice
    INSTALL_DIR=sdk-sailfish
  elif host_is Linux; then
    test -n "$vaapi_opt" && PLATFORM_OPT="$PLATFORM_OPT $vaapi_opt"
    test -n "$vdpau_opt" && PLATFORM_OPT="$PLATFORM_OPT $vdpau_opt"
  elif host_is Darwin; then
    test -n "$vda_opt" && PLATFORM_OPT="$PLATFORM_OPT $vda_opt"
    test -n "$videotoolbox_opt" && PLATFORM_OPT="$PLATFORM_OPT $videotoolbox_opt"
    TOOLCHAIN_OPT="$TOOLCHAIN_OPT --cc=clang" #libav has no --cxx
    EXTRA_CFLAGS=-mmacosx-version-min=10.8
    EXTRA_LDFLAGS=-mmacosx-version-min=10.8
  fi
fi

test -n "$EXTRA_CFLAGS" && TOOLCHAIN_OPT="$TOOLCHAIN_OPT --extra-cflags=\"$EXTRA_CFLAGS\""
test -n "$EXTRA_LDFLAGS" && TOOLCHAIN_OPT="$TOOLCHAIN_OPT --extra-ldflags=\"$EXTRA_LDFLAGS\""
test -n "$EXTRALIBS" && TOOLCHAIN_OPT="$TOOLCHAIN_OPT --extra-libs=\"$EXTRALIBS\""
echo $LIB_OPT
is_libav || MISC_OPT="$MISC_OPT --enable-avresample --disable-postproc"
CONFIGURE="configure --extra-version=QtAV --disable-doc --disable-debug $LIB_OPT --enable-pic --enable-runtime-cpudetect $USER_OPT $MISC_OPT $PLATFORM_OPT $TOOLCHAIN_OPT"
CONFIGURE=`echo $CONFIGURE |tr -s ' '`
# http://ffmpeg.org/platform.html
# static: --enable-pic --extra-ldflags="-Wl,-Bsymbolic" --extra-ldexeflags="-pie"
# ios: https://github.com/FFmpeg/gas-preprocessor

JOBS=2
if which nproc >/dev/null; then
    JOBS=`nproc`
elif host_is Darwin && which sysctl >/dev/null; then
    JOBS=`sysctl -n machdep.cpu.thread_count`
fi

echo $CONFIGURE

mkdir -p build_$INSTALL_DIR
cd build_$INSTALL_DIR
time eval $CONFIGURE
if [ $? -eq 0 ]; then
  time (make -j$JOBS install prefix="$PWD/../$INSTALL_DIR")
fi

