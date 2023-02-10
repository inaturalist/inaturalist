# frozen_string_literal: true

class DefaultFormBuilder < ActionView::Helpers::FormBuilder
  include ActionView::Helpers::TagHelper
  helpers = field_helpers.map( &:to_s ) +
    %w(date_select datetime_select time_select) +
    %w(collection_select select country_select time_zone_select) -
    %w(hidden_field label fields_for) # Don't decorate these
  custom_params = %w(description label label_after wrapper label_class field_value datalist)
  helpers.each do | name |
    define_method( name ) do | field, *args, &block |
      options = if name.to_s == "select"
        args.last.is_a?( Hash ) ? args.last : {}
      elsif args[-2].is_a?( Hash )
        args.pop
      elsif args.last.is_a?( Hash )
        args.last
      else
        args.reverse.detect {| a | a.is_a?( Hash ) } || {}
      end
      options = options.clone
      return super( field, *args ) if options[:skip_builder]

      options[:field_name] = name
      if name == "radio_button"
        options[:field_value] = args[0]
      end
      if %w(text_field file_field).include?( name.to_s )
        css_class = options[:class] || []
        css_class = [css_class, "text"].flatten.uniq.join( " " ) if name.to_s == "text_field"
        css_class = [css_class, "file"].flatten.uniq.join( " " ) if name.to_s == "file_field"
        args << {} unless args.last.is_a?( Hash )
        args.last[:class] = css_class
        options[:wrapper] ||= {}
        options[:wrapper][:class] = "#{options[:wrapper][:class]} #{name}".strip
      end
      args.each_with_index do | a, i |
        custom_params.each do | p |
          next unless a.is_a?( Hash )

          if p == "datalist" && a[:datalist]
            a[:list] = dom_id( object, "#{field}-datalist" )
          end
          args[i].delete( p.to_sym )
        end
      end
      content = super( field, *args, &block )
      form_field( field, content, options )
    end
  end

  class INatInstanceTag < ActionView::Helpers::Tags::Base
    def to_select_tag_with_option_tags( option_tags, options, html_options )
      html_options = html_options.stringify_keys
      add_default_name_and_id( html_options )
      value = value( object )
      selected_value = options.key?( :selected ) ? options[:selected] : value
      disabled_value = options.key?( :disabled ) ? options[:disabled] : nil
      if disabled_value
        content_tag(
          "select",
          add_options( option_tags, options, selected: selected_value, disabled: disabled_value ),
          html_options
        )
      else
        content_tag( "select", add_options( option_tags, options, selected_value ), html_options )
      end
    end
  end

  # Override to get better attrs in there
  def time_zone_select( method, priority_zones = nil, options = {}, html_options = {} )
    options[:include_blank] = true if options[:include_blank].nil?
    html_options[:class] = "#{html_options[:class]} time_zone_select"
    zone_options = "".html_safe
    selected = options.delete( :selected )
    model = options.delete( :model ) || ActiveSupport::TimeZone
    zones = model.all
    convert_zones = lambda {| list, selected_zone |
      list.map do | z |
        opts = {
          :value => z.name,
          "data-time-zone-abbr" => z.tzinfo.current_period.abbreviation,
          "data-time-zone-tzname" => z.tzinfo.name,
          "data-time-zone-offset" => z.utc_offset,
          "data-time-zone-formatted-offset" => z.formatted_offset
        }
        opts[:selected] = "selected" if selected_zone == z.name
        content_tag( :option, z.to_s, opts )
      end.join( "\n" )
    }
    if priority_zones
      if priority_zones.is_a?( Regexp )
        priority_zones = model.all.grep( priority_zones )
      end
      zone_options += convert_zones.call( priority_zones, selected ).html_safe
      zone_options += "<option value=\"\" disabled=\"disabled\">-------------</option>\n".html_safe
      zones = zones.reject {| z | priority_zones.include?( z ) }
    end
    zone_options += convert_zones.call( zones, selected ).html_safe
    tag = INatInstanceTag.new(
      object_name, method, self
    ).to_select_tag_with_option_tags( zone_options, options, html_options )
    form_field method, tag, options.merge( html_options )
  end

  def sort_lexicons( lexicons )
    sortable_locale = I18N_LOCALES.detect {| l | l =~ /#{I18n.locale}-phonetic/ }
    if sortable_locale
      lexicons.sort do | a, b |
        t_a = I18n.t(
          "lexicons.#{a.gsub( ' ', '_' ).gsub( '-', '_' ).gsub( /[()]/, '' ).downcase}",
          locale: sortable_locale,
          default: ""
        )
        t_b = I18n.t(
          "lexicons.#{b.gsub( ' ', '_' ).gsub( '-', '_' ).gsub( /[()]/, '' ).downcase}",
          locale: sortable_locale,
          default: ""
        )
        # Make sure sortable translations appear first
        [( t_a == "" ? 1 : 0 ), t_a] <=> [( t_b == "" ? 1 : 0 ), t_b]
      end
    else
      lexicons.sort_by do | lexicon |
        key = "lexicons.#{lexicon.gsub( ' ', '_' ).gsub( '-', '_' ).gsub( /[()]/, '' ).downcase}"
        I18n.t( key, default: lexicon ).to_s.downcase
      end
    end
  end

  def select_lexicon( method, lexicons, options = {}, html_options = {} )
    separator = "---------------------------"
    lexicons = sort_lexicons( lexicons.uniq {| l | TaxonName.normalize_lexicon( l ) } )
    default_lexicons = sort_lexicons( TaxonName::DEFAULT_LEXICONS.map {| l | TaxonName.normalize_lexicon( l ) }.uniq )
    default_lexicons.delete( TaxonName::SCIENTIFIC_NAMES )
    lexicons.delete( TaxonName::SCIENTIFIC_NAMES )
    lexicon_optionifier = lambda do | lexicon |
      key = "lexicons.#{lexicon.gsub( ' ', '_' ).gsub( '-', '_' ).gsub( /[()]/, '' ).downcase}"
      [
        I18n.t( key, default: lexicon ),
        lexicon,
        { data: { "i18n-key" => key } }
      ]
    end
    lexicon_options =
      [
        [I18n.t( "lexicons.scientific_names" ), TaxonName::SCIENTIFIC_NAMES],
        separator
      ] +
      [I18n.t( :translated_languages )] +
      default_lexicons.map( &lexicon_optionifier ) +
      [separator, I18n.t( :other_lexicons )] +
      ( lexicons - default_lexicons ).map( &lexicon_optionifier )
    options[:include_blank] ||= I18n.t( :unknown )
    options[:disabled] ||= [separator, I18n.t( :translated_languages ), I18n.t( :other_lexicons )]
    select( method, lexicon_options, options, html_options )
  end

  def form_field( field, field_content = nil, options = {}, &block )
    options = field_content if block_given?
    options ||= {}
    label_after = options.delete( :label_after )
    description_after = options.delete( :description_after )
    wrapper_options = options.delete( :wrapper ) || {}
    wrapper_options[:class] = "#{wrapper_options[:class]} field #{field.to_s.parameterize.underscore}_field".strip
    content = ""
    label_content = ""

    if options[:label] != false
      label_field = field
      if options[:field_name] == "radio_button"
        label_field = [label_field, options[:field_value]].compact.join( "_" ).gsub( /\W/, "" ).downcase
      end
      label_options = { class: options[:label_class] }
      label_options[:for] = options[:id] if options[:id]
      label_tag = label( label_field, options[:label].to_s.html_safe, label_options )
      if options[:required]
        label_tag += content_tag( :span, " *", class: "required" )
      end
      label_content = content_tag( label_after ? :span : :div, label_tag, class: "inlabel" )
    end

    description = content_tag( :div, options[:description], class: "description" ) if options[:description]
    content = "#{content}#{block_given? ? @template.capture( &block ) : field_content}"

    datalist = nil
    if options[:datalist]
      datalist = content_tag(
        :datalist,
        options[:datalist].map {| item | content_tag( :option, item, value: item ) }.join( "\n" ).html_safe,
        id: dom_id( object, "#{field}-datalist" )
      )
    end

    content = if label_after
      "#{content} #{datalist} #{label_content} #{description}"
    elsif description_after
      "#{label_content} #{content} #{datalist} #{description}"
    else
      "#{label_content} #{description} #{content} #{datalist}"
    end

    @template.content_tag( :div, content.html_safe, wrapper_options )
  end

  def dom_id( record, prefix = nil )
    [prefix, record.class.name, record&.id].compact.join( "-" )
  end
end
