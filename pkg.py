#!/usr/bin/env python3
# This script will manage packages installed from this repository
# This script takes options folowed by a list of packages or sets
# Packages are a string in the "category/package" format (e.g. app-editor/nano)
# Sets starts with '@', they are a group of package, there is currently only the
# @world set representing the list of installed packages

import sys, os, argparse, pathlib, subprocess, re

"""
   accessFile() - Try accessing a file, creates it if necessary
   path:          File path to access
   Return: True if sucess, False if failure
"""
def accessFile(path, verbose):
	if os.path.isfile(path):
		return True
	# Try creating the file
	if verbose: print(f"Creating file {path}")
	try:
		if path.rfind("/") != -1:
			pathlib.Path(path[0:path.rfind("/")]).mkdir(parents=True, exist_ok=True)
		pathlib.Path(path).touch(exist_ok=True)
	except IOError:
		return False
	return True

"""
   sync() - Synchronize the repository using git
   Return: True if success, False if failure
"""
def sync():
	try:
		subprocess.check_call(["git", "pull"])
	except subprocess.CalledProcessError:
		print(f"Error: Could not sync the repository")
		return False
	return True

"""
   cd(pkg) - Change directory
   pkg:      Package to cd to
   Return: True if success, False if failure
"""
def cd(pkg):
	try:
		os.chdir(pkg)
	except FileNotFoundError:
		print(f"Error: Could not build {pkg}: package not in the repository")
		return False
	except PermissionError:
		print(f"Error: Could not build {pkg}: permission denied")
		return False
	return True

"""
   build() - Build the program from current directory
   Return: True if success, False if failure
"""
def build():
	try:
		subprocess.check_call(["../../make.sh"])
	except FileNotFoundError:
		return True
	except (subprocess.CalledProcessError, PermissionError):
		return False
	return True

"""
   install() - Install the program from current directory
   Return: True if success, False if failure
"""
def install():
	try:
		subprocess.check_call(["../../make.sh", "install"])
	except FileNotFoundError:
		return True
	except (subprocess.CalledProcessError, PermissionError):
		return False
	return True

"""
   remove() - Install the program from current directory
   Return: True if success, False if failure
"""
def remove():
	try:
		subprocess.check_call(["../../make.sh", "remove"])
	except FileNotFoundError:
		return True
	except (subprocess.CalledProcessError, PermissionError):
		return False
	return True

"""
   isUpdate() - Check if package has been updated
   pkg:            Package to check for update
   world:          List of [pkg, hash] for each installed packages
   Return: True if update available, False if none
"""
def isUpdate(pkg, world):
	diff = subprocess.check_output(["git", "diff", "--name-only", world[pkg], "HEAD"]).decode().split("\n")
	for filepath in diff:
		if re.search(pkg, filepath):
			return True
	return False

"""
   writeWorld() - Write world to file
   world:         World to write
   filepath       File to write world into
   verbose        Bool indicating to show verbose output
   Return: Boolean for success
"""
def writeWorld(world, filepath, verbose):
	if verbose:
		print(f"Writing world to {filepath}")
	try:
		with open(filepath, "w", encoding="utf8") as f:
			for pkg in world:
				f.write(pkg + " " + world[pkg] + "\n")
	except IOError:
		return False
	return True

"""
   die() - Write world and die
   world   World to write
   cause   String containing the cause of failure
"""
def die(world, cause):
	if not(writeWorld(world, "world.dat", True)):
		print("FATAL: Failed to write to world file", file=sys.stderr)
	sys.exit(cause)

# Parse command line
parser = argparse.ArgumentParser(description="Manages packages from this repository")
parser.add_argument("-p", "--pretend", action="store_true", help="Display what would be done, do not do anything")
parser.add_argument("-v", "--verbose", action="store_true", help="Run in verbose mode")
parser.add_argument("-S", "--sync", action="store_true", help="Sync this repository")
parser.add_argument("-a", "--ask", action="store_true", help="Ask for confirmation before doing anything to the packages")
parser.add_argument("-u", "--update", action="store_true", help="Update packages")
parser.add_argument("-r", "--remove", action="store_true", help="Uninstall packages")
parser.add_argument("--debug", action="store_true", help="Print debug informations")
parser.add_argument("package", nargs="*")
args = parser.parse_args()

# Change working directory to repository
repo = os.path.abspath(os.path.dirname(sys.argv[0]))
os.chdir(repo)

# Read world file
world = {}
if not(accessFile("world.dat", args.verbose)):
	sys.exit(f"Fatal: Could not access world file {os.getcwd()}/world.dat")
try:
	with open("world.dat", "r", encoding="utf8") as f:
		for pkg in f:
			if not(pkg): continue
			world[pkg.split()[0]] = pkg.split()[1]
except IOError:
	sys.exit(f"Fatal: Could not read world file {os.getcwd()}/world.dat")

# If debug, print world
if args.debug:
	print("World:")
	for pkg in world: print(pkg, world[pkg])


# Sync
if args.verbose:
	commit = subprocess.check_output(["git", "rev-parse", "--verify", "HEAD"]).decode().strip()
	date = subprocess.check_output(["git", "show", "-s", "--format=\"%ci\"", commit]).decode().strip()
	version = "Current repository version: " + commit + "\nCurrent repository date: " + date + "\n"
	print(version)
if not(args.pretend) and args.sync and not(sync()):
	sys.exit("Failed to sync repository")
commit = subprocess.check_output(["git", "rev-parse", "--verify", "HEAD"]).decode().strip()
date = subprocess.check_output(["git", "show", "-s", "--format=\"%ci\"", commit]).decode().strip()
if args.sync:
	version = "Current repository version: " + commit + "\nCurrent repository date: " + date + "\n"
	print(version)

# Get set pkgs of package to handle, sets are packages starting with @, e.g. @world
pkgs = set()
for pkg in args.package:
	if pkg[0] != '@' and not(os.path.isdir(pkg)):
		sys.exit(f"{pkg} does not exists in this repository")
	elif pkg[0] != '@':
		pkgs.add(pkg)
	elif pkg == "@world":
		for p in world: pkgs.add(p)
	else:
		sys.exit(f"Unknown set {pkg}")

# If update flag enabled, remove packages that are already updated
if args.update:
	for pkg in pkgs.copy():
		if not(isUpdate(pkg, world)):
			pkgs.remove(pkg)

# If remove flag enabled, remove packages that are not installed
if args.remove:
	for pkg in pkgs.copy():
		if pkg not in world:
			pkgs.remove(pkg)

# Print report of what will be done
print("Here is what will be installed in order:")
for pkg in pkgs:
	if pkg in world:
		if args.remove:
			s = "D"
		elif isUpdate(pkg, world):
			s = "U"
		else:
			s = "R"
	else:
		s = "N"
	print(f"{s}\t{pkg}")

# Check for pretend flag
if args.ask and not(args.pretend):
	ask = input("\nConfirm [yes/no] ? ")
	if ask.lower() not in ["y", "yes"]:
		if ask.lower() not in ["n", "no"]:
			sys.exit(f"Unexpected answer {ask}")
		args.pretend = True

# Install or reinstall packages
print("\nInstalling packages...")
if not(args.pretend):
	for pkg in pkgs:
		print(f"Installing {pkg}")
		if not(cd(pkg)): die(world, f"Failed to access package directory for {pkg}")
		if not(args.remove):
			if not(build()): die(world, f"Failed to build package {pkg}")
		if pkg in world:
			if not(remove()): die(world, f"Failed to remove package {pkg}")
		if not(args.remove):
			if not(install()): die(world, f"Failed to install package {pkg}")
		if args.remove:
			del world[pkg]
		else:
			world[pkg] = commit
		os.chdir(repo)
		if not(writeWorld(world, "world.dat", args.debug)):
			print(f"Error: Failed to update world file after installing {pkg}", file=sys.stderr)

# Write world file
if not(writeWorld(world, "world.dat", args.verbose)):
	sys.exit("FATAL: Failed to write to world file")

print("\nAll done.")

