#!/bin/bash

REPO=`echo ${DRONE_REPO_SLUG} | cut -d / -f 3`
## Read the configuration file for the project
if [ ! -e packaging/drone.io/${REPO}.conf ]; then
  echo "No such configuration file: packaging/drone.io/${REPO}.conf"
  exit 1
fi

## Include the repo configuration
source packaging/drone.io/${REPO}.conf

## Add our local repo and our specific dependencies
if [ ! -z ${REMOTE_DEPENDENCIES} ]; then
	mkdir repo
	cd repo
	for i in ${REMOTE_DEPENDENCIES}; do
		wget ${REMOTE_DEPENDENCIES} -O - | tar x
	done
	sudo dpkg-scanpackages . /dev/null | gzip -c9 > Packages.gz
	sudo dpkg-scansources . | gzip -c9 > Sources.gz
	cd ..
	sudo apt-add-repository "deb file://${DRONE_BUILD_DIR}/repo /"
	sudo apt-get update
fi

## Install the dependencies
sudo apt-get install devscripts cdbs check
if [ ! -z ${BUILD_DEPENDENCIES} ]; then
	sudo apt-get install ${BUILD_DEPENDENCIES}
fi

if [ -z ${NODOC} ]; then
	sudo apt-get install doxygen
fi

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
		tar cf ${REPO}-debs.tar.gz ../*.deb
	fi
fi

## Push the doc to the gh-pages branch and docs directory
## Be sure to add the drone.io key to the deploy keys
if [ -z ${NODOC} ]; then
	git branch -r | grep gh-pages
	exist=$?
	if [ ${exist} -eq 0 ]; then
		git clone -b gh-pages git@github.com:turran/${REPO}.git gh-pages
		make doc
		rm -rf gh-pages/docs/*
		cp -r doc/html/* gh-pages/docs
		## Finally add the new files, remove the old ones, etc
		cd gh-pages
		git add -A
		git commit -m "Updating the docs"
		git push
		cd ..
	fi
fi
