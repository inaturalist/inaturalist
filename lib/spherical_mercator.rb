# Quick and dirty port from Dane Springmeyer's tilelite
# Originally from:  
#   http://svn.openstreetmap.org/applications/rendering/mapnik/generate_tiles.py
#
# Copyright (c) 2009, Dane Springmeyer
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
# 
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above
#       copyright notice, this list of conditions and the following
#       disclaimer in the documentation and/or other materials provided
#       with the distribution.
#     * Neither the name of the author nor the names of other
#       contributors may be used to endorse or promote products derived
#       from this software without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

class SphericalMercator
  attr_accessor :levels, :tilesize
  
  def initialize(levels = 18, tilesize = 256)
    @Bc = []
    @Cc = []
    @zc = []
    @Ac = []
    @DEG_TO_RAD = Math::PI / 180
    @RAD_TO_DEG = 180 / Math::PI
    @levels = levels
    @tilesize = tilesize
    c = tilesize
    (0..levels).each do |d|
      e = c / 2
      @Bc << c / 360.0
      @Cc << c / (2 * Math::PI)
      @zc << [e,e]
      @Ac << c
      c *= 2
    end
  end
   
  # Convert from URL pixel scheme to mercator bbox.
  def from_pixel_to_ll(px, zoom)
    e = @zc[zoom]
    f = (px[0] - e[0]) / @Bc[zoom]
    g = (px[1] - e[1]) / -@Cc[zoom]
    h = @RAD_TO_DEG * (2 * Math.atan(Math.exp(g)) - 0.5 * Math::PI)
    return f, h
  end
  
  def from_ll_to_pixel(lonlat, zoom, options = {})
    lonlat[1] = -89.999 if lonlat[1] <= -90
    lonlat[1] = 90 if lonlat[1] > 90
    e = @zc[zoom]
    x = lonlat[0] * @Bc[zoom] + e[0]
    g = Math.log(Math.tan((lonlat[1] / (2*@RAD_TO_DEG)) + (Math::PI / 4)))
    y = e[1] - (g * @Cc[zoom])
    if options[:skip_round]
      [x, y]
    else
      [x.round, y.round]
    end
  end
  
  def from_ll_to_world_coordinate(lonlat, zoom)
    x, y = from_ll_to_pixel(lonlat, zoom, :skip_round => true)
    [(x / @tilesize).round, (y / @tilesize).round]
  end
end
