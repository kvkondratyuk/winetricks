#!/bin/sh
# Trivial release helper for winetricks
#
# Usage: $0 optional_version_name
#
# Copyright (C) 2016 Austin English
#
# This software comes with ABSOLUTELY NO WARRANTY.
#
# This is free software, placed under the terms of the GNU Lesser
# Public License version 2.1 (or later), as published by the Free
# Software Foundation. Please see the file COPYING for details.

set -e
set -u
set -x

# Needed by the list commands below:
export WINETRICKS_LATEST_VERSION_CHECK="development"

if [ -z "$GITHUB_TOKEN" ] ; then
    echo "GITHUB_TOKEN must be set in the environment!"
    exit 1
fi

# Make sure we're at top level:
if [ ! -f Makefile ] ; then
    echo "Please run this from the top of the source tree"
    exit 1
fi

version="${1:-$(date +%Y%m%d)}"

if git tag | grep -w "${version}" ; then
    echo "A tag for ${version} already exists!"
    exit 1
fi

# update version in winetricks itself
sed -i -e "s%WINETRICKS_VERSION=.*%WINETRICKS_VERSION=${version}%" src/winetricks

# update manpage
line=".TH WINETRICKS 1 \"$(date +"%B %Y")\" \"Winetricks ${version}\" \"Wine Package Manager\""
sed -i -e "s%\\.TH.*%${line}%" src/winetricks.1

# update LATEST (version) file
echo "${version}" > files/LATEST

# Update verb lists:
# actual categories
./src/winetricks apps list > files/verbs/apps.txt
./src/winetricks benchmarks list > files/verbs/benchmarks.txt
./src/winetricks dlls list > files/verbs/dlls.txt
./src/winetricks games list > files/verbs/games.txt
./src/winetricks settings list > files/verbs/settings.txt

# meta categories
./src/winetricks list-all > files/verbs/all.txt
./src/winetricks list-download > files/verbs/download.txt
./src/winetricks list-manual-download > files/verbs/manual-download.txt

git commit files/LATEST files/verbs/*.txt src/winetricks src/winetricks.1 -m "version bump - ${version}"
git tag -s -m "winetricks-${version}" "${version}"

# update development version in winetricks
sed -i -e "s%WINETRICKS_VERSION=.*%WINETRICKS_VERSION=${version}-next%" src/winetricks
git commit src/winetricks -m "development version bump - ${version}-next"

git push
git push --tags


# create local tarball, identical to github's generated one
git archive --prefix="winetricks-${version}/" -o "../${version}.tar.gz" "${version}"

# create a detached signature of the tarball
gpg --armor --default-key 0xA041937B --detach-sign "../${version}.tar.gz"

# upload the detached signature to github:
python3 src/github-api-releases.py  ../../"${version}.tar.gz.asc" Winetricks winetricks "${version}"

exit 0
