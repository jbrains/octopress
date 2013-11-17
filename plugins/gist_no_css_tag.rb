
module Jekyll
  GistNoCssTagParameters = Struct.new(:gist_id, :username, :filename)

  class GistNoCssTag < Liquid::Tag
    def initialize(tag_name, parameters, tokens)
      @tag_name = name
      @parameters = parameters
      @tokens = tokens
    end

    def self.parse_parameters(parameters)
      GistNoCssTagParameters.new(1234, "jbrains", "Gist1.java")
    end

    def render(context)
      "<pre>#{CGI.escapeHTML(self.inspect.to_s)}</pre>"
    end
  end
end

Liquid::Template.register_tag('gist_no_css', Jekyll::GistNoCssTag)
