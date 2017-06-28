#!/bin/bash
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
# Copyright (c) 2017 Jamf.  All rights reserved.
#
#       Redistribution and use in source and binary forms, with or without
#       modification, are permitted provided that the following conditions are met:
#               * Redistributions of source code must retain the above copyright
#                 notice, this list of conditions and the following disclaimer.
#               * Redistributions in binary form must reproduce the above copyright
#                 notice, this list of conditions and the following disclaimer in the
#                 documentation and/or other materials provided with the distribution.
#               * Neither the name of the Jamf nor the names of its contributors may be
#                 used to endorse or promote products derived from this software without
#                 specific prior written permission.
#
#       THIS SOFTWARE IS PROVIDED BY JAMF SOFTWARE, LLC "AS IS" AND ANY
#       EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
#       WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
#       DISCLAIMED. IN NO EVENT SHALL JAMF SOFTWARE, LLC BE LIABLE FOR ANY
#       DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
#       (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
#       LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
#       ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
#       (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
#       SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
# This script was designed to be used in a Self Service policy to ensure specific
# requirements have been met before proceeding with an inplace upgrade to macOS Sierra,
# as well as to address changes Apple has made to the ability to complete macOS upgrades
# silently.
#
# REQUIREMENTS:
#           - Jamf Pro
#           - Latest Version of macOS Sierra Installer
#
#
# For more information, visit https://github.com/kc9wwh/macOSUpgrade
#
#
# Written by: Joshua Roskos | Professional Services Engineer | Jamf
# Modified by Louis Treger | Senior Mac Technician | MullenLowe Group
#
# Created On: January 5th, 2017
# Updated On: April 5th, 2017
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# USER VARIABLES
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
##Enter 0 for Full Screen, 1 for Utility window (screenshots available on GitHub)
userDialog=0
##Title to be used for userDialog (only applies to Utility Window)
title="macOS Sierra Upgrade"
##Heading to be used for userDialog
heading="Please wait as we prepare your computer for macOS Sierra..."
##Title to be used for userDialog
description="
This process will take approximately 5-10 minutes.
Once completed your computer will reboot and begin the upgrade."
##Icon to be used for userDialog
##Default is macOS Sierra Installer logo which is included in the staged installer package
icon=/Users/Shared/Install\ macOS\ Sierra.app/Contents/Resources/InstallAssistant.icns
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# SYSTEM CHECKS
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
##Check if device is on battery or ac power
pwrAdapter=$( /usr/bin/pmset -g ps )
if [[ ${pwrAdapter} == *"AC Power"* ]]; then
pwrStatus="OK"
/bin/echo "Power Check: OK - AC Power Detected"
else
pwrStatus="ERROR"
/bin/echo "Power Check: ERROR - No AC Power Detected"
fi
##Check if free space > 15GB
osMinor=$( /usr/bin/sw_vers -productVersion | awk -F. {'print $2'} )
if [[ $osMinor -ge 12 ]]; then
freeSpace=$( /usr/sbin/diskutil info / | grep "Available Space" | awk '{print $4}' )
else
freeSpace=$( /usr/sbin/diskutil info / | grep "Free Space" | awk '{print $4}' )
fi
if [[ ${freeSpace%.*} -ge 15 ]]; then
spaceStatus="OK"
/bin/echo "Disk Check: OK - ${freeSpace%.*}GB Free Space Detected"
else
spaceStatus="ERROR"
/bin/echo "Disk Check: ERROR - ${freeSpace%.*}GB Free Space Detected"
fi
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# CREATE FIRST BOOT SCRIPT
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
/bin/mkdir /usr/local/jamfps
/bin/echo "#!/bin/bash
## First Run Script to remove the installer.
## Clean up files
/bin/rm -fdr /Users/Shared/Install\ macOS\ Sierra.app
/bin/sleep 2
## Update Device Inventory
/usr/local/jamf/bin/jamf recon
## Remove LaunchDaemon
/bin/rm -f /Library/LaunchDaemons/com.jamfps.cleanupOSInstall.plist
## Remove Script
/bin/rm -fdr /usr/local/jamfps
exit 0" > /usr/local/jamfps/finishOSInstall.sh
/usr/sbin/chown root:admin /usr/local/jamfps/finishOSInstall.sh
/bin/chmod 755 /usr/local/jamfps/finishOSInstall.sh
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# LAUNCH DAEMON
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
cat << EOF > /Library/LaunchDaemons/com.jamfps.cleanupOSInstall.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
<key>Label</key>
<string>com.jamfps.cleanupOSInstall</string>
<key>ProgramArguments</key>
<array>
<string>/bin/bash</string>
<string>-c</string>
<string>/usr/local/jamfps/finishOSInstall.sh</string>
</array>
<key>RunAtLoad</key>
<true/>
</dict>
</plist>
EOF
##Set the permission on the file just made.
/usr/sbin/chown root:wheel /Library/LaunchDaemons/com.jamfps.cleanupOSInstall.plist
/bin/chmod 644 /Library/LaunchDaemons/com.jamfps.cleanupOSInstall.plist
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# APPLICATION
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
if [[ ${pwrStatus} == "OK" ]] && [[ ${spaceStatus} == "OK" ]]; then
##Launch jamfHelper
if [[ ${userDialog} == 0 ]]; then
/bin/echo "Launching jamfHelper as FullScreen..."
/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType fs -title "" -icon "$icon" -heading "$heading" -description "$description" &
jamfHelperPID=$(echo $!)
fi
if [[ ${userDialog} == 1 ]]; then
/bin/echo "Launching jamfHelper as Utility Window..."
/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType utility -title "$title" -icon "$icon" -heading "$heading" -description "$description" -iconSize 100 &
jamfHelperPID=$(echo $!)
fi
#Open the app as the current user to enable Authenticated reboot
macOSinstallerAppPath="/Users/Shared/Install macOS Sierra.app"
CurrentloggedInUser=$(/usr/bin/python -c 'from SystemConfiguration import SCDynamicStoreCopyConsoleUser; import sys; username = (SCDynamicStoreCopyConsoleUser(None, None, None) or [None])[0]; username = [username,""][username in [u"loginwindow", None, u""]]; sys.stdout.write(username + "\n");')
# There was an issue with startosinstall command that "Install macOS..app" needs to be opened once by logged in user to get it working properly
effectiveUserID=$(/usr/bin/id -u "$CurrentloggedInUser")
/bin/launchctl asuser "$effectiveUserID" sudo -u "$CurrentloggedInUser" /usr/bin/osascript <<EOT
tell application "${macOSinstallerAppPath}" to activate
EOT
# Wait for 5 seconds to settle down then quit the app
/bin/sleep 5
/bin/launchctl asuser "$effectiveUserID" sudo -u "$CurrentloggedInUser" /usr/bin/osascript <<EOT
tell application "${macOSinstallerAppPath}" to quit
EOT
##Begin Upgrade
/bin/echo "Launching startosinstall..."
/Users/Shared/Install\ macOS\ Sierra.app/Contents/Resources/startosinstall --applicationpath /Users/Shared/Install\ macOS\ Sierra.app --nointeraction --pidtosignal $jamfHelperPID &
/bin/sleep 3
else
/bin/echo "Launching jamfHelper Dialog (Requirements Not Met)..."
/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType utility -title "$title" -icon "$icon" -heading "Requirements Not Met" -description "We were unable to prepare your computer for macOS Sierra. Please ensure you are connected to power and that you have at least 15GB of Free Space.
If you continue to experience this issue, please contact the IT Support Center." -iconSize 100 -button1 "OK" -defaultButton 1
fi
exit 0
