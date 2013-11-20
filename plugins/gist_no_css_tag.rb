# mandatory: gist_id
# optional: username, filename
GistFileKey = Struct.new(:gist_id, :username, :filename)

# I don't know why this needs to reside in module Jekyll, but
# I'm going with it for now.
module Jekyll
  class GistNoCssTag < Liquid::Tag
    def initialize(tag_name, parameters, tokens)
      @tag_name = name
      @parameters = parameters
      @tokens = tokens
    end

    def self.parse_parameters(parameters)
      match_data = /^(?:(.+)\/)?(\d+)(?:\s+([^\s]+))?$/.match(parameters)
      begin
        Integer(match_data[2])
      rescue
        raise ArgumentError.new(parameters)
      end
      GistFileKey.new(match_data[2].to_i, match_data[1], match_data[3])
    end

    def render(context)
      "<pre>#{CGI.escapeHTML(self.inspect.to_s)}</pre>"
    end
  end
end

Liquid::Template.register_tag('gist_no_css', Jekyll::GistNoCssTag)
