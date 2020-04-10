#!/bin/sh
# This script is the standard script used for build, install, removal of programs
#
# It uses the 3 functions "build" for building, "install" for installing, "remove"
# to uninstall a program
# The script will source the ./makerc file from the current package, the file is located
# in "category/package/makerc" and will override the default functions
# The default functions are still available as function_default (e.g. install_default)
# The function "die" is available to stop the process at any point sending an error message
# The function "elevate" is available to run a command as root (using sudo or su)
#
# The functions install_default and remove_default will be run as root if the variables
# ELEVATED_INSTALL or ELEVATED_REMOVE are not empty

die()
{
	echo "$@" 1>&2
	exit 1
}

# elevate() - Run "$@" with elevated privileges
elevate()
{
	[ "$(id -u)" = "0" ] && "$@" && return 0
	command -v sudo 1>/dev/null 2>/dev/null && echo "Requesting elevated privileges using sudo" && sudo "$@" && return 0
	echo "Requesting elevated privileges using su" && su -c "$*" root && return 0
	return 1
}

build_default()
{
	# Load environment variable from env.conf
	if [ -f "../../env.conf" ]; then
		. "../../env.conf"
		for vname in CC CXX CTARGET CFLAGS CXXFLAGS CPPFLAGS FCFLAGS FFLAGS LDFLAGS; do
			export "${vname}"
		done
	fi

	# Try default configure and build process
	if [ -x ./configure ]; then
		./configure || die "Configure failed"
	fi
	if [ -f Makefile ] || [ -f makefile ] || [ -f GNUmakefile ]; then
		eval make MAKEOPTS="${MAKEOPTS}" || die "Make failed"
	fi

	return 0
}

install_default()
{
	# Try default install process
	if [ -f Makefile ] || [ -f makefile ] || [ -f GNUmakefile ]; then
		if [ -n "${ELEVATED_INSTALL}" ]; then
			elevate make DESTDIR="${DESTDIR}" install || die "Make install failed"
		else
			make DESTDIR="${DESTDIR}" install || die "Make install failed"
		fi
	fi

	return 0
}

remove_default()
{
	# Try defaut install process
	if [ -f Makefile ] || [ -f makefile ] || [ -f GNUmakefile ]; then
		if [ -n "${ELEVATED_REMOVE}" ]; then
			elevate make DESTDIR="${DESTDIR}" uninstall || die "Make uninstall failed"
		else
			make DESTDIR="${DESTDIR}" uninstall || die "Make uninstall failed"
		fi
	fi

	return 0
}


build() { build_default; }
install() { install_default; }
remove() { remove_default; }

# Read makerc
if [ -f "./makerc" ]; then
	. "./makerc"
fi

# Parse arguments
[ $# -eq 0 ] && build || die "Build failed"
for arg in "$@"; do
	case "$arg" in
	""|all|make|build)
		build || die "Build failed"
		;;
	remove)
		remove || die "Remove failed"
		;;
	install)
		install || die "Install failed"
		;;
	*)
		die "Error: Invalid argument: $arg"
		;;
	esac
done
exit 0

