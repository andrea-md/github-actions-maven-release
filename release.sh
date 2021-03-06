#!/usr/bin/env bash
set -e

# avoid the release loop by checking if the latest commit is a release commit
readonly local last_release_commit_hash=$(git log --author="$GIT_RELEASE_BOT_NAME" --pretty=format:"%H" -1)
echo "Last $GIT_RELEASE_BOT_NAME commit: ${last_release_commit_hash}"
echo "Current commit: ${GITHUB_SHA}"
if [[ "${last_release_commit_hash}" = "${GITHUB_SHA}" ]]; then
     echo "Skipping for $GIT_RELEASE_BOT_NAME commit"
     exit 0
fi

# Filter the branch to execute the release on
readonly local branch=${GITHUB_REF##*/}
echo "Current branch: ${branch}"
if [[ -n "$RELEASE_BRANCH_NAME" && ! "${branch}" = "$RELEASE_BRANCH_NAME" ]]; then
     echo "Skipping for ${branch} branch"
     exit 0
fi

# Making sure we are on top of the branch
echo "Git checkout branch ${GITHUB_REF##*/}"
git checkout ${GITHUB_REF##*/}
echo "Git reset hard to ${GITHUB_SHA}"
git reset --hard ${GITHUB_SHA}

# This script will do a release of the artifact according to http://maven.apache.org/maven-release/maven-release-plugin/
echo "Setup git user name to '$GIT_RELEASE_BOT_NAME'"
git config --global user.name "$GIT_RELEASE_BOT_NAME";
echo "Setup git user email to '$GIT_RELEASE_BOT_EMAIL'"
git config --global user.email "$GIT_RELEASE_BOT_EMAIL";

# Setup GPG
echo "GPG_ENABLED '$GPG_ENABLED'"
if [[ $GPG_ENABLED == "true" ]]; then
     echo "Enable GPG signing in git config"
     git config --global commit.gpgsign true
     echo "Using the GPG key ID $GPG_KEY_ID"
     git config --global user.signingkey $GPG_KEY_ID
     echo "GPG_KEY_ID = $GPG_KEY_ID"
     echo "Import the GPG key"
     echo  "$GPG_KEY" | base64 -d > private.key
     gpg --import ./private.key
     rm ./private.key
else
  echo "GPG signing is not enabled"
fi
echo "Override the java home as gitactions is seting up the JAVA_HOME env variable"
JAVA_HOME="/usr/java/openjdk-14/"
# Setup maven local repo
if [[ -n "$MAVEN_LOCAL_REPO_PATH" ]]; then
     MAVEN_REPO_LOCAL="-Dmaven.repo.local=$MAVEN_LOCAL_REPO_PATH"
fi

if [[ -n "$MAVEN_REPO_SERVER_ID" ]]; then
     MAVEN_SETTINGS_OPTION="-s /usr/share/maven/conf/settings-with-repo.xml"
fi

echo "Move to folder $MAVEN_PROJECT_FOLDER"
cd $MAVEN_PROJECT_FOLDER

# Create the release and set the version:
echo "Do mvn release:branch version: $MAVEN_RELEASE_VERSION"
mvn -B $MAVEN_SETTINGS_OPTION $MAVEN_REPO_LOCAL release:branch -DbranchName=v$MAVEN_RELEASE_VERSION.x -DautoVersionSubmodules=true -DupdateBranchVersions=true -DupdateWorkingCopyVersions=false -DreleaseVersion=$MAVEN_RELEASE_VERSION.0-SNAPSHOT  -Dsonatype2.repo.username=$MAVEN_USERNAME -Dsonatype2.repo.password=$MAVEN_PASSWORD

if [[ ("$?" -eq 0) && ($SKIP_PERFORM == "false") ]]; then
# Build release
echo "Do mvn release:branch with arguments $MAVEN_BUILD_RELEASE_ARGS"
mvn -B $MAVEN_SETTINGS_OPTION $MAVEN_REPO_LOCAL build-helper:parse-version clean release:clean release:prepare release:perform -Darguments="-Dmaven.javadoc.skip=true -Dmaven.test.skip=true" -DautoVersionSubmodules=true -DreleaseVersion=$MAVEN_RELEASE_VERSION.$MAVEN_INCREMENT_VERSION -DdevelopmentVersion=$MAVEN_RELEASE_VERSION.$MAVEN_INCREMENT_VERSION-SNAPSHOT -DtagNameFormat=v@{project.version}  -Dsonatype2.repo.username=$MAVEN_USERNAME -Dsonatype2.repo.password=$MAVEN_PASSWORD
fi