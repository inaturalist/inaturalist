require "rdoc/parser/ruby"
require "cgi"

FLICKR_API_URL='http://www.flickr.com/services/api'

FakedToken = Struct.new :text

module RDoc
  class FlickrawParser < Parser::Ruby
    parse_files_matching(/flickraw\.rb$/)

    def scan
      super

      fr = @top_level.find_module_named 'FlickRaw'
      k = fr.add_class NormalClass, 'Flickr', 'FlickRaw::Request'
      k.record_location @top_level
      @stats.add_class 'Flickr'

      add_flickr_methods(FlickRaw::Flickr, k)
      @top_level
    end

    private
    def add_flickr_methods(obj, doc)
      obj.constants.each { |const_name|
        const = obj.const_get const_name
        if const.is_a?(Class) && const < FlickRaw::Request
          name = const.name.sub(/.*::/, '')
          k = doc.add_class NormalClass, name, 'FlickRaw::Request'
          k.record_location @top_level
          @stats.add_class name

          m = AnyMethod.new nil, name.downcase
          m.comment = "Returns a #{name} object."
          m.params = ''
          m.singleton = false
          doc.add_method m
          @stats.add_method m

          add_flickr_methods(const, k)
        end
      }

      obj.flickr_methods.each {|name|
        flickr_method = obj.request_name + '.' + name
        info = flickr.reflection.getMethodInfo :method_name => flickr_method

        m = AnyMethod.new nil, name
        m.comment = flickr_method_comment(info)
        m.params = flickr_method_args(info)
        m.singleton = false

        m.start_collecting_tokens
        m.add_token FakedToken.new( %{
# Generated automatically from flickr api
  def #{name}(*args)
    @flickr.call '#{flickr_method}', *args
  end
} )
        doc.add_method m
         @stats.add_method m
      }
    end

    def flickr_method_comment(info)
      description = CGI.unescapeHTML(info.method.description.to_s)
#       description.gsub!( /<\/?(\w+)>/ ) {|b|
#         return b if ['em', 'b', 'tt'].include? $1
#         return ''
#       }

      if info.respond_to? :arguments
        args = info.arguments.select { |arg| arg.name != 'api_key' }

        arguments = "<b>Arguments</b>\n"
        if args.size > 0
          args.each {|arg|
            arguments << "[#{arg.name} "
            arguments << "<em>(required)</em> " if arg.optional == '0'
            arguments << "] "
            arguments << "#{CGI.unescapeHTML(arg.to_s)}\n"
          }
        end
      end

      if info.respond_to? :errors
        errors = "<b>Error codes</b>\n"
        info.errors.each {|e|
          errors << "* #{e.code}: <em>#{e.message}</em>\n\n"
          errors << "  #{CGI.unescapeHTML e.to_s}\n"
        }
      end

      if info.method.respond_to? :response
        response = "<b>Returns</b>\n"
        raw = CGI.unescapeHTML(info.method.response.to_s)
        response << raw.lines.collect { |line| line.insert(0, ' ') }.join
      else
        response = ''
      end

      str = "{#{info.method.name}}[#{FLICKR_API_URL}/#{info.method.name}.html] request.\n\n"
      str << description << "\n\n"
      str << arguments << "\n\n"
      str << errors << "\n\n"
      str << response << "\n\n"
    end

    def flickr_method_args(info)
      str = ''
      if info.respond_to? :arguments
        args = info.arguments.select { |arg| arg.name != 'api_key' }

        if args.size > 0
          str << '('
          args.each {|arg|
            str << ":#{arg.name} => '#{arg.name}'"
            str << ','
          }
          str.chomp! ','
          str << ')'
        end
      end
      str
    end

  end
end
