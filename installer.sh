#!/bin/bash

#A better policy Editor
# fr jmoney46 68 240 67

if [ $(id -u) -ne 0 ]; then
    echo "Run this script as root (sudo su)"
    exit
fi


clear

echo "  
      WELCOME TO THE ALL ENCOMPASSING LORD OF THE POLICY EDITORS!
      A policy tool for all chrome os versions."

