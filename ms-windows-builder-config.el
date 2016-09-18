;;; ms-windows-builder-config.el ---                    -*- lexical-binding: t; -*-

;; Copyright (C) 2016 Nikolay Kudryavtsev <Nikolay.Kudryavtsev@gmail.com>

;; Author: Nikolay Kudryavtsev <Nikolay.Kudryavtsev@gmail.com>
;; Keywords: internal, windows

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; This file contains transient

;;; Code:
(defcustom mwb-emacs-source "c:/Emacs/source"
  "*Directory that contains Emacs source code."
  :group 'mwb
  :type 'directory)

(defcustom mwb-mingw-directory "c:/Emacs/MinGW"
  "* Place to check for MinGW and install it if it's not present."
  :group 'mwb
  :type 'directory)

(defcustom mwb-msys2-x32-directory "c:/Emacs/msys32"
  "* Place to check for 32 bit msys2 and install it if it's not present."
  :group 'mwb
  :type 'directory)

(defcustom mwb-msys2-x64-directory "c:/Emacs/msys64"
  "* Place to check for MinGW and install it if it's not present."
  :group 'mwb
  :type 'directory)

(defvar mwb-toolchains
  '((mingw ((ensure-fn mwb-mingw-ensure)
            (get-exec-path-fn mwb-mingw-get-exec-path)
            (get-path-fn mwb-mingw-get-path)
            (get-extra-env-fn mwb-mingw-get-extra-env)))
    (msys2-x32 ((ensure-fn mwb-msys2-x32-ensure)
                (get-exec-path-fn mwb-msys2-get-exec-path)
                (get-path-fn mwb-msys2-x32-get-path)
                (get-extra-env-fn mwb-msys2-x32-get-extra-env)))
    (msys2-x64 ((ensure-fn mwb-msys2-x64-ensure)
                (get-exec-path-fn mwb-msys2-get-exec-path)
                (get-path-fn mwb-msys2-x64-get-path)
                (get-extra-env-fn mwb-msys2-x64-get-extra-env))))
  "List of possbile builds for building Emacs.")

(defcustom mwb-configurations
  '((debug
     ((configure-env ("CFLAGS=-O0 -gdwarf-2 -g3"))
      (configure-args "--without-imagemagick --enable-checking='yes,glyphs' --enable-check-lisp-object-type")))
    (debug-with-modules
     ((configure-env ("CFLAGS=-O0 -gdwarf-2 -g3"))
      (configure-args "--without-imagemagick --enable-checking='yes,glyphs' --enable-check-lisp-object-type --with-modules")))
    (release
     ((configure-env ("CFLAGS=-O2 -gdwarf-4 -g3"))
      (configure-args "--without-imagemagick")))
    (release-with-modules
     ((configure-env ("CFLAGS=-O2 -gdwarf-4 -g3"))
      (configure-args "--without-imagemagick --with-modules"))))
  "*List of possible configurations."
  :group 'mwb)

(defcustom mwb-configuration-default 'debug
  "*Default configure setup to use."
  :group 'mwb)

(defcustom mwb-make-threads 1
  "The number of threads to pass as -j flag to make.")

(defvar mwb-mingw-packages
  '(("https://sourceforge.net/projects/mingw/files/MinGW/Base/"
     ("binutils/binutils-2.25.1/binutils-2.25.1-1-mingw32-bin.tar.xz"
      "mingwrt/mingwrt-3.22/mingwrt-3.22.1-mingw32-dev.tar.xz"
      "mingwrt/mingwrt-3.22/mingwrt-3.22.1-mingw32-dll.tar.xz"
      "w32api/w32api-3.18/w32api-3.18.1-mingw32-dev.tar.xz"
      "mpc/mpc-1.0.2/libmpc-1.0.2-mingw32-dll-3.tar.xz"
      "mpfr/mpfr-3.1.2-2/mpfr-3.1.2-2-mingw32-dll.tar.lzma"
      "gmp/gmp-5.1.2/gmp-5.1.2-1-mingw32-dll.tar.lzma"
      ;; Pthreads is no longer required by gcc and does not get installed with it by mingw-get, but it's still required by ld.
      "pthreads-w32/pthreads-w32-2.9.1/pthreads-w32-2.9.1-1-mingw32-dll.tar.lzma"
      "pthreads-w32/pthreads-w32-2.9.1/pthreads-w32-2.9.1-1-mingw32-dev.tar.lzma"
      "gettext/gettext-0.18.3.2-2/gettext-0.18.3.2-2-mingw32-dev.tar.xz"
      "gcc/Version5/gcc-5.3.0-2/gcc-core-5.3.0-2-mingw32-bin.tar.xz"))
    ("https://sourceforge.net/projects/ezwinports/files/"
     ("pkg-config-0.28-w32-bin.zip"
      ;; gnutls dependencies start
      "p11-kit-0.9-w32-bin.zip"
      "libtasn1-4.2-w32-bin.zip"
      "nettle-2.7.1-w32-bin.zip"
      "zlib-1.2.8-2-w32-bin.zip"
      "gnutls-3.3.11-w32-bin.zip"))))


(defvar mwb-msys-packages
  '(("https://sourceforge.net/projects/mingw/files/MSYS/"
     ("Base/msys-core/msys-1.0.19-1/msysCORE-1.0.19-1-msys-1.0.19-bin.tar.xz"
      "Base/bash/bash-3.1.23-1/bash-3.1.23-1-msys-1.0.18-bin.tar.xz"
      "Base/gettext/gettext-0.18.1.1-1/libintl-0.18.1.1-1-msys-1.0.17-dll-8.tar.lzma"
      "Base/libiconv/libiconv-1.14-1/libiconv-1.14-1-msys-1.0.17-dll-2.tar.lzma"
      "Base/xz/xz-5.0.3-1/liblzma-5.0.3-1-msys-1.0.17-dll-5.tar.lzma"
      "Base/xz/xz-5.0.3-1/xz-5.0.3-1-msys-1.0.17-bin.tar.lzma"
      "Base/bzip2/bzip2-1.0.6-1/libbz2-1.0.6-1-msys-1.0.17-dll-1.tar.lzma"
      "Base/bzip2/bzip2-1.0.6-1/bzip2-1.0.6-1-msys-1.0.17-bin.tar.lzma"
      "Base/make/make-3.81-3/make-3.81-3-msys-1.0.13-bin.tar.lzma"
      "Base/coreutils/coreutils-5.97-3/coreutils-5.97-3-msys-1.0.13-ext.tar.lzma"
      "Base/coreutils/coreutils-5.97-3/coreutils-5.97-3-msys-1.0.13-bin.tar.lzma"
      "Base/findutils/findutils-4.4.2-2/findutils-4.4.2-2-msys-1.0.13-bin.tar.lzma"
      "Base/diffutils/diffutils-2.8.7.20071206cvs-3/diffutils-2.8.7.20071206cvs-3-msys-1.0.13-bin.tar.lzma"
      "Base/tar/tar-1.23-1/tar-1.23-1-msys-1.0.13-bin.tar.lzma"
      "Base/less/less-436-2/less-436-2-msys-1.0.13-bin.tar.lzma"
      "Base/gawk/gawk-3.1.7-2/gawk-3.1.7-2-msys-1.0.13-bin.tar.lzma"
      "Base/gzip/gzip-1.3.12-2/gzip-1.3.12-2-msys-1.0.13-bin.tar.lzma"
      "Base/grep/grep-2.5.4-2/grep-2.5.4-2-msys-1.0.13-bin.tar.lzma"
      "Base/file/file-5.04-1/libmagic-5.04-1-msys-1.0.13-dll-1.tar.lzma"
      "Base/file/file-5.04-1/file-5.04-1-msys-1.0.13-bin.tar.lzma"
      "Base/sed/sed-4.2.1-2/sed-4.2.1-2-msys-1.0.13-bin.tar.lzma"
      "Base/regex/regex-1.20090805-2/libregex-1.20090805-2-msys-1.0.13-dll-1.tar.lzma"
      "Base/termcap/termcap-0.20050421_1-2/termcap-0.20050421_1-2-msys-1.0.13-bin.tar.lzma"
      "Base/termcap/termcap-0.20050421_1-2/libtermcap-0.20050421_1-2-msys-1.0.13-dll-0.tar.lzma"
      "Extension/flex/flex-2.5.35-2/flex-2.5.35-2-msys-1.0.13-bin.tar.lzma"
      "Extension/bison/bison-2.4.2-1/bison-2.4.2-1-msys-1.0.13-bin.tar.lzma"
      "Extension/m4/m4-1.4.16-2/m4-1.4.16-2-msys-1.0.17-bin.tar.lzma"
      ;; Perl dependencies start. Perl is needed for automake.
      "Extension/libxml2/libxml2-2.7.6-1/libxml2-2.7.6-1-msys-1.0.13-dll-2.tar.lzma"
      "Extension/expat/expat-2.0.1-1/libexpat-2.0.1-1-msys-1.0.13-dll-1.tar.lzma"
      "Extension/crypt/crypt-1.1_1-3/libcrypt-1.1_1-3-msys-1.0.13-dll-0.tar.lzma"
      "Extension/gdbm/gdbm-1.8.3-3/libgdbm-1.8.3-3-msys-1.0.13-dll-3.tar.lzma"
      "Extension/perl/perl-5.8.8-1/perl-5.8.8-1-msys-1.0.17-bin.tar.lzma"
      "Extension/mktemp/mktemp-1.6-2/mktemp-1.6-2-msys-1.0.13-bin.tar.lzma"))
    ("https://sourceforge.net/projects/ezwinports/files/"
     ("automake-1.11.6-msys-bin.zip"
      "autoconf-2.65-msys-bin.zip"
      "texinfo-6.3-w32-bin.zip"))))


(defvar mwb-msys2-x32-packages '("base-devel" "mingw-w64-i686-toolchain"
                                 "mingw-w64-i686-xpm-nox" "mingw-w64-i686-libtiff"
                                 "mingw-w64-i686-giflib" "mingw-w64-i686-libpng"
                                 "mingw-w64-i686-libjpeg-turbo" "mingw-w64-i686-librsvg"
                                 "mingw-w64-i686-libxml2" "mingw-w64-i686-gnutls"))

(defvar mwb-msys2-x32-dist
  "https://sourceforge.net/projects/msys2/files/Base/i686/msys2-base-i686-20160719.tar.xz")


(defvar mwb-msys2-x64-packages '("base-devel" "mingw-w64-x86_64-toolchain"
                                 "mingw-w64-x86_64-xpm-nox" "mingw-w64-x86_64-libtiff"
                                 "mingw-w64-x86_64-giflib" "mingw-w64-x86_64-libpng"
                                 "mingw-w64-x86_64-libjpeg-turbo" "mingw-w64-x86_64-librsvg"
                                 "mingw-w64-x86_64-libxml2" "mingw-w64-x86_64-gnutls"))

(defvar mwb-msys2-x64-dist
  "https://sourceforge.net/projects/msys2/files/Base/x86_64/msys2-base-x86_64-20160719.tar.xz")


(provide 'ms-windows-builder-config)
;;; ms-windows-builder-config.el ends here
