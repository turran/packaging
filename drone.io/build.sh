#!/bin/bash

REPO=`echo ${DRONE_REPO_SLUG} | cut -d / -f 3`
## Read the configuration file for the project
if [ ! -e packaging/drone.io/${REPO}.conf ]; then
  echo "No such configuration file: packaging/drone.io/${REPO}.conf"
  exit 1
fi

## Include the repo configuration
source packaging/drone.io/${REPO}.conf

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
cp ${REPO}*.tar.gz ${REPO}-latest.tar.gz

## The packaging project must be already cloned, just copy the debian
## directory
if [ -z ${NODEB} ]; then
	if [ -e packaging/debian/${REPO}/debian ]; then
		cp -r packaging/debian/${REPO}/debian .
		debuild -i -us -uc -b
		cp ../*.deb .
	fi
fi

## TODO Make the doc
## Push the doc to the gh-pages branch and docs directory
if [ -z ${NODOC} ]; then
	git clone -b gh-pages git@github.com:turran/${REPO}.git gh-pages
	make doc
	rm -rf gh-pages/docs/*
	cp -r doc/html/* gh-pages/docs
	## Finally add the new files, remove the old ones, etc
	cd gh-pages
	git add -A
	git commit -m "Updating the docs"
	git push --dry-run
	cd ..
fi
