FROM andrea-md/maven-git-gpg:latest

COPY ./release.sh /usr/local/bin
COPY ./settings.xml /usr/share/maven/conf/settings-with-repo.xml
