var CACHED_AT = new Date(Date.now()*1000);

function get_content(url, target){
  $.ajax({
    type: "GET",
    url: url,
    error: function(data){
      console.log("There was a problem");
    },
    success: function(data){
      $(target).html(data);

      $("#more_pagination").click(function(e){
        e.preventDefault();
        $('body').scrollTop(0);
        var from = $(this).data('from');
        var url = "/users/dashboard_updates?from="+from;
        var target = "#updates_target";
        $(target).html('<div class="loading status">'+I18n.t('loading')+'</div>');
        get_content(url, target);         
      });

      $("#more_pagination_you").click(function(e){
        e.preventDefault();
        $('body').scrollTop(0);
        var from = $(this).data('from');
        var url = "/users/dashboard_updates?from="+from+"&filter=you";
        var target = "#updates_by_you_target";
        $(target).html('<div class="loading status">'+I18n.t('loading')+'</div>');
        get_content(url, target);          
      });

      if(target == "#comments_target"){
        $('#comments_target').addClass('timeline');
      }else{
        $('.subscriptionsettings').subscriptionSettings()
      }

    }
  });
}

function close_panel(element, panelType) {
  $( "#" + panelType + "_panel" ).fadeOut();
  var pref = { };
  pref[ "prefers_hide_" + panelType + "_onboarding" ] = true;
  updateSession( pref );       
}

$(document).ready(function() {
  get_content("/users/dashboard_updates","#updates_target");

  $('a[data-toggle="tab"]').on('shown.bs.tab', function (e) {
    var active_tab = $(e.target).attr("href") // activated tab
    if(active_tab == "#comments"){
      var url = "/comments?partial=true";
      var target = "#comments_target";
    }else if(active_tab == "#updates_by_you"){          
      var url = "/users/dashboard_updates?filter=you";
      var target = "#updates_by_you_target";
    }else{
      var url = "/users/dashboard_updates";
      var target = "#updates_target";
    }
    get_content(url, target);
  })

  $('abbr.timeago').timeago()
  if ((new Date()).getTime() - CACHED_AT.getTime() > 5000) {
    $('#flash').hide()
  }
  var dayInSeconds = 24 * 60 * 60,
      now = new Date(),
      monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']

  var elt = $('abbr.compact.date:first')
  if (elt.length > 0) {
    var dateString = $(elt).attr('title').split('T')[0],
        timeString = $(elt).attr('title').split('T')[1],
        d = new Date(Date.parse($(elt).attr('title')))

    $('abbr.compact.date').each(function() {
      var dateString = $(this).attr('title').split('T')[0],
          timeString = $(this).attr('title').split('T')[1],
          d = new Date(Date.parse($(elt).attr('title')))
      if (!timeString.indexOf(':') || typeof(d) != 'object') { return }
      if (now.getFullYear() == d.getFullYear() &&
          now.getMonth() == d.getMonth() &&
          now.getDate() == d.getDate()) {
        return 
      }
      $(this).html(monthNames[d.getMonth()] + ' ' + d.getDate())
    })
  }

  $("#subscribeModal").on("show.bs.modal", function(e) {
    $this = $(this);
    taxonLabel = $this.find("#subscribeTaxonLabel");
    subscribe_type = (taxonLabel.css('display') == 'none') ? "place" : "taxon";   
    subscribe_url = "/subscriptions/new?type=" + subscribe_type + "&partial=form&authenticity_token=" + $('meta[name=csrf-token]').attr('content');
    $.ajax({
        url: subscribe_url,
        cache: false,
        success: function(html){
          $this.find(".modal-body").append(html);
        }
    });
  });

  $("#subscribeModal").on("hide.bs.modal", function(e) {
    $(this).find(".modal-body").children("form").remove()
  });

  $("a[data-subscribe-type]").click(function(e){
    subscribeType = $(this).data("subscribe-type")
    if(subscribeType == "taxon"){
      $("#subscribeTaxonLabel").show();
      $("#subscribePlaceLabel").hide();
      $("#subscribeTaxonBody").show();
      $("#subscribePlaceBody").hide();
    }else{
      $("#subscribePlaceLabel").show();
      $("#subscribeTaxonLabel").hide();
      $("#subscribePlaceBody").show(); 
      $("#subscribeTaxonBody").hide();         
    }
  });

  $("a[data-panel-type]").click(function(e){
    e.preventDefault()
    panelType = $(this).data("panel-type")
    close_panel(this, panelType)
  });

  $("[data-toggle=popover]").popover();

  $(".dashboard_tab").click(function(){
     $(".dashboard_tab").removeClass("active");
     $(this).addClass("active");
  });

  $('html').on('mouseup', function(e) {
      if(!$(e.target).closest('.popover').length) {
          $('.popover').each(function(){
              $(this.previousSibling).popover('hide');
          });
      }
  });

})
