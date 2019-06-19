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
          $this.closest('td').prev().text("true");
        }else{
          $this.closest('td').prev().text("false");
        }
      },
      error: function(data){
        console.log("error");
      }
    });
  });
});
