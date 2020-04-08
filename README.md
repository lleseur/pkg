# yoshi-utils - Personnal utilities repository

This repository contain personnal packages and a small package manager.
The package manager is pkg.py and is made to install/remove/update packages from this repository.

The purpose of this repository is to allow me to easilly synchronize packages between different machines.
This also allow me to update a package from any machine using this repository.
The majority of the packages here are simple scripts to make my life easier and are only relevant on my personnal systems.

## pkg.py

This small package manager can install, reinstall, update, uninstall packages on any supported systems.
Supported system vary according to the purpose of the package
(e.g. the package to create the initramfs for a specific machine will only be made compatible for this machine).

The syntax of this package manager is inspired by the Portage package manager used by Gentoo.

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
`./pkg.py --ask --update @world`  
To install (or reinstall) the package "sys-app/remount", run:
`./pkg.py --ask sys-app/remount`  
To uninstall the package "sys-app/remount", run:
`./pkg.py --ask --remove sys-app/remount`

