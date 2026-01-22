#!/usr/bin/python3

# CCPM Build script
# Copyright (C) 2026  Alexandre Leconte <aleconte@dwightstudio.fr>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

import argparse
import base64
import binascii
import hashlib
import json
import os
import zlib

PACKAGES_ROOT_SRC_DIR = "./packages"
PACKAGES_SRC_DIR = "source"
MANIFEST_FILE = "manifest.json"
MANIFEST_FIELDS = [
    "description",
    "license",
    "authors",
    "maintainers",
    "version",
    "dependencies",
]
PACKAGES_POOL_DIR = "./pool"
INDEX_FILE = "index.json"

# Command-line arguments parser
parser = argparse.ArgumentParser(description="CCPM build tool")
parser.add_argument("-r", "--repair", action="store_true", help="Repair package index")


def get_source_packages():
    return map(lambda entry: entry.name, os.scandir(PACKAGES_ROOT_SRC_DIR))


def get_built_packages():
    rtn = {}
    entries = filter(
        lambda entry: entry.name != INDEX_FILE and not entry.is_dir(),
        os.scandir(PACKAGES_POOL_DIR),
    )

    for entry in entries:
        name, version = entry.name[:-4].split(".", maxsplit=1)

        if name in rtn:
            rtn[name].append(version)
        else:
            rtn[name] = [version]

    return rtn


def get_package_files(name):
    path = f"{PACKAGES_ROOT_SRC_DIR}/{name}/{PACKAGES_SRC_DIR}/"
    rtn = []

    for root, _, files in os.walk(path):
        root_path = "" if root == path else root.removeprefix(path) + "/"
        rtn.extend(map(lambda file: root_path + file, files))

    return rtn


def get_manifest(name):
    path = f"{PACKAGES_ROOT_SRC_DIR}/{name}/{MANIFEST_FILE}"

    print("[i] Reading manifest")

    try:
        with open(path) as file:
            manifest = json.load(file)

            for key in MANIFEST_FIELDS:
                if key not in manifest:
                    print(f"[!] Package manifest is incomplete (missing '{key}')")

            return manifest
    except FileNotFoundError:
        print("[!] Package is invalid (no manifest)")
    except json.JSONDecodeError:
        print("[!] Package is invalid (unreadable manifest)")


def build_package(name):
    manifest = get_manifest(name)

    if manifest is not None:
        manifest["files"] = {}

        for path in get_package_files(name):
            print(f"[+] {path}")
            with open(
                f"{PACKAGES_ROOT_SRC_DIR}/{name}/{PACKAGES_SRC_DIR}/{path}"
            ) as file:
                content = file.read()

                manifest["files"][path] = {
                    "content": content,
                    "digest": hashlib.sha256(content.encode()).hexdigest(),
                }

        return manifest


def compress(package):
    return base64.b64encode(
        zlib.compress(json.dumps(package).encode(), level=zlib.Z_BEST_COMPRESSION)
    )


def build_and_write_package(name):
    print(f"Packaging {name}")
    package = build_package(name)

    if package is not None:
        data = compress(package)

        with open(
            f"{PACKAGES_POOL_DIR}/{name}.{package['version']}.ccp", mode="w"
        ) as file:
            file.write(data.decode())

        return {
            "manifest": package,
            "digest": hashlib.sha256(data).hexdigest(),
        }


def read_package(name, version):
    try:
        with open(f"{PACKAGES_POOL_DIR}/{name}.{version}.ccp", mode="r") as file:
            data = file.read()
            manifest = json.loads(zlib.decompress(base64.b64decode(data)))

            return {
                "manifest": manifest,
                "digest": hashlib.sha256(data.encode()).hexdigest(),
            }
    except FileNotFoundError:
        print(f"[!] Version {version} not found")
        return None
    except json.JSONDecodeError:
        print(f"[!] Version {version} is invalid (no manifest)")
        return None
    except (zlib.error, binascii.Error):
        print(f"[!] Version {version} is invalid (corrupted)")
        return None


def repair_package_index():
    packages = {}

    for name, versions in get_built_packages().items():
        print(f"Indexing {name}")

        for version in versions:
            package = read_package(name, version)

            if package is not None:
                print(f"[+] Version {version}")

                if name not in packages:
                    packages[name] = {
                        "description": "",
                        "versions": {},
                        "latest_version": "",
                    }

                packages[name]["description"] = package["manifest"]["description"]
                packages[name]["versions"][version] = {
                    "digest": package["digest"],
                    "dependencies": package["manifest"]["dependencies"],
                }
                packages[name]["latest_version"] = version

    return packages


if __name__ == "__main__":
    args = parser.parse_args()

    try:
        os.makedirs(PACKAGES_POOL_DIR)
    except:
        pass

    packages = {}

    try:
        if args.repair:
            packages = repair_package_index()
        else:
            if os.path.exists(f"{PACKAGES_POOL_DIR}/{INDEX_FILE}"):
                with open(f"{PACKAGES_POOL_DIR}/{INDEX_FILE}", mode="r") as file:
                    packages = json.loads(file.read())

            for name in get_source_packages():
                package = build_and_write_package(name)

                if package is not None:
                    if name not in packages:
                        packages[name] = {
                            "description": "",
                            "versions": {},
                            "latest_version": "",
                        }

                    packages[name]["description"] = package["manifest"]["description"]
                    packages[name]["versions"][package["manifest"]["version"]] = {
                        "digest": package["digest"],
                        "dependencies": package["manifest"]["dependencies"],
                    }
                    packages[name]["latest_version"] = package["manifest"]["version"]
    except Exception as e:
        print(f"Error: {e}")
        print("You can try to repair the package index using the --repair option.")
        exit(1)

    print("Writing index")
    with open(f"{PACKAGES_POOL_DIR}/{INDEX_FILE}", mode="w") as file:
        file.write(json.dumps(packages))
