if (HOMEPAGE_DATA_URL) {
  console.log("[DEBUG] HOMEPAGE_DATA_URL: ", HOMEPAGE_DATA_URL)
  $.getJSON(HOMEPAGE_DATA_URL, function(json) {
    console.log("[DEBUG] json: ", json)
    addObservations(json.observations)
    addTestimonials(json.testimonials)
  })
}

function addObservations(observations) {
  if (!observations) {
    return
  }
  var o = observations[0]
  $('#hero .heroimage').html(
    $('<img/>').attr('src', o.image_url)
  )
  $("#herofooter [class*='col-']").html(
    $('<a>').attr('href', '/people/'+o.user.login).html(
      $('<img/>').attr('src', o.user.user_icon_url)
    )
  ).append(
    $('<a class="obstext">').attr('href', '/observations/'+o.id).html(o.taxon.default_name.name),
    $('<a class="username">').attr('href', '/observations/'+o.id).html(I18n.t('observed_by') + ' ' + o.user.name)
  )
}

function addTestimonials(testimonials) {
  if (!testimonials) { return };
  for (var i = 0; i < testimonials.length; i++) {
    var t = testimonials[i]
    var item = $('<div class="item">').append(
      $('<div class="row">').append(
        $('<div class="col-xs-8 bigpadded">').append(
          $('<blockquote>').html(t.body),
          $('<a class="name">').attr('href', t.url).html(t.name),
          $('<div class="role">').html(t.role),
          $('<div class="location">').append(
            $('<i class="fa fa-map-marker></i>'),
            t.location
          )
        ),
        $('<div class="col-xs-3">').append(
          $('<a class="name">').attr('href', t.url).html(
            $('<img class="img-circle img-responsive">').attr('src', t.image_url)
          )
        )
      )
    )
    if (i == 0) {
      item.addClass('active')
    }
    $('#who .carousel-inner').append(item)
  }
}