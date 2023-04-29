/* global _ */
/* global google */
/* global I18n */
/* global STATS_JSON */
/* global d3 */

var Stats = { };

Stats.dateForStat = function ( stat ) {
  var date = new Date( stat.created_at );
  var timezoneOffsetInMilliseconds = date.getTimezoneOffset( ) * 60 * 1000;
  var startOfLocalDay = new Date( date.getTime() + timezoneOffsetInMilliseconds );
  return startOfLocalDay;
};

Stats.loadCharts = function ( ) {
  var prefetchedStats;
  try {
    prefetchedStats = STATS_JSON;
  } catch ( err ) {
    prefetchedStats = null;
  }
  if ( prefetchedStats ) {
    Stats.loadChartsFromJSON( prefetchedStats );
  } else {
    Stats.loadAjaxCharts( );
  }
};

Stats.loadAjaxCharts = function ( ) {
  $.getJSON( "/stats.json?start_date=" + Stats.yearAgoDate( ), function ( json ) {
    Stats.loadChartsFromJSON( json );
  } );
};

Stats.loadChartsFromJSON = function ( json ) {
  Stats.loadObsSpark( json );
  Stats.loadPercentIdSpark( json );
  Stats.loadPercentCIDToGenusSpark( json );
  Stats.loadActiveUsersSpark( json );
  Stats.loadNewUsersSpark( json );
  Stats.load7ObsUsersSpark( json );

  Stats.loadObservations7Days( json );
  Stats.loadPlatforms( json );
  Stats.loadTTID( json );
  Stats.loadActiveUsers( json );
  Stats.loadRecentUsers( json );
  Stats.loadDailyUsers( json );
  Stats.loadObservations( json );
  Stats.loadCumulativeUsers( json );
  Stats.loadCumulativePlatforms( json );
  Stats.loadProjects( json );
  Stats.loadRanks( json );
  Stats.loadRanksPie( json );
};

Stats.loadObsSpark = function ( json ) {
  Stats.sparkline( {
    element_id: "obsspark",
    series: [
      { label: "Today" }
    ],
    data: _.map( json, function ( stat ) {
      return [Stats.dateForStat( stat ), stat.data.observations.today];
    } )
  } );
};

Stats.loadPercentIdSpark = function ( json ) {
  Stats.sparkline( {
    element_id: "percentidspark",
    series: [
      { label: "% ID" }
    ],
    data: _.map( json, function ( stat ) {
      if ( stat.data.identifier ) {
        return [Stats.dateForStat( stat ), stat.data.identifier.percent_id];
      }
      return [Stats.dateForStat( stat ), 0];
    } )
  } );
};

Stats.loadPercentCIDToGenusSpark = function ( json ) {
  Stats.sparkline( {
    element_id: "percentcidtogenusspark",
    series: [
      { label: "% ID" }
    ],
    data: _.map( json, function ( stat ) {
      if ( stat.data.identifier ) {
        return [Stats.dateForStat( stat ), stat.data.identifier.percent_cid_to_genus];
      }
      return [Stats.dateForStat( stat ), 0];
    } )
  } );
};

Stats.loadActiveUsersSpark = function ( json ) {
  Stats.sparkline( {
    element_id: "activeusersspark",
    series: [
      { label: "% ID" }
    ],
    data: _.map( json, function ( stat ) {
      return [Stats.dateForStat( stat ), stat.data.users.active];
    } )
  } );
};

Stats.loadNewUsersSpark = function ( json ) {
  Stats.sparkline( {
    element_id: "newusersspark",
    series: [
      { label: "% ID" }
    ],
    data: _.map( json, function ( stat ) {
      return [Stats.dateForStat( stat ), stat.data.users.last_7_days];
    } )
  } );
};

Stats.load7ObsUsersSpark = function ( json ) {
  Stats.sparkline( {
    element_id: "new7obsusersspark",
    series: [
      { label: "% ID" }
    ],
    data: _.map( json, function ( stat ) {
      return [Stats.dateForStat( stat ), stat.data.users.recent_7_obs];
    } )
  } );
};

Stats.loadObservations = function ( json ) {
  google.charts.setOnLoadCallback( function ( ) {
    Stats.simpleChart( {
      chartOptions: {
        legend: { position: "bottom" }
      },
      element_id: "observations",
      series: [
        { label: I18n.t( "total" ) },
        { label: I18n.t( "research_grade" ) }
      ],
      data: _.map( json, function ( stat ) {
        stat.data.platforms_cumulative = stat.data.platforms_cumulative || { };
        return [
          Stats.dateForStat( stat ),
          stat.data.observations.count,
          stat.data.observations.research_grade
        ];
      } )
    } );
  } );
};

Stats.loadCumulativePlatforms = function ( json ) {
  google.charts.setOnLoadCallback( function ( ) {
    Stats.simpleChart( {
      element_id: "cumulative-platforms",
      chartOptions: { isStacked: true },
      series: [
        { label: I18n.t( "website" ) },
        { label: I18n.t( "iphone" ) },
        { label: I18n.t( "android" ) },
        { label: I18n.t( "other" ) }
      ],
      data: _.map( json, function ( stat ) {
        stat.data.platforms_cumulative = stat.data.platforms_cumulative || { };
        return [
          Stats.dateForStat( stat ),
          stat.data.platforms_cumulative.web,
          stat.data.platforms_cumulative.iphone,
          stat.data.platforms_cumulative.android,
          stat.data.platforms_cumulative.other
        ];
      } )
    } );
  } );
};

Stats.loadObservations7Days = function ( json ) {
  google.charts.setOnLoadCallback( function ( ) {
    Stats.simpleChart( {
      element_id: "obs_7",
      chartType: "AnnotationChart",
      series: [
        { label: I18n.t( "obs" ) },
        { label: I18n.t( "obs_id_d" ) },
        { label: I18n.t( "obs_cid_d" ) },
        { label: I18n.t( "views.stats.index.obs_cid_d_to_genus" ) },
        { label: I18n.t( "views.stats.index.obs_1_day" ) }
      ],
      data: _.map( json, function ( stat ) {
        return [
          Stats.dateForStat( stat ),
          stat.data.observations.last_7_days,
          stat.data.observations.identified,
          stat.data.observations.community_identified,
          stat.data.observations.community_identified_to_genus,
          stat.data.observations.today
        ];
      } )
    } );
  } );
};

Stats.loadPlatforms = function ( json ) {
  google.charts.setOnLoadCallback( function ( ) {
    Stats.simpleChart( {
      element_id: "platforms",
      chartType: "AnnotationChart",
      series: [
        { label: I18n.t( "website" ) },
        { label: I18n.t( "iphone" ) },
        { label: I18n.t( "android" ) },
        { label: I18n.t( "other" ) }
      ],
      data: _.map( json, function ( stat ) {
        stat.data.platforms = stat.data.platforms || { };
        return [
          Stats.dateForStat( stat ),
          stat.data.platforms.web,
          stat.data.platforms.iphone,
          stat.data.platforms.android,
          stat.data.platforms.other
        ];
      } )
    } );
  } );
};

Stats.loadTTID = function ( json ) {
  var dodgerblue = d3.rgb( "dodgerblue" );
  var ldodgerblue = d3.rgb( dodgerblue.r + 75, dodgerblue.g + 75, dodgerblue.b + 75 );
  var pink = d3.rgb( "deeppink" );
  var lpink = d3.rgb( pink.r + 100, pink.g + 100, pink.b + 100 );
  google.charts.setOnLoadCallback( function ( ) {
    Stats.simpleChart( {
      element_id: "ttid",
      chartType: "AnnotationChart",
      series: [
        { label: I18n.t( "views.stats.index.med_ttid" ) },
        { label: I18n.t( "views.stats.index.avg_ttid" ) },
        { label: I18n.t( "views.stats.index.med_ttcid" ) },
        { label: I18n.t( "views.stats.index.avg_ttcid" ) }
      ],
      data: _.map( json, function ( stat ) {
        if ( stat.data.identifier ) {
          return [
            Stats.dateForStat( stat ),
            stat.data.identifier.med_ttid / 60,
            stat.data.identifier.avg_ttid / 60,
            stat.data.identifier.med_ttcid / 60,
            stat.data.identifier.avg_ttcid / 60
          ];
        }
        return [Stats.dateForStat( stat ), null, null, null, null];
      } ),
      chartOptions: {
        scaleType: "allfixed",
        colors: [
          dodgerblue.toString(),
          ldodgerblue.toString(),
          pink.toString(),
          lpink.toString()
        ]
      }
    } );
  } );
};

Stats.loadProjects = function ( json ) {
  google.charts.setOnLoadCallback( function ( ) {
    Stats.simpleChart( {
      chartOptions: {
        legend: { position: "none" }
      },
      element_id: "projects",
      series: [{ label: I18n.t( "total" ) }],
      data: _.map( json, function ( stat ) {
        return [Stats.dateForStat( stat ), stat.data.projects.count];
      } )
    } );
  } );
};

Stats.loadCumulativeUsers = function ( json ) {
  google.charts.setOnLoadCallback( function ( ) {
    Stats.simpleChart( {
      chartOptions: {
        legend: { position: "bottom" }
      },
      element_id: "cumulative-users",
      series: [
        { label: I18n.t( "total" ) },
        { label: I18n.t( "active" ) },
        { label: I18n.t( "curators" ) }
      ],
      data: _.map( json, function ( stat ) {
        return [
          Stats.dateForStat( stat ),
          stat.data.users.count,
          stat.data.users.active,
          stat.data.users.curators
        ];
      } )
    } );
  } );
};

Stats.loadDailyUsers = function ( json ) {
  google.charts.setOnLoadCallback( function ( ) {
    Stats.simpleChart( {
      element_id: "daily-users",
      chartType: "AnnotationChart",
      series: [
        { label: I18n.t( "new" ) },
        { label: I18n.t( "observers" ) },
        { label: I18n.t( "identifiers" ) }
      ],
      data: _.map( json, function ( stat ) {
        return [
          Stats.dateForStat( stat ),
          stat.data.users.today,
          stat.data.users.observers,
          stat.data.users.identifiers
        ];
      } )
    } );
  } );
};

Stats.loadActiveUsers = function ( json ) {
  google.charts.setOnLoadCallback( function ( ) {
    Stats.simpleChart( {
      element_id: "active-users",
      chartType: "AnnotationChart",
      series: [
        { label: I18n.t( "active_users" ) }
      ],
      data: _.map( json, function ( stat ) {
        return [
          Stats.dateForStat( stat ),
          stat.data.users.active
        ];
      } )
    } );
  } );
};

Stats.loadRecentUsers = function ( json ) {
  google.charts.setOnLoadCallback( function ( ) {
    Stats.simpleChart( {
      element_id: "recent-users",
      chartType: "AnnotationChart",
      series: [
        { label: I18n.t( "recent" ) },
        { label: I18n.t( "views.stats.index.recent_w_7_obs" ) },
        { label: I18n.t( "views.stats.index.recent_w_0_obs" ) }
      ],
      data: _.map( json, function ( stat ) {
        return [
          Stats.dateForStat( stat ),
          stat.data.users.last_7_days,
          stat.data.users.recent_7_obs,
          stat.data.users.recent_0_obs
        ];
      } )
    } );
  } );
};

Stats.loadRanks = function ( json ) {
  var ranks = Object.keys( json[0].data.taxa.count_by_rank ).reverse( );
  google.charts.setOnLoadCallback( function ( ) {
    Stats.simpleChart( {
      element_id: "ranks",
      series: _.map( ranks, function ( rank ) {
        return {
          label: I18n.t( "ranks." + rank, {
            defaultValue: I18n.t( rank, {
              defaultValue: rank
            } )
          } )
        };
      } ),
      data: _.map( json, function ( stat ) {
        var values = _.map( ranks, function ( rank ) {
          return _.find( stat.data.taxa.count_by_rank, function ( v, k ) { return k === rank; } );
        } );
        values.unshift( Stats.dateForStat( stat ) );
        return values;
      } ),
      chartOptions: {
        isStacked: true
      }
    } );
  } );
};

Stats.loadRanksPie = function ( json ) {
  google.charts.setOnLoadCallback( function ( ) {
    Stats.simpleChart( {
      element_id: "ranks_pie",
      data: _.map( json[0].data.taxa.count_by_rank, function ( value, rank ) {
        return [I18n.t( "ranks." + rank, { defaultValue: rank } ), parseInt( value, 0 )];
      } ),
      chartType: "PieChart"
    } );
  } );
};

Stats.yearAgoDate = function ( ) {
  var date = new Date( );
  return ( date.getFullYear( ) - 4 ) + "-"
    + ( date.getMonth( ) + 1 ) + "-" + date.getDate( );
};

Stats.monthAgoDate = function ( ) {
  var date = new Date( );
  var year = date.getFullYear( );
  var month = ( ( date.getMonth( ) + 11 ) % 12 ) + 1;
  if ( date.getMonth( ) === 0 ) {
    year -= 1;
  }
  var monthAgo = year + "-" + month + "-" + date.getDate( );
  return monthAgo;
};

Stats.simpleChart = function ( opts ) {
  var options = _.assign( {}, opts );
  options.chartType = options.chartType || google.visualization.AreaChart;
  if ( typeof ( options.chartType ) === "string" ) {
    options.chartType = google.visualization[options.chartType];
  }
  var chartOptions = options.chartOptions || { };
  var data = new google.visualization.DataTable( );
  if ( options.chartType === google.visualization.AreaChart ) {
    data.addColumn( "date", "Date" );
    chartOptions.vAxis = { minValue: 0 };
    chartOptions.height = 300;
    chartOptions.chartArea = { height: "80%" };
    chartOptions.explorer = {
      axis: "horizontal",
      keepInBounds: false,
      zoomDelta: 1.05
    };
  } else if ( options.chartType === google.visualization.PieChart ) {
    data.addColumn( "string", "Key" );
    data.addColumn( "number", "Value" );
  } else if ( options.chartType === google.visualization.AnnotationChart ) {
    data.addColumn( "date", "Date" );
    chartOptions.min = 0;
    chartOptions.zoomStartTime = new Date( Stats.monthAgoDate( ) );
  }
  _.each( options.series, function ( s ) {
    data.addColumn( "number", s.label );
  } );
  data.addRows( options.data );
  var chart = new options.chartType( document.getElementById( options.element_id ) );
  chart.draw( data, chartOptions );
};

Stats.sparkline = function ( options ) {
  var element = options.element_id;
  var series = options.series;
  var data = options.data;
  var graph = d3.select( "#" + element ).append( "svg:svg" ).attr( "width", "100%" ).attr( "height", "100%" );
  var numDays = 100;
  data = _.map( data.slice( 0, numDays ).reverse(), function ( stat ) {
    return stat[1] || 0;
  } );
  var x = d3.scale.linear().domain( [0, data.length] ).range( [0, $( "#" + element ).width()] );
  var y = d3.scale.linear().domain( [0, _.max( data )] ).range( [$( "#" + element ).height(), 0] );
  var line = d3.svg.line()
    .x( function ( d, i ) {
      return x( i );
    } )
    .y( function ( d ) {
      return y( d );
    } );
  graph.append( "svg:path" ).attr( "d", line( data ) );
};
