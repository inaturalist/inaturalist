var Windshaft = require('../lib/windshaft');
var _         = require('underscore');

var pointQuery = "(SELECT o.id, o.species_guess, o.iconic_taxon_id, o.taxon_id, o.latitude, o.longitude, o.geom FROM " + 
  "observations o, taxa t " +
  "WHERE o.taxon_id = t.id AND ( o.taxon_id = {{taxon_id}} OR '/' || t.ancestry || '/' LIKE '%/{{taxon_id}}/%' ) " +
  " AND o.id != {{obs_id}}) as points";

//Don't like hardcoding taxon colors here
var defaultStylePoints = 
  "#observations [zoom >=9]{" +
  "marker-fill: {{taxon_color}}; " +
  "marker-opacity: 1;" +
  "marker-width: 8;" +
  "marker-line-color: white;" +
  "marker-line-width: 2;" +
  "marker-line-opacity: 0.9;" +
  "marker-placement: point;" +
  "marker-type: ellipse;" +
  "marker-allow-overlap: true; " +
  "[taxon_id=2] { marker-fill: #1E90FF; } " +
  "[taxon_id=3] { marker-fill: #1E90FF; } " +
  "[taxon_id=5] { marker-fill: #1E90FF; } " +
  "[taxon_id=6] { marker-fill: #1E90FF; } " +
  "[taxon_id=7] { marker-fill: #1E90FF; } " +
  "[taxon_id=8] { marker-fill: #1E90FF; } " +
  "[taxon_id=9] { marker-fill: #FF4500; } " +
  "[taxon_id=11] { marker-fill: #FF4500; } " +
  "[taxon_id=12] { marker-fill: #73AC13; } " +
  "[taxon_id=13] { marker-fill: #FF1493; } " +
  "[taxon_id=14] { marker-fill: #8B008B; } " +
  "[taxon_id=15] { marker-fill: #FF4500; } " +
  "[taxon_id=16] { marker-fill: #993300; } " +
  "}";

var gridQuery = "(SELECT cnt, taxon_id, ST_Envelope(" +
  "ST_GEOMETRYFROMTEXT('LINESTRING('||(st_xmax(the_geom)-({{seed}}/2))||' '||(st_ymax(the_geom)-({{seed}}/2))||'," +
  "'||(st_xmax(the_geom)+({{seed}}/2))||' '||(st_ymax(the_geom)+({{seed}}/2))||')',4326)) as geom FROM " +
  "(SELECT count(*) as cnt, o.taxon_id, t.ancestry,  ST_SnapToGrid(geom, 0+({{seed}}/2), 75+({{seed}}/2), {{seed}}, {{seed}}) as the_geom FROM " +
  "observations o, taxa t  " +
  "WHERE o.taxon_id=t.id AND (taxon_id={{taxon_id}} OR '/' || t.ancestry || '/' LIKE '%/{{taxon_id}}/%') " + 
  "GROUP By taxon_id, ancestry, ST_SnapToGrid(geom, 0+({{seed}}/2), 75+({{seed}}/2), {{seed}}, {{seed}})) snap_grid ) as obs_grid";


var defaultStyleGrid = 
  "#observations [zoom <9]{ " +
  "polygon-fill:#EFF3FF; " +
  "polygon-opacity:0.6; " +
  "line-opacity:1; " +
  "line-color:#FFFFFF; " +
  "[cnt>=25] { polygon-fill: {{taxon_color}}; polygon-opacity:1.0;  } " +
  "[cnt<20]  { polygon-fill: {{taxon_color}}; polygon-opacity:0.8;  } " +
  "[cnt<15]  { polygon-fill: {{taxon_color}}; polygon-opacity:0.6;  } " +
  "[cnt<10]  { polygon-fill: {{taxon_color}}; polygon-opacity:0.4;  } " +
  "[cnt<5]  { polygon-fill: {{taxon_color}}; polygon-opacity:0.2;  } }";


var config = {
  // base_url: '/database/:dbname/table/:table',
  base_url: '/:table/:endpoint',
  base_url_notable: '/:endpoint',
  grainstore: {
    datasource: {
      user:'agusti', 
      host: 'localhost',
      port: 5432,
      geometry_field: 'geom',
      srid: 4326
    }
  }, //see grainstore npm for other options
  redis: {host: '127.0.0.1', port: 6379},
  enable_cors: true,
  req2params: function(req, callback){
    // this is in case you want to test sql parameters eg ...png?sql=select * from my_table limit 10
    req.params =  _.extend({}, req.params);
    _.extend(req.params, req.query);

    req.params.dbname = 'inaturalist_fork';

    if(req.params.endpoint == 'grid' ){		//Grid endpoint
      var seed = 16/Math.pow(2,parseInt(req.params.z));
      if(seed > 4){
        seed = 4;
      }else if (seed == 1){
        seed = 0.99;
      }
      req.params.sql = gridQuery;
      if(req.params.taxon_id){
        req.params.sql = req.params.sql.replace(/\{\{taxon_id\}\}/g,req.params.taxon_id);
      }else{
        req.params.sql = req.params.sql.replace(/\{\{taxon_id\}\}/g,'-1');
      }
      req.params.sql = req.params.sql.replace(/\{\{seed\}\}/g, seed);
      if(!req.params.style){
        req.params.style = defaultStyleGrid;
      }
      if(req.params.taxon_color && req.params.taxon_color != 'undefined'){
        req.params.style = req.params.style.replace(/\{\{taxon_color\}\}/g,req.params.taxon_color);
      }else{
        //Boring blue
        req.params.style = req.params.style.replace(/\{\{taxon_color\}\}/g,'#FBB7ED');	
      }      
    }else if(req.params.endpoint == 'points'){	//Points endpoint
      req.params.sql = pointQuery;
      if(req.params.taxon_id){
        req.params.sql = req.params.sql.replace(/\{\{taxon_id\}\}/g,req.params.taxon_id);
      }else{
        req.params.sql = req.params.sql.replace(/\{\{taxon_id\}\}/g,'-1');
      }
      if(req.params.obs_id){
        req.params.sql = req.params.sql.replace(/\{\{obs_id\}\}/g,req.params.obs_id);		
      }else{
        req.params.sql = req.params.sql.replace(/\{\{obs_id\}\}/g,'-1');
      }
      if(!req.params.style){
        req.params.style = defaultStylePoints;
      }
      if(req.params.taxon_color && req.params.taxon_color != 'undefined'){
	req.params.style = req.params.style.replace(/\{\{taxon_color\}\}/g,req.params.taxon_color);
      }else{
        //Boring pink
	req.params.style = req.params.style.replace(/\{\{taxon_color\}\}/g,'#1E90FF');	
      }
    }
  // send the finished req object on
  var x = parseInt(req.params.x),
    y = parseInt(req.params.y),
    z = parseInt(req.params.z),
    numTiles = Math.pow(2,z),
    maxCoord = numTiles - 1
    
    x = x >= 0 ? x : maxCoord + x
    y = y >= 0 ? y : maxCoord + y
    if (x > maxCoord) {x = x % numTiles}
    if (y > maxCoord) {y = y % numTiles}
    if (x < -1*maxCoord) {x = Math.abs(x) % numTiles}
    if (y < -1*maxCoord) {y = Math.abs(y) % numTiles}
    req.params.x = ''+x
    req.params.y = ''+y
    req.params.z = ''+z

    callback(null,req);
  },
  beforeTileRender: function(req, res, callback) {
    callback(null);
  }
};

// Initialize tile server on port 4000
var ws = new Windshaft.Server(config);

ws.listen(4000);


console.log("map tiles are now being served out of: http://localhost:4000" + config.base_url + '/:z/:x/:y');
