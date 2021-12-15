#!/bin/bash
KIBANA_VERSION=$(cat package.json| jq .version | cut -d'"' -f2)
ELASTICSEARCH_SECURITY_PLUGIN_VERSION="$1"
COMMAND="$2"

# sanity checks for options
if [ -z "$KIBANA_VERSION" ] || [ -z "$ELASTICSEARCH_SECURITY_PLUGIN_VERSION" ] || [ -z "$COMMAND" ]; then
    echo "Usage: ./build.sh <kibana_version> <elasticsearch_security_plugin_version> <install|deploy>"
    exit 1;
fi

if [ "$COMMAND" != "deploy" ] && [ "$COMMAND" != "install" ]; then
    echo "Usage: ./build.sh <kibana_version> <elasticsearch_security_plugin_version> <install|deploy>"
    echo "Unknown command: $COMMAND"
    exit 1;
fi


echo "+++ Checking Maven version +++"
mvn -version
if [ $? != 0 ]; then
    echo "Checking maven version failed";
    exit 1;
fi

# sanity checks for nvm
if [ -z "$NVM_HOME" ]; then
    echo "NVM_HOME not set"
    exit 1;
fi

echo "+++ Sourcing nvm +++"
[ -s "$NVM_HOME/nvm.sh" ] && \. "$NVM_HOME/nvm.sh"

echo "+++ Checking nvm version +++"
nvm version
if [ $? != 0 ]; then
    echo "Checking mvn version failed";
    exit 1;
fi

# check version matches. Do not use jq here, only bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $DIR
# while read -r line
# do
#     if [[ "$line" =~ ^\"version\".* ]]; then
#       if [[ "$line" != "\"version\": \"$1-$2\"," ]]; then
#         echo "Provided version \"version\": \"$1-$2\" does not match Kibana version: $line"
#         exit 1;
#       fi
#     fi
# done < "package.json"

# cleanup any leftovers
./clean.sh
if [ $? != 0 ]; then
    echo "Cleaning leftovers failed";
    exit 1;
fi

# prepare artefacts
PLUGIN_NAME="opendistro_security_kibana_plugin-$ELASTICSEARCH_SECURITY_PLUGIN_VERSION"
echo "+++ Building $PLUGIN_NAME.zip +++"

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"
mkdir -p build_stage
cd build_stage

echo "+++ Cloning https://github.com/elastic/kibana.git +++"
git clone https://github.com/elastic/kibana.git || true > /dev/null 2>&1
if [ $? != 0 ]; then
    echo "got clone Kibana repository failed";
    exit 1;
fi

cd "kibana"
git fetch

echo "+++ Change to tags/v$KIBANA_VERSION +++"
git checkout "tags/v$KIBANA_VERSION"

if [ $? != 0 ]; then
    echo "Switching to Kibana tags/v$KIBANA_VERSION failed";
    exit 1;
fi

echo "+++ Installing node version $(cat .node-version) +++"
nvm install "$(cat .node-version)"
if [ $? != 0 ]; then
    echo "Installing node $(cat .node-version) failed";
    exit 1;
fi


cd "$DIR"
rm -rf build/
rm -rf node_modules/

echo "+++ Installing node modules +++"
npm install
if [ $? != 0 ]; then
    echo "Installing node modules failed";
    exit 1;
fi


echo "+++ Copy plugin contents +++"
COPYPATH="build/kibana/$PLUGIN_NAME"
mkdir -p "$COPYPATH"
cp -a "$DIR/index.js" "$COPYPATH"
cp -a "$DIR/package.json" "$COPYPATH"
cp -a "$DIR/lib" "$COPYPATH"
cp -a "$DIR/node_modules" "$COPYPATH"
cp -a "$DIR/public" "$COPYPATH"

if [ "$COMMAND" = "deploy" ] ; then
    echo "+++ mvn clean deploy -Prelease +++"
    mvn clean deploy -Prelease
    if [ $? != 0 ]; then
        echo "mvn clean deploy -Prelease failed";
        exit 1;
    fi
fi

if [ "$COMMAND" = "install" ] ; then
    echo "+++ mvn clean install +++"
    mvn clean install
    if [ $? != 0 ]; then
        echo "mvn clean install failed";
        exit 1;
    fi
fi
