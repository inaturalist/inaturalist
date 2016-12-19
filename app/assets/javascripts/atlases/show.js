$(function() {
  
  $('.destroy_all_alterations').on('click', function(event){
    event.preventDefault();    
    var $this = $(this);    
    var atlas_id = $this.attr("data-id");
    console.log(atlas_id);
    $.ajax({
      type: "POST",
      url: "/atlases/" + atlas_id + "/destroy_all_alterations",
      data: { id: atlas_id },
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
  
  $('.remove_atlas_alteration').on('click', function(event){
    event.preventDefault();    
    var $this = $(this);    
    var aa_id = $this.attr("data-atlas-alteration-id");
    $.ajax({
      type: "POST",
      url: "/atlases/" + $( "#map" ).data( "atlas-id" ) + "/remove_atlas_alteration",
      data: { aa_id: aa_id },
      success: function(data){
        console.log("success");
      },
      error: function(data){
        console.log("error");
      },
      dataType: 'JSON'
    });
  });
      
  $('.remove_listed_taxon_alteration').on('click', function(event){
    event.preventDefault();    
    var $this = $(this);    
    var lta_id = $this.attr("data-listed-taxon-alteration-id");
    $.ajax({
      type: "POST",
      url: "/atlases/" + $( "#map" ).data( "atlas-id" ) + "/remove_listed_taxon_alteration",
      data: { lta_id: lta_id },
      success: function(data){
        console.log("success");
      },
      error: function(data){
        console.log("error");
      },
      dataType: 'JSON'
    });
  });
  
});


