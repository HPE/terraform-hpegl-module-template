#!/bin/bash
# (c) Copyright 2022 Hewlett Packard Enterprise Development LP

# Originally taken from https://github.com/anothrNick/github-tag-action/

# MIT License
#
# Copyright (c) 2019 Lars

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

set -o pipefail

# config
default_semvar_bump=${DEFAULT_BUMP:-minor}
with_v=${WITH_V:-false}
release_branches=${RELEASE_BRANCHES:-master}
customtag=${CUSTOM_TAG}
source=${SOURCE:-.}
dryrun=${DRY_RUN:-false}
initial_version=${INITIAL_VERSION:-0.0.0}
tag_context=${TAG_CONTEXT:-repo}
suffix=${PRERELEASE_SUFFIX:-beta}
# action options are 'tag' or 'release'
action=${ACTION:-tag}

cd ${GITHUB_WORKSPACE}/${source} || exit

echo "*** CONFIGURATION ***"
echo -e "\tDEFAULT_BUMP: ${default_semvar_bump}"
echo -e "\tWITH_V: ${with_v}"
echo -e "\tRELEASE_BRANCHES: ${release_branches}"
echo -e "\tCUSTOM_TAG: ${customtag}"
echo -e "\tSOURCE: ${source}"
echo -e "\tDRY_RUN: ${dryrun}"
echo -e "\tINITIAL_VERSION: ${initial_version}"
echo -e "\tTAG_CONTEXT: ${tag_context}"
echo -e "\tPRERELEASE_SUFFIX: ${suffix}"

current_branch=$(git rev-parse --abbrev-ref HEAD)

pre_release="true"
IFS=',' read -ra branch <<< "$release_branches"
for b in "${branch[@]}"; do
    echo "Is $b a match for ${current_branch}"
    if [[ "${current_branch}" =~ $b ]]
    then
        pre_release="false"
    fi
done
echo "pre_release = $pre_release"

# fetch tags
git fetch --tags

# get latest tag that looks like a semver (with or without v)
case "$tag_context" in
    *repo*)
        tag=$(git for-each-ref --sort=-v:refname --format '%(refname)' | cut -d / -f 3- | grep -E "^v?[0-9]+.[0-9]+.[0-9]+$" | head -n1)
        pre_tag=$(git for-each-ref --sort=-v:refname --format '%(refname)' | cut -d / -f 3- | grep -E "^v?[0-9]+.[0-9]+.[0-9]+(-$suffix.[0-9]+)?$" | head -n1)
        ;;
    *branch*)
        tag=$(git tag --list --merged HEAD --sort=-v:refname | grep -E "^v?[0-9]+.[0-9]+.[0-9]+$" | head -n1)
        pre_tag=$(git tag --list --merged HEAD --sort=-v:refname | grep -E "^v?[0-9]+.[0-9]+.[0-9]+(-$suffix.[0-9]+)?$" | head -n1)
        ;;
    * ) echo "Unrecognised context"; exit 1;;
esac

# if there are none, start tags at INITIAL_VERSION which defaults to 0.0.0
if [ -z "$tag" ]
then
    log=$(git log --pretty='%B')
    tag="$initial_version"
    pre_tag="$initial_version"
else
    log=$(git log $tag..HEAD --pretty='%B')
fi

# get current commit hash for tag
tag_commit=$(git rev-list -n 1 $tag)

# get current commit hash
commit=$(git rev-parse HEAD)

if [ "$tag_commit" == "$commit" ]; then
    echo "No new commits since previous tag. Skipping..."
    echo ::set-output name=tag::$tag
    exit 0
fi

echo $log

case "$log" in
    *#major* ) new=$(semver -i major $tag); part="major";;
    *#minor* ) new=$(semver -i minor $tag); part="minor";;
    *#patch* ) new=$(semver -i patch $tag); part="patch";;
    * )
        if [ "$default_semvar_bump" == "none" ]; then
            echo "Default bump was set to none. Skipping..."; exit 0
        else
            new=$(semver -i "${default_semvar_bump}" $tag); part=$default_semvar_bump
        fi
        ;;
esac

if $pre_release
then
    # Already a prerelease available, bump it
    if [[ "$pre_tag" == *"$new"* ]]; then
        new=$(semver -i prerelease $pre_tag --preid $suffix); part="pre-$part"
    else
        new="$new-$suffix.1"; part="pre-$part"
    fi
fi

echo $part

# did we get a new tag?
if [ ! -z "$new" ]
then
 # prefix with 'v'
 if $with_v
 then
  new="v$new"
 fi
fi

if [ ! -z $customtag ]
then
    new="$customtag"
fi

if $pre_release
then
    echo -e "Bumping tag ${pre_tag}. \n\tNew tag ${new}"
else
    echo -e "Bumping tag ${tag}. \n\tNew tag ${new}"
fi

# set outputs
echo ::set-output name=new_tag::$new
echo ::set-output name=part::$part

# use dry run to determine the next tag
if $dryrun
then
    echo ::set-output name=tag::$tag
    exit 0
fi

echo ::set-output name=tag::$new

# create local git tag
git tag $new

function do_tag() {
    # push new tag ref to github
    dt=$(date '+%Y-%m-%dT%H:%M:%SZ')
    full_name=$GITHUB_REPOSITORY
    git_refs_url=$(jq .repository.git_refs_url $GITHUB_EVENT_PATH | tr -d '"' | sed 's/{\/sha}//g')

    echo "$dt: **pushing tag $new to repo $full_name"

    git_refs_response=$(
    curl -s -X POST $git_refs_url \
    -H "Authorization: token $GITHUB_TOKEN" \
    -d @- << EOF
{
  "ref": "refs/tags/$new",
  "sha": "$commit"
}
EOF
    )

    git_ref_posted=$( echo "${git_refs_response}" | jq .ref | tr -d '"' )

    echo "::debug::${git_refs_response}"
    if [ "${git_ref_posted}" = "refs/tags/${new}" ]; then
      exit 0
    else
      echo "::error::Tag was not created properly."
      exit 1
    fi
}

function do_release() {
    # push new tag ref to github
    dt=$(date '+%Y-%m-%dT%H:%M:%SZ')
    full_name=$GITHUB_REPOSITORY
    releases_url=$(jq .repository.releases_url $GITHUB_EVENT_PATH | tr -d '"' | sed 's/{\/id}//g')

    echo "$dt: **creating release $new of repo $full_name"

    git_release_response=$(
    curl -s -X POST $releases_url \
    -H "Authorization: token $GITHUB_TOKEN" \
    -d @- << EOF
{
"tag_name": "$new",
"target_commitish": "$commit"
}
EOF
    )

    git_release_posted=$( echo "${git_release_response}" | jq .tag_name | tr -d '"' )

    echo "::debug::${git_release_posted}"
    if [ "${git_release_posted}" = "${new}" ]; then
      exit 0
    else
      echo "::error::Release was not created properly."
      exit 1
    fi
}

if [ ${action} = "tag" ]
then
    do_tag
fi

if [ ${action} = "release" ]
then
    do_release
fi
