#!/bin/bash

REPO=`echo ${DRONE_REPO_SLUG} | cut -d / -f 3`
UPDATE_REPOS=0

## Some color definitions
RED="\033[31m"
GREEN="\033[32m"
NORMAL="\033[0m"


## Read the configuration file for the project
if [ ! -e packaging/drone.io/${REPO}.conf ]; then
  echo "No such configuration file: packaging/drone.io/${REPO}.conf"
  exit 1
fi

echo -e "${GREEN}Using repo ${REPO}${NORMAL}"

## Include the repo configuration
source packaging/drone.io/${REPO}.conf

## Add remote ppas
if [ ! -z "${EXTERNAL_PPAS}" ]; then
	for i in ${EXTERNAL_PPAS}; do
		echo -e "${GREEN}Adding external ppa $i${NORMAL}"
		sudo apt-add-repository $i
	done
	UPDATE_REPOS=1
fi

## Add our local repo and our specific dependencies
if [ ! -z "${REMOTE_DEPENDENCIES}" ]; then
	mkdir repo
	cd repo
	for i in ${REMOTE_DEPENDENCIES}; do
		echo -e "${GREEN}Downloading $i"
		wget --quiet ${i} -O - | tar x
	done
	echo -e "${GREEN}Creating our local repo${NORMAL}"
	sudo dpkg-scanpackages . /dev/null | gzip -c9 > Packages.gz
	sudo dpkg-scansources . | gzip -c9 > Sources.gz
	cd ..
	sudo apt-add-repository "deb file://${DRONE_BUILD_DIR}/repo /"
	UPDATE_REPOS=1
fi

if [ ${UPDATE_REPOS} -eq 1 ]; then
	sudo apt-get update
fi

## Install the dependencies
sudo apt-get install devscripts cdbs check
if [ ! -z "${BUILD_DEPENDENCIES}" ]; then
	echo -e "${GREEN}Installing ${BUILD_DEPENDENCIES}${NORMAL}"
	sudo apt-get install ${BUILD_DEPENDENCIES}
	if [ ! $? -eq 0 ]; then
		echo -e "${RED}Failed to install build dependencies${NORMAL}"
		exit 1
	fi

## Check that everything is fine
echo -e "${GREEN}Everything setup to build${NORMAL}"
NOCONFIGURE=1 ./autogen.sh
./configure || exit 1
make dist || exit 1

## Copy the dist
cp ${REPO}*.tar.gz ${REPO}-latest.tar.gz

## Upload to coverity in case the envvar is set
if [ ! -z "{COVERITY_TOKEN}" ]; then
	echo -e "${GREEN}Downloading the coverity build tools${NORMAL}"
	wget --quiet https://scan.coverity.com/download/linux-64 -O - | tar x
	cov-analysis-linux64-6.6.1/bin/cov-build --dir cov-int make -j4
	tar czvf ${REPO}-coverity.tar.gz cov-int
	echo -e "${GREEN}Uploading to coverity${NORMAL}"
	curl --form project=${REPO} --form token=${COVERITY_TOKEN} \
			--form email=${COVERITY_EMAIL} \
			--form file=@${REPO}-latest.tar.gz --form version=head \
			http://scan5.coverity.com/cgi-bin/upload.py
fi

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
		make doxygen
		rm -rf gh-pages/docs/*
		if [ ! -e gh-pages/docs ]; then
			mkdir gh-pages/docs
		fi
		cp -r doc/html/* gh-pages/docs
		## Finally add the new files, remove the old ones, etc
		cd gh-pages
		git add -A
		git commit -m "Updating the docs"
		git push
		cd ..
	fi
fi
