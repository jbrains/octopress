# SMELL Production code needs Jekyll, but doesn't require it, so this file has to.
require "jekyll"

require "rspec"
require "plugins/code_block"

describe "Parsing parameters for codeblock" do
  # The @file field appears to be unused, so don't bother checking it
  example "only a URL" do
    results = Jekyll::CodeBlock.parse_tag_parameters("https://gist.github.com/1234 ")
    results.should include({
      caption: %Q{<figcaption><span>https://gist.github.com/1234</span><a href='https://gist.github.com/1234'>#{'link'}</a></figcaption>},
      filetype: nil
    })
  end

  example "only a title that does not look like a filename" do
    # SMELL This really should not expect a newline at the end of the caption; that's just stupid
    results = Jekyll::CodeBlock.parse_tag_parameters("anything that does not contain a dot")
    results.should include({ 
      filetype: nil,
      caption: %Q{<figcaption><span>anything that does not contain a dot</span></figcaption>}
    })
  end

  example "a single-word title that looks like a filename" do
    results = Jekyll::CodeBlock.parse_tag_parameters("filename.xyz")
    results.should include({ 
      filetype: "xyz",
      caption: %Q{<figcaption><span>filename.xyz</span></figcaption>}
    })
  end

  example "a multiple-word title that looks like it has a filename at the end" 
  example "a multiple-word title that looks like it has a filename in the middle"

  example "all advertised parameters" do
    results = Jekyll::CodeBlock.parse_tag_parameters("A nice, simple caption for gist2.rb http://www.jbrains.ca see more")
    results.should include({
      filetype: "rb", 
      caption: %Q{<figcaption><span>A nice, simple caption for gist2.rb</span><a href='http://www.jbrains.ca'>see more</a></figcaption>}
    })
  end
end

