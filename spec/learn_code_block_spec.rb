require "rspec"
require "plugins/code_block"

describe "Parsing parameters for {% codeblock %}" do
  example "Am I requiring everything correctly?" do
    Jekyll::CodeBlock.new
  end
end

