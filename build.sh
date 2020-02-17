#!/usr/bin/bash.exe

# Exit immediately if an error occurs
set -e

export PATH=/bin:/usr/bin:/${MINGW_VERSION}/bin:/c/Program\ Files/Git/cmd:/c/Windows/System32

WORKDIR=${PWD}

JOBS=3

CC=/${MINGW_VERSION}/bin/${ARCH}-w64-mingw32-gcc.exe
CXX=/${MINGW_VERSION}/bin/${ARCH}-w64-mingw32-g++.exe
CMAKE_OPTS="-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_INSTALL_PREFIX=/${MINGW_VERSION} \
	-DCMAKE_C_COMPILER:FILEPATH=${CC} \
	-DCMAKE_CXX_COMPILER:FILEPATH=${CXX} \
	-DPKG_CONFIG_EXECUTABLE:FILEPATH=/${MINGW_VERSION}/bin/pkg-config.exe"
AUTOCONF_OPTS="--prefix=/msys64/${MINGW_VERSION} \
	--host=${ARCH}-w64-mingw32 \
	--enable-shared \
	--disable-static"

if [ ${ARCH} == "i686" ]
then
	RC_COMPILER_OPT="-DCMAKE_RC_COMPILER=/c/windres.exe"
else
	RC_COMPILER_OPT=""
fi

DEPENDENCIES="mingw-w64-${ARCH}-libxml2 \
	mingw-w64-${ARCH}-boost \
	mingw-w64-${ARCH}-fftw \
	mingw-w64-${ARCH}-libzip \
	mingw-w64-${ARCH}-python3 \
	mingw-w64-${ARCH}-glib2 \
	mingw-w64-${ARCH}-glibmm \
	mingw-w64-${ARCH}-pkg-config \
	" \

# Remove dependencies that prevent us from upgrading to GCC 6.2
pacman -Rs --noconfirm \
	mingw-w64-${ARCH}-gcc-ada \
	mingw-w64-${ARCH}-gcc-fortran \
	mingw-w64-${ARCH}-gcc-libgfortran \
	mingw-w64-${ARCH}-gcc-objc

# Remove existing file that causes GCC install to fail
rm /${MINGW_VERSION}/etc/gdbinit

# Update to GCC 6.2 and install build-time dependencies
pacman --force --noconfirm -Sy \
	mingw-w64-${ARCH}-gcc \
	mingw-w64-${ARCH}-cmake \
	autoconf \
	automake-wrapper

pacman -U --noconfirm http://repo.msys2.org/mingw/${ARCH}/mingw-w64-${ARCH}-doxygen-1.8.14-2-any.pkg.tar.xz
pacman -U --noconfirm http://repo.msys2.org/mingw/${ARCH}/mingw-w64-${ARCH}-graphviz-2.40.1-4-any.pkg.tar.xz
pacman -U --noconfirm http://repo.msys2.org/mingw/${ARCH}/mingw-w64-${ARCH}-llvm-5.0.0-3-any.pkg.tar.xz http://repo.msys2.org/mingw/${ARCH}/mingw-w64-${ARCH}-clang-5.0.0-3-any.pkg.tar.xz      

# Install an older version of icu
#pacman -U --noconfirm http://repo.msys2.org/mingw/${ARCH}/mingw-w64-${ARCH}-icu-58.2-3-any.pkg.tar.xz
#pacman -U --noconfirm http://repo.msys2.org/mingw/${ARCH}/mingw-w64-${ARCH}-icu-debug-libs-58.2-3-any.pkg.tar.xz

# Install dependencies
pacman --force --noconfirm -Sy ${DEPENDENCIES}

pacman -U --noconfirm http://repo.msys2.org/mingw/${ARCH}/mingw-w64-${ARCH}-libusb-1.0.21-2-any.pkg.tar.xz 

build_libiio() {
	git clone --depth 1 https://github.com/analogdevicesinc/libiio.git ${WORKDIR}/libiio

	mkdir ${WORKDIR}/libiio/build-${ARCH}
	cd ${WORKDIR}/libiio/build-${ARCH}
	# Download a 32-bit version of windres.exe

        cd /c
        wget http://swdownloads.analog.com/cse/build/windres.exe.gz
        gunzip windres.exe.gz
        cd ${WORKDIR}/libiio/build-${ARCH}

	cmake -G 'Unix Makefiles' \
		${CMAKE_OPTS} \
		${RC_COMPILER_OPT} \
		-DWITH_TESTS:BOOL=OFF \
		-DWITH_DOC:BOOL=OFF \
		-DWITH_MATLAB_BINDINGS:BOOL=OFF \
		-DCSHARP_BINDINGS:BOOL=OFF \
		-DPYTHON_BINDINGS:BOOL=OFF \
		${WORKDIR}/libiio

	make -j ${JOBS} install
	DESTDIR=${WORKDIR} make -j ${JOBS} install
}

build_libad9361() {
	git clone --depth 1 https://github.com/analogdevicesinc/libad9361-iio.git ${WORKDIR}/libad9361

	mkdir ${WORKDIR}/libad9361/build-${ARCH}
	cd ${WORKDIR}/libad9361/build-${ARCH}

	cmake -G 'Unix Makefiles' \
		${CMAKE_OPTS} \
		${WORKDIR}/libad9361

	make -j ${JOBS} install
	DESTDIR=${WORKDIR} make -j ${JOBS} install
}

build_markdown() {
	mkdir -p ${WORKDIR}/markdown
	cd ${WORKDIR}/markdown

	wget https://pypi.python.org/packages/1d/25/3f6d2cb31ec42ca5bd3bfbea99b63892b735d76e26f20dd2dcc34ffe4f0d/Markdown-2.6.8.tar.gz -O- \
		| tar xz --strip-components=1 -C ${WORKDIR}/markdown

	python2 setup.py build
	python2 setup.py install
}

build_cheetah() {
	mkdir -p ${WORKDIR}/cheetah
	cd ${WORKDIR}/cheetah

	wget https://pypi.python.org/packages/cd/b0/c2d700252fc251e91c08639ff41a8a5203b627f4e0a2ae18a6b662ab32ea/Cheetah-2.4.4.tar.gz -O- \
		| tar xz --strip-components=1 -C ${WORKDIR}/cheetah

	python2 setup.py build
	python2 setup.py install
}


build_gnuradio() {
	git clone --recurse-submodules --depth 1 https://github.com/gnuradio/gnuradio.git -b maint-3.8 ${WORKDIR}/gnuradio

	mkdir ${WORKDIR}/gnuradio/build-${ARCH}
	cd ${WORKDIR}/gnuradio/build-${ARCH}

	cmake -G 'Unix Makefiles' \
		${CMAKE_OPTS} \
		-DENABLE_GR_DIGITAL:BOOL=OFF \
		-DENABLE_GR_DTV:BOOL=OFF \
		-DENABLE_GR_ATSC:BOOL=OFF \
		-DENABLE_GR_AUDIO:BOOL=OFF \
		-DENABLE_GR_CHANNELS:BOOL=OFF \
		-DENABLE_GR_NOAA:BOOL=OFF \
		-DENABLE_GR_PAGER:BOOL=OFF \
		-DENABLE_GR_TRELLIS:BOOL=OFF \
		-DENABLE_GR_VOCODER:BOOL=OFF \
		-DENABLE_GR_FEC:BOOL=OFF \
		-DENABLE_INTERNAL_VOLK:BOOL=ON \
		${WORKDIR}/gnuradio

	make -j ${JOBS} install
	DESTDIR=${WORKDIR} make -j ${JOBS} install
}

build_griio() {
	git clone --depth 1 https://github.com/analogdevicesinc/gr-iio.git ${WORKDIR}/gr-iio

	mkdir ${WORKDIR}/gr-iio/build-${ARCH}
	cd ${WORKDIR}/gr-iio/build-${ARCH}

	# -D_hypot=hypot: http://boost.2283326.n4.nabble.com/Boost-Python-Compile-Error-s-GCC-via-MinGW-w64-td3165793.html#a3166757
	cmake -G 'Unix Makefiles' \
		${CMAKE_OPTS} \
		-DCMAKE_CXX_FLAGS="-D_hypot=hypot" \
		${WORKDIR}/gr-iio

	make -j ${JOBS} install
	DESTDIR=${WORKDIR} make -j ${JOBS} install
}

#build_markdown
#build_cheetah
#build_libvolk
build_gnuradio
build_libiio
build_libad9361
build_griio

# Fix DLLs installed in the wrong path
mv ${WORKDIR}/msys64/${MINGW_VERSION}/lib/qwt.dll \
	${WORKDIR}/msys64/${MINGW_VERSION}/lib/qwtpolar.dll \
	${WORKDIR}/msys64/${MINGW_VERSION}/bin

rm -rf ${WORKDIR}/msys64/${MINGW_VERSION}/doc \
	${WORKDIR}/msys64/${MINGW_VERSION}/share/doc \
	${WORKDIR}/msys64/${MINGW_VERSION}/lib/*.la

tar cavf ${WORKDIR}/scopy-${MINGW_VERSION}-build-deps.tar.xz -C ${WORKDIR} msys64

echo -n ${DEPENDENCIES} > ${WORKDIR}/dependencies.txt
