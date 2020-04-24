# yoshi-utils - Personnal utilities repository

This repository contain personnal packages and a small package manager.
The package manager is pkg and is made to install/remove/update packages from this repository.

The purpose of this repository is to allow me to easilly synchronize packages between different machines.
This also allow me to update a package from any machine using this repository.
The majority of the packages here are simple scripts to make my life easier and are only relevant on my personnal systems.

## pkg

This small package manager can install, reinstall, update, uninstall packages on any supported systems.
Supported system vary according to the purpose of the package
(e.g. the package to create the initramfs for a specific machine will only be made compatible for this machine).

The syntax of this package manager is inspired by the Portage package manager used by Gentoo.

This program shound **NOT** be called as root.

### Verbosity options

 * `--verbose`, `-v`: Output verbose informations
 * `--debug`: Output debug informations

### Action options

 * `--update`, `-u`: Update if any update is available
 * `--remove`, `-r`: Uninstall
 * `--sync`, `-S`: Update the repository (with `git pull`)

### Security options

 * `--ask`, `-a`: Ask for confirmation before doing any modification to the system
 * `--pretend`, `-p`: Don't do any thing to the system, just show what would be done (dry-run)

### Packages and sets

A package is in the format "category/name" (e.g. app-editor/nano),
the packages can be found in this repository under the same structure "category/name".

A set is a list of packages, their name starts with an '@'.
There currently is only one set which is "@world", it is a list of all the packages installed.

### Examples

To update all installed packages, run:
`./pkg --ask --update @world`  
To install (or reinstall) the package "sys-app/remount", run:
`./pkg --ask sys-app/remount`  
To uninstall the package "sys-app/remount", run:
`./pkg --ask --remove sys-app/remount`

## make

This script is a package installer placing itself between the package manager and the package installation process.
The purpose of this script is to call the package installation process (e.g. Makefile, ./install.sh script).

### Syntaxe

Its syntaxe is `./make [make|install|remove]`.
 * `make`, `build`, `compile`, nothing: Builds the program
 * `install`: Installs the program on the system
 * `remove`: Removes the program from the system

### Package specific configuration

./make have 3 functions: `build`, `install`, `remove` that are called according to the arguments received.
By default, those 3 functions will call respectively `build_default`, `install_default`, `remove_default`.
This behavior can be overriden by redefining the functions in a `makerc` file placed in the package's directory.
Before calling any function, `makerc` is sourced by ./make.
The script will also source the `env.conf` file from the repository's root directory,
and export all the variables defined in it.

Default functions available:
 * `build_default` if a Makefile is found, it will call `make`, otherwist it will exit successfully.
 * `install_default` will call `make install` if a Makefile exists, otherwise it will exit successfully.
   If the variable "ELEVATED_INSTALL" is defined, it will run `make install` as root.
 * `remove_default` will call `make uninstall` if a Makefile exists, otherwise it will exit successfully.
   If the variable "ELEVATED_REMOVE" is defined, it will run `make uninstall` as root.
 * `die` will exit unsuccessfylly with an error message given in argument.
 * `elevate` will run the command given in arguments as root. It works like sudo.
   It will check if it already has root privileges, otherwise it will try to use `sudo` then `su`.

### Files used

Here, we define `$ROOT` as the root folder of the repository,
and `$PKG` as the folder containing the package.
./make will use multiple files if they exists:
 * `$ROOT/env.conf` is sourced by the script to get some environment variables.
   It will then export all variables defined in threre.
   The script will also use the `MAKEOPTS` and `DESTDIR` if defined,
   this variable will be used as an argument list to append to the `make` command (e.g. "-j4 -l4").
 * `$PKG/makerc` is sourced by ./make before calling the `build`, `install`, or `remove` functions.
   This is where a package should redefine those functions.
   This is also where a package should define the variables it needs (e.g. ELEVATED_INSTALL, ELEVATED_REMOVE).

