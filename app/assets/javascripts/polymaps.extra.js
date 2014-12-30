var Polymaps = {
  boundPoint: function(bounds, coordinate) {
    var x = coordinate[0], y = coordinate[1];
    if (x < bounds[0].lon) bounds[0].lon = x;
    if (x > bounds[1].lon) bounds[1].lon = x;
    if (y < bounds[0].lat) bounds[0].lat = y;
    if (y > bounds[1].lat) bounds[1].lat = y;
  },

  boundPoints: function(bounds, coordinates) {
    var i = -1, n = coordinates.length;
    while (++i < n) Polymaps.boundPoint(bounds, coordinates[i]);
  },

  boundMultiPoints: function(bounds, coordinates) {
    var i = -1, n = coordinates.length;
    while (++i < n) Polymaps.boundPoints(bounds, coordinates[i]);
  }
}

Polymaps.boundGeometry = {
  Point: Polymaps.boundPoint,
  MultiPoint: Polymaps.boundPoints,
  LineString: Polymaps.boundPoints,
  MultiLineString: Polymaps.boundMultiPoints,
  Polygon: function(bounds, coordinates) {
    Polymaps.boundPoints(bounds, coordinates[0]); // exterior ring
  },
  MultiPolygon: function(bounds, coordinates) {
    var i = -1, n = coordinates.length;
    while (++i < n) Polymaps.boundPoints(bounds, coordinates[i][0]);
  }
}

Polymaps.bounds = function(features) {
  var i = -1,
      n = features.length,
      geometry,
      bounds = [{lon: Infinity, lat: Infinity}, {lon: -Infinity, lat: -Infinity}];
  while (++i < n) {
    geometry = features[i].data.geometry;
    Polymaps.boundGeometry[geometry.type](bounds, geometry.coordinates);
  }
  return bounds;
}

// Lifted from the bing example in the polymaps source
Polymaps.bingUrlTemplate = function(url, subdomains) {
  var n = subdomains.length,
      salt = ~~(Math.random() * n); // per-session salt

  /** Returns the given coordinate formatted as a 'quadkey'. */
  function quad(column, row, zoom) {
    var key = "";
    for (var i = 1; i <= zoom; i++) {
      key += (((row >> zoom - i) & 1) << 1) | ((column >> zoom - i) & 1);
    }
    return key;
  }

  return function(c) {
    var quadKey = quad(c.column, c.row, c.zoom),
        server = Math.abs(salt + c.column + c.row + c.zoom) % n;
    return url
        .replace("{quadkey}", quadKey)
        .replace("{subdomain}", subdomains[server]);
  };
}


