/* global I18n */
/* global STATS_SUMMARY_URL */
/* global STATS_SUMMARY */
/* global HOMEPAGE_DATA */

function addObservations( observations ) {
  if ( !observations ) {
    return;
  }
  for ( var i = 0; i < observations.length; i += 1 ) {
    var o = observations[i];
    var item = $( "<div class=\"item\">" ).append(
      $( "<a class=\"heroimage\">" ).attr( "href", "/observations/" + o.id ).css( "backgroundImage", "url(" + o.image_url + ")" ).html(
        "........... ........... ........... ........... ........... ........... "
        + "........... ........... ........... ........... ........... ........... "
        + "........... ........... ........... ........... ........... ........... "
        + "........... ........... ........... ........... ........... ........... "
        + "........... ........... ........... ........... ........... ........... "
        + "........... ........... ........... ........... ........... ........... "
      ),
      $( "<div class=\"herofooter\">" ).append(
        $( "<div class=\"container container-fixed\">" ).append(
          $( "<div class=\"row\">" ).append(
            $( "<div class=\"col-xs-11 col-xs-offset-1\">" ).append(
              $( "<a>" ).attr( "href", "/people/" + o.user.login ).html(
                $( "<img/>" ).attr( "src", o.user.user_icon_url )
              ),
              $( "<a class=\"obstext\">" ).attr( "href", "/observations/" + o.id ).append(
                $( "<span class=\"username\">" ).html( o.user.name ),
                I18n.t( "observation_brief_taxon_from_place", {
                  taxon: $( "<span class='taxonname'>" ).html( o.taxon.default_name.name ).prop( "outerHTML" ),
                  place: $( "<span class='location'>" ).html( o.place_guess ).prop( "outerHTML" )
                } )
              )
            )
          )
        )
      )
    );
    item.data( "observation", o );
    if ( i === 0 ) {
      item.addClass( "active" );
      $( "#hero .item" ).removeClass( "active" );
      $( "#hero .carousel-inner" ).prepend( item, " " );
    } else {
      $( "#hero .carousel-inner" ).append( " ", item );
    }
  }
}

function addTestimonials( testimonials ) {
  if ( !testimonials ) { return; }
  for ( var i = 0; i < testimonials.length; i += 1 ) {
    var t = testimonials[i];
    var item = $( "<div class=\"item\">" ).append(
      $( "<div class=\"row\">" ).append(
        $( "<div class=\"col-xs-7\">" ).append(
          $( "<blockquote>" ).html( t.body ),
          $( "<a class=\"name\">" ).attr( "href", t.url ).html( t.name ),
          $( "<div class=\"role\">" ).html( t.role ),
          $( "<div class=\"location\">" ).append(
            $( "<i class=\"fa fa-map-marker\"></i>" ),
            " ",
            t.location
          )
        ),
        $( "<div class=\"col-xs-4 col-xs-offset-1 centered\">" ).append(
          $( "<a>" ).attr( "href", t.url ).html(
            $( "<img class=\"img-circle img-responsive\">" ).attr( "src", t.image_url )
          )
        )
      )
    );
    var indicator = $( "<li>" ).attr( "data-target", "#who-carousel" ).attr( "data-slide-to", i );
    if ( i === 0 ) {
      item.addClass( "active" );
      indicator.addClass( "active" );
    }
    $( "#who .carousel-inner" ).append( item, " " );
    $( "#who .carousel-indicators" ).append( indicator, " " );
  }
}

$( document ).ready( function () {
  $.getJSON( STATS_SUMMARY_URL, function ( json ) {
    window.STATS_SUMMARY = json;
    $( "#obs-stats-container h1" ).html( I18n.toNumber( STATS_SUMMARY.total_observations, { precision: 0 } ) );
    $( "#obs-stats-container p" ).html(
      I18n.t( "views.welcome.index.observations_to_date", { count: STATS_SUMMARY.total_leaf_taxa } )
    );
    $( "#species-stats-container h1" ).html( I18n.toNumber( STATS_SUMMARY.total_leaf_taxa, { precision: 0 } ) );
    $( "#species-stats-container p" ).html(
      I18n.t( "views.welcome.index.species_observed", { count: STATS_SUMMARY.total_leaf_taxa } )
    );
    $( "#people-stats-container h1" ).html( I18n.toNumber( STATS_SUMMARY.total_users, { precision: 0 } ) );
    $( "#people-stats-container p" ).html(
      I18n.t( "views.welcome.index.people_signed_up", { count: STATS_SUMMARY.total_users } )
    );
  } );
  if ( HOMEPAGE_DATA ) {
    addObservations( HOMEPAGE_DATA.observations );
    addTestimonials( HOMEPAGE_DATA.testimonials );
  }
} );

$( "#hero-carousel" ).on( "slide.bs.carousel", function ( e ) {
  var item = $( e.relatedTarget );
  var fadeInSelector = "#connect-container";
  switch ( item.index() ) {
    case 1:
      fadeInSelector = "#obs-stats-container";
      break;
    case 2:
      fadeInSelector = "#species-stats-container";
      break;
    case 3:
      fadeInSelector = "#people-stats-container";
      break;
    default:
      fadeInSelector = "#obs-stats-container";
  }
  $( ".herobox-container:visible" ).fadeOut( function () {
    if ( item.data( "observation" ) && item.data( "observation" ).background_color ) {
      $( ".herobox", fadeInSelector ).css( "backgroundColor", item.data( "observation" ).background_color );
    }
    $( fadeInSelector ).fadeIn();
  } );
} );
