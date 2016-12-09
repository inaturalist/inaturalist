$(function() {
  
  $('#destroy_all_alterations').on('click', function(event){
    event.preventDefault();    
    var $this = $(this);    
    var atlas_id = $this.attr("data-id");
    $.ajax({
      type: "POST",
      url: $this.attr('href'),
      data: { atlas_id: atlas_id },
      success: function(data){
        $("tbody#alteration tr").fadeOut();
        $("table").append("<div class='no_alteration'>No alterations to this atlas yet</div>");
        $this.fadeOut();
      },
      error: function(data){
        console.log("error");
      },
      dataType: 'JSON'
    });
  });
      
  var width = 960,
      height = 580;

  var color = d3.scale.category10();

  var projection = d3.geo.kavrayskiy7()
    .scale(170)
    .translate([width / 2, height / 2])
    .precision(.1);

  var path = d3.geo.path()
    .projection(projection);

  var graticule = d3.geo.graticule();

  var svg = d3.select("#map").append("svg") 
    .attr("viewBox", "0 0 " + width + " " + height)
    .attr("preserveAspectRatio", "xMinYMin meet");

  svg.append("defs").append("path")
    .datum({type: "Sphere"})
    .attr("id", "sphere")
    .attr("d", path);

  svg.append("use")
    .attr("class", "stroke")
    .attr("xlink:href", "#sphere");

  svg.append("use")
    .attr("class", "fill")
    .attr("xlink:href", "#sphere");
  
  var countries = world.features
  console.log(countries);
 
  var places = svg.selectAll(".country")
    .data(countries)
    .enter()
    .insert("path", ".graticule")
    .attr("class", "country")
    .attr("class", function(d){return "listing_"+d.id+"_"+taxon_id})
    .attr("d", path)
    .style('fill', function(d,i){ return (d.presence ? 'yellow' : 'rgb(204, 204, 204)');})
    .on("click", function(d){
      places.style("stroke", "#fff");
      var alter_link = d3.selectAll("#alter"); 
      alter_link.style("opacity", 1);
      alter_link.attr("data-taxon_id",taxon_id);
      alter_link.attr("data-place_id",d.id);
      var element = d3.selectAll(".listing_"+d.id+"_"+taxon_id);
      if(element.style("fill") == "rgb(204, 204, 204)"){
        element.style("stroke", "#000");        
        alter_link.text("Click here to list "+d.name);
      }else{
        element.style("stroke", "#000");
        alter_link.text("Click here to unlist "+d.name);        
      }
    });
  
  $('#alter').on('click', function(event){
    event.preventDefault();
    
    var $this = $(this);
    if($this.hasClass("disabled")){
      return;
    }else{
      $this.addClass("disabled")
      var taxon_id = $this.attr("data-taxon_id");
      var place_id = $this.attr("data-place_id");
      $.ajax({
        type: "POST",
        url: $this.attr('href'),
        data: { place_id: place_id, taxon_id: taxon_id },
        success: function(data){
          console.log("success");
          var place_id = data.place_id;
          var presence = data.presence;
          var link = $(".disabled");
          link.attr("data-taxon_id",taxon_id);
          link.attr("data-place_id",place_id);
          if(presence){
            link.text("Click here to unlist "+data.place_name);  
            var element = d3.selectAll(".listing_"+place_id+"_"+taxon_id);
            element.style("fill", "yellow");
          }else{
            link.text("Click here to list "+data.place_name);  
            var element = d3.selectAll(".listing_"+place_id+"_"+taxon_id);
            element.style("fill", "#ccc");
          }
          link.removeClass("disabled");
        },
        error: function(data){
          console.log("error");
        },
        dataType: 'JSON'
      });
    }
  });  
 
});


