# SMELL Production code needs Jekyll, but doesn't require it, so this file has to.
require "jekyll"

require "rspec"
require "plugins/code_block"

describe "Parsing parameters for codeblock" do
  example "only a URL" do
    results = Jekyll::CodeBlock.parse_tag_parameters("https://gist.github.com/1234")
    pending("Filetype appears to be interpreted incorrectly") do
      results[:filetype].should be_nil
    end
  end

  example "all advertised parameters" do
    results = Jekyll::CodeBlock.parse_tag_parameters("A nice, simple caption gist2.rb see more")
    # SMELL caption is captionHtml, rather than caption text; more context dependence
    pending("Another mistake: the 'file' and 'caption' properties are wrong, and it appears that nobody's using the 'file' property.") do
      results.should == {filetype: "rb", file: "gist2.rb", caption: "<figcaption><span>A nice, simple caption</span></figcaption>\n"}
    end
  end
end

