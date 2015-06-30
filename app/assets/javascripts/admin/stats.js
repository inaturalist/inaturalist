var Stats = { };

$(document).ready(function( ) {
  Stats.loadCharts( );
});

Stats.loadCharts = function( ) {
  var prefetched_stats;
  try { prefetched_stats = STATS_JSON; }
  catch( err ) { prefetched_stats = null; }
  if( prefetched_stats ) {
    Stats.loadChartsFromJSON( prefetched_stats );
  } else {
    Stats.loadAjaxCharts( );
  }
};

Stats.loadAjaxCharts = function( ) {
  $.getJSON("/admin/stats.json?start_date=" + Stats.yearAgoDate( ), function( json ) {
    Stats.loadChartsFromJSON( json );
  });
};

Stats.loadChartsFromJSON = function( json ) {
  Stats.loadObsSpark( json );
  Stats.loadPercentIdSpark( json );
  Stats.loadPercentCIDToGenusSpark( json );
  Stats.loadActiveUsersSpark( json );
  Stats.loadNewUsersSpark( json );
  Stats.load7ObsUsersSpark( json );

  Stats.loadObservations7Days( json );
  Stats.loadTTID( json );
  Stats.loadUsers( json );
  Stats.loadObservations( json );
  Stats.loadCumulativeUsers( json );
  Stats.loadProjects( json );
  Stats.loadRanks( json );
  Stats.loadRanksPie( json );
};

Stats.loadObsSpark = function ( json ) {
  google.setOnLoadCallback(Stats.sparkline({
    element_id: "obsspark",
    series: [
      { label: "Today" }
    ],
    data: _.map( json, function( stat ) {
      return [ new Date(stat.created_at), stat.data.observations.today ]
    })
  }));
}

Stats.loadPercentIdSpark = function ( json ) {
  google.setOnLoadCallback(Stats.sparkline({
    element_id: "percentidspark",
    series: [
      { label: "% ID" }
    ],
    data: _.map( json, function( stat ) {
      if (stat.data.identifier) {
        return [ new Date(stat.created_at), stat.data.identifier.percent_id]
      } else {
        return [ new Date(stat.created_at), 0]
      }
    })
  }));
}

Stats.loadPercentCIDToGenusSpark = function ( json ) {
  google.setOnLoadCallback(Stats.sparkline({
    element_id: "percentcidtogenusspark",
    series: [
      { label: "% ID" }
    ],
    data: _.map( json, function( stat ) {
      if (stat.data.identifier) {
        return [ new Date(stat.created_at), stat.data.identifier.percent_cid_to_genus ]
      } else {
        return [ new Date(stat.created_at), 0 ]
      }
    })
  }));
}
Stats.loadActiveUsersSpark = function ( json ) {
  google.setOnLoadCallback(Stats.sparkline({
    element_id: "activeusersspark",
    series: [
      { label: "% ID" }
    ],
    data: _.map( json, function( stat ) {
      return [ new Date(stat.created_at), stat.data.users.active ]
    })
  }));
}
Stats.loadNewUsersSpark = function ( json ) {
  google.setOnLoadCallback(Stats.sparkline({
    element_id: "newusersspark",
    series: [
      { label: "% ID" }
    ],
    data: _.map( json, function( stat ) {
      return [ new Date(stat.created_at), stat.data.users.last_7_days ]
    })
  }));
}
Stats.load7ObsUsersSpark = function ( json ) {
  google.setOnLoadCallback(Stats.sparkline({
    element_id: "new7obsusersspark",
    series: [
      { label: "% ID" }
    ],
    data: _.map( json, function( stat ) {
      return [ new Date(stat.created_at), stat.data.users.recent_7_obs ]
    })
  }));
}

Stats.loadObservations = function( json ) {
  google.setOnLoadCallback(Stats.simpleChart({
    element_id: "observations",
    series: [
      { label: "Total" },
      { label: "Research Grade" }
    ],
    data: _.map( json, function( stat ) {
      return [ new Date(stat.created_at), stat.data.observations.count, stat.data.observations.research_grade ]
    })
  }));
};

Stats.loadObservations7Days = function( json ) {
  google.setOnLoadCallback(Stats.simpleChart({
    element_id: "obs_7",
    chartType: google.visualization.AnnotationChart,
    series: [
      { label: "Obs" },
      { label: "Obs ID'd" },
      { label: "Obs CID'd" },
      { label: "Obs CID'd to genus" },
      { label: "Obs (1 day)" },
      { label: "Active Users" }
    ],
    data: _.map( json, function( stat ) {
      return [ 
        new Date(stat.created_at), 
        stat.data.observations.last_7_days, 
        stat.data.observations.identified, 
        stat.data.observations.community_identified, 
        stat.data.observations.community_identified_to_genus, 
        stat.data.observations.today, 
        stat.data.users.active
      ];
    })
  }));
};

Stats.loadTTID = function( json ) {
  var dodgerblue = d3.rgb('dodgerblue'),
      ldodgerblue = d3.rgb(dodgerblue.r + 75, dodgerblue.g + 75, dodgerblue.b + 75),
      pink = d3.rgb('deeppink'),
      lpink = d3.rgb(pink.r + 100, pink.g + 100, pink.b + 100)
  google.setOnLoadCallback(Stats.simpleChart({
    element_id: "ttid",
    chartType: google.visualization.AnnotationChart,
    series: [
      { label: "Med TTID" },
      { label: "Avg TTID" },
      { label: "Med TTCID" },
      { label: "Avg TTCID" }
    ],
    data: _.map( json, function( stat ) {
      if (stat.data.identifier) {
        return [ 
          new Date(stat.created_at), 
          stat.data.identifier.med_ttid / 60, 
          stat.data.identifier.avg_ttid / 60, 
          stat.data.identifier.med_ttcid / 60,
          stat.data.identifier.avg_ttcid / 60
        ];
      } else {
        return [ new Date(stat.created_at), null, null, null, null];
      }
    }),
    chartOptions: {
      scaleType: 'allfixed',
      colors: [
        dodgerblue.toString(), 
        ldodgerblue.toString(),
        pink.toString(), 
        lpink.toString()
      ]
    }
  }));
};

Stats.loadProjects = function( json ) {
  google.setOnLoadCallback(Stats.simpleChart({
    element_id: "projects",
    series: [ { label: "Total" } ],
    data: _.map( json, function( stat ) {
      return [ new Date(stat.created_at), stat.data.projects.count ]
    })
  }));
};

Stats.loadCumulativeUsers = function( json ) {
  google.setOnLoadCallback(Stats.simpleChart({
    element_id: "cumulative-users",
    series: [
      { label: "Total" },
      { label: "Active" },
      { label: "Curators" },
      { label: "Admins" }
    ],
    data: _.map( json, function( stat ) {
      return [ new Date(stat.created_at), stat.data.users.count, stat.data.users.active, stat.data.users.curators, stat.data.users.admins ];
    })
  }));
};

Stats.loadUsers = function( json ) {
  google.setOnLoadCallback(Stats.simpleChart({
    element_id: "users",
    chartType: google.visualization.AnnotationChart,
    series: [
      { label: "Active" },
      { label: "New" },
      { label: "Identifiers" },
      { label: "Recent" },
      { label: "Recent w/ >= 7 obs" },
      { label: "Recent w/ 0 obs" },
    ],
    data: _.map( json, function( stat ) {
      return [ 
        new Date(stat.created_at), 
        stat.data.users.active, 
        stat.data.users.today, 
        stat.data.users.identifiers,
        stat.data.users.last_7_days,
        stat.data.users.recent_7_obs,
        stat.data.users.recent_0_obs
      ];
    })
  }));
};

Stats.loadRanks = function( json ) {
  var ranks = _.keys( json[0].data.taxa.count_by_rank ).reverse( );
  google.setOnLoadCallback(Stats.simpleChart({
    element_id: "ranks",
    series: _.map( ranks, function( rank ) {
      return { label: rank }
    }),
    data: _.map( json, function( stat ) {
      var values = _.map( ranks, function( rank ) {
        return _.detect(stat.data.taxa.count_by_rank, function(v, k) { return k === rank });
      });
      values.unshift( new Date(stat.created_at) );
      return values;
    }),
    chartOptions: { isStacked: true }
  }));
};

Stats.loadRanksPie = function( json ) {
  google.setOnLoadCallback(Stats.simpleChart({
    element_id: "ranks_pie",
    data: _.map( json[0].data.taxa.count_by_rank, function( value, rank ) {
      return [ rank, parseInt( value ) ];
    }),
    chartType: google.visualization.PieChart
  }));
};

Stats.yearAgoDate = function( ) {
  var date = new Date( );
  return ( date.getFullYear( ) - 4 ) + "-" +
    (date.getMonth( ) + 1) + "-" + date.getDate( );
};

Stats.monthAgoDate = function( ) {
  var date = new Date( );
  return date.getFullYear( ) + "-" + date.getMonth( ) + "-" + date.getDate( );
};

Stats.simpleChart = function( options ) {
  options.chartType = options.chartType || google.visualization.AreaChart;
  var chartOptions = options.chartOptions || { };
  var data = new google.visualization.DataTable( );
  if( options.chartType === google.visualization.AreaChart ) {
    data.addColumn( 'date', 'Date' );
    chartOptions.vAxis = { minValue: 0 };
    chartOptions.height = 300;
    chartOptions.chartArea = { height: "80%" };
    chartOptions.explorer = { 
      axis: "horizontal", 
      keepInBounds: false, 
      zoomDelta: 1.05
    };
  } else if( options.chartType === google.visualization.PieChart ) {
    data.addColumn( 'string', 'Key' );
    data.addColumn( 'number', 'Value' );
    chartOptions.height = 600;
  } else if (options.chartType = google.visualization.AnnotationChart) {
    data.addColumn( 'date', 'Date' );
    chartOptions.min = 0
    chartOptions.zoomStartTime = new Date(Stats.monthAgoDate())
  }
  _.each( options.series, function( s ) {
    data.addColumn( 'number', s.label );
  });
  data.addRows( options.data );
  var chart = new options.chartType(
    document.getElementById( options.element_id ));
  chart.draw( data, chartOptions );
};

Stats.sparkline = function( options ) {
  var element = options.element_id,
      series = options.series,
      data = options.data,
      graph = d3.select("#"+element).append("svg:svg").attr("width", "100%").attr("height", "100%"),
      numDays = 100;
  data = _.map( data.slice(0, numDays).reverse(), function( stat ) {
    return stat[1] || 0
  })
  var x = d3.scale.linear().domain([0, data.length]).range([0, $('#'+element).width()]);
  var y = d3.scale.linear().domain([0, _.max(data)]).range([$('#'+element).height(), 0]);
  var line = d3.svg.line()
    .x(function(d,i) { 
      return x(i); 
    })
    .y(function(d) { 
      console.log("[DEBUG] scaling ", d, " to ", y(d))
      return y(d); 
    });
  graph.append("svg:path").attr("d", line(data));
}

