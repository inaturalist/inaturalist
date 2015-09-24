if (HOMEPAGE_DATA_URL) {
  console.log("[DEBUG] HOMEPAGE_DATA_URL: ", HOMEPAGE_DATA_URL)
  $.getJSON(HOMEPAGE_DATA_URL, function(json) {
    addObservations(json.observations)
    addTestimonials(json.testimonials)
  })
}

function addObservations(observations) {
  if (!observations) {
    return
  }
  for (var i = 0; i < observations.length; i++) {
    var o = observations[i]
    var item = $('<div class="item">').append(
      $('<div class="heroimage">').css('backgroundImage', 'url('+o.image_url+')').html(
        '........... ........... ........... ........... ........... ........... ' +
        '........... ........... ........... ........... ........... ........... ' +
        '........... ........... ........... ........... ........... ........... ' +
        '........... ........... ........... ........... ........... ........... ' +
        '........... ........... ........... ........... ........... ........... ' +
        '........... ........... ........... ........... ........... ........... '
      ),
      $('<div class="herofooter">').append(
        $('<div class="row">').append(
          $('<div class="col-xs-11 col-xs-offset-1">').append(
            $('<a>').attr('href', '/people/'+o.user.login).html(
              $('<img/>').attr('src', o.user.user_icon_url)
            ),
            $('<a class="obstext">').attr('href', '/observations/'+o.id).html(o.taxon.default_name.name),
            $('<a class="username">').attr('href', '/observations/'+o.id).html(I18n.t('observed_by') + ' ' + o.user.name)
          )
        )
      ),
      $('#herobox').clone().attr('id', '').removeClass('fade')
    )
    if (i == 0) {
      item.addClass('active')
      $('#hero .item').removeClass('active')
      $('#hero .carousel-inner').prepend(item, ' ')
    } else {
      $('#hero .carousel-inner').append(' ', item)
    }
  }
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
          $('<a>').attr('href', t.url).html(
            $('<img class="img-circle img-responsive">').attr('src', t.image_url)
          )
        )
      )
    )
    var indicator = $('<li>').attr('data-target', '#who-carousel').attr('data-slide-to', i)
    if (i == 0) {
      item.addClass('active')
      indicator.addClass('active')
    }
    $('#who .carousel-inner').append(item, ' ')
    $('#who .carousel-indicators').append(indicator, ' ')
  }
}
