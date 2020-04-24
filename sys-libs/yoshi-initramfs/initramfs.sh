# yoshi-initramfs.sh
#
# This shell script is a library of functions used by yoshi-initramfs.
# All informations, warnings and errors are outputed to stderr, this
# allow the possibility to output the initramfs to stdout.
#
# Environment variables:
#   DRYRUN        If set, don't create the final cpio archive
#   OUTPUT        Override the cpio archive destination
#                 If set to '-', the archive is outputed to stdout
#   QUIET         If set, don't print information messages
#   VERBOSE       If set, will print more messages
#   TMPDIR        Defines the temporary directory where the initramfs is built,
#                 defaults to /tmp/yoshi-initramfs
#

# Define default values for global variables
[ -z "${TMPDIR}" ] && TMPDIR="/tmp/yoshi-initramfs"

#
# info() - Print an information message
#   $@        Messages to print
#

info()
{
	[ -n "${QUIET}" ] && return 0
	for arg in "$@"; do
		echo "${arg}" 1>&2
	done
}

#
# warn() - Print a warning message
#   $@        Messages to print
#

warn()
{
	for arg in "$@"; do
		echo "Warning: ${arg}" 1>&2
	done
}

#
# die() - Print an error message and die
#   $@        Messages to print
#

die()
{
	for arg in "$@"; do
		echo "Error: ${arg}" 1>&2
	done
	exit 1
}

#
# mklayout() - Create the base layout for initramfs
# Warning: If the TMPDIR directory exists, it will be overwritten
# The layout consists of bin, dev, etc, lib, (lib32), (lib64), mnt/root, proc,
# root, run, sbin, sys
#

mklayout()
{
	set -ue
	[ -n "${TMPDIR}" ] || die "mklayout: No TMPDIR set, cannot continue"

	# Create directory
	[ -e "${TMPDIR}" ] && die "mklayout: Cannot create ${TMPDIR}, file exists"
	mkdir "${TMPDIR}"

	# Create layout
	mkdir -m 755 "${TMPDIR}/bin"
	mkdir -m 755 "${TMPDIR}/dev"
	mkdir -m 755 "${TMPDIR}/etc"
	mkdir -m 755 "${TMPDIR}/lib"
	[ -d "/lib64" ] && mkdir -m 755 "${TMPDIR}/lib64"
	[ -d "/lib32" ] && mkdir -m 755 "${TMPDIR}/lib32"
	mkdir -m 755 "${TMPDIR}/mnt"
	mkdir -m 755 "${TMPDIR}/mnt/root"
	mkdir -m 555 "${TMPDIR}/proc"
	mkdir -m 700 "${TMPDIR}/root"
	mkdir -m 755 "${TMPDIR}/run"
	mkdir -m 755 "${TMPDIR}/sbin"
	mkdir -m 555 "${TMPDIR}/sys"

	# Create nodes for console
	mknod -m 600 "${TMPDIR}/dev/console" c 5 1
	mknod -m 666 "${TMPDIR}/dev/tty" c 5 0
	mknod -m 666 "${TMPDIR}/dev/null" c 1 3
	# TODO: Check if necessary
	mknod -m 620 "${TMPDIR}/dev/tty0" c 4 0
}

#
# copyfile() - Copy a file to TMPDIR
#   $1        File to copy ('-' for stdin)
#   $2        Destination name (defaults to the same as source, without /usr or /usr/local)
# The filepath can be relative or absolute. It it is '-' (stdin), a destination
# name is required.
#

copyfile()
{
	set -ue
	filepath="$1"
	destpath="$2"

	if [ "${filepath}" != '-' ]; then
		# Get absolute path and check if it exists
		abspath="$(realpath "${filepath}")"
		[ -f "${abspath}" ] || die "copyfile: Failed to copy ${filepath}, file ${abspath} not found"

		# Get destination and make sure it is part of the base layout
		# of the initramfs, otherwise change the directory:
		# /home/[username]/ -> /root/
		# /usr/local/ -> /
		# /usr/ -> /
		[ -z "${destpath}" ] && destpath="$(echo "${abspath}" | sed -e 's/\/home\/[^/]*\//\/root\//' -e 's/\/usr\/local\//\//' -e 's/\/usr\//\//')" || true
	fi

	# Check the destination is valid: destination is an absolute path,
	# and parent directory exists in base layout (/bin, ...)
	[ "$(echo "${destpath}" | cut -c 1)" = '/' ] || die "copyfile: Failed to copy ${filepath}, destination ${destpath} is a relative path"
	[ -d "${TMPDIR}/$(echo "${destpath}" | cut -d '/' -f 2)" ] && warn "copyfile: Creating base directory" "/$(echo "${destpath}" | cut -d '/' -f 2)\"" "for file \"${filepath}"

	# Create destination directories and copy file
	mkdir -p "${TMPDIR}$(dirname -- "${destpath}")"
	if [ "${filename}" != '-' ]; then
		cp -L "${abspath}" "${TMPDIR}${destpath}"
	else
		cat - >"${TMPDIR}${destpath}"
	fi
}

#
# copyexec() - Copy executables file and all the libraries they need to TMPDIR
#   $1        Executable file
#   $2        Destination name (defaults to the same as source, without /usr or /usr/local)
# The filename can be in PATH, relative, or absolute
#

copyexec()
{
	set -ue
	filename="$1"
	destpath="$2"

	# Find file path
	if [ -x "${filename}" ]; then
		# Relative or absolute path, nothing to do
		filepath="${filename}"
	else
		# Search in every PATH directories
		for directory in $(echo "${PATH}" | tr ':' '\n'); do
			[ -d "${directory}" ] && filefound="$(find "${directory}" -maxdepth 1 '(' -type f -o -type l ')' -executable -name "${filename}")" || true
			[ -x "${filefound}" ] && filepath="${filefound}" && break || continue
		done
	fi

	# Check the file exists and is executable
	[ -x "${filepath}" ] || die "copyexec: Failed to copy ${filename}, file ${filepath} is not executable"

	# Copy inecessaries libraries to TMPDIR
	if lddtree "${filepath}" 1>/dev/null 2>&1; then
		# The file is an elf binary, search libraries
		for lib in $(lddtree --list "${filepath}"); do
			copyfile "${lib}"
		done
	fi

	# Copy the file itself
	copyfile "${filepath}" "${destpath}"
}

#
# copylib() - Copy a library file to TMPDIR
#   $1        Librarie to copy
#   $2        Destination name (defaults to the same as source, without /usr or /usr/local)
# The library can be an absolute/relative path, or the name of the library.
# In the later case, the library will be searched in the directories listed in
# /etc/ld.so.conf, /etc/ld.so.conf.d/*.conf, LD_LIBRARY_PATH
#

copylib()
{
	set -ue
	libname="$1"
	destpath="$2"

	# Find lib path
	if [ -f "${libname}" ]; then
		# Relative or absolute path, nothing to do
		libpath="${libpath}"
	else
		# Parse LD config files and LD_LIBRARY_PATH and search in all directories
		for directory in $(cat /etc/ld.so.conf /etc/ld.so.conf.d/*.conf) $(echo "${LD_LIBRARY_PATH}" | tr ':' '\n'); do
			[ -d "${directory}" ] && libfound="$(find "${directory}" -maxdepth 1 '(' -type f -o -type l ')' -name "${libname}")" || true
			[ -f "${libfound}" ] && libpath="${libfound}" && break || continue
		done
	fi

	# Check the file exists and copy to TMPDIR
	[ -f "${libpath}" ] && copyfile "${libpath}" "${destpath}" || die "copylib: Failed to copy ${libname}, file ${libpath} does not exists"
}

#
# setperms() - Make a file in TMPDIR executable
#   $1        Permissions to set
#   $2        File path to change mode (relative to TMPDIR)
#

setperms()
{
	set -ue
	chmod "$1" "${TMPDIR}${2}"
}

#
# busybox_install() - Install busybox links on the initramfs
#

busybox_install()
{
	set -ue
	for applet in $(busybox --list-full); do
		[ -e "${TMPDIR}/${applet}" ] || ln -s '/bin/busybox' "${TMPDIR}/${applet}"
	done
}

#
# initramfs_build() - Create the initramfs cpio archive and output it to stdout
#

initramfs_build()
{
	set -ue
	oldpwd="$(pwd)"
	cd "${TMPDIR}"
	find . -print0 | cpio --null --create --format=newc "${VERBOSE:+--verbose}"
	cd "${oldpwd}"
}

#
# initramfs_install() - Install the initramfs in the system
# If OUTPUT is not set, the initramfs is copied to /boot
# If OUTPUT is '-', the initramfs is outputted to stdout
#

initramfs_install()
{
	[ -n "${DRYRUN}" ] && warn "initramfs_install: Dry run, not installing, not cleaning up TMPDIR" && return 0
	[ -z "${OUTPUT}" ] && output='/usr/src/initramfs.cpio' && copy_boot=y || output="${OUTPUT}"
	[ "${output}" = '-' ] && output="$(tty)" && output_stdout=y

	initramfs_build 1>"${output}"
	[ -z "${output_stdout}" ] && chmod 0600 "${output}"
	if [ -n "${copy_boot}" ]; then
		# Copy to /boot and compress it
		info "initramfs_install: Installing initramfs to /boot"
		mount -o remount,rw /boot
		[ -f '/boot/initramfs.cpio.xz' ] && mv '/boot/initramfs.cpio.xz' '/boot/initramfs.cpio.xz.bak'
		xz -zkc "${output}" 1>'/boot/initramfs.cpio.xz'
		chmod 0600 '/boot/initramfs.cpio.xz'
		mount -o remount,ro /boot || warn 'initramfs_install: Could not remount /boot read-only'

		# Cleanup kernel objects containing old initramfs
		info "initramfs_install: Cleaning up kernel objects"
		for kfile in ./usr/initramfs_data.cpio*; do
			[ -e "${kfile}" ] && rm -f "${kfile}"
		done
	fi

	# Cleanup TMPDIR
	rm -rf "${TMPDIR}"
}

