= GeoIP

http://geoip.rubyforge.org/

== DESCRIPTION:

GeoIP searches a GeoIP database for a given host or IP address, and
returns information about the country where the IP address is allocated,
and the city, ISP and other information, if you have that database version.

== FEATURES/PROBLEMS:

This release applies a Mutex around file I/O operations, which should
prevent GeoIP blowing up under multi-threaded usage.

== SYNOPSIS:

require 'geoip'
GeoIP.new('GeoIP.dat').country("www.netscape.sk")
=> ["www.netscape.sk", "217.67.16.35", 196, "SK", "SVK", "Slovakia", "EU"]

== REQUIREMENTS:

You need at least the free GeoIP.dat, for which the last known download
location is <http://www.maxmind.com/download/geoip/database/GeoIP.dat.gz>,
or the city database from <http://www.maxmind.com/app/geolitecity>.

This API requires the file to be decompressed for searching. Other versions
of this database are available for purchase which contain more detailed
information, but this information is not returned by this implementation.
See www.maxmind.com for more information.

== INSTALL:

sudo gem install geoip

== LICENSE:

(The MIT License)

Copyright (c) 2008 FIX

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

==
