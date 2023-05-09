# frozen_string_literal: true

module FlagsHelper
  def flag_actions( flag )
    link_to( flag, class: "btn btn-info btn-sm" ) do
      capture do
        concat content_tag( :i, "", class: "fa fa-info" )
        concat " "
        concat t( :details )
      end
    end
  end

  def flag_content( flag, options = {} )
    flaggable = flag.flaggable
    flaggable = flaggable.becomes( Photo ) if flaggable.is_a?( Photo )
    capture do
      if flaggable
        concat link_to_if( flaggable.respond_to?( :to_plain_s ), flaggable.to_plain_s, flaggable )
        concat flaggable_edit( flaggable ) unless options[:no_edit]
        concat flaggable_with_body( flaggable ) unless options[:no_body]
        concat flaggable_user( flaggable )
      else
        concat t "deleted_#{flag.flaggable_type}"
        if flag.flaggable_content_viewable_by?( current_user )
          concat content_tag :blockquote, formatted_user_text( flag.flaggable_content )
        end
        if flag.flaggable_parent
          txt = t :bold_label_colon_value_html,
            label: t(:parent),
            value: link_to( flag.flaggable_parent.to_plain_s, flag.flaggable_parent )
          concat content_tag :div, "[#{txt}]".html_safe
        end
      end
    end
  end

  def flag_content_author( flag )
    return unless flag.flaggable_user

    author_link = link_to_user( flag.flaggable_user ) { char_wrap( flag.flaggable_user.login, 20 ) }
    author_flags = content_tag :div, class: "small text-muted" do
      link_to t( :view_all ), url_for_params( user_id: flag.flaggable_user.login, without: [:user_id] )
    end
    author_link + author_flags
  end

  def flag_flagger( flag, site )
    if flag.user
      flagger_link = link_to_user( flag.user ) { char_wrap( flag.user.login, 20 ) }
      flagger_flags = content_tag :div, class: "small text-muted" do
        link_to t( :view_all ), url_for_params( flagger_type: "user", flagger_user_id: flag.user.id,
          without: [:flagger_type, :flagger_user_id, :user_id] )
      end
      flagger_link + flagger_flags
    elsif flag.user_id.zero?
      site.site_name_short
    else
      t :deleted_user
    end
  end

  def flag_resolution( flag, site )
    return unless flag.resolved?

    resolved_at = flag.resolved_at || flag.updated_at
    resolved_by = if flag.resolver
      link_to_user( flag.resolver )
    elsif flag.resolver_id
      t :deleted_user
    else
      site.name
    end

    resolver = content_tag :div, class: "text-muted" do
      t :resolved_by_user_on_date_html, user: resolved_by, date: resolved_at ? l( resolved_at ) : t( :unknown )
    end

    [formatted_user_text( flag.comment ), resolver].compact.join.html_safe
  end

  def flaggable_edit( flaggable )
    return "" unless editable?( flaggable )

    edit_path = if flaggable.is_a?( Sound )
      sound_path( flaggable )
    elsif flaggable.is_a?( Photo )
      photo_path( flaggable )
    elsif respond_to?( "edit_#{flaggable.class.name.underscore}_path" )
      send( "edit_#{flaggable.class.name.underscore}_path", flaggable )
    end
    return "" if edit_path.blank?

    link_to( edit_path ) do
      content_tag :i, "", class: "fa fa-pencil"
    end
  end

  def flaggable_user( flaggable )
    return "" unless flaggable.respond_to?( :user ) && flaggable.user

    content_tag :div, "", class: "small" do
      link_to_user flaggable.user, class: "text-muted" do
        t( :added_by_user_on_date_html, user: flaggable.user.login, date: l( flaggable.created_at ) )
      end
    end
  end

  def flaggable_with_body( flaggable )
    return "" if flaggable.is_a?( Message )

    txt = flaggable.try_methods( :body, :description )
    return "" if txt.blank?

    content_tag :blockquote, truncate_with_more( formatted_user_text( txt ), length: 200 )
  end

  private

  def editable?( flaggable )
    flaggable.respond_to?( :editable_by? ) && flaggable.editable_by?( current_user ) \
      && defined? "edit_#{flaggable.class.name.underscore}_path"
  end
end
