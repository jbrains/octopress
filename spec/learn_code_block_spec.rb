# SMELL Production code needs Jekyll, but doesn't require it, so this file has to.
require "jekyll"

require "rspec"
require "plugins/code_block"

describe "Parsing parameters for codeblock" do
  example "only a URL" do
    results = Jekyll::CodeBlock.parse_tag_parameters("https://gist.github.com/1234 ")
    results[:caption].should == %Q{<figcaption><span>https://gist.github.com/1234</span><a href='https://gist.github.com/1234'>#{'link'}</a></figcaption>}
    results[:filetype].should be_nil
    results[:file].should be_nil
  end

  example "all advertised parameters" do
    results = Jekyll::CodeBlock.parse_tag_parameters("A nice, simple caption for gist2.rb http://www.jbrains.ca see more")
    # SMELL caption is captionHtml, rather than caption text; more context dependence
    # SMELL production code computes obsolete property 'file'
    results.delete_if { |key, _| key == :file }.should == {filetype: "rb", caption: %Q{<figcaption><span>A nice, simple caption for gist2.rb</span><a href='http://www.jbrains.ca'>see more</a></figcaption>}}
  end
end

