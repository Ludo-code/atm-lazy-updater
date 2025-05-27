#!/bin/bash
set -eu

installed_version=$(cat latest_version.md)
newer_version=$(find -name "ServerFiles-*.zip" | sed -n 's/.*ServerFiles-\(.*\)\.zip.*/\1/p')
if [ -z "$newer_version" ]; then
    newer_version=$installed_version
fi

echo -e "Dernière version installer : \e[32m$installed_version\e[0m \n"
echo -e "Dernière version télécharger : \e[32m$newer_version\e[0m \n"

echo "Check présence ZIP"
if [ "$(echo "$installed_version < $newer_version" | bc -l)" -eq 1 ]; then
    if find -name "ServerFiles-*.zip" | grep -q . ; then
        if [ "$(echo "$installed_version < $newer_version" | bc -l)" -eq 1 ]; then
        echo -e "Unzip du dossier dans tmp/ \n"
        unzip -o $(find -name "ServerFiles-*.zip" -print -quit) -d tmp/
        fi
        echo -e "Suppression des répertoires avant déplacement \n"
        if [[ -d "config" && -d "defaultconfigs" && -d "kubejs" && -d "mods" ]]; then
            rm -rv config defaultconfigs kubejs mods
        else
            echo "Aucun dossier config, defaultconfigs, kubejs ou mods trouver"
        fi
        echo -e "Déplacement des répertoires \n"
        mv tmp/config tmp/defaultconfigs tmp/kubejs tmp/mods .
        echo -e "Check de la version de neoforge \n"
        installed_neoforge_version=$(find . -maxdepth 1 -name "neoforge-*-installer.jar" -print -quit | sed -n 's/.*neoforge-\(.*\)\-installer.jar.*/\1/p')
        newer_neoforge_version=$(find tmp/ -name "neoforge-*-installer.jar" -print -quit | sed -n 's/.*neoforge-\(.*\)\-installer.jar.*/\1/p')
        echo -e "Dernière version installer : \e[32m$installed_neoforge_version\e[0m \n"
        echo -e "Dernière version télécharger : \e[32m$newer_neoforge_version\e[0m \n"
        installed_neoforge_version_clean=$(echo "$installed_neoforge_version" | sed 's/\.//g')
        newer_neoforge_version_clean=$(echo "$newer_neoforge_version" | sed 's/\.//g')
        if [ "$installed_neoforge_version_clean" -lt "$newer_neoforge_version_clean" ]; then
        echo -e "Suppression du dossier libraries et déplacement du jar d'installation et suppression de l'ancien \n"
        if [ -d "libraries" ]; then
            rm -rv libraries
        else
            echo "Aucun dossier libraries trouver"
        fi
        if [ -f "neoforge-$installed_neoforge_version-installer.jar" ]; then
            rm -rv "neoforge-$installed_neoforge_version-installer.jar"
        else
            echo "Aucun fichier jar trouver"
        fi
        fichier_a_deplacer=$(find tmp/ -name "neoforge-*-installer.jar" -print -quit)
        if [ -n "$fichier_a_deplacer" ]; then
            mv "$fichier_a_deplacer" .
        else
            echo "Aucun fichier trouvé dans tmp/"
        fi
        fi
    echo -e "Maj du fichier de version \n"
    echo -e $newer_version > latest_version.md
    echo -e "Suppression du zip et du tmp \n"
    rm -v "ServerFiles-$newer_version.zip" "neoforge-$installed_neoforge_version-installer.jar.log"
    rm -rv tmp/
    fi
fi
echo "Définition de la variable de la version de neoforge"
installed_neoforge_version=$(find . -maxdepth 1 -name "neoforge-*-installer.jar" -print -quit | sed -n 's/.*neoforge-\(.*\)\-installer.jar.*/\1/p')
echo "Pas de zip trouvé, lancement de atm dans 5 secondes"
sleep 5

ATM10_RESTART=false
NEOFORGE_VERSION=$installed_neoforge_version
# To use a specific Java runtime, set an environment variable named ATM10_JAVA to the full path of java.exe.
# To disable automatic restarts, set an environment variable named ATM10_RESTART to false.
# To install the pack without starting the server, set an environment variable named ATM10_INSTALL_ONLY to true.

INSTALLER="neoforge-$NEOFORGE_VERSION-installer.jar"
NEOFORGE_URL="https://maven.neoforged.net/releases/net/neoforged/neoforge/$NEOFORGE_VERSION/neoforge-$NEOFORGE_VERSION-installer.jar"

pause() {
    printf "%s\n" "Press enter to continue..."
    read ans
}

if ! command -v "${ATM10_JAVA:-java}" >/dev/null 2>&1; then
    echo "Minecraft 1.21 requires Java 21 - Java not found"
    pause
    exit 1
fi

cd "$(dirname "$0")"
if [ ! -d libraries ]; then
    echo "Neoforge not installed, installing now."
    if [ ! -f "$INSTALLER" ]; then
        echo "No Neoforge installer found, downloading now."
        if command -v wget >/dev/null 2>&1; then
            echo "DEBUG: (wget) Downloading $NEOFORGE_URL"
            wget -O "$INSTALLER" "$NEOFORGE_URL"
        else
            if command -v curl >/dev/null 2>&1; then
                echo "DEBUG: (curl) Downloading $NEOFORGE_URL"
                curl -o "$INSTALLER" -L "$NEOFORGE_URL"
            else
                echo "Neither wget or curl were found on your system. Please install one and try again"
                pause
                exit 1
            fi
        fi
    fi

    echo "Running Neoforge installer."
    "${ATM10_JAVA:-java}" -jar "$INSTALLER" -installServer
fi

if [ ! -e server.properties ]; then
    printf "allow-flight=true\nmotd=All the Mods 10\nmax-tick-time=180000" > server.properties
fi

if [ "${ATM10_INSTALL_ONLY:-false}" = "true" ]; then
    echo "INSTALL_ONLY: complete"
    exit 0
fi

JAVA_VERSION=$("${ATM10_JAVA:-java}" -fullversion 2>&1 | awk -F '"' '/version/ {print $2}' | cut -d'.' -f1)
if [ ! "$JAVA_VERSION" -ge 21 ]; then
    echo "Minecraft 1.21 requires Java 21 - found Java $JAVA_VERSION"
    pause
    exit 1
fi

while true
do
    "${ATM10_JAVA:-java}" @user_jvm_args.txt @libraries/net/neoforged/neoforge/$NEOFORGE_VERSION/unix_args.txt nogui

    if [ "${ATM10_RESTART:-true}" = "false" ]; then
        exit 0
    fi

    echo "Restarting automatically in 10 seconds (press Ctrl + C to cancel)"
    sleep 10
done
