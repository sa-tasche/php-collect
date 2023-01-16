#!/usr/bin/env bash

# Note: If you see this error on Ubuntu, don't worry; we're using a macOS-friendly sed syntax
#       that throws errors but still works fine on Linux.
#
#       sed: can't read : No such file or directory

##
 # tightenco/collect upgrader script
 #
 # usage
 #    ./upgrade.sh [laravel framework version]
 #
 #    or
 #
 #    bash upgrade.sh [laravel framework version]
 #

##
 # Include dotfiles on file operations
 #
shopt -s dotglob

##
 # App
 #

function main()
{
    # a='a.b.y'
    # echo ${a##*.}
    # exit

    echo "Upgrading..."

    checkDependencies

    prepareEnvironment $1

    displayVariables

    cleanDirectories

    downloadRepository

    extractZip

    copyClasses

    copyContracts

    copyTraits

    copyStubs

    downloadTests

    copyTestSupportClasses

    renameNamespace

    fillAliases

    cleanupDir

    runTests
}

##
 # Check if all dependencies are available
 #
function checkDependencies()
{
    for dependency in ${dependencies[@]}; do
        if ! [ -x "$(command -v ${dependency})" ]; then
            echo "Error: ${dependency} is not installed." >&2
            exit 1
        fi
    done
}

##
 # Prepare the environment
 #
function prepareEnvironment()
{
    ##
     # Define all variables
     #
    requestedVersion=$1
    rootDir=.
    baseDir=${rootDir}/src
    vendor=laravel
    project=framework
    oldNamespace='Illuminate'
    newNamespace='Tightenco\\Collect'
    newDir='Collect'
    logFile=$(mktemp /tmp/collect-log.XXXXXX)
    repository=https://github.com/$vendor/$project.git

    getCurrentVersionFromGitHub

    repositoryDir=${rootDir}/$project-${collectionVersion}
    repositorySrcDir=${repositoryDir}/src
    collectionZip=${rootDir}/$project-${collectionVersion}.zip
    collectionZipUrl=https://github.com/$vendor/$project/archive/v${collectionVersion}.zip
    # If a new version has not been tagged, use the following
    # collectionZipUrl=https://github.com/$vendor/$project/archive/${collectionVersion}.zip
    oldNamespaceDir=${repositorySrcDir}/${oldNamespace}
    newNamespaceDir=${baseDir}/${newDir}
    testsDir=${rootDir}/tests
    testsBaseUrl=https://raw.githubusercontent.com/${vendor}/${project}/v${collectionVersion}/tests
    # If a new version has not been tagged, use the following
    # testsBaseUrl=https://raw.githubusercontent.com/${vendor}/${project}/${collectionVersion}/tests
    stubsDir=${rootDir}/stubs
    aliasFile=${baseDir}/${newDir}/Support/alias.php
carriageReturn="
"

    classes=(
        'Support/Arr'
        'Support/Collection'
        'Support/Enumerable'
        'Support/HigherOrderCollectionProxy'
        'Support/LazyCollection'
    )

    classesNotInSupport=(
        'Conditionable/HigherOrderWhenProxy'
    )

    traits=(
        'Support/Traits/EnumeratesValues'
    )

    supportTraits=(
        'Conditionable/Traits/Conditionable'
        'Macroable/Traits/Macroable'
        'Support/Traits/Tappable'
    )

    contracts=(
        'Contracts/Support/Arrayable'
        'Contracts/Support/Jsonable'
        'Contracts/Support/Htmlable'
        'Contracts/Support/CanBeEscapedWhenCastToString'
    )

    tests=(
        'Support/Enums.php'
        'Support/SupportCollectionTest.php'
        'Support/SupportArrTest.php'
        'Support/SupportMacroableTest.php'
        'Support/SupportLazyCollectionTest.php'
        'Support/SupportLazyCollectionIsLazyTest.php'
        'Support/Concerns/CountsEnumerations.php'
    )

    testSupportClasses=(
        'Support/Carbon'
        'Support/HigherOrderTapProxy'
        'Support/HtmlString'
        'Support/Str'
        'Support/Stringable'
    )

    testSupportClassesInExtractedCollections=(
        'Support/ItemNotFoundException'
        'Support/MultipleItemsFoundException'
    )

    stubs=(
        'src/Collect/Support/helpers.php'
        'src/Collect/Support/alias.php'
        'tests/bootstrap.php'
    )

    dependencies=(
        'wget'
        'unzip'
        'mktemp'
    )
}

##
 # Display all variables
 #
function displayVariables()
{
    echo
    echo "-- Variables"
    echo "---------------------------------------------"

    echo baseDir = ${baseDir}
    echo collectionVersion = ${collectionVersion}
    echo repositoryDir = ${repositoryDir}
    echo repositorySrcDir = ${repositorySrcDir}
    echo collectionZip = ${collectionZip}
    echo baseDir = ${baseDir}
    echo oldNamespace = ${oldNamespace}
    echo newNamespace = ${newNamespace}
    echo oldNamespaceDir = ${oldNamespaceDir}
    echo newNamespaceDir = ${newNamespaceDir}
    echo testsDir = ${testsDir}
    echo testsBaseUrl = ${testsBaseUrl}

    echo "---------------------------------------------"
    echo ""
}

##
 # Clean the destination directory
 #
function cleanDirectories()
{
    echo "Cleaning ${baseDir} and ${testsDir}/Support..."

    if [ -d ${baseDir} ]; then
        rm -rf ${baseDir}
    fi

    if [ -d ${testsDir}/Support ]; then
        rm -rf ${testsDir}
    fi

    if [ -d ${repositoryDir} ]; then
        rm -rf ${repositoryDir}
    fi
}

##
 # Download a new version
 #
function downloadRepository()
{
    echo "-- Downloading ${collectionZipUrl} to ${baseDir}"

    wget ${collectionZipUrl} -O ${collectionZip} >${logFile} 2>&1

    handleErrors
}

##
 # Extract from compressed file
 #
function extractZip()
{
    echo "-- Extracting $project.zip..."

    unzip -u ${collectionZip} -d ${rootDir} >${logFile} 2>&1

    rm ${collectionZip}

    handleErrors
}

##
 # Copy classes
 #
function copyClasses()
{
    echo "-- Copying classes ..."

    for class in ${classes[@]}; do
        classSrc="${class/Support/Collections}"
        echo "Copying ${oldNamespaceDir}/${classSrc}.php..."

        mkdir -p $(dirname ${newNamespaceDir}/${class}.php)

        cp ${oldNamespaceDir}/${classSrc}.php $newNamespaceDir/$class.php

        chmod 644 ${newNamespaceDir}/${class}.php
    done

    for class in ${classesNotInSupport[@]}; do
        classSrc="${class/Support/Collections}"
        echo "Copying ${oldNamespaceDir}/${classSrc}.php..."

        mkdir -p $(dirname ${newNamespaceDir}/${class}.php)

        cp ${oldNamespaceDir}/${classSrc}.php $newNamespaceDir/$class.php

        chmod 644 ${newNamespaceDir}/${class}.php
    done
}

##
 # Move contracts
 #
function copyContracts()
{
    echo "-- Copying contracts..."

    for contract in ${contracts[@]}; do
        echo "Copying ${oldNamespaceDir}/${contract}.php..."

        mkdir -p $(dirname ${newNamespaceDir}/${contract})

        cp ${oldNamespaceDir}/${contract}.php ${newNamespaceDir}/${contract}.php
    done
}

##
 # Move traits
 #
function copyTraits()
{
    echo "-- Copying traits..."

    for trait in ${traits[@]}; do
        traitSrc="${trait/Support/Collections}"
        echo "Copying ${oldNamespaceDir}/${traitSrc}.php..."

        mkdir -p $(dirname ${newNamespaceDir}/${trait})

        cp ${oldNamespaceDir}/${traitSrc}.php ${newNamespaceDir}/${trait}.php
    done

    for traitSrc in ${supportTraits[@]}; do
        traitClassName="${traitSrc##*/}"

        echo "Copying ${oldNamespaceDir}/${traitSrc}.php... to ${newNamespaceDir}/Support/Traits/${traitClassName}.php"

        mkdir -p $(dirname ${newNamespaceDir}/${traitClassName})

        cp ${oldNamespaceDir}/${traitSrc}.php ${newNamespaceDir}/Support/Traits/${traitClassName}.php
    done
}

##
 # Copy classes and contracts
 #
function copyStubs()
{
    echo "-- Copying stubs..."

    for stub in ${stubs[@]}; do
        echo "Copying ${stubsDir}/${stub} to ${rootDir}/${stub}..."

        mkdir -p $(dirname ${rootDir}/${stub})

        cp ${stubsDir}/${stub} ${rootDir}/${stub}

        chmod 644 ${rootDir}/${stub}
    done
}

##
 # Fill the alias.php file with the list of aliases
 #
function fillAliases()
{
    echo "-- Filling aliases.php..."

    indent='    '
    aliases='CARRIAGERETURN'

    for contract in ${contracts[@]}; do
        aliases="${aliases}${indent}${newNamespace}/${contract}::class => ${oldNamespace}/${contract}::class,CARRIAGERETURN"
    done

    for class in ${classes[@]}; do
        aliases="${aliases}${indent}${newNamespace}/${class}::class => ${oldNamespace}/${class}::class,CARRIAGERETURN"
    done

    for trait in ${traits[@]}; do
        aliases="${aliases}${indent}${newNamespace}/${trait}::class => ${oldNamespace}/${trait}::class,CARRIAGERETURN"
    done

    aliases=${aliases//\//\\\\}

    sed -i "" -e "s|/\*--- ALIASES ---\*/|${aliases}|g" $aliasFile
    sed -i "" -e "s|CARRIAGERETURN|\\${carriageReturn}|g" $aliasFile
}

##
 # Copy tests to our tests dir
 #
function getCurrentVersionFromGitHub()
{
    echo Getting current version from $repository...

    if [ -z "$requestedVersion" ]; then
        collectionVersion=$(git ls-remote $repository --tags  v9.47\* | grep tags/ | grep -v {} | cut -d \/ -f 3 | cut -d v -f 2  | grep -v RC | grep -vi beta | sort -t. -k 1,1n -k 2,2n -k 3,3n| tail -1)
    else
        collectionVersion=$requestedVersion
    fi

    echo Upgrading to $vendor/$project $collectionVersion
}

##
 # Download tests to tests dir
 #
function downloadTests()
{
    echo "-- Copying tests..."

    for test in ${tests[@]}; do
        echo "---- Downloading test ${testsBaseUrl}/${test} to ${testsDir}/${test}..."

        mkdir -p $(dirname ${testsDir}/${test})

        wget ${testsBaseUrl}/${test} -O ${testsDir}/${test} >/dev/null 2>&1
    done
}

##
 # Copy support files for tests
 #
function copyTestSupportClasses()
{
    echo "-- Copying support files for tests..."
    testSupportDirectory='./tests/files'

    for class in ${testSupportClasses[@]}; do
        echo "Copying ${oldNamespaceDir}/${class}..."

        mkdir -p $(dirname $testSupportDirectory/$class)

        cp ${oldNamespaceDir}/${class}.php ${testSupportDirectory}/$class.php

        chmod 644 ${testSupportDirectory}/${class}.php
    done

    for class in ${testSupportClassesInExtractedCollections[@]}; do
        echo "Copying ${oldNamespaceDir}/${class} (from extracted Collections)..."

        mkdir -p $(dirname $testSupportDirectory/$class)

        # Extract these classes from Illuminate/Collections, even though they end up in
        # the Illuminate/Support namespace
        movedClassFilename=${class/Support/Collections}

        cp ${oldNamespaceDir}/${movedClassFilename}.php ${testSupportDirectory}/$class.php

        chmod 644 ${testSupportDirectory}/${class}.php
    done

    # @todo: do this more cleanly
    find ./tests/files -name "*.php" -exec sed -i "" -e "s|Illuminate\\\Support|/\*--- OLDNAMESPACE ---\*/\\\Support|g" {} \;
}

##
 # Rename namespace on all files
 #
function renameNamespace()
{
    echo "-- Renaming namespace from $oldNamespace to $newNamespace..."

    find ${newNamespaceDir} -name "*.php" -exec sed -i "" -e "s|${oldNamespace}|${newNamespace}|g" {} \;
    find ${testsDir} -name "*.php" -exec sed -i "" -e "s|${oldNamespace}|${newNamespace}|g" {} \;
    find ${testsDir} -name "*.php" -exec sed -i "" -e "s|/\*--- OLDNAMESPACE ---\*/|${oldNamespace}|g" {} \;
    find ${newNamespaceDir} -name "*.php" -exec sed -i "" -e "s|/\*--- OLDNAMESPACE ---\*/|${oldNamespace}|g" {} \;

    # rename the namespaces of Conditional
    find ${newNamespaceDir} -name "*.php" -exec sed -i "" -e "s|Support\\\HigherOrderWhenProxy|Conditionable\\\HigherOrderWhenProxy|g" {} \;
    find ${newNamespaceDir} -name "HigherOrderWhenProxy.php" -exec sed -i "" -e "s|Tightenco\\\Collect\\\Support|Tightenco\\\Collect\\\Conditionable|g" {} \;

    echo "-- Expand the alias for Stringable to check for Illuminate, not Tightenco, Stringable"

    find ${newNamespaceDir} -name "*.php" -exec sed -i "" -e "s|instanceof\ Stringable|instanceof\ \\\Illuminate\\\Support\\\Stringable|g" {} \;

    echo "-- Reigning the renaming back in; bringing Carbon, HtmlString, Str back to Illuminate/Support"

    # @todo: do this more cleanly
    # Just in tests, fix namespaces for classes that are no longer provided in collections as of 8.0+ Illuminate\Support\Traits\Macroable, etc
    find ${testsDir} -name "*.php" -exec sed -i "" -e "s|Tightenco\\\Collect\\\Support\\\Carbon|Illuminate\\\Support\\\Carbon|g" {} \;
    find ${testsDir} -name "*.php" -exec sed -i "" -e "s|Tightenco\\\Collect\\\Support\\\HtmlString|Illuminate\\\Support\\\HtmlString|g" {} \;
    find ${testsDir} -name "*.php" -exec sed -i "" -e "s|Tightenco\\\Collect\\\Support\\\Str|Illuminate\\\Support\\\Str|g" {} \;
    find ${testsDir} -name "*.php" -exec sed -i "" -e "s|Illuminate\\\Support\\\Traits\\\Conditionable|Tightenco\\\Collect\\\Support\\\Traits\\\Conditionable|g" {} \;
    find ${testsDir} -name "*.php" -exec sed -i "" -e "s|Illuminate\\\Support\\\Traits\\\Macroable|Tightenco\\\Collect\\\Support\\\Traits\\\Macroable|g" {} \;
    find ${testsDir} -name "*.php" -exec sed -i "" -e "s|Illuminate\\\Support\\\Traits\\\Tappable|Tightenco\\\Collect\\\Support\\\Traits\\\Tappable|g" {} \;

    find ${testSupportDirectory} -name "HigherOrderTapProxy.php" -exec sed -i "" -e "s|Illuminate\\\Support|Tightenco\\\Collect\\\Support|g" {} \;
    find ${testSupportDirectory} -name "ItemNotFoundException.php" -exec sed -i "" -e "s|Illuminate\\\Support|Tightenco\\\Collect\\\Support|g" {} \;
    find ${testSupportDirectory} -name "MultipleItemsFoundException.php" -exec sed -i "" -e "s|Illuminate\\\Support|Tightenco\\\Collect\\\Support|g" {} \;
}

##
 # Clean up dir
 #
function cleanupDir()
{
    echo "-- Cleaning up ${repositoryDir}..."

    rm -rf ${repositoryDir}
}

##
 # Run tests
 #
function runTests()
{
    echo "-- Running tests..."

    if [ -f ${rootDir}/composer.lock ]; then
        rm ${rootDir}/composer.lock
    fi

    if [ -d ${rootDir}/vendor ]; then
        rm -rf ${rootDir}/vendor
    fi

    composer install

    vendor/bin/phpunit
}

##
 # Handle command errors
 #
function handleErrors()
{
    if [[ $? -ne 0 ]]; then
        echo "FATAL ERROR occurred during command execution:"
        cat ${logFile}
        exit 1
    fi
}

##
 # Run the app
 #
main $@
