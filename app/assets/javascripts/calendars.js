$(document).ready(function() {
  if ($.browser.msie && parseInt($.browser.version) < 9) {
    return
  }
  window.colorscale = d3.scale.linear()
    .domain([0,50])
    .range(["#fefefe", "#aaa"])
  $('.calendar .daylink').css('background-color', function() {
    var c = $(this).attr('data-count')
    return colorscale(Math.min(c, 50))
  })
})
