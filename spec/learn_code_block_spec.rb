# SMELL Production code needs Jekyll, but doesn't require it, so this file has to.
require "jekyll"

require "rspec"
require "plugins/code_block"

describe "Parsing parameters for codeblock" do
  def code_block_with_url(url)
    irrelevant_tokens = []
    Jekyll::CodeBlock.new("irrelevant tag name", "https://gist.github.com/1234", irrelevant_tokens)
  end

  example "only a URL" do
    code_block_with_url("https://gist.github.com/1234")
  end
end

