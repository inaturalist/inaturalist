$(function() {
  $('.collapse_button').on('click', function(event){
    
    var $this = $(this)
    $this.closest('tr').fadeOut();
    event.preventDefault();
    
    $.ajax({
      type: "DELETE",
      url: $this.attr('href'),
      success: function(data){
        console.log("success");
        var table_row = '<tr><td><a href="/places/'+data.place_id+'">'+data.place_name+'</a></td><td></td></tr>'; 
        $("tbody.places tr:last").after(table_row);
      },
      error: function(data){
        console.log("error");
      },
      dataType: 'JSON'
    });
  });
  
  $('.explode_button').on('click', function(event){
    
    var $this = $(this)
    $this.closest('tr').fadeOut();
    event.preventDefault();
    var place_atlas_ids = this.id.split("_");
    var place_id = place_atlas_ids[0];
    var atlas_id = place_atlas_ids[1];
    $.ajax({
      type: "POST",
      url: $this.attr('href'),
      data: { place_id: place_id, atlas_id: atlas_id },
      success: function(data){
        var table_row = '<tr><td><a href="/places/'+data.place_id+'">'+data.place_name+'</a></td><td></td></tr>'; 
        if($("tbody.exploded tr:last")){
          $("tbody.exploded").append(table_row);
          $(".no_exploded").fadeOut();
        }else{
          $("tbody.exploded tr:last").after(table_row);
        }
      },
      error: function(data){
        console.log("error");
      },
      dataType: 'JSON'
    });
  });
});