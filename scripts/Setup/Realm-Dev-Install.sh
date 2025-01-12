#!/bin/bash

### TRINITYCORE INSTALL SCRIPT
### TESTED WITH UBUNTU ONLY

. /Legends-Of-Azeroth-548-Auto-Installer/configs/root-config
. /Legends-Of-Azeroth-548-Auto-Installer/configs/auth-config
. /Legends-Of-Azeroth-548-Auto-Installer/configs/realm-dev-config

if [ $USER != "$SETUP_REALM_USER" ]; then
    echo "You must run this script under the $SETUP_REALM_USER user!"
    exit 1
fi

## LETS START
echo ""
echo "##########################################################"
echo "## DEV REALM INSTALL SCRIPT STARTING...."
echo "##########################################################"
echo ""
NUM=0
export DEBIAN_FRONTEND=noninteractive

if [ "$1" = "" ]; then
echo ""
echo "## No option selected, see list below"
echo ""
echo "- [all] : Run Full Script"
echo "- [stop] : Stop Worldserver"
echo "- [start] : Start Worldserver"
echo ""
((NUM++)); echo "- [$NUM] : Close Worldserver"
((NUM++)); echo "- [$NUM] : Setup MySQL Database & Users"
((NUM++)); echo "- [$NUM] : Pull and Setup Source"
((NUM++)); echo "- [$NUM] : Setup Worldserver Config"
((NUM++)); echo "- [$NUM] : Pull and Setup Database"
((NUM++)); echo "- [$NUM] : Download 5.4.8 Client"
((NUM++)); echo "- [$NUM] : Setup Client Tools"
((NUM++)); echo "- [$NUM] : Run Map/DBC Extractor"
((NUM++)); echo "- [$NUM] : Run VMap Extractor"
((NUM++)); echo "- [$NUM] : Run Mmaps Extractor"
((NUM++)); echo "- [$NUM] : Setup Realmlist"
((NUM++)); echo "- [$NUM] : Setup Linux Service"
((NUM++)); echo "- [$NUM] : Setup Misc Scripts"
((NUM++)); echo "- [$NUM] : Start Worldserver"
echo ""

else


NUM=0
((NUM++))
if [ "$1" = "all" ] || [ "$1" = "stop" ] ||  [ "$1" = "$NUM" ]; then
echo ""
echo "##########################################################"
echo "## $NUM.Closing Worldserver"
echo "##########################################################"
echo ""
sudo systemctl stop worldserverd
sudo pkill -u "$SETUP_REALM_USER" -f screen
fi


((NUM++))
if [ "$1" = "all" ] || [ "$1" = "$NUM" ]; then
echo ""
echo "##########################################################"
echo "## $NUM.Setup MySQL Database & Users"
echo "##########################################################"
echo ""

# World Database Setup
echo "Checking if the database '${REALM_DB_USER}_world' exists..."
if ! mysql -u "$ROOT_USER" -p"$ROOT_PASS" -e "SHOW DATABASES LIKE '${REALM_DB_USER}_world';" | grep -q "${REALM_DB_USER}_world"; then
    mysql -u "$ROOT_USER" -p"$ROOT_PASS" -e "CREATE DATABASE ${REALM_DB_USER}_world DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;"
    if [[ $? -eq 0 ]]; then
        echo "Database '${REALM_DB_USER}_world' created."
    else
        echo "Failed to create database '${REALM_DB_USER}_world'."
        exit 1
    fi
else
    echo "Database '${REALM_DB_USER}_world' already exists."
fi

echo "Checking if the database '${REALM_DB_USER}_character' exists..."
if ! mysql -u "$ROOT_USER" -p"$ROOT_PASS" -e "SHOW DATABASES LIKE '${REALM_DB_USER}_character';" | grep -q "${REALM_DB_USER}_character"; then
    mysql -u "$ROOT_USER" -p"$ROOT_PASS" -e "CREATE DATABASE ${REALM_DB_USER}_character DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;"
    if [[ $? -eq 0 ]]; then
        echo "Database '${REALM_DB_USER}_character' created."
    else
        echo "Failed to create database '${REALM_DB_USER}_character'."
        exit 1
    fi
else
    echo "Database '${REALM_DB_USER}_character' already exists."
fi

# Create the realm user if it does not already exist
echo "Checking if the realm user '${REALM_DB_USER}' exists..."
if ! mysql -u "$ROOT_USER" -p"$ROOT_PASS" -e "SELECT User FROM mysql.user WHERE User = '${REALM_DB_USER}' AND Host = 'localhost';" | grep -q "${REALM_DB_USER}"; then
    mysql -u "$ROOT_USER" -p"$ROOT_PASS" -e "CREATE USER '${REALM_DB_USER}'@'localhost' IDENTIFIED BY '$REALM_DB_PASS';"
    if [[ $? -eq 0 ]]; then
        echo "Realm DB user '${REALM_DB_USER}' created."
    else
        echo "Failed to create realm DB user '${REALM_DB_USER}'."
        exit 1
    fi
else
    echo "Realm DB user '${REALM_DB_USER}' already exists."
fi

# Grant privileges
echo "Granting privileges on '${REALM_DB_USER}_world' to '${REALM_DB_USER}'..."
if mysql -u "$ROOT_USER" -p"$ROOT_PASS" -e "GRANT ALL PRIVILEGES ON ${REALM_DB_USER}_world.* TO '${REALM_DB_USER}'@'localhost';"; then
    echo "Granted all privileges on '${REALM_DB_USER}_world' to '${REALM_DB_USER}'."
else
    echo "Failed to grant privileges on '${REALM_DB_USER}_world' to '${REALM_DB_USER}'."
    exit 1
fi

echo "Granting privileges on '${REALM_DB_USER}_character' to '${REALM_DB_USER}'..."
if mysql -u "$ROOT_USER" -p"$ROOT_PASS" -e "GRANT ALL PRIVILEGES ON ${REALM_DB_USER}_character.* TO '${REALM_DB_USER}'@'localhost';"; then
    echo "Granted all privileges on '${REALM_DB_USER}_character' to '${REALM_DB_USER}'."
else
    echo "Failed to grant privileges on '${REALM_DB_USER}_character' to '${REALM_DB_USER}'."
    exit 1
fi

# Flush privileges
mysql -u "$ROOT_USER" -p"$ROOT_PASS" -e "FLUSH PRIVILEGES;"
echo "Flushed privileges."
echo "Setup World DB Account completed."
fi


((NUM++))
if [ "$1" = "all" ] || [ "$1" = "update" ] || [ "$1" = "$NUM" ]; then
echo ""
echo "##########################################################"
echo "## $NUM. Pulling Source"
echo "##########################################################"
echo ""

SETUP_DIR="/home/$SETUP_REALM_USER"
SERVER_DIR="$SETUP_DIR/server"
SOURCE_DIR="$SETUP_DIR/source"

build_source() {
    echo "Building Source"
    cd "$SOURCE_DIR" || { echo "Failed to change directory to source. Exiting."; exit 1; }
    rm -rf "$SOURCE_DIR/build"
    mkdir "$SOURCE_DIR/build"
    cd "$SOURCE_DIR/build" || { echo "Failed to change to build directory. Exiting."; exit 1; }
    cmake "$SOURCE_DIR" \
        -DCMAKE_INSTALL_PREFIX="$SERVER_DIR" \
        -DWITH_DYNAMIC_LINKING=ON \
        -DSCRIPTS="dynamic" \
        -DSCRIPTS_CUSTOM="dynamic" \
        -DUSE_COREPCH=1 \
        -DUSE_SCRIPTPCH=1 \
        -DSERVERS=1 \
        -DTOOLS=1 \
        -DCMAKE_BUILD_TYPE=RelWithDebInfo \
        -DWITH_COREDEBUG=0 \
        -DWITH_WARNINGS=0 || { echo "CMake failed. Exiting."; exit 1; }
    make -j $(( $(nproc) - 1 )) || { echo "Build failed. Exiting."; exit 1; }
    make install || { echo "Install failed. Exiting."; exit 1; }
}

mkdir -p "$SERVER_DIR/logs/crashes" "$SERVER_DIR/data"

if [ -d "$SOURCE_DIR" ]; then
    if [ "$1" = "update" ]; then
        rm -rf "$SOURCE_DIR"; 
        if [ "$REPO_ENABLE_USER" = "true" ]; then
            git clone --single-branch --branch $CORE_BRANCH "https://$REPO_USER:$REPO_USER@$CORE_REPO_URL" "$SOURCE_DIR";
        else
            git clone --single-branch --branch $CORE_BRANCH "$CORE_REPO_URL" "$SOURCE_DIR";
        fi
    else
        while true; do
            read -p "Source already exists. Redownload? (y/n): " file_choice
            case "$file_choice" in
                [Yy]*) 
                rm -rf "$SOURCE_DIR"; 
                if [ "$REPO_ENABLE_USER" = "true" ]; then
                    git clone --single-branch --branch $CORE_BRANCH "https://$REPO_USER:$REPO_USER@$CORE_REPO_URL" "$SOURCE_DIR";
                else
                    git clone --single-branch --branch $CORE_BRANCH "$CORE_REPO_URL" "$SOURCE_DIR";
                fi
                break ;;
                [Nn]*) echo "Skipping download."; break ;;
                *) echo "Please answer y (yes) or n (no)." ;;
            esac
        done
    fi
else
    if [ "$REPO_ENABLE_USER" = "true" ]; then
        git clone --single-branch --branch $CORE_BRANCH "https://$REPO_USER:$REPO_USER@$CORE_REPO_URL" "$SOURCE_DIR";
    else
        git clone --single-branch --branch $CORE_BRANCH "$CORE_REPO_URL" "$SOURCE_DIR";
    fi
fi

if [ ! -d "$SOURCE_DIR" ]; then
    echo "Source not found, somehow didn't clone... cancelling..."
    exit 1
fi

if [ -f "$SERVER_DIR/bin/worldserver" ]; then
    if [ "$1" != "update" ]; then
        while true; do
            read -p "Worldserver already exists. Recompile source? (y/n): " file_choice
            case "$file_choice" in
                [Yy]*) build_source; break ;;
                [Nn]*) echo "Skipping rebuild."; break ;;
                *) echo "Please answer y (yes) or n (no)." ;;
            esac
        done
    else
        build_source
    fi
else
    build_source
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
cd /home/$SETUP_REALM_USER/source/build
make install
fi
cd /home/$SETUP_REALM_USER/server/etc/
mv -f worldserver.conf.dist worldserver.conf
## Changing Config values
echo "Changing Config values"
## Misc Edits
sed -i 's/RealmID = 1/RealmID = '${REALM_ID}'/g' worldserver.conf
sed -i 's/WorldServerPort = 8085/WorldServerPort = '${SETUP_REALM_PORT}'/g' worldserver.conf
sed -i 's/RealmZone = 1/RealmZone = '${REALM_ZONE}'/g' worldserver.conf
sed -i 's/mmap.enablePathFinding = 0/mmap.enablePathFinding = 1/g' worldserver.conf
## Folders
sed -i 's^LogsDir = "Logs"^LogsDir = "/home/'${SETUP_REALM_USER}'/server/logs"^g' worldserver.conf
sed -i 's^DataDir = "Data"^DataDir = "/home/'${SETUP_REALM_USER}'/server/data"^g' worldserver.conf
sed -i 's^BuildDirectory  = ""^BuildDirectory  = "/home/'${SETUP_REALM_USER}'/source/build"^g' worldserver.conf
sed -i 's^SourceDirectory  = ""^SourceDirectory  = "/home/'${SETUP_REALM_USER}'/source/"^g' worldserver.conf
sed -i "s/Updates.EnableDatabases = 1/Updates.EnableDatabases = 0/g" worldserver.conf
sed -i "s/Updates.AutoSetup   = 1/Updates.AutoSetup = 0/g" worldserver.conf
REALM_NAME=$(printf '%s\n' "$REALM_NAME" | sed "s/'/'\\\\''/g")
sed -i "s|Welcome to a Pandaria server.|Welcome to the '${REALM_NAME}'|g" worldserver.conf
sed -i '/^PlayerLimit/s/= 100$/= 10000/' worldserver.conf
## DatabaseInfo
sed -i "s|127.0.0.1;3306;root;root;auth|${AUTH_DB_HOST};3306;${AUTH_DB_USER};${AUTH_DB_PASS};${AUTH_DB_USER}|g" worldserver.conf
sed -i "s|127.0.0.1;3306;root;root;world|${REALM_DB_HOST};3306;${REALM_DB_USER};${REALM_DB_PASS};${REALM_DB_USER}_world|g" worldserver.conf
sed -i "s|127.0.0.1;3306;root;root;characters|${REALM_DB_HOST};3306;${REALM_DB_USER};${REALM_DB_PASS};${REALM_DB_USER}_character|g" worldserver.conf
fi


((NUM++))
if [ "$1" = "all" ] || [ "$1" = "update" ] || [ "$1" = "$NUM" ]; then
echo ""
echo "##########################################################"
echo "## $NUM.Setup Database Data"
echo "##########################################################"
echo ""
FILENAME="${DB_REPO_URL##*/}"           # Get the filename from the URL
FOLDERNAME="${FILENAME%.7z}"  # Removes .7z from the filename
SQLNAME="${FOLDERNAME}.sql"  # Appends .sql to the filename
TARGET_DIR="/home/$SETUP_REALM_USER/source/sql/base/"
cd "$TARGET_DIR" || { echo "Directory does not exist: $TARGET_DIR"; exit 1; }
if [ -d "$TARGET_DIR/$FOLDERNAME" ]; then
	while true; do
		read -p "$FOLDERNAME already exists. Redownload? (y/n): " file_choice
		if [[ "$file_choice" =~ ^[Yy]$ ]]; then
			rm -rf $TARGET_DIR/$FOLDERNAME
			sudo wget "$DB_REPO_URL"
			break
		elif [[ "$file_choice" =~ ^[Nn]$ ]]; then
			echo "Skipping download." && break
		else
			echo "Please answer y (yes) or n (no)."
		fi
	done
else
	sudo wget "$DB_REPO_URL"
fi

# Ensure the file exists before extracting
if [ -f "$FILENAME" ]; then
    7z x "$FILENAME" -o"$TARGET_DIR" -y
    rm -f "$TARGET_DIR/$FILENAME"
    sudo chown $SETUP_REALM_USER:$SETUP_REALM_USER $TARGET_DIR/$SQLNAME
    sudo chmod +x $TARGET_DIR/$SQLNAME
fi

# World
# Applying SQL base
SQL_FILE="/home/$SETUP_REALM_USER/source/sql/base/$SQLNAME"
# Check if 'world_map_template' table exists in the '${SETUP_REALM_USER}_world' database
TABLE_CHECK=$(mysql -u "$ROOT_USER" -p"$ROOT_PASS" -e "SHOW TABLES LIKE 'world_map_template';" ${SETUP_REALM_USER}_world | grep -c "world_map_template")
if [ "$TABLE_CHECK" -gt 0 ]; then
    echo "'world_map_template' table exists. Skipping SQL execution."
else
    echo "'world_map_template' table does not exist. Proceeding to execute SQL file..."
    echo "THIS MAY TAKE A WHILE DUE TO SQL FILE SIZE!!!!...please be patient"
    mysql -u "$ROOT_USER" -p"$ROOT_PASS" ${SETUP_REALM_USER}_world < "$SQL_FILE"
fi

# Function to apply SQL updates in the specified directory to the specified database
apply_sql_updates() 
{
    UPDATES_DIR="$1"
    TARGET_DB="$2"

    # Ensure the updates directory exists
    if [ ! -d "$UPDATES_DIR" ]; then
        echo "Error: Directory $UPDATES_DIR does not exist."
        return 1
    fi

    # Get the list of SQL files sorted by date (based on filename)
    SQL_FILES=$(ls "$UPDATES_DIR"/*.sql 2>/dev/null | sort)

    if [ -z "$SQL_FILES" ]; then
        echo "No SQL files found in $UPDATES_DIR."
        return 0
    fi

    echo "Processing SQL updates from $UPDATES_DIR for database $TARGET_DB."

    # Process each SQL file
    for FILE in $SQL_FILES; do
        FILENAME=$(basename "$FILE")
        FILE_HASH=$(sha1sum "$FILE" | awk '{print $1}')

        # Check if the update has already been applied
        QUERY="SELECT COUNT(*) FROM updates WHERE name = '$FILENAME' AND hash = '$FILE_HASH';"
        ALREADY_APPLIED=$(mysql -u "$ROOT_USER" -p"$ROOT_PASS" -D "$TARGET_DB" -se "$QUERY")
        
        if [ "$ALREADY_APPLIED" -eq 0 ]; then
            echo "Applying update: $FILENAME"
            
            # Record the start time
            START_TIME=$(date +%s%3N)
            
            # Apply the SQL file
            mysql -u "$ROOT_USER" -p"$ROOT_PASS" -D "$TARGET_DB" < "$FILE"
            if [ $? -eq 0 ]; then
                END_TIME=$(date +%s%3N)
                SPEED=$((END_TIME - START_TIME))
                echo "Successfully applied $FILENAME in ${SPEED}ms."
                
                # Insert the update into the `updates` table
                INSERT_QUERY="INSERT INTO updates (name, hash, state, timestamp, speed) VALUES ('$FILENAME', '$FILE_HASH', 'RELEASED', NOW(), $SPEED);"
                mysql -u "$ROOT_USER" -p"$ROOT_PASS" -D "$TARGET_DB" -se "$INSERT_QUERY"
                
                if [ $? -eq 0 ]; then
                    echo "Recorded $FILENAME in updates table."
                else
                    echo "Error recording $FILENAME in updates table."
                fi
            else
                echo "Error applying $FILENAME. Exiting."
                return 1
            fi
        else
            echo "Update $FILENAME with hash $FILE_HASH has already been applied. Skipping."
        fi
    done

    echo "All updates processed for database $TARGET_DB."
    return 0
}

# All World updates after base import
apply_sql_updates "/home/$SETUP_REALM_USER/source/sql/updates/world" "${SETUP_REALM_USER}_world"

# Character
# Applying SQL base
SQL_FILE="/home/$SETUP_REALM_USER/source/sql/base/characters.sql"
# Check if 'worldstates' table exists in the '${SETUP_REALM_USER}_character' database
TABLE_CHECK=$(mysql -u "$ROOT_USER" -p"$ROOT_PASS" -e "SHOW TABLES LIKE 'worldstates';" ${SETUP_REALM_USER}_character | grep -c "worldstates")
if [ "$TABLE_CHECK" -gt 0 ]; then
    echo "'worldstates' table exists. Skipping SQL execution."
else
    echo "'worldstates' table does not exist. Proceeding to execute SQL file..."
    mysql -u "$ROOT_USER" -p"$ROOT_PASS" ${SETUP_REALM_USER}_character < "$SQL_FILE"
fi

fi


((NUM++))
if [ "$1" = "all" ] || [ "$1" = "$NUM" ]; then
echo ""
echo "##########################################################"
echo "## $NUM.Download 5.4.8 Client"
echo "##########################################################"
echo ""
FILENAME="${CLIENT_URL##*/}"
cd /home/
if [ -f "$FILENAME" ]; then
    while true; do
        read -p "$FILENAME already exists. Redownload? (y/n): " file_choice
        if [[ "$file_choice" =~ ^[Yy]$ ]]; then
            rm "$FILENAME" && sudo wget $CLIENT_URL && break
        elif [[ "$file_choice" =~ ^[Nn]$ ]]; then
            echo "Skipping download." && break
        else
            echo "Please answer y (yes) or n (no)."
        fi
    done
else
    while true; do
        read -p "Would you like to download the full 548 Client? (y/n): " file_choice
        if [[ "$file_choice" =~ ^[Yy]$ ]]; then
            sudo wget $CLIENT_URL
        elif [[ "$file_choice" =~ ^[Nn]$ ]]; then
            echo "Skipping download." && break
            DOWNLOAD_SKIPPED="true"
        else
            echo "Please answer y (yes) or n (no)."
        fi
    done
fi
if [ -d "/home/WoW548" ]; then
    while true; do
        read -p "WoW548 Folder already exists. Reextract? (y/n): " folder_choice
        if [[ "$folder_choice" =~ ^[Yy]$ ]]; then
            sudo unzip "$FILENAME" && break
        elif [[ "$folder_choice" =~ ^[Nn]$ ]]; then
            echo "Skipping extraction." && break
        else
            echo "Please answer y (yes) or n (no)."
        fi
    done
else
	sudo unzip "$FILENAME"
fi
if [ "$DOWNLOAD_SKIPPED" != "true" ]; then
    if [ -d "/home/MOP-5.4.8.18414-enUS-Repack" ]; then
        sudo mv -f /home/MOP-5.4.8.18414-enUS-Repack /home/WoW548
    fi
    if [ -d "/home/WoW548" ]; then
        sudo chmod -R 777 /home/WoW548
    fi
fi
if [ -f "/home/$FILENAME" ]; then
    while true; do
        read -p "Would you like to delete the 5.4.8 client zip folder to save folder space? (y/n): " folder_choice
        if [[ "$folder_choice" =~ ^[Yy]$ ]]; then
            if [ "$DOWNLOAD_SKIPPED" != "true" ]; then
            sudo rm $FILENAME
            fi
            break
        elif [[ "$folder_choice" =~ ^[Nn]$ ]]; then
            echo "Skipping deletion." && break
        else
            echo "Please answer y (yes) or n (no)."
        fi
    done
fi
fi


((NUM++))
if [ "$1" = "all" ] || [ "$1" = "$NUM" ]; then
echo ""
echo "##########################################################"
echo "## $NUM.Setup Client Tools"
echo "##########################################################"
echo ""
if [ "$DOWNLOAD_SKIPPED" == "true" ]; then
cp /home/$SETUP_REALM_USER/server/bin/mapextractor /home/WoW548/
cp /home/$SETUP_REALM_USER/server/bin/vmap4extractor /home/WoW548/
cp /home/$SETUP_REALM_USER/server/bin/mmaps_generator /home/WoW548/
cp /home/$SETUP_REALM_USER/server/bin/vmap4assembler /home/WoW548/
echo "Client tools copied over to /home/WoW548"
else
echo "No need to setup client tools as client download disabled."
fi
fi


((NUM++))
if [ "$1" = "all" ] || [ "$1" = "$NUM" ]; then
echo ""
echo "##########################################################"
echo "## $NUM.Run Map/DBC Extractor"
echo "##########################################################"
echo ""
cd /home/WoW548/
if [ -d "/home/WoW548/maps" ]; then
    while true; do
        read -p "maps Folder already exists. Reextract? (y/n): " folder_choice
        if [[ "$folder_choice" =~ ^[Yy]$ ]]; then
            if [ "$DOWNLOAD_SKIPPED" != "true" ]; then
                ./mapextractor
            fi
            break
        elif [[ "$folder_choice" =~ ^[Nn]$ ]]; then
            echo "Skipping extraction." && break
        else
            echo "Please answer y (yes) or n (no)."
        fi
    done
else
    if [ "$DOWNLOAD_SKIPPED" != "true" ]; then
        ./mapextractor
    fi
fi
if [ ! -d "/home/WoW548/maps" ]; then
    while true; do
        read -p "Would you like to copy the maps/dbc data folders? (y/n): " folder_choice
        if [[ "$folder_choice" =~ ^[Yy]$ ]]; then
            if [ "$DOWNLOAD_SKIPPED" != "true" ]; then
                echo "Copying dbc folder"
                cp -r /home/WoW548/dbc /home/$SETUP_REALM_USER/server/data/
                echo "Copying Cameras folder"
                cp -r /home/WoW548/Cameras /home/$SETUP_REALM_USER/server/data/
                echo "Copying maps folder"
                cp -r /home/WoW548/maps /home/$SETUP_REALM_USER/server/data/
            fi
            break
        elif [[ "$folder_choice" =~ ^[Nn]$ ]]; then
            echo "Skipping data copy." && break
        else
            echo "Please answer y (yes) or n (no)."
        fi
    done
fi
fi

((NUM++))
if [ "$1" = "all" ] || [ "$1" = "$NUM" ]; then
echo ""
echo "##########################################################"
echo "## $NUM.Run VMap Extractor"
echo "##########################################################"
echo ""
cd /home/WoW548/
if [ -d "/home/WoW548/vmaps" ]; then
    while true; do
        read -p "vmaps Folder already exists. Reextract? (y/n): " folder_choice
        if [[ "$folder_choice" =~ ^[Yy]$ ]]; then
            if [ "$DOWNLOAD_SKIPPED" != "true" ]; then
                ./vmap4extractor && ./vmap4assembler
            fi
            break
        elif [[ "$folder_choice" =~ ^[Nn]$ ]]; then
            echo "Skipping extraction." && break
        else
            echo "Please answer y (yes) or n (no)."
        fi
    done
else
    if [ "$DOWNLOAD_SKIPPED" != "true" ]; then
        ./vmap4extractor && ./vmap4assembler
    fi
fi
if [ ! -d "/home/WoW548/vmaps" ]; then
    while true; do
        read -p "Would you like to copy the vmap data folders? (y/n): " folder_choice
        if [[ "$folder_choice" =~ ^[Yy]$ ]]; then
            if [ "$DOWNLOAD_SKIPPED" != "true" ]; then
                echo "Copying Buildings folder"
                cp -r /home/WoW548/Buildings /home/$SETUP_REALM_USER/server/data/
                echo "Copying vmaps folder"
                cp -r /home/WoW548/vmaps /home/$SETUP_REALM_USER/server/data/
            fi
            break
        elif [[ "$folder_choice" =~ ^[Nn]$ ]]; then
            echo "Skipping data copy." && break
        else
            echo "Please answer y (yes) or n (no)."
        fi
    done
fi
fi

((NUM++))
if [ "$1" = "all" ] || [ "$1" = "$NUM" ]; then
echo ""
echo "##########################################################"
echo "## $NUM.Run Mmaps Extractor"
echo "##########################################################"
echo ""
cd /home/WoW548/
if [ -d "/home/WoW548/mmaps" ]; then
    while true; do
        read -p "mmaps Folder already exists. Reextract? (y/n): " folder_choice
        if [[ "$folder_choice" =~ ^[Yy]$ ]]; then
            if [ "$DOWNLOAD_SKIPPED" != "true" ]; then
                ./mmaps_generator
            fi
            break
        elif [[ "$folder_choice" =~ ^[Nn]$ ]]; then
            echo "Skipping extraction." && break
        else
            echo "Please answer y (yes) or n (no)."
        fi
    done
else
    if [ "$DOWNLOAD_SKIPPED" != "true" ]; then
	    ./mmaps_generator
    fi
fi
if [ ! -d "/home/WoW548/mmaps" ]; then
    while true; do
        read -p "Would you like to copy the mmaps data folders? (y/n): " folder_choice
        if [[ "$folder_choice" =~ ^[Yy]$ ]]; then
            if [ "$DOWNLOAD_SKIPPED" != "true" ]; then
                echo "Copying mmaps folder"
                cp -r /home/WoW548/mmaps /home/$SETUP_REALM_USER/server/data/
            fi
            break
        elif [[ "$folder_choice" =~ ^[Nn]$ ]]; then
            echo "Skipping data copy." && break
        else
            echo "Please answer y (yes) or n (no)."
        fi
    done
fi
fi

((NUM++))
if [ "$1" = "all" ] || [ "$1" = "update" ] || [ "$1" = "$NUM" ]; then
echo ""
echo "##########################################################"
echo "## $NUM.Update Realmlist"
echo "##########################################################"
echo ""
if [ $SETUP_REALMLIST == "true" ]; then
# Get the external IP address
EXTERNAL_IP=$(curl -s -4 http://ifconfig.me/ip)
mysql --host=$REALM_DB_HOST -h $AUTH_DB_HOST -u $AUTH_DB_USER -p$AUTH_DB_PASS << EOF
use auth
DELETE from realmlist where id = $REALM_ID;
REPLACE INTO realmlist VALUES ('$REALM_ID', '$REALM_NAME', '$EXTERNAL_IP', '$SETUP_REALM_PORT', '127.0.0.1', '255.255.255.0', '0', '0', '$REALM_ZONE', '$REALM_SECURITY', '0', '18414');
quit
EOF
fi
fi


((NUM++))
if [ "$1" = "all" ] || [ "$1" = "$NUM" ]; then
echo ""
echo "##########################################################"
echo "## $NUM.Setup Linux Service"
echo "##########################################################"
echo ""
# Make Folders
mkdir /home/$SETUP_REALM_USER/server/scripts/
mkdir /home/$SETUP_REALM_USER/server/scripts/Restarter/
mkdir /home/$SETUP_REALM_USER/server/scripts/Restarter/World/
sudo cp -r -u /Legends-Of-Azeroth-548-Auto-Installer/scripts/Restarter/World/* /home/$SETUP_REALM_USER/server/scripts/Restarter/World/
# Fix Permissions
sudo chmod +x /home/$SETUP_REALM_USER/server/scripts/Restarter/World/GDB/start_gdb.sh
sudo chmod +x /home/$SETUP_REALM_USER/server/scripts/Restarter/World/GDB/restarter_world_gdb.sh
sudo chmod +x /home/$SETUP_REALM_USER/server/scripts/Restarter/World/GDB/gdbcommands
sudo chmod +x /home/$SETUP_REALM_USER/server/scripts/Restarter/World/Normal/start.sh
sudo chmod +x /home/$SETUP_REALM_USER/server/scripts/Restarter/World/Normal/restarter_world.sh
# Update script names
sudo sed -i "s/realmname/$SETUP_REALM_USER/g" /home/$SETUP_REALM_USER/server/scripts/Restarter/World/GDB/start_gdb.sh
sudo sed -i "s/realmname/$SETUP_REALM_USER/g" /home/$SETUP_REALM_USER/server/scripts/Restarter/World/Normal/start.sh
# Setup Crontab
crontab -r
if [ $SETUP_TYPE == "GDB" ]; then
	echo "Setup Restarter in GDB mode...."
	crontab -l | { cat; echo "############## START WORLD ##############"; } | crontab -
	crontab -l | { cat; echo "#### GDB WORLD"; } | crontab -
	crontab -l | { cat; echo "@reboot /home/$SETUP_REALM_USER/server/scripts/Restarter/World/GDB/start_gdb.sh"; } | crontab -
	crontab -l | { cat; echo "#### NORMAL WORLD"; } | crontab -
	crontab -l | { cat; echo "#@reboot /home/$SETUP_REALM_USER/server/scripts/Restarter/World/Normal/start.sh"; } | crontab -
fi
if [ $SETUP_TYPE == "Normal" ]; then
	echo "Setup Restarter in Normal mode...."
	crontab -l | { cat; echo "############## START WORLD ##############"; } | crontab -
	crontab -l | { cat; echo "#### GDB WORLD"; } | crontab -
	crontab -l | { cat; echo "#@reboot /home/$SETUP_REALM_USER/server/scripts/Restarter/World/GDB/start_gdb.sh"; } | crontab -
	crontab -l | { cat; echo "#### NORMAL WORLD"; } | crontab -
	crontab -l | { cat; echo "@reboot /home/$SETUP_REALM_USER/server/scripts/Restarter/World/Normal/start.sh"; } | crontab -
fi

fi


((NUM++))
if [ "$1" = "all" ] || [ "$1" = "$NUM" ]; then
echo ""
echo "##########################################################"
echo "## $NUM.Setup Misc Scripts"
echo "##########################################################"
echo ""
cp -r -u /Legends-Of-Azeroth-548-Auto-Installer/scripts/Setup/Clean-Logs.sh /home/$SETUP_REALM_USER/server/scripts/
sudo chmod +x  /home/$SETUP_REALM_USER/server/scripts/Clean-Logs.sh
cd /home/$SETUP_REALM_USER/server/scripts/
sudo sed -i "s^USER^${SETUP_REALM_USER}^g" Clean-Logs.sh
# Setup Crontab
crontab -l | { cat; echo "############## MISC SCRIPTS ##############"; } | crontab -
crontab -l | { cat; echo "* */1* * * * /home/$SETUP_REALM_USER/server/scripts/Clean-Logs.sh"; } | crontab -
echo "$SETUP_REALM_USER Realm Crontab setup"
fi


((NUM++))
if [ "$1" = "all" ] || [ "$1" = "start" ] ||  [ "$1" = "$NUM" ]; then
echo ""
echo "##########################################################"
echo "## $NUM.Start Server"
echo "##########################################################"
echo ""
if [ $SETUP_TYPE == "GDB" ]; then
    echo "REALM STARTED IN GDB MODE!"
    /home/$SETUP_REALM_USER/server/scripts/Restarter/World/GDB/start_gdb.sh
fi
if [ $SETUP_TYPE == "Normal" ]; then
    echo "REALM STARTED IN NORMAL MODE!"
    /home/$SETUP_REALM_USER/server/scripts/Restarter/World/Normal/start.sh
fi
fi


echo ""
echo "##########################################################"
echo "## DEV REALM INSTALLED AND FINISHED!"
echo "##########################################################"
echo ""
echo -e "\e[32m↓↓↓ To access the worldserver - Run the following ↓↓↓\e[0m"
echo ""
echo "screendev"
echo ""
echo ""
echo -e "\e[32m↓↓↓ To access the authserver - Run the following ↓↓↓\e[0m"
echo ""
echo "screenauth"
echo ""
echo ""

fi

