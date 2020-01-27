$(function() {
  
  data = $('#data').data('data');
  
  var stratify = d3.stratify()
    .id(function(d) { return d.name})
    .parentId(function(d) { return d.parent});

  function format_name(d) {
    if(d.data.rank == "species"){
      var split_string = d.id.split(" ");
      var first_word = split_string.shift();
      split_string.unshift(first_word[0]+".");
      return split_string.join(' ')    
    }else if(d.data.rank == "subspecies" ){
      var split_string = d.id.split(" ");
      var first_word = split_string.shift();
      var second_word = split_string.shift();
      split_string.unshift(second_word[0]+".");
      split_string.unshift(first_word[0]+".");
      return split_string.join(' ')    
    }else{
      return d.id;
    }
  }

  function truncate(d, cutoff) {
    if(d.length > cutoff){
      return d.substring(0,(cutoff-3))+'...';
    }else{
      return d;
    }
  }
  
  // sort based on input taxa
  var sorting = data.internal_taxa.sort((a, b) => (a.name > b.name) ? 1 : -1),
    data_external_taxa = [];
  
  data.external_taxa.forEach(function(et){
    var match = sorting.map(function(j) { return j.name }).indexOf(et.name)
    if(match){
      et.ind = match 
    }else{
      et.ind = data.external_taxa.map(function(j) { return j.name }).indexOf(et.name)
    }
    data_external_taxa.push(et);
  });
  
  data_external_taxa.sort(function(a, b){
    var a1= a.ind, b1= b.ind;
    if(a1== b1) return 0;
      return a1> b1? 1: -1;
    });
    
  var root_internal = stratify(data.internal_taxa),
    root_external = stratify(data_external_taxa).sort(function(a, b){
      var a1= a.data.ind, b1= b.data.ind;
        if(a1== b1) return 0;
        return a1> b1? 1: -1;
      }),
    num_rows = Math.max(root_external.descendants().length, root_internal.descendants().length);
  
  // set up the svg
  var margin = {top: 1, right: 1, bottom: 1, left: 1},
    width = 800 - margin.left - margin.right,
    offset1 = 100,
    offset2 = (width/2 + 75),
    voffset2 = 20,
    height = Math.max( ( num_rows * 12 ), 200) + voffset2 - margin.top - margin.bottom;
  
  var svg = d3.select("div.it").append("svg") 
    .attr("viewBox", "0 0 " + (width + margin.left + margin.right) + " " + (height + margin.top + margin.bottom))
    .attr("preserveAspectRatio", "xMinYMin meet");
  
  var tree = d3.cluster()
    .size([height - voffset2, width/4.5]);
  
  // get the trees
  tree(root_external);
  tree(root_internal);
  
  // groups for the two background trees
  var g = svg.append("g").attr("transform", "translate(" + offset1 + ",0)");
  var g2 = svg.append("g").attr("transform", "translate(" + offset2 + "," + voffset2 + ")");
  
  var link = g.selectAll(".link")
    .data(root_internal.descendants().slice(1))
    .enter().append("path")
    .attr("class", "link")
    .attr("d", function(d) {
      return "M" + d.y + "," + d.x
            + "C" + (d.parent.y + 50) + "," + d.x
            + " " + (d.parent.y + 50) + "," + d.parent.x
            + " " + d.parent.y + "," + d.parent.x;
    }); 
  
  var trianglePoints = (width/2-35) + ' ' + (height/2+15) + ', ' + 
                       (width/2-15) + ' ' + (height/2+10) + ', ' + 
                       (width/2-35) + ' ' + (height/2+5);
  
  svg.append('polyline')
    .attr('points', trianglePoints);
  
  var link = g2.selectAll(".link")
    .data(root_external.descendants().slice(1))
    .enter().append("path")
    .attr("class", "link")
    .attr("d", function(d) {
        return "M" + d.y + "," + d.x
            + "C" + (d.parent.y + 50) + "," + d.x
            + " " + (d.parent.y + 50) + "," + d.parent.x
            + " " + d.parent.y + "," + d.parent.x;
    });
  
  var node = g.selectAll(".node")
      .data(root_internal.descendants())
      .enter().append("g")
      .attr("class", function(d) { return "node" + (d.children ? " node--internal" : " node--leaf"); })
      .attr("transform", function(d) { return "translate(" + d.y + "," + d.x + ")"; })
  
  node.append("circle")
      .style("fill", function(d){ return d.parent == null ? "gray" : "#76AC1E"; })
      .attr("r", 4)
      .on("mouseover", function(d) {
        if(d.data.url != null){
          d3.select(this).style("cursor", "pointer"); 
        }
      })
      .on("mouseout", function(d) {
        d3.select(this).style("cursor", "default"); 
      })
      .on("click", function(d){
        if(d.data.url != null){
          var url = "/taxa/" + d.data.url;
          window.location = url;
        }
      });
      
  var node2 = g2.selectAll(".node")
      .data(root_external.descendants())
      .enter().append("g")
      .attr("class", function(d) { return "node" + (d.children ? " node--internal" : " node--leaf"); })
      .attr("transform", function(d) { return "translate(" + d.y + "," + d.x + ")"; })
  
  node2.append("circle")
      .style("fill", function(d){ return d.parent == null ? "gray" : "#76AC1E"; })
      .attr("r", 4)
      .on("mouseover", function(d) {
        if(d.data.url != null){
          d3.select(this).style("cursor", "pointer"); 
        }
      })
      .on("mouseout", function(d) {
        d3.select(this).style("cursor", "default"); 
      })
      .on("click", function(d){
        if(d.data.url != null){
          window.location = d.data.url;
        }
      });
  
  // group for the labels
  var g_2 = svg.append("g").attr("transform", "translate(" + offset1 + ",0)");  
  var g2_2 = svg.append("g").attr("transform", "translate(" + offset2 + "," + voffset2 + ")");
  
  var node = g_2.selectAll(".node")
      .data(root_internal.descendants())
      .enter().append("g")
      .attr("class", function(d) { return "node" + (d.children ? " node--internal" : " node--leaf"); })
      .attr("transform", function(d) { return "translate(" + d.y + "," + d.x + ")"; })
  
  node.append("text")
      .attr("dy", 3)
      .attr("x", function(d) { return d.children ? -8 : 8; })
      .style("text-anchor", function(d) { return d.children ? "end" : "start"; })
      .text(function(d) { return truncate(format_name(d),17); })
 
  var node2 = g2_2.selectAll(".node")
      .data(root_external.descendants())
      .enter().append("g")
      .attr("class", function(d) { return "node" + (d.children ? " node--internal" : " node--leaf"); })
      .attr("transform", function(d) { return "translate(" + d.y + "," + d.x + ")"; })

  node2.append("text")
      .attr("dy", 3)
      .attr("x", function(d) { return d.children ? -8 : 8; })
      .style("text-anchor", function(d) { return d.children ? "end" : "start"; })
      .text(function(d) { return truncate(format_name(d),17); })
  
  
});
