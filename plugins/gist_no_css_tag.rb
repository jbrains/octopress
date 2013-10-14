
module Jekyll
  class GistNoCssTag < Liquid::Tag
    def initialize(tag_name, parameters, tokens)
      @tag_name = name
      @parameters = parameters
      @tokens = tokens
    end

    def render(context)
      "<pre>#{CGI.escapeHTML(self.inspect.to_s)}</pre>"
    end
  end
end

Liquid::Template.register_tag('gist_no_css', Jekyll::GistNoCssTag)
