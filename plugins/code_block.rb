# Title: Simple Code Blocks for Jekyll
# Author: Brandon Mathis http://brandonmathis.com
# Description: Write codeblocks with semantic HTML5 <figure> and <figcaption> elements and optional syntax highlighting — all with a simple, intuitive interface.
#
# Syntax:
# {% codeblock [title] [url] [link text] %}
# code snippet
# {% endcodeblock %}
#
# For syntax highlighting, put a file extension somewhere in the title. examples:
# {% codeblock file.sh %}
# code snippet
# {% endcodeblock %}
#
# {% codeblock Time to be Awesome! (awesome.rb) %}
# code snippet
# {% endcodeblock %}
#
# Example:
#
# {% codeblock Got pain? painreleif.sh http://site.com/painreleief.sh Download it! %}
# $ rm -rf ~/PAIN
# {% endcodeblock %}
#
# Output:
#
# <figure class='code'>
# <figcaption><span>Got pain? painrelief.sh</span> <a href="http://site.com/painrelief.sh">Download it!</a>
# <div class="highlight"><pre><code class="sh">
# -- nicely escaped highlighted code --
# </code></pre></div>
# </figure>
#
# Example 2 (no syntax highlighting):
#
# {% codeblock %}
# <sarcasm>Ooooh, sarcasm... How original!</sarcasm>
# {% endcodeblock %}
#
# <figure class='code'>
# <pre><code>&lt;sarcasm> Ooooh, sarcasm... How original!&lt;/sarcasm></code></pre>
# </figure>
#
require './plugins/pygments_code'
require './plugins/raw'

module Jekyll

  class CodeBlock < Liquid::Block
    include HighlightCode
    include TemplateWrapper
    CaptionUrlTitle = /(\S[\S\s]*)\s+(https?:\/\/\S+|\/\S+)\s*(.+)?/i
    UrlOnly = /(https?:\/\/\S+|\/\S+)/i
    Caption = /(\S[\S\s]*)/

    def self.parse_tag_parameters(markup)
      # Process, then extract "lang:" attribute
      if markup =~ /\s*lang:(\S+)/i
        filetype = $1
        markup = markup.sub(/\s*lang:(\S+)/i,'')
      end

      if markup =~ CaptionUrlTitle
        # Match exactly <caption> <URL> <title>
        file = $1
        caption = "<figcaption><span>#{$1}</span><a href='#{$2}'>#{$3 || 'link'}</a></figcaption>"
      elsif markup =~ UrlOnly
        file = nil
        filetype = nil
        caption = "<figcaption><span>#{$1}</span><a href='#{$1}'>#{'link'}</a></figcaption>"
      elsif markup =~ Caption
        # Match exactly <caption>
        # Why, exactly, do we assume that the caption text is a file?!
        # What if the only text is actually a URL?!
        file = $1
        caption = "<figcaption><span>#{$1}</span></figcaption>"
      end

      if file =~ /\S[\S\s]*\w+\.(\w+)/ && filetype.nil?
        filetype = $1
      end
      return {filetype: filetype, file: file, caption: caption}
    end

    def initialize(tag_name, markup, tokens)
      # SMELL This appears to be completely unused.
      @title = nil
      @highlight = true

      parsed_tag_parameters = self.class.parse_tag_parameters(markup)
      @filetype = parsed_tag_parameters[:filetype]
      # SMELL This appears to be completely unused.
      @file = parsed_tag_parameters[:file]
      @caption = parsed_tag_parameters[:caption]

      super
    end

    def render(context)
      # SMELL No-one appears to be using 'output'
      output = super
      code = super
      source = "<figure class='code'>"
      source += @caption if @caption
      if @filetype
        begin
          source += "#{highlight(code, @filetype)}"
        rescue => highlighting_error
          # Really? No logging?
          puts "Couldn't highlight code. Falling back to tableizing. Here is the cause:"
          puts highlighting_error
          puts highlighting_error.backtrace
          puts "Here is the code:"
          puts code
          puts "Here are the tag parameters:"
          puts @markup
          source += "#{tableize_code(code.lstrip.rstrip.gsub(/</,'&lt;'))}"
        end
      else
        # WTF is all the stripping and the gsub?!
        source += "#{tableize_code(code.lstrip.rstrip.gsub(/</,'&lt;'))}"
      end
      source += "</figure>"
      source = safe_wrap(source)
      # pygments_prefix/suffix come from the HighlightCode module?
      source = context['pygments_prefix'] + source if context['pygments_prefix']
      source = source + context['pygments_suffix'] if context['pygments_suffix']
      source
    end
  end
end

Liquid::Template.register_tag('codeblock', Jekyll::CodeBlock)
