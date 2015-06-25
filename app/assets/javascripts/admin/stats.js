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
  Stats.loadObservations( json );
  Stats.loadUsers( json );
  Stats.loadProjects( json );
  Stats.loadRanks( json );
  Stats.loadRanksPie( json );
  Stats.loadObservations7Days( json );
};

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
      { label: "Observations" },
      { label: "Identifications" },
      { label: "Active Users" }
    ],
    data: _.map( json, function( stat ) {
      return [ new Date(stat.created_at), stat.data.identifications.last_7_days, stat.data.observations.last_7_days, stat.data.users.active ];
    })
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

Stats.loadUsers = function( json ) {
  google.setOnLoadCallback(Stats.simpleChart({
    element_id: "users",
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
    chartOptions.chartArea = { width: "70%", height: "80%" };
    chartOptions.explorer = { axis: "horizontal", keepInBounds: true, zoomDelta: 1.05 };
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
