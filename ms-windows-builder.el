;;; windows-builder.el --- Elisp script for quckly building emacs on Windows.  -*- lexical-binding: t; -*-

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

;;; Code:
(require 'ms-windows-builder-config)

;; * Main
(defun mwb-build (selected-toolchain make-path output-path &optional configuration)
  "Build Emacs using SELECTED-BUILD, which should be defined in mwb-builds. Run
configure and make in MAKE-PATH. Install Emacs into OUTPUT-PATH."
  (let ((toolchain (cadr (assoc selected-toolchain mwb-toolchains)))
        (selected-configuration
         (mwb-apply-arg-configurations selected-toolchain
                                       (cadr (assoc (if configuration configuration
                                                      mwb-default-configuration)
                       mwb-configurations)))))
    (funcall (cadr (assoc 'ensure-fn toolchain)))
    (mwb-build-full (funcall (cadr (assoc 'get-exec-path-fn toolchain)))
                    (funcall (cadr (assoc 'get-path-fn toolchain)))
                    (funcall (cadr (assoc 'get-extra-env-fn toolchain)))
                    selected-configuration make-path output-path
                    (funcall (cadr (assoc 'get-libraries-dir-fn toolchain))))))

(defun mwb-apply-arg-configurations (selected-toolchain configuration)
  "Apply configurations for each configure argument in the configuration."
  (add-to-list
   'configuration
   `(configure-args .
                    ,(list (mwb-filter-args selected-toolchain
                                            (cadr (assoc 'configure-args configuration)))))))

(defun mwb-filter-args (selected-toolchain configure-args)
  "Filter arguments from CONFIGURE-ARGS, when SELECTED-TOOLCHAIN is in
mwb-confugration-args for them."
  (delq
   nil
   (mapcar
    (lambda (s)
      (if
          (or
           (not (assoc 'toolchains
                       (cadr (assoc s mwb-configuration-args))))
           (memq selected-toolchain
                 (cadr (assoc 'toolchains
                              (cadr (assoc s mwb-configuration-args))))))
          s nil))
    configure-args)))

;; * Generic builder

(defun mwb-build-full (exec-path path extra-env configuration
                                 configuration-dir destination-dir libraries-dir)
  "Build Emacs in CONFIGURATION-DIR from sources in mwb-emacs-source and install
it into DESTINATION-DIR.  EXEC-PATH, PATH and EXTRA-ENV would eventually get passed
to mwb-command and used there."
  (mwb-autogen exec-path path extra-env)
  (mwb-configure exec-path path extra-env configuration configuration-dir destination-dir)
  (mwb-make exec-path path extra-env configuration-dir)
  (mwb-make-install exec-path path extra-env configuration configuration-dir)
  (mwb-copy-libraries libraries-dir destination-dir))

(defun mwb-autogen (exec-path path extra-env)
  (mwb-command exec-path path extra-env "./autogen.sh" mwb-emacs-source))

(defun mwb-configure (exec-path path extra-env configuration configuration-dir prefix)
  (mwb-command exec-path path (append extra-env (cadr (assoc 'configure-env configuration)))
               (concat "eval " mwb-emacs-source "/configure" " \""
                       (mapconcat 'identity (cadr (assoc 'configure-args configuration)) " ")
                       " --prefix="
                       (mwb-mingw-convert-path prefix) "\"")
               configuration-dir))

(defun mwb-make (exec-path path extra-env configuration-dir)
  (mwb-command exec-path path extra-env
               (concat "make -j " (number-to-string mwb-make-threads))
               configuration-dir))

(defun mwb-make-install (exec-path path extra-env configuration configuration-dir)
  (mwb-command exec-path path extra-env
               (concat "make install"
                       (when (cadr (assoc 'install-strip configuration))
                         "-strip"))
               configuration-dir))

(defun mwb-copy-libraries (libraries-dir destination-dir)
  "Copies each library from MWB-DYNAMIC-LIBRARIES that exists in LIBRARIES-DIR
into DESTINATION-DIR."
  (dolist (library mwb-dynamic-libraries)
    (dolist (library-file (directory-files libraries-dir t library))
      (copy-file library-file (concat  destination-dir "/bin/") t))))

(defun mwb-command (exec-path path extra-env command &optional dir)
  "Execute shell command COMMAND. Global exec-path is replaced with EXEC-PATH.
EXTRA-ENV is added to process-environment passed to the process.  Path on it
is replaced with PATH.  If DIR is passed, the command is ran in that directory."
  (let* ((shell-file-name "bash")
         ;; By using lexical binding we can use setenv and getenv
         ;; on our local version of process-environment.
         (process-environment (append process-environment extra-env))
         (process-environment (progn (setenv "PATH" path)
                                     ;; Default LANG may screw up automake
                                     ;; version detection in autogen.sh.
                                     (setenv "LANG" "")
                                     process-environment))
         (exec-path exec-path))
    (when dir
      (when (not (file-exists-p dir))
        (mkdir dir t))
      (cd dir))
    (process-file-shell-command command nil "mwb")))

;; * MinGW
(defun mwb-mingw-get-exec-path ()
    (list (concat mwb-mingw-directory "/msys/1.0/bin/")))


(defun mwb-mingw-convert-path (path)
  "Convert path PATH to MinGW format.  c:/Emacs would become /c/Emacs."
  (concat "/" (replace-regexp-in-string ":" "" path)))

(defun mwb-mingw-get-path ()
  (concat "/usr/local/bin/:/mingw/bin/:/bin/:"
          (mwb-mingw-convert-path (concat mwb-mingw-directory "/mingw32/bin/")) ":"
          (mwb-mingw-convert-path (concat mwb-mingw-directory "/bin/"))))

(defun mwb-mingw-get-extra-env ()
  '())

(defun mwb-mingw-get-libraries-dir ()
  (concat mwb-mingw-directory "/bin/"))

(defun mwb-mingw-ensure ()
  "Ensure we have MinGW installed."
  ;; HACK: need a better check here.
  (when (not (file-exists-p (concat mwb-mingw-directory "/msys/1.0/bin/bash.exe")))
    (mwb-mingw-install)))

(defun mwb-mingw-install ()
  (mwb-mingw-install-packages)
  (rename-file (concat mwb-mingw-directory "/msys/1.0/etc/" "fstab.sample")
               (concat mwb-mingw-directory "/msys/1.0/etc/" "fstab")))

(defun mwb-mingw-install-packages ()
  "Install all packages from mwb-mingw-packages and mwb-msys-packages into mwb-mingw-directory."
  (dolist (source-packages mwb-mingw-packages)
    (mwb-mingw-install-packages-from-source source-packages mwb-mingw-directory))
  (dolist (source-packages mwb-msys-packages)
    (mwb-mingw-install-packages-from-source source-packages (concat mwb-mingw-directory "/msys/1.0/"))))

(defun mwb-mingw-install-packages-from-source (source-packages directory)
  "Install packages from a list SOURCE-PACKAGES into direcotry DIRECTORY.
SOURCE-PACKAGES should have the common download path as car and the list of packages as cdr."
  (dolist (package (cadr source-packages))
    (mwb-mingw-install-package (concat (car source-packages) package)
                               directory)))

(defun mwb-mingw-install-package (package path)
  "Install PACKAGE by downloading it and puts it into PATH."
  (mwb-7z-extract (mwb-wget-download-file package) path t))

;; * Msys2
(defcustom mwb-msys2-x32-force nil
  "Forcefully install 32 bit version of msys2 on 64 it machines."
  :group 'mwb)

(defun mwb-msys2-install ()
  (let* ((install-x32 (if (or mwb-msys2-x32-force
                             (not (mwb-windows-is-64-bit))) t nil))
         (dir (if install-x32 mwb-msys2-x32-directory mwb-msys2-x64-directory))
         (dist (if install-x32 mwb-msys2-x32-dist mwb-msys2-x64-dist)))
    (mwb-7z-extract (mwb-wget-download-file dist)
                    (mapconcat 'identity (butlast (split-string dir "/")) "/") t)
    (start-process-shell-command "msys2" "mwb" (concat dir "/msys2_shell.cmd"))
    (sleep-for 30)))

(defun mwb-msys2-install-packages (exec-path path extra-env packages)
  (dolist (package packages)
    (mwb-msys2-install-package exec-path path extra-env package)))

(defun mwb-msys2-install-package (exec-path path extra-env package)
  (mwb-command exec-path path extra-env
               (concat "pacman -S --noconfirm --needed " package)))

(defun mwb-windows-is-64-bit ()
  "Determines whether Windows is 64 bit."
  ;; HACK, but should generally work.
  (file-exists-p "c:/Program Files (x86)/"))

(defun mwb-msys2-get-common-path ()
  (concat "/usr/local/bin:/usr/bin:"
          "/bin:/c/Windows/System32:/c/Windows:"
          "/c/Windows/System32/Mwbem:/c/Windows/System32/WindowsPowerShell/v1.0/:"
          "/usr/bin/site_perl:/usr/bin/vendor_perl:/usr/bin/core_perl:/"))

(defun mwb-msys2-get-exec-path ()
  (list (concat (mwb-msys2-get-current-directory)  "/usr/bin/")))

(defun mwb-msys2-get-libraries-dir ()
  (concat (mwb-msys2-get-current-directory)
          (if (or mwb-msys2-x32-force
                  (not (mwb-windows-is-64-bit))) "/mingw32/bin/"
            "/mingw64/bin/")))

(defun mwb-msys2-get-current-directory ()
  "Return directory for currently installed msys"
  (if (or mwb-msys2-x32-force
          (not (mwb-windows-is-64-bit))) mwb-msys2-x32-directory
    mwb-msys2-x64-directory))

;; ** x32
(defun mwb-msys2-x32-get-path ()
  (concat "/mingw32/bin:" (mwb-msys2-get-common-path)))

(defun mwb-msys2-x32-get-extra-env ()
  '("MSYSTEM=MINGW32" "PKG_CONFIG_PATH=/mingw32/lib/pkgconfig"))

(defun mwb-msys2-x32-ensure ()
  ;; Need a much better check here...
  (when (not (file-exists-p (mwb-msys2-get-current-directory)))
    (mwb-msys2-install))
  (mwb-msys2-install-packages (mwb-msys2-get-exec-path) (mwb-msys2-x32-get-path)
                              (mwb-msys2-x32-get-extra-env) mwb-msys2-x32-packages))

;; ** x64
(defun mwb-msys2-x64-get-path ()
  (concat "/mingw64/bin:" (mwb-msys2-get-common-path)))


(defun mwb-msys2-x64-get-extra-env ()
  '("MSYSTEM=MINGW64" "PKG_CONFIG_PATH=/mingw64/lib/pkgconfig"))

(defun mwb-msys2-x64-ensure ()
  ;; Need a much better check here...
  (when (not (file-exists-p mwb-msys2-x64-directory))
    (mwb-msys2-install))
  (mwb-msys2-install-packages (mwb-msys2-get-exec-path) (mwb-msys2-x64-get-path)
                              (mwb-msys2-x64-get-extra-env) mwb-msys2-x64-packages))

;; * 7zip
(defun mwb-7z-extract (file path &optional keep)
  "Recursively extracts archives."
  (let* ((file-list (reverse (split-string file "\\.")))
         (recurse (member (cadr file-list) mwb-7z-archives-to-recurse))
         (extract-path (if recurse (file-name-directory file) path))
         (new-file (substring file 0 (- (+ 1 (string-width (car file-list)))))))
    (process-file-shell-command
     (concat "\"" (mwb-get-7z) "\" x " file " -aoa -o"
             (replace-regexp-in-string "/" "\\\\" extract-path)) nil "mwb")
        (when (not keep) (delete-file file))
    (when recurse (mwb-7z-extract new-file path))))

(defvar mwb-7z-archives-to-recurse '("tar" "lzma"))

(defun mwb-get-7z ()
  "Ensure we have 7zip on our path for unarchiving."
  (or (executable-find "7z.exe")
      (locate-file "7z.exe" mwb-7z-paths)
      (mwb-install-7z)))

(defun mwb-install-7z ()
  (let ((setup-file (mwb-wget-download-file (if (mwb-windows-is-64-bit)
                                                mwb-7z-x64-setup
                                              mwb-7z-x32-setup)))
        (setup-dir (concat "\""
                           (replace-regexp-in-string
                            "/"
                            "\\\\"
                            "c:/Program Files/7-Zip/")
                           "\"")))
  (process-file-shell-command
   (concat setup-file " /S  /D=" setup-dir) nil "mwb")
  (locate-file "7z.exe" mwb-7z-paths)))

(defvar mwb-7z-paths '("c:/Program Files/7-Zip/" "c:/Program Files (x86)/7-Zip/"))

(defvar mwb-7z-x64-setup "http://www.7-zip.org/a/7z1602-x64.exe")

(defvar mwb-7z-x32-setup "http://www.7-zip.org/a/7z1602.exe")

;; * Wget
(defun mwb-wget-download-file (file)
  (let* ((local-file (concat mwb-wget-download-directory "/"
                             (car (reverse (split-string file "/")))))
         (wget (mwb-wget-get))
         (check-certificate (if (mwb-wget-check-certificate)
                                "--no-check-certificate" "")))
    (when (not (file-exists-p local-file))
      (when (not (file-exists-p mwb-wget-download-directory))
        (mkdir mwb-wget-download-directory t))
      (cd mwb-wget-download-directory)
      (process-file-shell-command
       (concat "\"" wget
               "\" " check-certificate " " file) nil "mwb"))
    local-file))

(defun mwb-wget-get ()
  "Ensure we have wget on our path for downloading dependencies.
Wget works nicely, since it's able to get stuff from sourceforge."
  (let ((wget (or (executable-find "wget.exe")
              (locate-file "wget.exe" mwb-wget-paths)
              (error "Wget not found."))))
    wget))

(defun mwb-wget-check-certificate ()
  "Whether to pass --no-check-certificate flag to wget.
Needed for GnuWin version, because it fails for https."
  (let ((wget (mwb-wget-get)))
    (if (string-match "GnuWin32" wget)
        t
      nil)))

(defcustom mwb-wget-paths '("c:/Program Files (x86)/GnuWin32/bin/" "c:/Program Files/GnuWin32/bin/")
  "*Paths to search for wget."
  :group 'mwb)

(provide 'ms-windows-builder)
;;; ms-windows-builder.el ends here
