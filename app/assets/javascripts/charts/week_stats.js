$(function() {
  var margin = {top: 20, right: 100, bottom: 30, left: 50},
      width = 500 - margin.left - margin.right,
      height = 200 - margin.top - margin.bottom;

  var parseDate = d3.time.format("%d-%b-%y").parse,
      bisectDate = d3.bisector(function(d) { return d.date; }).left,
      formatValue = d3.format(",f"),
      formatDate = d3.time.format("%b %d");

  var x = d3.time.scale()
      .range([0, width]);

  var y = d3.scale.linear()
      .range([height, 0]);

  var xAxis = d3.svg.axis()
      .scale(x)
      .orient("bottom");

  var yAxis = d3.svg.axis()
      .scale(y)
      .orient("left");

  var line = d3.svg.line()
      .x(function(d) { return x(d.date); })
      .y(function(d) { return y(d.week_total); });

  var svg = d3.select("body").append("svg")
      .attr("viewBox", "0 0 " + (width + margin.left + margin.right) + " " + (height + margin.top + margin.bottom))
      .attr("preserveAspectRatio", "xMinYMin meet")
      .append("g")
      .attr("transform", "translate(" + margin.left + "," + margin.top + ")");

  d3.json("week_stats_json", function(error, data) {
    if (error) throw error;

    console.log(data);

    data.forEach(function(d) {
      d.date = new Date(d.week);
    });

    console.log(data);

    data.sort(function(a, b) {
      return a.date - b.date;
    });
    x.domain([data[0].date, data[data.length - 1].date]);
    y.domain(d3.extent(data, function(d) { return d.week_total; }));

    svg.append("g")
        .attr("class", "x axis")
        .attr("transform", "translate(0," + height + ")")
        .call(xAxis);

    svg.append("g")
        .attr("class", "y axis")
        .call(yAxis)
      .append("text")
        .attr("transform", "rotate(-90)")
        .attr("y", 6)
        .attr("dy", ".71em")
        .style("text-anchor", "end")
        .text("No. observations / week");

    svg.append("path")
        .datum(data)
        .attr("class", "line")
        .attr("d", line);

    maxy = d3.max(data, function(d) { return d.week_total; });
    maxx = data.filter(function(d) { return d.week_total == maxy; })[0].date

    var record = svg.append("g")
        .attr("class", "record")
        .attr("transform", "translate(" + x(maxx) + "," + y(maxy) + ")");;

    record.append("circle")
        .attr("r", 4.5);

    record.append("text")
        .text("1")
        .attr("class","rank")
        .attr("text-anchor", "middle")
        .attr("dy", ".35em");

    var focus = svg.append("g")
        .attr("class", "focus")
        .style("display", "none");

    focus.append("circle")
        .attr("r", 4.5);

    focus.append("text")
        .attr("class","rank")
        .attr("text-anchor", "middle")
        .attr("dy", ".35em");

    focus.append("rect")
        .attr("class","rect")
        .attr("x", 3)
        .attr("y", 3)
        .attr("width", 70)
        .attr("height", 50);

    focus.append("clipPath")
        .attr("id","clipCircle")
        .append("circle")
        .attr("class","clipPath")
        .attr("r",function(d) { return 7; })
        .attr("cx",function(d) { return 15; })
        .attr("cy",function(d) { return 40; });

    focus.append("image")
        .attr("x", function(d) { return 15-7; })
        .attr("y", function(d) { return 40-7; })
        .attr("width", function(d) { return 7*2; })
        .attr("height", function(d) { return 7*2; })
        .attr("class","img-circle")
        .attr("clip-path",function(d) { return "url(weekly_counts.html#clipCircle)"; });

    focus.append("text")
        .attr("class","title")
        .attr("text-anchor", "left")
        .attr("x",10)
        .attr("y",10)
        .attr("dy", ".35em");

    focus.append("text")
        .attr("class","obscount")
        .attr("text-anchor", "left")
        .attr("x",10)
        .attr("y",18)
        .attr("dy", ".35em");

    focus.append("text")
        .attr("class","topobserver")
        .text("Top observer")
        .attr("text-anchor", "left")
        .attr("x",10)
        .attr("y",27)
        .attr("dy", ".35em");

    focus.append("text")
        .attr("class","login")
        .attr("text-anchor", "left")
        .attr("x",25)
        .attr("y",40)
        .attr("dy", ".35em");

    svg.append("rect")
        .attr("class", "overlay")
        .attr("width", width)
        .attr("height", height)
        .on("mouseover", function() { focus.style("display", null); })
        .on("mouseout", function() { focus.style("display", "none"); })
        .on("mousemove", mousemove);

    function mousemove() {
      var x0 = x.invert(d3.mouse(this)[0]),
          i = bisectDate(data, x0, 1),
          d0 = data[i - 1],
          d1 = data[i],
          d = x0 - d0.date > d1.date - x0 ? d1 : d0;
      focus.attr("transform", "translate(" + x(d.date) + "," + y(d.week_total) + ")");
      focus.select("text.rank")
        .text( d.week_rank )
        .style("font", (d.week_rank < 100) ? "5px sans-serif" : "3px sans-serif" );
      var text_title = focus.select("text.title")
        text_title.text("Week of "+formatDate(d.date));
      var text_obscount = focus.select("text.obscount")
        text_obscount.text( formatValue(d.week_total) + " obs");
      var text_login = focus.select("text.login")
        text_login.text( (d.user_login.length > 15) ? "@"+d.user_login.substring(0,12)+'...' : "@"+d.user_login );
      if(y(d.week_total)>125){
        text_title.attr("y", (10-55) );
        text_obscount.attr("y", (18-55) );
        text_login.attr("y", (40-55));
        focus.select("rect.rect").attr("y", (3-55) );
        focus.select("text.topobserver").attr("y", (27-55));
        focus.select(".clipPath").attr("cy", (40-55));
        focus.select("image").attr("y", ((40-7)-55));
      }else{
        text_title.attr("y", 10 );
        text_obscount.attr("y", 18 );
        text_login.attr("y", 40 );
        focus.select("rect.rect").attr("y", 3 );
        focus.select("text.topobserver").attr("y", 27 );
        focus.select(".clipPath").attr("cy", 40 );
        focus.select("image").attr("y", (40-7) );
      }

      focus.select("image").attr("xlink:href", d.user_icon );
    }
  });
});