#!/bin/bash

### TRINITYCORE AUTH INSTALL SCRIPT
### TESTED WITH UBUNTU ONLY

. /Legends-Of-Azeroth-548-Auto-Installer/configs/root-config
. /Legends-Of-Azeroth-548-Auto-Installer/configs/realm-dev-config
. /Legends-Of-Azeroth-548-Auto-Installer/configs/auth-config

if [ $USER != "$SETUP_AUTH_USER" ]; then

echo "You must run this script under the $SETUP_AUTH_USER user!"

else

## LETS START
echo ""
echo "##########################################################"
echo "## AUTH SERVER INSTALL SCRIPT STARTING...."
echo "##########################################################"
echo ""
NUM=0
export DEBIAN_FRONTEND=noninteractive


if [ "$1" = "" ]; then
## Option List
echo "## No option selected, see list below"
echo ""
echo "- [all] : Run Full Script"
echo "- [update] : Update Source and DB"
echo "- [stop] : Stop Authserver"
echo "- [start] : Start Authserver"
echo ""
((NUM++)); echo "- [$NUM] : Close Authserver"
((NUM++)); echo "- [$NUM] : Setup MySQL Database & Users"
((NUM++)); echo "- [$NUM] : Pull and Setup Source"
((NUM++)); echo "- [$NUM] : Setup Authserver Config"
((NUM++)); echo "- [$NUM] : Setup Database Data"
((NUM++)); echo "- [$NUM] : Setup Restarter"
((NUM++)); echo "- [$NUM] : Setup Crontab"
((NUM++)); echo "- [$NUM] : Start Authserver"
((NUM++)); echo "- [$NUM] : Final Message"
echo ""

else


NUM=0
((NUM++))
if [ "$1" = "all" ] || [ "$1" = "stop" ] || [ "$1" = "$NUM" ]; then
echo ""
echo "##########################################################"
echo "## $NUM.Closing Authserver"
echo "##########################################################"
echo ""
sudo systemctl stop authserverd
sudo pkill -u "$SETUP_AUTH_USER" -f screen
fi


((NUM++))
if [ "$1" = "all" ] || [ "$1" = "$NUM" ]; then
echo ""
echo "##########################################################"
echo "## $NUM.Setup MySQL Database & Users"
echo "##########################################################"
echo ""

# Auth Database Setup
echo "Checking if the 'auth' database exists..."
if ! mysql -u "$ROOT_USER" -p"$ROOT_PASS" -e "SHOW DATABASES LIKE 'auth';" | grep -q "auth"; then
    mysql -u "$ROOT_USER" -p"$ROOT_PASS" -e "CREATE DATABASE auth DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;"
    if [[ $? -eq 0 ]]; then
        echo "Auth database created."
    else
        echo "Failed to create Auth database."
        exit 1
    fi
else
    echo "Auth database already exists."
fi

# Create the auth user if it does not already exist
echo "Checking if the auth user '$AUTH_DB_USER' exists..."
if ! mysql -u "$ROOT_USER" -p"$ROOT_PASS" -e "SELECT User FROM mysql.user WHERE User = '$AUTH_DB_USER' AND Host = 'localhost';" | grep -q "$AUTH_DB_USER"; then
    mysql -u "$ROOT_USER" -p"$ROOT_PASS" -e "CREATE USER '$AUTH_DB_USER'@'localhost' IDENTIFIED BY '$AUTH_DB_PASS';"
    if [[ $? -eq 0 ]]; then
        echo "Auth DB user '$AUTH_DB_USER' created."
    else
        echo "Failed to create Auth DB user '$AUTH_DB_USER'."
        exit 1
    fi
else
    echo "Auth DB user '$AUTH_DB_USER' already exists."
fi

# Grant privileges to the auth user
echo "Granting privileges to '$AUTH_DB_USER' on the 'auth' database..."
if mysql -u "$ROOT_USER" -p"$ROOT_PASS" -e "GRANT ALL PRIVILEGES ON auth.* TO '$AUTH_DB_USER'@'localhost';"; then
    echo "Granted all privileges on 'auth' database to '$AUTH_DB_USER'."
else
    echo "Failed to grant privileges to '$AUTH_DB_USER'."
    exit 1
fi

# Flush privileges
mysql -u "$ROOT_USER" -p"$ROOT_PASS" -e "FLUSH PRIVILEGES;"
echo "Flushed privileges."
echo "Setup Auth DB Account completed."

fi


((NUM++))
if [ "$1" = "all" ] || [ "$1" = "update" ] || [ "$1" = "$NUM" ]; then
echo ""
echo "##########################################################"
echo "## $NUM.Pulling Source"
echo "##########################################################"
echo ""
cd /home/$SETUP_AUTH_USER/
mkdir /home/$SETUP_AUTH_USER/
mkdir /home/$SETUP_AUTH_USER/server/
mkdir /home/$SETUP_AUTH_USER/logs/
if [ -d "/home/$SETUP_AUTH_USER/source" ]; then
    if [ "$1" = "update" ]; then
        rm -rf "/home/$SETUP_AUTH_USER/source"; 
        if [ "$REPO_ENABLE_USER" = "true" ]; then
            git clone --single-branch --branch $CORE_BRANCH "$REPO_USER:$REPO_PASS@$CORE_REPO_URL" source
        else
            git clone --single-branch --branch $CORE_BRANCH "$CORE_REPO_URL" source
        fi
        break
    else
        while true; do
            read -p "Source already exists. Redownload? (y/n): " file_choice
            if [[ "$file_choice" =~ ^[Yy]$ ]]; then
                rm -rf /home/$SETUP_AUTH_USER/source/
                ## Source install
                if [ "$REPO_ENABLE_USER" = "true" ]; then
                    git clone --single-branch --branch $CORE_BRANCH "$REPO_USER:$REPO_PASS@$CORE_REPO_URL" source
                else
                    git clone --single-branch --branch $CORE_BRANCH "$CORE_REPO_URL" source
                fi
                break
            elif [[ "$file_choice" =~ ^[Nn]$ ]]; then
                echo "Skipping download." && break
            else
                echo "Please answer y (yes) or n (no)."
            fi
        done
    fi
else
    ## Source install
    if [ "$REPO_ENABLE_USER" = "true" ]; then
        git clone --single-branch --branch $CORE_BRANCH "$REPO_USER:$REPO_PASS@$CORE_REPO_URL" source
    else
        git clone --single-branch --branch $CORE_BRANCH "$CORE_REPO_URL" source
    fi
fi
if [ ! -d "/home/$SETUP_AUTH_USER/source/" ]; then
    echo "Source not found.... exiting..."
    exit 1
fi
if [ -f "/home/$SETUP_AUTH_USER/server/bin/authserver" ]; then
    if [ "$1" != "update" ]; then
        while true; do
            read -p "Authserver already exists. Recompile source? (y/n): " file_choice
            if [[ "$file_choice" =~ ^[Yy]$ ]]; then
                ## Build source
                echo "Building source...."
                cd /home/$SETUP_AUTH_USER/source/
                rm -rf /home/$SETUP_AUTH_USER/source/build
                mkdir /home/$SETUP_AUTH_USER/source/build
                cd /home/$SETUP_AUTH_USER/source/build
                cmake /home/$SETUP_AUTH_USER/source/ -DCMAKE_INSTALL_PREFIX=/home/$SETUP_AUTH_USER/server -DSCRIPTS=0 -DUSE_COREPCH=1 -DUSE_SCRIPTPCH=1 -DSERVERS=1 -DTOOLS=0 -DCMAKE_BUILD_TYPE=Release -DWITH_COREDEBUG=0 -DWITH_WARNINGS=0
                make -j $(( $(nproc) - 1 ))
                make install
                MAKE_INSTALLED="true"
                break
            elif [[ "$file_choice" =~ ^[Nn]$ ]]; then
                echo "Skipping download." && break
            else
                echo "Please answer y (yes) or n (no)."
            fi
        done
    else
        ## Build source
        echo "Building source...."
        cd /home/$SETUP_AUTH_USER/source/
        mkdir /home/$SETUP_AUTH_USER/source/build
        cd /home/$SETUP_AUTH_USER/source/build
        cmake /home/$SETUP_AUTH_USER/source/ -DCMAKE_INSTALL_PREFIX=/home/$SETUP_AUTH_USER/server -DSCRIPTS=0 -DUSE_COREPCH=1 -DUSE_SCRIPTPCH=1 -DSERVERS=1 -DTOOLS=0 -DCMAKE_BUILD_TYPE=Release -DWITH_COREDEBUG=0 -DWITH_WARNINGS=0
        make -j $(( $(nproc) - 1 ))
        make install
        MAKE_INSTALLED="true"
    fi
else
    ## Build source
    echo "Building source...."
    cd /home/$SETUP_AUTH_USER/source/
    mkdir /home/$SETUP_AUTH_USER/source/build
    cd /home/$SETUP_AUTH_USER/source/build
    cmake /home/$SETUP_AUTH_USER/source/ -DCMAKE_INSTALL_PREFIX=/home/$SETUP_AUTH_USER/server -DSCRIPTS=0 -DUSE_COREPCH=1 -DUSE_SCRIPTPCH=1 -DSERVERS=1 -DTOOLS=0 -DCMAKE_BUILD_TYPE=Release -DWITH_COREDEBUG=0 -DWITH_WARNINGS=0
    make -j $(( $(nproc) - 1 ))
    make install
    MAKE_INSTALLED="true"
fi
fi


((NUM++))
if [ "$1" = "all" ] || [ "$1" = "update" ] || [ "$1" = "$NUM" ]; then
echo ""
echo "##########################################################"
echo "## $NUM.Setup Config"
echo "##########################################################"
echo ""
if [ "$MAKE_INSTALLED" != "true" ]; then
cd /home/$SETUP_AUTH_USER/source/build
make install
fi
cd /home/$SETUP_AUTH_USER/server/etc/
if [ -f "authserver.conf.dist" ]; then
    mv -f "authserver.conf.dist" "authserver.conf"
    echo "Moved authserver.conf.dist to authserver.conf."
fi
## Changing Config values
echo "Changing Config values"
sed -i 's^LogsDir = "Logs"^LogsDir = "/home/'${SETUP_AUTH_USER}'/server/logs"^g' authserver.conf
sed -i 's^SourceDirectory  = ""^SourceDirectory = "/home/'${SETUP_AUTH_USER}'/source/"^g' authserver.conf
sed -i "s/Updates.EnableDatabases = 1/Updates.EnableDatabases = 0/g" authserver.conf
sed -i "s/Updates.AutoSetup   = 1/Updates.AutoSetup = 0/g" authserver.conf
sed -i "s/127.0.0.1;3306;root;root;auth/${AUTH_DB_HOST};3306;${AUTH_DB_USER};${AUTH_DB_PASS};${AUTH_DB_USER};/g" authserver.conf
fi


((NUM++))
if [ "$1" = "all" ] || [ "$1" = "update" ] || [ "$1" = "$NUM" ]; then
echo ""
echo "##########################################################"
echo "## $NUM.Setup Database Data"
echo "##########################################################"
echo ""
# Applying SQL base
SQL_FILE="/home/$SETUP_AUTH_USER/source/sql/base/auth.sql"
# Check if 'uptime' table exists in the 'auth' database
TABLE_CHECK=$(mysql -u "$ROOT_USER" -p"$ROOT_PASS" -e "SHOW TABLES LIKE 'uptime';" auth | grep -c "uptime")
if [ "$TABLE_CHECK" -gt 0 ]; then
    echo "'uptime' table exists. Skipping SQL execution."
else
    echo "'uptime' table does not exist. Proceeding to execute SQL file..."
    mysql -u "$ROOT_USER" -p"$ROOT_PASS" auth < "$SQL_FILE"
fi
fi


((NUM++))
if [ "$1" = "all" ] || [ "$1" = "$NUM" ]; then
echo ""
echo "##########################################################"
echo "## $NUM.Setup Restarter"
echo "##########################################################"
echo ""
mkdir /home/$SETUP_AUTH_USER/server/scripts/
mkdir /home/$SETUP_AUTH_USER/server/scripts/Restarter/
mkdir /home/$SETUP_AUTH_USER/server/scripts/Restarter/Auth/
sudo cp -r -u /Legends-Of-Azeroth-548-Auto-Installer/scripts/Restarter/Auth/* /home/$SETUP_AUTH_USER/server/scripts/Restarter/Auth/
## FIX SCRIPTS PERMISSIONS
sudo chmod +x /home/$SETUP_AUTH_USER/server/scripts/Restarter/Auth/start.sh
sed -i "s/realmname/$SETUP_AUTH_USER/g" /home/$SETUP_AUTH_USER/server/scripts/Restarter/Auth/start.sh
crontab -r
crontab -l | { cat; echo "############## START AUTHSERVER ##############"; } | crontab -
crontab -l | { cat; echo "@reboot /home/$SETUP_AUTH_USER/server/scripts/Restarter/Auth/start.sh"; } | crontab -
echo "Auth Crontab setup"
fi


((NUM++))
if [ "$1" = "all" ] || [ "$1" = "start" ] ||  [ "$1" = "$NUM" ]; then
echo ""
echo "##########################################################"
echo "## $NUM.Starting Authserver"
echo "##########################################################"
echo ""
/home/$SETUP_AUTH_USER/server/scripts/Restarter/Auth/start.sh
echo "Authserver started"
fi


((NUM++))
if [ "$1" = "all" ] || [ "$1" = "$NUM" ]; then
echo ""
echo "##########################################################"
echo "## AUTH INSTALLED AND FINISHED!"
echo "##########################################################"
echo ""
echo -e "\e[32m↓↓↓ To access the authserver - Run the following ↓↓↓\e[0m"
echo ""
echo -e "\e[32m→→→→→\e[0m screenauth"
echo ""
echo -e "\e[32m↓↓↓ To Install the Dev Realm - Run the following ↓↓↓\e[0m"
echo ""
echo -e "\e[32m→→→→→\e[0m rundev"
echo ""
echo ""
fi

fi
fi
