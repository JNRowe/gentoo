# Copyright 1999-2017 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=6

inherit cmake-utils toolchain-funcs xdg-utils

if [[ "${PV}" == "9999" ]] ; then
	inherit git-r3
	EGIT_REPO_URI="git://git.freedesktop.org/git/${PN}/${PN}"
	SLOT="0/9999"
else
	SRC_URI="https://poppler.freedesktop.org/${P}.tar.xz"
	KEYWORDS="~alpha amd64 arm ~arm64 ~hppa ia64 ~mips ppc ppc64 ~s390 ~sh ~sparc x86 ~amd64-fbsd ~sparc-fbsd ~x86-fbsd ~amd64-linux ~x86-linux ~ppc-macos ~x64-macos ~x86-macos ~sparc-solaris ~sparc64-solaris ~x64-solaris ~x86-solaris"
	SLOT="0/68"   # CHECK THIS WHEN BUMPING!!! SUBSLOT IS libpoppler.so SOVERSION
fi

DESCRIPTION="PDF rendering library based on the xpdf-3.0 code base"
HOMEPAGE="https://poppler.freedesktop.org/"

LICENSE="GPL-2"
IUSE="cairo cjk curl cxx debug doc +introspection +jpeg +jpeg2k +lcms nss png qt4 qt5 tiff +utils"

# No test data provided
RESTRICT="test"

COMMON_DEPEND="
	>=media-libs/fontconfig-2.6.0
	>=media-libs/freetype-2.3.9
	sys-libs/zlib
	cairo? (
		dev-libs/glib:2
		>=x11-libs/cairo-1.10.0
		introspection? ( >=dev-libs/gobject-introspection-1.32.1:= )
	)
	curl? ( net-misc/curl )
	jpeg? ( virtual/jpeg:0 )
	jpeg2k? ( media-libs/openjpeg:2= )
	lcms? ( media-libs/lcms:2 )
	nss? ( >=dev-libs/nss-3.19:0 )
	png? ( media-libs/libpng:0= )
	qt4? (
		dev-qt/qtcore:4
		dev-qt/qtgui:4
	)
	qt5? (
		dev-qt/qtcore:5
		dev-qt/qtgui:5
		dev-qt/qtxml:5
	)
	tiff? ( media-libs/tiff:0 )
"
DEPEND="${COMMON_DEPEND}
	virtual/pkgconfig
"
RDEPEND="${COMMON_DEPEND}
	cjk? ( >=app-text/poppler-data-0.4.7 )
"

DOCS=(AUTHORS NEWS README README-XPDF TODO)

PATCHES=(
	"${FILESDIR}/${PN}-0.26.0-qt5-dependencies.patch"
	"${FILESDIR}/${PN}-0.28.1-fix-multilib-configuration.patch"
	"${FILESDIR}/${PN}-0.53.0-respect-cflags.patch"
	"${FILESDIR}/${PN}-0.33.0-openjpeg2.patch"
	"${FILESDIR}/${PN}-0.40-FindQt4.patch"
)

src_prepare() {
	cmake-utils_src_prepare

	# Clang doesn't grok this flag, the configure nicely tests that, but
	# cmake just uses it, so remove it if we use clang
	if [[ ${CC} == clang ]] ; then
		sed -i -e 's/-fno-check-new//' cmake/modules/PopplerMacros.cmake || die
	fi

	if ! grep -Fq 'cmake_policy(SET CMP0002 OLD)' CMakeLists.txt ; then
		sed '/^cmake_minimum_required/acmake_policy(SET CMP0002 OLD)' \
			-i CMakeLists.txt || die
	else
		einfo "policy(SET CMP0002 OLD) - workaround can be removed"
	fi

	if tc-is-clang && [[ ${CHOST} == *-darwin* ]] ; then
		# we need to up the C++ version, bug #622526
		export CXX="$(tc-getCXX) -std=c++11"
	fi
}

src_configure() {
	xdg_environment_reset
	local mycmakeargs=(
		-DBUILD_GTK_TESTS=OFF
		-DBUILD_QT4_TESTS=OFF
		-DBUILD_QT5_TESTS=OFF
		-DBUILD_CPP_TESTS=OFF
		-DENABLE_SPLASH=ON
		-DENABLE_ZLIB=ON
		-DENABLE_ZLIB_UNCOMPRESS=OFF
		-DENABLE_XPDF_HEADERS=ON
		-DENABLE_LIBCURL="$(usex curl)"
		-DENABLE_CPP="$(usex cxx)"
		-DENABLE_UTILS="$(usex utils)"
		-DSPLASH_CMYK=OFF
		-DUSE_FIXEDPOINT=OFF
		-DUSE_FLOAT=OFF
		-DWITH_Cairo="$(usex cairo)"
		-DWITH_GObjectIntrospection="$(usex introspection)"
		-DWITH_JPEG="$(usex jpeg)"
		-DWITH_NSS3="$(usex nss)"
		-DWITH_PNG="$(usex png)"
		-DWITH_Qt4="$(usex qt4)"
		$(cmake-utils_use_find_package qt5 Qt5Core)
		-DWITH_TIFF="$(usex tiff)"
	)
	if use jpeg; then
		mycmakeargs+=(-DENABLE_DCTDECODER=libjpeg)
	else
		mycmakeargs+=(-DENABLE_DCTDECODER=none)
	fi
	if use jpeg2k; then
		mycmakeargs+=(-DENABLE_LIBOPENJPEG=openjpeg2)
	else
		mycmakeargs+=(-DENABLE_LIBOPENJPEG=none)
	fi
	if use lcms; then
		mycmakeargs+=(-DENABLE_CMS=lcms2)
	else
		mycmakeargs+=(-DENABLE_CMS=)
	fi

	cmake-utils_src_configure
}

src_install() {
	cmake-utils_src_install

	# live version doesn't provide html documentation
	if use cairo && use doc && [[ ${PV} != 9999 ]]; then
		# For now install gtk-doc there
		insinto /usr/share/gtk-doc/html/poppler
		doins -r "${S}"/glib/reference/html/*
	fi
}
