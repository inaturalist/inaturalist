$:.unshift File.dirname(__FILE__)
#
# Native Ruby reader for the GeoIP database
# Lookup the country where IP address is allocated
#
#= COPYRIGHT
# This version Copyright (C) 2005 Clifford Heath
# Derived from the C version, Copyright (C) 2003 MaxMind LLC
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
#= SYNOPSIS
#
#   require 'geoip'
#   p GeoIP.new('/usr/share/GeoIP/GeoIP.dat').country("www.netscape.sk")
#
#= DESCRIPTION
#
# GeoIP searches a GeoIP database for a given host or IP address, and
# returns information about the country where the IP address is allocated.
#
#= PREREQUISITES
#
# You need at least the free GeoIP.dat, for which the last known download
# location is <http://www.maxmind.com/download/geoip/database/GeoIP.dat.gz>
# This API requires the file to be decompressed for searching. Other versions
# of this database are available for purchase which contain more detailed
# information, but this information is not returned by this implementation.
# See www.maxmind.com for more information.
#
#=end
require 'thread'  # Needed for Mutex

require 'socket'

class GeoIP
    private
    CountryCode = [
        "--","AP","EU","AD","AE","AF","AG","AI","AL","AM","AN",
        "AO","AQ","AR","AS","AT","AU","AW","AZ","BA","BB",
        "BD","BE","BF","BG","BH","BI","BJ","BM","BN","BO",
        "BR","BS","BT","BV","BW","BY","BZ","CA","CC","CD",
        "CF","CG","CH","CI","CK","CL","CM","CN","CO","CR",
        "CU","CV","CX","CY","CZ","DE","DJ","DK","DM","DO",
        "DZ","EC","EE","EG","EH","ER","ES","ET","FI","FJ",
        "FK","FM","FO","FR","FX","GA","GB","GD","GE","GF",
        "GH","GI","GL","GM","GN","GP","GQ","GR","GS","GT",
        "GU","GW","GY","HK","HM","HN","HR","HT","HU","ID",
        "IE","IL","IN","IO","IQ","IR","IS","IT","JM","JO",
        "JP","KE","KG","KH","KI","KM","KN","KP","KR","KW",
        "KY","KZ","LA","LB","LC","LI","LK","LR","LS","LT",
        "LU","LV","LY","MA","MC","MD","MG","MH","MK","ML",
        "MM","MN","MO","MP","MQ","MR","MS","MT","MU","MV",
        "MW","MX","MY","MZ","NA","NC","NE","NF","NG","NI",
        "NL","NO","NP","NR","NU","NZ","OM","PA","PE","PF",
        "PG","PH","PK","PL","PM","PN","PR","PS","PT","PW",
        "PY","QA","RE","RO","RU","RW","SA","SB","SC","SD",
        "SE","SG","SH","SI","SJ","SK","SL","SM","SN","SO",
        "SR","ST","SV","SY","SZ","TC","TD","TF","TG","TH",
        "TJ","TK","TM","TN","TO","TL","TR","TT","TV","TW",
        "TZ","UA","UG","UM","US","UY","UZ","VA","VC","VE",
        "VG","VI","VN","VU","WF","WS","YE","YT","RS","ZA",
        "ZM","ME","ZW","A1","A2","O1","AX","GG","IM","JE",
        "BL","MF"
    ]

    CountryCode3 = [
        "--","AP","EU","AND","ARE","AFG","ATG","AIA","ALB","ARM","ANT",
        "AGO","AQ","ARG","ASM","AUT","AUS","ABW","AZE","BIH","BRB",
        "BGD","BEL","BFA","BGR","BHR","BDI","BEN","BMU","BRN","BOL",
        "BRA","BHS","BTN","BV","BWA","BLR","BLZ","CAN","CC","COD",
        "CAF","COG","CHE","CIV","COK","CHL","CMR","CHN","COL","CRI",
        "CUB","CPV","CX","CYP","CZE","DEU","DJI","DNK","DMA","DOM",
        "DZA","ECU","EST","EGY","ESH","ERI","ESP","ETH","FIN","FJI",
        "FLK","FSM","FRO","FRA","FX","GAB","GBR","GRD","GEO","GUF",
        "GHA","GIB","GRL","GMB","GIN","GLP","GNQ","GRC","GS","GTM",
        "GUM","GNB","GUY","HKG","HM","HND","HRV","HTI","HUN","IDN",
        "IRL","ISR","IND","IO","IRQ","IRN","ISL","ITA","JAM","JOR",
        "JPN","KEN","KGZ","KHM","KIR","COM","KNA","PRK","KOR","KWT",
        "CYM","KAZ","LAO","LBN","LCA","LIE","LKA","LBR","LSO","LTU",
        "LUX","LVA","LBY","MAR","MCO","MDA","MDG","MHL","MKD","MLI",
        "MMR","MNG","MAC","MNP","MTQ","MRT","MSR","MLT","MUS","MDV",
        "MWI","MEX","MYS","MOZ","NAM","NCL","NER","NFK","NGA","NIC",
        "NLD","NOR","NPL","NRU","NIU","NZL","OMN","PAN","PER","PYF",
        "PNG","PHL","PAK","POL","SPM","PCN","PRI","PSE","PRT","PLW",
        "PRY","QAT","REU","ROU","RUS","RWA","SAU","SLB","SYC","SDN",
        "SWE","SGP","SHN","SVN","SJM","SVK","SLE","SMR","SEN","SOM",
        "SUR","STP","SLV","SYR","SWZ","TCA","TCD","TF","TGO","THA",
        "TJK","TKL","TKM","TUN","TON","TLS","TUR","TTO","TUV","TWN",
        "TZA","UKR","UGA","UM","USA","URY","UZB","VAT","VCT","VEN",
        "VGB","VIR","VNM","VUT","WLF","WSM","YEM","YT","SRB","ZAF",
        "ZMB","MNE","ZWE","A1","A2","O1","ALA","GGY","IMN","JEY",
        "BLM","MAF"
    ]

    CountryName = [
        "N/A",
        "Asia/Pacific Region",
        "Europe",
        "Andorra",
        "United Arab Emirates",
        "Afghanistan",
        "Antigua and Barbuda",
        "Anguilla",
        "Albania",
        "Armenia",
        "Netherlands Antilles",
        "Angola",
        "Antarctica",
        "Argentina",
        "American Samoa",
        "Austria",
        "Australia",
        "Aruba",
        "Azerbaijan",
        "Bosnia and Herzegovina",
        "Barbados",
        "Bangladesh",
        "Belgium",
        "Burkina Faso",
        "Bulgaria",
        "Bahrain",
        "Burundi",
        "Benin",
        "Bermuda",
        "Brunei Darussalam",
        "Bolivia",
        "Brazil",
        "Bahamas",
        "Bhutan",
        "Bouvet Island",
        "Botswana",
        "Belarus",
        "Belize",
        "Canada",
        "Cocos (Keeling) Islands",
        "Congo, the Democratic Republic of the",
        "Central African Republic",
        "Congo",
        "Switzerland",
        "Cote D'Ivoire",
        "Cook Islands",
        "Chile",
        "Cameroon",
        "China",
        "Colombia",
        "Costa Rica",
        "Cuba",
        "Cape Verde",
        "Christmas Island",
        "Cyprus",
        "Czech Republic",
        "Germany",
        "Djibouti",
        "Denmark",
        "Dominica",
        "Dominican Republic",
        "Algeria",
        "Ecuador",
        "Estonia",
        "Egypt",
        "Western Sahara",
        "Eritrea",
        "Spain",
        "Ethiopia",
        "Finland",
        "Fiji",
        "Falkland Islands (Malvinas)",
        "Micronesia, Federated States of",
        "Faroe Islands",
        "France",
        "France, Metropolitan",
        "Gabon",
        "United Kingdom",
        "Grenada",
        "Georgia",
        "French Guiana",
        "Ghana",
        "Gibraltar",
        "Greenland",
        "Gambia",
        "Guinea",
        "Guadeloupe",
        "Equatorial Guinea",
        "Greece",
        "South Georgia and the South Sandwich Islands",
        "Guatemala",
        "Guam",
        "Guinea-Bissau",
        "Guyana",
        "Hong Kong",
        "Heard Island and McDonald Islands",
        "Honduras",
        "Croatia",
        "Haiti",
        "Hungary",
        "Indonesia",
        "Ireland",
        "Israel",
        "India",
        "British Indian Ocean Territory",
        "Iraq",
        "Iran, Islamic Republic of",
        "Iceland",
        "Italy",
        "Jamaica",
        "Jordan",
        "Japan",
        "Kenya",
        "Kyrgyzstan",
        "Cambodia",
        "Kiribati",
        "Comoros",
        "Saint Kitts and Nevis",
        "Korea, Democratic People's Republic of",
        "Korea, Republic of",
        "Kuwait",
        "Cayman Islands",
        "Kazakhstan",
        "Lao People's Democratic Republic",
        "Lebanon",
        "Saint Lucia",
        "Liechtenstein",
        "Sri Lanka",
        "Liberia",
        "Lesotho",
        "Lithuania",
        "Luxembourg",
        "Latvia",
        "Libyan Arab Jamahiriya",
        "Morocco",
        "Monaco",
        "Moldova, Republic of",
        "Madagascar",
        "Marshall Islands",
        "Macedonia, the Former Yugoslav Republic of",
        "Mali",
        "Myanmar",
        "Mongolia",
        "Macau",
        "Northern Mariana Islands",
        "Martinique",
        "Mauritania",
        "Montserrat",
        "Malta",
        "Mauritius",
        "Maldives",
        "Malawi",
        "Mexico",
        "Malaysia",
        "Mozambique",
        "Namibia",
        "New Caledonia",
        "Niger",
        "Norfolk Island",
        "Nigeria",
        "Nicaragua",
        "Netherlands",
        "Norway",
        "Nepal",
        "Nauru",
        "Niue",
        "New Zealand",
        "Oman",
        "Panama",
        "Peru",
        "French Polynesia",
        "Papua New Guinea",
        "Philippines",
        "Pakistan",
        "Poland",
        "Saint Pierre and Miquelon",
        "Pitcairn",
        "Puerto Rico",
        "Palestinian Territory, Occupied",
        "Portugal",
        "Palau",
        "Paraguay",
        "Qatar",
        "Reunion",
        "Romania",
        "Russian Federation",
        "Rwanda",
        "Saudi Arabia",
        "Solomon Islands",
        "Seychelles",
        "Sudan",
        "Sweden",
        "Singapore",
        "Saint Helena",
        "Slovenia",
        "Svalbard and Jan Mayen",
        "Slovakia",
        "Sierra Leone",
        "San Marino",
        "Senegal",
        "Somalia",
        "Suriname",
        "Sao Tome and Principe",
        "El Salvador",
        "Syrian Arab Republic",
        "Swaziland",
        "Turks and Caicos Islands",
        "Chad",
        "French Southern Territories",
        "Togo",
        "Thailand",
        "Tajikistan",
        "Tokelau",
        "Turkmenistan",
        "Tunisia",
        "Tonga",
        "Timor-Leste",
        "Turkey",
        "Trinidad and Tobago",
        "Tuvalu",
        "Taiwan, Province of China",
        "Tanzania, United Republic of",
        "Ukraine",
        "Uganda",
        "United States Minor Outlying Islands",
        "United States",
        "Uruguay",
        "Uzbekistan",
        "Holy See (Vatican City State)",
        "Saint Vincent and the Grenadines",
        "Venezuela",
        "Virgin Islands, British",
        "Virgin Islands, U.S.",
        "Viet Nam",
        "Vanuatu",
        "Wallis and Futuna",
        "Samoa",
        "Yemen",
        "Mayotte",
        "Serbia",
        "South Africa",
        "Zambia",
        "Montenegro",
        "Zimbabwe",
        "Anonymous Proxy",
        "Satellite Provider",
        "Other",
        "Aland Islands",
        "Guernsey",
        "Isle of Man",
        "Jersey",
        "Saint Barthelemy",
        "Saint Martin"
    ]

    CountryContinent = [
        "--","AS","EU","EU","AS","AS","SA","SA","EU","AS","SA",
        "AF","AN","SA","OC","EU","OC","SA","AS","EU","SA",
        "AS","EU","AF","EU","AS","AF","AF","SA","AS","SA",
        "SA","SA","AS","AF","AF","EU","SA","NA","AS","AF",
        "AF","AF","EU","AF","OC","SA","AF","AS","SA","SA",
        "SA","AF","AS","AS","EU","EU","AF","EU","SA","SA",
        "AF","SA","EU","AF","AF","AF","EU","AF","EU","OC",
        "SA","OC","EU","EU","EU","AF","EU","SA","AS","SA",
        "AF","EU","SA","AF","AF","SA","AF","EU","SA","SA",
        "OC","AF","SA","AS","AF","SA","EU","SA","EU","AS",
        "EU","AS","AS","AS","AS","AS","EU","EU","SA","AS",
        "AS","AF","AS","AS","OC","AF","SA","AS","AS","AS",
        "SA","AS","AS","AS","SA","EU","AS","AF","AF","EU",
        "EU","EU","AF","AF","EU","EU","AF","OC","EU","AF",
        "AS","AS","AS","OC","SA","AF","SA","EU","AF","AS",
        "AF","NA","AS","AF","AF","OC","AF","OC","AF","SA",
        "EU","EU","AS","OC","OC","OC","AS","SA","SA","OC",
        "OC","AS","AS","EU","SA","OC","SA","AS","EU","OC",
        "SA","AS","AF","EU","AS","AF","AS","OC","AF","AF",
        "EU","AS","AF","EU","EU","EU","AF","EU","AF","AF",
        "SA","AF","SA","AS","AF","SA","AF","AF","AF","AS",
        "AS","OC","AS","AF","OC","AS","AS","SA","OC","AS",
        "AF","EU","AF","OC","NA","SA","AS","EU","SA","SA",
        "SA","SA","AS","OC","OC","OC","AS","AF","EU","AF",
        "AF","EU","AF","--","--","--","EU","EU","EU","EU",
        "SA","SA"
    ]

    public
    # Edition enumeration:
    (GEOIP_COUNTRY_EDITION,
    GEOIP_CITY_EDITION_REV1,
    GEOIP_REGION_EDITION_REV1,
    GEOIP_ISP_EDITION,
    GEOIP_ORG_EDITION,
    GEOIP_CITY_EDITION_REV0,
    GEOIP_REGION_EDITION_REV0,
    GEOIP_PROXY_EDITION,
    GEOIP_ASNUM_EDITION,
    GEOIP_NETSPEED_EDITION,
    ) = *1..10

    private
    COUNTRY_BEGIN = 16776960
    STATE_BEGIN_REV0 = 16700000
    STATE_BEGIN_REV1 = 16000000
    STRUCTURE_INFO_MAX_SIZE = 20
    DATABASE_INFO_MAX_SIZE = 100
    MAX_ORG_RECORD_LENGTH = 300
    US_OFFSET = 1
    CANADA_OFFSET = 677
    WORLD_OFFSET = 1353
    FIPS_RANGE = 360
    FULL_RECORD_LENGTH = 50

    STANDARD_RECORD_LENGTH = 3
    SEGMENT_RECORD_LENGTH = 3

    public
    attr_reader :databaseType

    # Open the GeoIP database and determine the file format version
    #
    # +filename+ is a String holding the path to the GeoIP.dat file
    # +options+ is an integer holding caching flags (unimplemented)
    def initialize(filename, flags = 0)
        @mutex = Mutex.new
        @flags = flags
        @databaseType = GEOIP_COUNTRY_EDITION
        @record_length = STANDARD_RECORD_LENGTH
        @file = File.open(filename, 'rb')
        @file.seek(-3, IO::SEEK_END)
        0.upto(STRUCTURE_INFO_MAX_SIZE-1) { |i|
            if @file.read(3) == "\xFF\xFF\xFF"
                @databaseType = @file.getc
                @databaseType -= 105 if @databaseType >= 106

                if (@databaseType == GEOIP_REGION_EDITION_REV0)
                    # Region Edition, pre June 2003
                    @databaseSegments = [ STATE_BEGIN_REV0 ]
                elsif (@databaseType == GEOIP_REGION_EDITION_REV1)
                    # Region Edition, post June 2003
                    @databaseSegments = [ STATE_BEGIN_REV1 ]
                elsif (@databaseType == GEOIP_CITY_EDITION_REV0 ||
                       @databaseType == GEOIP_CITY_EDITION_REV1 ||
                       @databaseType == GEOIP_ORG_EDITION ||
                       @databaseType == GEOIP_ISP_EDITION ||
                       @databaseType == GEOIP_ASNUM_EDITION)
                    # City/Org Editions have two segments, read offset of second segment
                    @databaseSegments = [ 0 ]
                    sr = @file.read(3).unpack("C*")
                    @databaseSegments[0] += le_to_ui(sr)

                    if (@databaseType == GEOIP_ORG_EDITION ||
                        @databaseType == GEOIP_ISP_EDITION)
                        @record_length = 4
                    end
                end
                break

            else
                @file.seek(-4, IO::SEEK_CUR)
            end
        }
        if (@databaseType == GEOIP_COUNTRY_EDITION ||
            @databaseType == GEOIP_PROXY_EDITION ||
            @databaseType == GEOIP_NETSPEED_EDITION)
            @databaseSegments = [ COUNTRY_BEGIN ]
        end
    end

    # Close the file handle for the GeoIP data file.
    def close
      @file.close
    end

    # Search the GeoIP database for the specified host, returning country info
    #
    # +hostname+ is a String holding the host's DNS name or numeric IP address.
    # Return an array of seven elements:
    # * The host or IP address string as requested
    # * The IP address string after looking up the host
    # * The GeoIP country-ID as an integer
    # * The ISO3166-1 two-character country code
    # * The ISO3166-2 three-character country code
    # * The ISO3166 English-language name of the country
    # * The two-character continent code
    #
    def country(hostname)
        if (@databaseType == GEOIP_CITY_EDITION_REV0 ||
            @databaseType == GEOIP_CITY_EDITION_REV1)
            return city(hostname)
        end

        ip = hostname
        if ip.kind_of?(String) && ip !~ /^[0-9.]*$/
            # Lookup IP address, we were given a name
            ip = IPSocket.getaddress(hostname)
        end

        # Convert numeric IP address to an integer
        ipnum = iptonum(ip)
        if (@databaseType != GEOIP_COUNTRY_EDITION && 
            @databaseType != GEOIP_PROXY_EDITION &&
            @databaseType != GEOIP_NETSPEED_EDITION)
            throw "Invalid GeoIP database type, can't look up Country by IP"
        end
        code = seek_record(ipnum) - COUNTRY_BEGIN;
        [   hostname,                   # Requested hostname
            ip,                         # Ip address as dotted quad
            code,                       # GeoIP's country code
            CountryCode[code],          # ISO3166-1 code
            CountryCode3[code],         # ISO3166-2 code
            CountryName[code],          # Country name, per IS03166
            CountryContinent[code] ]    # Continent code.
    end

    # Search the GeoIP database for the specified host, returning city info
    #
    # +hostname+ is a String holding the host's DNS name or numeric IP address
    # Return an array of twelve or fourteen elements:
    # * All elements from the country query
    # * The region (state or territory) name
    # * The city name
    # * The postal code (zipcode)
    # * The latitude
    # * The longitude
    # * The dma_code and area_code, if available (REV1 City database)
    private

    def read_city(pos, hostname = '', ip = '')
        record = ""
        @mutex.synchronize {
            @file.seek(pos + (2*@record_length-1) * @databaseSegments[0])
            return nil unless record = @file.read(FULL_RECORD_LENGTH)
        }

        # The country code is the first byte:
        code = record[0]
        record = record[1..-1]
        @iter_pos += 1 unless @iter_pos.nil?

        spl = record.split("\x00", 4)
        # Get the region:
        region = spl[0]
        @iter_pos += (region.size + 1) unless @iter_pos.nil?

        # Get the city:
        city = spl[1]
        @iter_pos += (city.size + 1) unless @iter_pos.nil?

        # Get the postal code:
        postal_code = spl[2]
        @iter_pos += (postal_code.size + 1) unless @iter_pos.nil?

        record = spl[3]
        # Get the latitude/longitude:
        if(record && record[0,3]) then
            latitude  = le_to_ui(record[0,3].unpack('C*')) / 10000.0 - 180
            record = record[3..-1]
            @iter_pos += 3 unless @iter_pos.nil?
        else
            latitude = ''
        end
        if(record && record[0,3]) then
            longitude = le_to_ui(record[0,3].unpack('C*')) / 10000.0 - 180
            record = record[3..-1]
            @iter_pos += 3 unless @iter_pos.nil?
        else
            longitude = ''
        end

        us_area_codes = []
        if (record &&
                record[0,3] &&
                @databaseType == GEOIP_CITY_EDITION_REV1 &&
                CountryCode[code] == "US")      # UNTESTED
            dmaarea_combo = le_to_ui(record[0,3].unpack('C*'))
            dma_code = dmaarea_combo / 1000;
            area_code = dmaarea_combo % 1000;
            us_area_codes = [ dma_code, area_code ]
            @iter_pos += 3 unless @iter_pos.nil?
        end

        [   hostname,                   # Requested hostname
            ip,                         # Ip address as dotted quad
            CountryCode[code],          # ISO3166-1 code
            CountryCode3[code],         # ISO3166-2 code
            CountryName[code],          # Country name, per IS03166
            CountryContinent[code],     # Continent code.
            region,                     # Region name
            city,                       # City name
            postal_code,                # Postal code
            latitude,
            longitude,
        ] + us_area_codes
    end

    public

    # Search the GeoIP database for the specified host, returning city info.
    #
    # +hostname+ is a String holding the host's DNS name or numeric IP address.
    # Return an array of twelve or fourteen elements:
    # * The host or IP address string as requested
    # * The IP address string after looking up the host
    # * The GeoIP country-ID as an integer
    # * The ISO3166-1 two-character country code
    # * The ISO3166-2 three-character country code
    # * The ISO3166 English-language name of the country
    # * The two-character continent code
    # * The region name
    # * The city name
    # * The postal code
    # * The latitude
    # * The longitude
    # * The USA dma_code and area_code, if available (REV1 City database)
    #
    def city(hostname)
        ip = hostname
        if ip.kind_of?(String) && ip !~ /^[0-9.]*$/
            # Lookup IP address, we were given a name
            ip = IPSocket.getaddress(hostname)
        end

        # Convert numeric IP address to an integer
        ipnum = iptonum(ip)
        if (@databaseType != GEOIP_CITY_EDITION_REV0 &&
            @databaseType != GEOIP_CITY_EDITION_REV1)
            throw "Invalid GeoIP database type, can't look up City by IP"
        end
        pos = seek_record(ipnum);
        read_city(pos, hostname, ip)
    end

    # Search a ISP GeoIP database for the specified host, returning the ISP
    #
    # +hostname+ is a String holding the host's DNS name or numeric IP address.
    # Return the ISP name
    #
    def isp(hostname)
        ip = hostname
        if ip.kind_of?(String) && ip !~ /^[0-9.]*$/
            # Lookup IP address, we were given a name
            ip = IPSocket.getaddress(hostname)
        end

        # Convert numeric IP address to an integer
        ipnum = iptonum(ip)
        if @databaseType != GEOIP_ISP_EDITION
            throw "Invalid GeoIP database type, can't look up Organization/ISP by IP"
        end
        pos = seek_record(ipnum);
        record = ""
        @mutex.synchronize {
            @file.seek(pos + (2*@record_length-1) * @databaseSegments[0])
            record = @file.read(MAX_ORG_RECORD_LENGTH)
        }
        record = record.sub(/\000.*/, '')
        record
    end

    # Search a ISP GeoIP database for the specified host, returning the organization
    #
    # +hostname+ is a String holding the host's DNS name or numeric IP address.
    # Return the organization associated with it
    #
    alias_method(:organization, :isp)     # Untested, according to Maxmind docs this should work

    # Iterate through a GeoIP city database
    def each
        if (@databaseType != GEOIP_CITY_EDITION_REV0 &&
            @databaseType != GEOIP_CITY_EDITION_REV1)
            throw "Invalid GeoIP database type, can't iterate thru non-City database"
        end

        @iter_pos = @databaseSegments[0] + 1
        num = 0
        until((rec = read_city(@iter_pos)).nil?)
            yield(rec)
            print "#{num}: #{@iter_pos}\n" if((num += 1) % 1000 == 0)
        end
        @iter_pos = nil
        self
    end

    private
    def iptonum(ip)     # Convert numeric IP address to integer
        if ip.kind_of?(String) &&
            ip =~ /^([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)$/
            ip = be_to_ui(Regexp.last_match().to_a.slice(1..4))
        end
        ip
    end

    def seek_record(ipnum)
        # Binary search in the file.
        # Records are pairs of little-endian integers, each of @record_length.
        offset = 0
        mask = 0x80000000
        31.downto(0) { |depth|
            buf = @mutex.synchronize {
                @file.seek(@record_length * 2 * offset);
                @file.read(@record_length * 2);
            }
            buf.slice!(0...@record_length) if ((ipnum & mask) != 0)
            offset = le_to_ui(buf[0...@record_length].unpack("C*"))
            return offset if (offset >= @databaseSegments[0])
            mask >>= 1
        }
    end

    # Convert a big-endian array of numeric bytes to unsigned int
    def be_to_ui(s)
        s.inject(0) { |m, o|
            (m << 8) + o.to_i
        }
    end

    # Same for little-endian
    def le_to_ui(s)
        be_to_ui(s.reverse)
    end
end

if $0 == __FILE__
    data = '/usr/share/GeoIP/GeoIP.dat'
    data = ARGV.shift if ARGV[0] =~ /\.dat\Z/
    g = GeoIP.new data

    req = ([GeoIP::GEOIP_CITY_EDITION_REV1, GeoIP::GEOIP_CITY_EDITION_REV0].include?(g.databaseType)) ? :city : :country
    ARGV.each { |a|
        p g.send(req, a)
    }
end

