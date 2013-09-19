#!/bin/sh

## Read the configuration file for the project
if [ ! -e drone.io/${DRONE_REPO_SLUG}.conf ]; then
  echo "No such configuration file: drone.io/${DRONE_REPO_SLUG}.conf"
  exit 1
fi

# Add our local repo
mkdir repo
cd repo
wget ${REMOTE_DEPENDENCIES}
sudo dpkg-scanpackages . /dev/null | gzip -c9 > Packages.gz
sudo dpkg-scansources . | gzip -c9 > Sources.gz
cd ..
sudo apt-add-repository "deb file://${DRONE_BUILD_DIR}/repo /"
sudo apt-get update

## Install the dependencies
sudo apt-get install devscripts cdbs check doxygen
sudo apt-get install ${BUILD_DEPENDENCIES}

## Check that everything is fine
NOCONFIGURE=1 ./autogen.sh
./configure
make dist

## Copy the dist
cp ${DRONE_REPO_SLUG}*.tar.gz ${DRONE_REPO_SLUG}-latest.tar.gz

## Clone the packaging repo so we now how to build for debian
git clone git://github.com/turran/packaging.git
cp -r packaging/debian/${DRONE_REPO_SLUG}/debian .
debuild -i -us -uc -b
cp ../*.deb .

## TODO Make the doc
## Push the doc to the gh-pages branch and docs directory
