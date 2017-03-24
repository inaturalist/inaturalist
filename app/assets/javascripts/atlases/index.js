$(function() {
  $('.refresh_button').on('click', function(event){
    var $this = $(this)
    event.preventDefault();
    $.ajax({
  type: "post",
      dataType: "json",
      url: "/atlases/" + $this.data( "atlas-id" ) + "/refresh_atlas",
      success: function(data){
        if(data){
          $this.text("still marked");
        }else{
          $this.closest('tr').fadeOut();
        }
      },
      error: function(data){
        console.log("error");
      },
      dataType: 'JSON'
    });
  });
});
