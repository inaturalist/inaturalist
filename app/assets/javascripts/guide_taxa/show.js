$('.taxonmap').taxonMap()
$('.imgmodal').on('shown.bs.modal', function() {
  $selection = $('img', this).not('.imagesloaded')
  $selection.hide()
  var newHeight = $(window).height() * 0.8
  $(this).height(newHeight)
  $('img', this).css({'height': newHeight+'px'})
  $(this).css('margin-left', $('img', this).width() / -2 + 'px')
  $(this).width($('img', this).width())
  $('img:hidden', this).fadeIn()
})
$('.imgmodal').imagesLoaded(function() {
  $('img', this).addClass('imagesloaded')
})
$('#reuse_guide_taxon_dialog').on('shown.bs.modal', function() {
  var current = $('.modal-body', this)
  if (current.hasClass('loaded')) {
    return
  }
  $.getJSON('/guides/user.json', function(json) {
    var guides = []
    for (var i = 0; i < json.length; i++) {
      if (json[i].id != GUIDE_TAXON.guide_id) {
        guides.push(json[i])
      }
    }
    if (!guides || guides.length == 0) {
      current.html("<p>"+I18n.t('you_are_not_editing_any_guides_add_one_html')+"</p>")
    } else {
      var ul = $('<div></div>')
      $.each(guides, function() {
        var guide = this
        ul.append(
          $('<div class="clear stacked lined"></div>').append(
            // $('<a>'+this.title+'</a>').attr('href', '/guide_taxa/new?guide_taxon[guide_id]='+this.id+'&guide_taxon_id='+GUIDE_TAXON.id)
            // $('<span>'+this.title+'</span>'),
            $('<img/>').attr('src', this.icon_url || '/attachment_defaults/guides/icons/small_square.png'),
            $('<a href="/guides/'+this.id+'" class="btn btn-link">'+this.title+'</a>'),
            $('<a class="btn btn-success pull-right">'+I18n.t('add')+'</a>').click(function() {
              reuseGuideTaxon(this, GUIDE_TAXON, guide)
            })
          )
        )
      })
      current.html(ul)
    }
  }).error(function() {
  })
  current.addClass('loaded')
})
function reuseGuideTaxon(btn, srcGuideTaxon, targetGuide) {
  $.post("/guide_taxa.json", {"guide_taxon[guide_id]": targetGuide.id, guide_taxon_id: srcGuideTaxon.id})
    .success(function(json, status, xhr) {
      $(btn).hide()
      $(btn).after('<a href="/guide_taxa/'+json.guide_taxon.id+'" class="btn btn-link pull-right">'+I18n.t('view')+'</a>')
    })
    .error(function(xhr) {
      var errors = $.parseJSON(xhr.responseText)
      alert(I18n.t('there_were_problems_adding_taxa', {errors: errors.join(', ')}))
    })
}
