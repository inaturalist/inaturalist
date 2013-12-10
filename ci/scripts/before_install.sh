#!/bin/bash -e

source ./ci/scripts/guard.sh

echo "Installing PostGIS 2.0"
sudo -s -- <<"EOF"
apt-get install python-software-properties
add-apt-repository -y ppa:ubuntugis/ppa
apt-get update
apt-get install -qq libgeos-dev libproj-dev postgresql-9.1-postgis

# Fix issue with linking to -lgeos in RGeo
ln -v -s "`readlink /usr/lib/libgeos_c.so`" /usr/lib/libgeos.so
ln -v -s "`readlink /usr/lib/libgeos_c.so.1`" /usr/lib/libgeos.so.1
EOF

echo "Installing wkhtmltopdf"
sudo apt-get install -qq wkhtmltopdf

echo "Installing gdal-bin"
sudo apt-get install -qq gdal-bin
