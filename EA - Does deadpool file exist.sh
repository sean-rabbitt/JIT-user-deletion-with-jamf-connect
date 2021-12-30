#!/bin/bash

# PART TWO: Extension Attribute - Does the deadpool file exist
#
# WHY: Jamf Connect allows for just-in-time account creation on a macOS client.
# So this means that an admin may want to just pop in and do some magic, log out
# and go away.  But there's no easy way to clean up after yourself, and like any
# good Girl Scout, we should always leave our campsite better than when we found
# it.

# HOW: 	1) Create an extension attribute with this script to look for the 
#			presence of file located at $DELETE_USER_TOUCH_FILE (defined below)
#		3) Create a Smart Computer Group based on the extension attribute above
#			and that the file exists
#		4) Create a policy that runs at reoccuring checkin, scoped to computers
#			that belong to the Smart Computer Group above.  Tell the policy to 
#			the delete a list of users script..

# WHAT: EA will return "TRUE" if the deadpool file user list exists.

# MIT License
#
# Copyright (c) 2021 Jamf Software

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# — SRABBITT 21DEC2021


# Location of user deadpool list
DELETE_USER_TOUCH_FILE="/Library/Application\ Support/JAMF/Receipts/.userCleanup"

if [ -f "$DELETE_USER_TOUCH_FILE" ]; then
	echo "<result>TRUE</result>"
else
	echo "<result>FALSE</result>"
fi
