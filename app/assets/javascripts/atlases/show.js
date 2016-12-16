$(function() {
  
  $('.destroy_all_alterations').on('click', function(event){
    event.preventDefault();    
    var $this = $(this);    
    var atlas_id = $this.attr("data-id");
    console.log(atlas_id);
    $.ajax({
      type: "POST",
      url: "/atlases/" + atlas_id + "/destroy_all_alterations",
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
      
  
});


