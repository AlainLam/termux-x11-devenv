#!/bin/bash
# Author: https://www.alainlam.cn

# APK Requirements
echo "This script requires the installation of the following applications:"
echo "Termux: https://f-droid.org/repo/com.termux_118.apk"
echo "Termux-x11: https://github.com/termux/termux-x11/suites/16954107083/artifacts/968612187"
echo "Termux-API: https://f-droid.org/repo/com.termux.api_51.apk"
echo "Termux-Widget: https://f-droid.org/repo/com.termux.widget_13.apk"

# Clear the input buffer
read -t 1 -n 10000 discard

is_installed_apps=""
while [[ $is_installed_apps != "Y" && $is_installed_apps != "y" ]]; do
    read -p "Have you already installed all the applications?:(Y) " is_installed_apps
done

# Install the repo
echo "Installing the x11-repo root-repo"
pkg install x11-repo root-repo -y

# Update the package to latest
echo "Update the package"
pkg upgrade -y

# OpenSSH
is_install_ssh=""

while [[ $is_install_ssh != "Y" && $is_install_ssh != "y" && $is_install_ssh != "N" && $is_install_ssh != "n" ]]; do
    read -p "Do you want to install the OpenSSH:(Y/n) " is_install_ssh
done

if [[ $is_install_ssh == "Y" || $is_install_ssh == "y" ]]; then
    pkg install openssh -y
    echo "Installed the OpenSSH, Please setup your password"
    passwd
else
    echo "Skip install the OpenSSH"
fi

# Prompt the storage permissions
is_require_storage=""

while [[ $is_require_storage != "Y" && $is_require_storage != "y" && $is_require_storage != "N" && $is_require_storage != "n" ]]; do
    read -p "Do you want to grant storage permissions for termux:(Y/n) " is_require_storage
done

if [[ $is_require_storage == "Y" || $is_require_storage == "y" ]]; then
    termux-setup-storage
else
    echo "Skip grant storage permissions"
fi

# Set up the Desktop Environment
pkg install termux-x11-nightly pulseaudio virglrenderer-android -y

# Install the Proot-distro
pkg install proot-distro -y

# Install the Debian
proot-distro install debian

# Update the package to latest
echo "Debian ENV: Updating the package to latest"
proot-distro login debian --shared-tmp -- bash -c "apt update && apt dist-upgrade -y"

# Install the some software to the Debian ENV
echo "Debian ENV: Installing the sudo nano wget firefox-esr p7zip-full"
proot-distro login debian --shared-tmp -- bash -c "apt-get install sudo nano wget firefox-esr p7zip-full -y"

# Create a normal user
echo "Debian ENV: Please create a normal user so that you can use it to login to xfce4 env"
echo "Debian ENV: Please enter your username:"
read normal_user_name
while [[ -z $normal_user_name ]]; do
    echo "Debian ENV: username can not be empty"
    read -p "Debian ENV: Please enter your username:" normal_user_name
done
proot-distro login debian --shared-tmp -- bash -c "adduser $normal_user_name"

# Grant the user sudo privileges.
echo "Debian ENV: Grant $normal_user_name sudo privileges."
proot-distro login debian --shared-tmp -- bash -c "sed -i \"/^root\s*ALL=(ALL:ALL)\s*ALL$/a $normal_user_name   ALL=(ALL:ALL) ALL\" /etc/sudoers"

# Add user to video and audio groups.
echo "Debian ENV: Add $normal_user_name to video and audio groups"
proot-distro login debian --shared-tmp -- bash -c "usermod -aG audio,video alain"

# Create a logs directory to save some log
user_log_directory="~/log"
proot-distro login debian --shared-tmp --user $normal_user_name -- bash -c "mkdir $user_log_directory"

# Setup the timezone
echo "Setup the timezone"
proot-distro login debian --shared-tmp -- bash -c "tz=\$(tzselect) && ln -sf /usr/share/zoneinfo/\$tz /etc/localtime && echo \"Update the timezone to: \$tz\""

# Fixing Chinese, Japanese, and Korean garbled characters.
# reference: https://wiki.archlinuxcn.org/wiki/Locale
# dpkg-reconfigure locales && locale
proot-distro login debian --shared-tmp -- bash -c "apt install locales fonts-noto-cjk -y"

# Update the default locate
locale_updates='
# Print /etc/locale.gen to the screen with the numbers
locale_list=$(cat /etc/locale.gen)
c_locale_line=$(grep -n "#[[:space:]]*C.UTF-8[[:space:]]*UTF-8" /etc/locale.gen | cut -d '\'':'\'' -f 1)
locale_list=$(echo "$locale_list" | tail -n "+$c_locale_line")

locale_num=0
while IFS= read -r line; do
    locale_num=$((locale_num + 1))
    line=${line#"#"[[:space:]]*}
    printf "%d.\t%s\n" "$locale_num" "$line"
done <<<"$locale_list"

# Prompt user to select a locale
valid_locale_selection=false
while [ "$valid_locale_selection" = false ]; do
    read -p "Please select a locale for you(number): " selection
    
    # Check if the input is a valid number
    if [[ "$selection" =~ ^[0-9]+$ ]]; then
        # Check if the selected number is within the range of available options
        if ((selection >= 1 && selection <= locale_num)); then
            valid_locale_selection=true
        fi
    fi
    
    if [ "$valid_locale_selection" = false ]; then
        echo "Invalid input. Please enter a valid number."
    fi
done

# Get the target item
real_selected_line=$((selection + c_locale_line - 1))

# Uncomment the selected item and remove leading spaces
sed -i "${real_selected_line}s/^#[[:space:]]*//" /etc/locale.gen
locale_selected=$(sed -n "${real_selected_line}p" /etc/locale.gen)
echo "$locale_selected"

# Reconfigure locales
locale-gen

# Add export statement to .profile
locale_selected=$(echo $locale_selected | cut -d" " -f1)
echo "export LANG=$locale_selected" >> /home/'"$normal_user_name"'/.profile
'

proot-distro login debian --shared-tmp -- bash -c "$locale_updates"

# Install the xfce4
echo "Debian ENV: Installing the xfce4 and xfce4-goodies"
proot-distro login debian --shared-tmp -- bash -c "apt install xfce4 xfce4-goodies -y"

# Install the input method
echo "Debian ENV: Installing the input method"
proot-distro login debian --shared-tmp -- bash -c "apt install fcitx5* -y"

# Download the Android SDK build tools method
download_build_tools='
echo "Debian ENV: Downlading Android SDK build tools for aarch64"
sdk_tools_folder="~/Android/android-sdk-tools"
if [[ ! -d $sdk_tools_folder ]]; then
    mkdir -p $sdk_tools_folder
    echo "Debian ENV: Please see also:"
    echo "Debian ENV: https://github.com/termux/termux-packages/issues/8350"
    echo "Debian ENV: https://github.com/lzhiyong/android-sdk-tools"
    echo "Debian ENV: https://github.com/lzhiyong/android-sdk-tools/releases"

    cd ~/Downloads
    # Get the compiled tools
    wget https://github.com/lzhiyong/android-sdk-tools/releases/download/34.0.3/android-sdk-tools-static-aarch64.zip

    # Decompress compressed files
    unzip android-sdk-tools-static-aarch64.zip

    mkdir ~/Android/android-sdk-tools
    # Move the tools
    mv platform-tools ~/Android/android-sdk-tools/
    mv build-tools ~/Android/android-sdk-tools/
else
    echo "Debian ENV: $sdk_tools_folder exist, skip..."
    echo "Debian ENV: If the directory is emtpy, please delete the directory, and redownload the files!"
fi
'

# Install the Android Studio
fixes_sdk_tools='#!/bin/bash
# Author: https://www.alainlam.cn

#### Define Variables
ANDROID_SDK_PATH=$ANDROID_SDK_HOME
MONITOR_DIRS=("platform-tools" "build-tools")
TARGET_DIRS=("/home/alain/Android/android-sdk-tools")

#### Download and Compile Tools
# if [ ! -d "$TARGET_DIRS" ]; then
#     mkdir -p ~/Download && cd ~/Downloads
#     # v34.0.3
#     wget https://github.com/lzhiyong/android-sdk-tools/releases/download/34.0.3/android-sdk-tools-static-aarch64.zip
#     # Extract
#     unzip android-sdk-tools-static-aarch64.zip
#     # Create directories
#     mkdir $TARGET_DIRS
#     # Move to specified directory
#     mv platform-tools $TARGET_DIRS
#     mv build-tools $TARGET_DIRS
# fi
####

#### Monitor SDK Directory for File Changes
checking_files() {
    local checking_file=$1
    file_name=$(basename "$checking_file")

    # If it is a directory, we need to traverse the entire directory again
    # as it may be a case of the entire directory being moved in
    if [ -d "$checking_file" ]; then
        files=($(ls "$checking_file"))
        for file in "${files[@]}"; do
            checking_files "$checking_file/$file"
        done
    else
        # Skip files that are already symbolic links
        if [ ! -L "$checking_file" ]; then
            target_file=""
            for dir in "${TARGET_DIRS[@]}"; do
                # Check if the corresponding file exists in the compilation tool directory
                target_file=$(find "$dir" -name "$file_name" -type f -print -quit)
                # If the file is found, break the loop
                if [ -n "$target_file" ]; then
                    break
                fi
            done

            # Found corresponding compilation tool file
            if [ -n "$target_file" ]; then
                # Remove the original compilation tool file
                rm -rf "$checking_file"
                # Create symbolic link
                ln -s "$target_file" "$checking_file"
                echo "Created symlink $checking_file -> $target_file"
            fi
        fi
    fi
}
# Set up file monitoring
inotifywait --exclude '\''^.*\.temp/.*\'' -mrq -e create,move "$ANDROID_SDK_PATH" | while read -r directory event file; do
    for monitor_dir in "${MONITOR_DIRS[@]}"; do
        if [[ "$directory$file" =~ "$ANDROID_SDK_PATH$monitor_dir" ]]; then
            checking_files "$directory$file"
        fi
    done
done
'

is_require_as=""

while [[ $is_require_as != "Y" && $is_require_as != "y" && $is_require_as != "N" && $is_require_as != "n" ]]; do
    read -p "Do you want to install the Android Studio:(Y/n) " is_require_as
done

if [[ $is_require_as == "Y" || $is_require_as == "y" ]]; then
    echo "Debian ENV: Installing openjdk-17-jre..."
    proot-distro login debian --shared-tmp -- bash -c "apt install openjdk-17-jre inotify-tools -y"

    # Android Studio install script
    echo "Debian ENV: Installing Android Studio..."
    cmdline='
    #!/bin/bash
    # Author: https://www.alainlam.cn

    # Create the download folder
    if [[ ! -d ~/Downloads ]]; then
        mkdir ~/Downloads
    fi

    ######## Install Android SDK Command line tools
    # enter the download folder
    cd ~/Downloads
    # Downloading Android SDK command line tools
    echo "Debian ENV: Downloading Android SDK command line tools"
    wget https://dl.google.com/android/repository/commandlinetools-linux-10406996_latest.zip
    # Decompress compressed files
    unzip commandlinetools-linux-*.zip

    echo "Debian ENV: Move the cmdline tools to the target directory"
    # Create the cmdline-tools folder
    mkdir -p ~/Android/Sdk/cmdline-tools/latest
    # Move the cmdline tools to the target directory
    mv ~/Downloads/cmdline-tools/* ~/Android/Sdk/cmdline-tools/latest/

    # Agree all the licenses
    echo "Debian ENV: Agree all the licenses"
    cd ~/Android/Sdk/cmdline-tools/latest/bin/
    yes | ./sdkmanager --licenses

    ######## Configure Android Environment Variables
    echo "Debian ENV: Configure Android Environment Variables"
    echo "" >> ~/.profile
    echo "export ANDROID_HOME=$HOME/Android/Sdk" >> ~/.profile
    echo "export ANDROID_SDK_HOME=$ANDROID_HOME" >> ~/.profile
    echo "export ANDROID_USER_HOME=$HOME/.android" >> ~/.profile
    echo "export ANDROID_EMULATOR_HOME=$ANDROID_USER_HOME" >> ~/.profile
    echo "export ANDROID_AVD_HOME=$ANDROID_EMULATOR_HOME/avd/" >> ~/.profile
    echo "export PATH=$PATH:$ANDROID_HOME/tools:$ANDROID_HOME/tools/bin:$ANDROID_HOME/platform-tools" >> ~/.profile

    ######## Install Android Studio
    cd ~/Downloads
    # Downloading the Android Studio
    echo "Debian ENV: Downloading the Android Studio"
    wget https://redirector.gvt1.com/edgedl/android/studio/ide-zips/2022.3.1.20/android-studio-2022.3.1.20-linux.tar.gz
    # Decompress compressed files
    tar -xvf android-studio-*-linux.tar.gz
    # Move the android-studio to the target directory
    mv ./android-studio ~/Android
    '
    proot-distro login debian --shared-tmp --user $normal_user_name -- bash -c "$cmdline"

    # Android SDK build tools fixes
    echo "Debian ENV: Fixing the build tools and platform tools issues..."

    echo "Save the script to the tmp directory"
    echo "$fixes_sdk_tools" >$PREFIX/tmp/fixes_sdk_tools.sh

    cmdline='
    # Create a folder to save the script files
    if [[ ! -d ~/Scripts ]]; then
        mkdir ~/Scripts
    fi

    echo "Move the fixes_sdk_tools.sh to the Scripts directory"
    mv /tmp/fixes_sdk_tools.sh ~/Scripts/

    echo "Update its permissions"
    chmod 700 ~/Scripts/fixes_sdk_tools.sh

    # setup the permission
    chmod 700 ~/Scripts/fixes_sdk_tools.sh

    # auto start the script
    echo "" >> ~/.profile
    echo "# Running the fixes_sdk_tools.sh on the background" >> ~/.profile
    echo "bash ~/Scripts/fixes_sdk_tools.sh >> '"$user_log_directory"'/fixes_sdk_tools.log 2>&1 &" >> ~/.profile
    echo "Fixed the build tools and platform tools issues"
    '

    proot-distro login debian --shared-tmp --user $normal_user_name -- bash -c "$download_build_tools"
    proot-distro login debian --shared-tmp --user $normal_user_name -- bash -c "$cmdline"

else
    echo "Debian ENV: Skip install Android Studio"
fi

# Install the VSCode
is_require_code=""

while [[ $is_require_code != "Y" && $is_require_code != "y" && $is_require_code != "N" && $is_require_code != "n" ]]; do
    read -p "Do you want to install the Code Server:(Y/n) " is_require_code
done

if [[ $is_require_code == "Y" || $is_require_code == "y" ]]; then

    # Code Server install script
    echo "Debian ENV: Installing Code Server..."
    cmdline='
    cd ~/Downloads

    # Downloading the Code Server
    echo "Debian ENV: Downloading the Code Server"
    wget https://github.com/coder/code-server/releases/download/v4.17.1/code-server-4.17.1-linux-arm64.tar.gz

    # Decompress compressed files
    mkdir -p ./tmpcoder
    tar -xvf code-server-*.tar.gz -C ./tmpcoder/

    echo "Debian ENV: Move the code-server to the target directory"
    # Create the Applications folder
    if [ ! -d ~/Applications ]; then
        mkdir -p ~/Applications
    fi

    # Move the code-server to the target directory and
    mv ./tmpcoder/code-server-* ~/Applications/coder
    rm -rf ./tmpcoder

    # Update code-server passwd
    code_server_pwd=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 12 | head -n 1)
    read -p "The code-server is already installed, 
and automatically generated random password.
Do you want to update your code-server password?
Your password(Default is $code_server_pwd): " new_server_pwd

    if [ -n "$new_server_pwd" ]; then
        code_server_pwd=$new_server_pwd
    fi
    
    # Update code-server port
    code_server_port="8080"
    read -p "Do you want to update your code-server port?
Your port(Default is $code_server_port): " new_server_port

    if [ -n "$new_server_port" ]; then
        code_server_port=$new_server_port
    fi

    code_server_config="bind-addr: 127.0.0.1:$code_server_port
auth: password
password: $code_server_pwd
cert: false"

    # rewrite the server config.yaml
    if [ ! -d ~/.config/code-server ]; then
        mkdir -p ~/.config/code-server
    fi

    echo "$code_server_config" > ~/.config/code-server/config.yaml
    echo "Installed the code-server"
    '
    proot-distro login debian --shared-tmp --user $normal_user_name -- bash -c "$cmdline"
else
    echo "Debian ENV: Skip install Code Server"
fi

# Automatically fixes the max_phantom_processes issue
fixes_mpp_script='#!/bin/bash
# Author https://www.alainlam.cn
# This script requires pre-pairing

### Configuration Variable Setup
#
# adb path
adb() {
    ~/Android/android-sdk-tools/platform-tools/adb "$@"
}
# File to store previous ports
adb_port_file=~/log/adb_port.txt
# Port range to scan when the port number is not available or invalid
# Adjust the range accordingly for your tablet
port_range="30000-50000"
#
######

connect_to_ports() {
    local ports=("$@")
    for port in "${ports[@]}"; do
        # Attempt connection
        echo "adb connecting localhost:$port"
        adb_output=$(adb connect localhost:"$port" 2>&1)
        # Check if connection is successful
        if [[ $adb_output =~ connected ]]; then
            echo "adb connected localhost:$port"
            # Modify max_phantom_processes
            echo "update max_phantom_processes to 32768"
            adb -s localhost:$port shell device_config put activity_manager max_phantom_processes 32768
            # Write port number to file
            echo "$port" >$adb_port_file
            # If start-server is not empty, adb was not previously opened, so kill adb
            if [ $kill_adb -eq 1 ]; then
                adb kill-server
                echo "adb killed server"
            fi
            # Exit the script
            exit 0
        else
            echo "Failed to connect to port $port"
            # Avoid listing too many devices in adb devices
            adb disconnect localhost:"$port"
        fi
    done
    echo "Failed to connect to any port"
    # If start-server is not empty, adb was not previously opened, so kill adb
    if [ $kill_adb -eq 1 ]; then
        adb kill-server
        echo "adb killed server"
    fi
}

# Start adb
kill_adb=0
if ! pgrep -x "adb" >/dev/null; then
    adb start-server
    kill_adb=1
fi

# Attempt connection to previous ports
if [ -f "$adb_port_file" ]; then
    adb_port=$(cat "$adb_port_file")
else
    echo "Port file $adb_port_file does not exist"
    directory=$(dirname "$adb_port_file")
    # If directory does not exist, create it
    if [ ! -d "$directory" ]; then
        mkdir -p "$directory"
    fi
fi

# Check if the port is open
if [ -n "$adb_port" ]; then
    echo "pending the localhost:$adb_port"
    nmap_output=$(nmap -p "$adb_port" localhost)
    if [[ $nmap_output == *"$adb_port/tcp"*open* ]]; then
        echo "Port $adb_port is open"
        # Attempt connection
        connect_to_ports "$adb_port"
    else
        echo "Port $adb_port is closed"
    fi
fi

# Prompt user to select a method
selected_port_method=""

while [[ $selected_port_method != "1" && $selected_port_method != "2" && $selected_port_method != "3" ]]; do
    read -p "
Please choose the method you want:

    1. Enter the special port(Manual)
    2. Use nmap to scan the ports(Slowly)
    3. Skip for now

Your choice(1/2/3): " selected_port_method
done

if [[ $selected_port_method == "1" ]]; then
    read -p "Please enter a special port(1-65535) " enter_port
    echo "pending the localhost:$enter_port"
    connect_to_ports "$enter_port"
fi

if [[ $selected_port_method == "2" ]]; then
    # If the port is invalid or does not exist, scan ports and save them to adb_test_ports
    echo "pending the localhost:[$port_range]"
    nmap_output=$(nmap -p "$port_range" localhost)
    while IFS= read -r line; do
        if [[ $line =~ ^[0-9]+/tcp.*open.* ]]; then
            echo "$line"
            port=$(echo "$line" | awk -F/ "{print $1}")
            adb_test_ports+=("$port")
        fi
    done <<<"$nmap_output"

    # Attempt connection to ports
    connect_to_ports "${adb_test_ports[@]}"
fi
'

is_fixes_mpp=""

while [[ $is_fixes_mpp != "Y" && $is_fixes_mpp != "y" && $is_fixes_mpp != "N" && $is_fixes_mpp != "n" ]]; do
    read -p "
Should the errors caused by the max_phantom_processes parameter introduced in Android 12 be automatically fixed?

    For the script to take effect:
    - You still need to manually enable Wireless debugging.
    - Perform at least one adb pairing (you may need to re-pair if the pairing fails).

Your choice(Y/n): " is_fixes_mpp
done

if [[ $is_fixes_mpp == "Y" || $is_fixes_mpp == "y" ]]; then
    echo "Fixing the max_phantom_processes issue..."
    echo "Debian ENV: Installing the nmap..."

    # Need to use the nmap tool to scan ADB ports
    proot-distro login debian --shared-tmp -- bash -c "apt install nmap -y"

    # Download the Android SDK build tools(Need to use adb)
    proot-distro login debian --shared-tmp --user $normal_user_name -- bash -c "$download_build_tools"

    # Automatically fixes script
    echo "Save the script to the tmp directory"
    echo "$fixes_mpp_script" >$PREFIX/tmp/fixes_mpp_script.sh

    cmdline='
    # Create a folder to save the script files
    if [[ ! -d ~/Scripts ]]; then
        mkdir ~/Scripts
    fi

    echo "Move the fixes_mpp_script.sh to the Scripts directory"
    mv /tmp/fixes_mpp_script.sh ~/Scripts/

    echo "Update its permissions"
    chmod 700 ~/Scripts/fixes_mpp_script.sh

    # Auto start the script
    # echo "" >> ~/.profile
    # echo "# Running the fixes_mpp_script.sh on the background" >> ~/.profile
    # echo "bash ~/Scripts/fixes_mpp_script.sh >> '$user_log_directory'/fixes_mpp_script.log 2>&1 &" >> ~/.profile
    echo "Done automatically fixes the max_phantom_processes issue"
    '
    proot-distro login debian --shared-tmp --user $normal_user_name -- bash -c "$cmdline"
else
    echo "Skip the max_phantom_processes fix."
fi

# The script for start the Debian X11 Desktop Environment
start_debian_x='#!/bin/bash
# Author: https://www.alainlam.cn

# Close all the xfce processes
processes=$(pgrep -f xfce4)
for pid in $processes; do
    echo "killing $pid"
    kill $pid
done

# Close all the x11 processes
processes=$(pgrep -f com.termux.x11)
for pid in $processes; do
    echo "killing x11 server: $pid"
    kill $pid
done

# Close all the pulseaudio processes
processes=$(pgrep -f pulseaudio)
for pid in $processes; do
    echo "killing pulseaudio: $pid"
    kill $pid
done

# Close all the virgl renderer processes
processes=$(pgrep -f virglrenderer-android)
for pid in $processes; do
    echo "killing virglrenderer-android: $pid"
    kill $pid
done

echo "Starting X11 server"
XDG_RUNTIME_DIR=$TMPDIR
termux-x11 :0 -ac &
sleep 3

echo "Starting pulseaudio server"
pulseaudio --start --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" --exit-idle-time=-1

echo "Starting Virgl Renderer"
virgl_test_server_android &

# Fix max_phantom_processes issues
echo "Trying to fix the max_phantom_processes issues"
fixes_mmp='\''
    script_path=~/Scripts/fixes_mpp_script.sh
    if [ -f "$script_path" ]; then
        bash "$script_path"
    else
        echo "Script not found: $script_path"
    fi
    '\''
proot-distro login debian --shared-tmp --user alain -- bash -c "$fixes_mmp"

# Start Termux X11
am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity

# Start the desktop environment
proot-distro login debian --user '"$normal_user_name"' --shared-tmp -- bash -c "export DISPLAY=:0 PULSE_SERVER=tcp:127.0.0.1; dbus-launch --exit-with-session startxfce4"
'

# Create a Desktop Shortcuts for Debian
is_require_shortcuts=""

while [[ $is_require_shortcuts != "Y" && $is_require_shortcuts != "y" && $is_require_shortcuts != "N" && $is_require_shortcuts != "n" ]]; do
    read -p "Do you want to create a desktop shortcuts for Debian:(Y/n) " is_require_shortcuts
done

if [[ $is_require_shortcuts == "Y" || $is_require_shortcuts == "y" ]]; then
    if [ ! -d ~/.shortcuts ]; then
        mkdir ~/.shortcuts
    fi
    echo $start_debian_x >~/.shortcuts/DebianX11
else
    echo "Debian ENV: Skip create a desktop shortcuts for Debian"
fi

# Create a Desktop Shortcuts for Debian
is_start_now=""

while [[ $is_start_now != "Y" && $is_start_now != "y" && $is_start_now != "N" && $is_start_now != "n" ]]; do
    read -p "Do you want to start the desktop for now:(Y/n) " is_start_now
done

if [[ $is_start_now == "Y" || $is_start_now == "y" ]]; then
    eval "$start_debian_x"
fi
