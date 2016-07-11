#!/bin/bash
set -e

# Only run on pushes to master
if [ "${TRAVIS_BRANCH}" != "master" || "${TRAVIS_EVENT_TYPE}" != "push" ]; then
  echo "skipping deploy"
  exit 0
fi

# Grab the just built version of the package outputted by R CMD build
PKG=$(ls -1t *.tar.gz | head -n 1)

# Get the package's name
# TODO: is package archive guaranteed to be pkgname_[whatever]?
PKGNAME=$(echo "${PKG}" | cut -d _ -f 1)

# Extract the package's contents
# TODO: potential namespace collision with original package dir?
tar xfz "${PKG}"


# Set up repo that will allow pushes to gh-pages branch

# TODO: process for specifying $AUTHOR_EMAIL in .travis.yaml
# TODO: process for adding github token to .travis.yaml
# travis encrypt -r username/reponame GH_TOKEN=[token] --add

REPO="https://${GH_TOKEN}@github.com/${TRAVIS_REPO_SLUG}.git"

DIR="_vignettes"
mkdir "${DIR}"
cd "${DIR}"

git init
git config user.name "Travis CI"
git config user.email "${AUTHOR_EMAIL}"

git remote add upstream "${REPO}"
git fetch upstream

GH_EXIST=$(git ls-remote --heads "${REPO}" gh-pages | wc -l)
echo $GH_EXIST

if [ $GH_EXIST == "1" ]; then
  git reset upstream/gh-pages
else
  git checkout --orphan gh-pages
fi


# Copy all rendered vignettes from package to repo
cp ../"${PKGNAME}"/inst/doc/*.html .

# Add/commit/push changes
git add --all .
# TODO: master commit in message? custom commit message?
git commit -m "deployed to github pages"
git push --quiet upstream HEAD:gh-pages
