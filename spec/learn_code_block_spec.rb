# SMELL Production code needs Jekyll, but doesn't require it, so this file has to.
require "jekyll"

require "rspec"
require "plugins/code_block"

describe "Parsing parameters for codeblock" do
  # The @file field appears to be unused, so don't bother checking it
  example "only a URL" do
    Jekyll::CodeBlock.parse_tag_parameters("https://gist.github.com/1234 ").should include({
      caption: %Q{<figcaption><span>https://gist.github.com/1234</span><a href='https://gist.github.com/1234'>#{'link'}</a></figcaption>},
      filetype: nil
    })
  end

  example "only a title that does not look like a filename" do
    Jekyll::CodeBlock.parse_tag_parameters("anything that does not contain a dot").should include({ 
      filetype: nil,
      caption: %Q{<figcaption><span>anything that does not contain a dot</span></figcaption>}
    })
  end

  example "a single-word title that looks like a filename" do
    Jekyll::CodeBlock.parse_tag_parameters("filename.xyz").should include({ 
      filetype: "xyz",
      caption: %Q{<figcaption><span>filename.xyz</span></figcaption>}
    })
  end

  example "a multiple-word title that looks like it has a filename at the end" do
    Jekyll::CodeBlock.parse_tag_parameters("a multiple-word title followed by filename.xyz").should include({
      filetype: "xyz",
      caption: %Q{<figcaption><span>a multiple-word title followed by filename.xyz</span></figcaption>}
    })
  end

  example "a multiple-word title that looks like it has a filename in the middle" do
    Jekyll::CodeBlock.parse_tag_parameters("word filename.xyz more words").should include({
      filetype: "xyz",
      caption: %Q{<figcaption><span>word filename.xyz more words</span></figcaption>}
    })
  end

  example "a multiple-word title that starts with a filename" do
    Jekyll::CodeBlock.parse_tag_parameters("filename.xyz word").should include({
      filetype: "xyz",
      caption: %Q{<figcaption><span>filename.xyz word</span></figcaption>}
    })
  end

  example "all advertised parameters" do
    Jekyll::CodeBlock.parse_tag_parameters("A nice, simple caption for gist2.rb http://www.jbrains.ca see more").should include({
      filetype: "rb", 
      caption: %Q{<figcaption><span>A nice, simple caption for gist2.rb</span><a href='http://www.jbrains.ca'>see more</a></figcaption>}
    })
  end

  example "lang attribute conflicts with filename extension" do
    Jekyll::CodeBlock.parse_tag_parameters("filename.xyz lang:rb").should include({
      filetype: "rb",
      caption: %Q{<figcaption><span>filename.xyz</span></figcaption>}
    })
  end

  example "filename then URL" do
    Jekyll::CodeBlock.parse_tag_parameters("Awesome.java http://www.jbrains.ca/permalink/x/y/z").should include({
      filetype: "java",
      caption: %Q{<figcaption><span>Awesome.java</span><a href='http://www.jbrains.ca/permalink/x/y/z'>link</a></figcaption>}
    })
  end

  example "URL then filename" do
    # We don't handle this case, so anything we do is just fine!
  end
end

