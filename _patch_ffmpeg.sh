function patch_ffmpeg {
  echo "Downloading and patching ffmpeg ..."

  # download ffmpeg
  ffmpeg_archive=${src_root}/ffmpeg-snapshot.tar.bz2
  if [ ! -f "${ffmpeg_archive}" ]; then
    test -x "$(which curl)" || die "You must install curl!"
    curl -s http://ffmpeg.org/releases/ffmpeg-snapshot.tar.bz2 -o ${ffmpeg_archive} >> ${build_log} 2>&1 || \
      die "Couldn't download ffmpeg sources!"
  fi

  #extract ffmpeg
  if [ ! -d "${src_root}/ffmpeg" ]; then
    cd ${src_root}
    tar xvfj ${ffmpeg_archive} >> ${build_log} 2>&1 || die "Couldn't extract ffmpeg sources!"
  fi

  cd ${src_root}/ffmpeg

  # patch the configure script to use an Android-friendly versioning scheme
  patch -u configure ${patch_root}/ffmpeg-configure.patch >> ${build_log} 2>&1 || \
     die "Couldn't patch ffmpeg configure script!"
}
