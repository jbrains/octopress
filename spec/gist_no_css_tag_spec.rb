require "rspec"

describe "gist_no_css tag" do
  context "the pieces", future: true do
    context "downloading gist code" do
      context "gist found" do
        context "gist has only one file" do
          example "filename specified"
          example "filename not specified"
          example "filename does not match"
        end
        context "gist has many files" do
          context "filename specified" do
            example "matches first file"
            example "matches other-than-first file"
            example "filename does not match"
          end
          example "filename not specified"
        end
      end
      example "gist not found"
      example "failure downloading gist"
    end

    context "parsing tag parameters" do
      example "all parameters specified" do
        pending
        # Remember to call the codeblock with filename, then URL
      end
      example "username not specified"
      example "filename not specified"
      example "only gist ID specified"
      context "failure cases" do
        example "no parameters"
        example "only username"
        example "only filename"
        example "username and filename"
      end
    end
  end

  context "putting the pieces together" do
    describe "render()" do
      class GistNoCssTag
        def initialize(renders_code, downloads_gist)
          @renders_code = renders_code
          @downloads_gist = downloads_gist
        end

        def self.with(collaborators_as_hash)
          self.new(collaborators_as_hash[:renders_code], collaborators_as_hash[:downloads_gist])
        end

        # SMELL This method doesn't yet say what it's downloading to render!
        def render()
          @renders_code.render(@downloads_gist.download())
        rescue => oops
          # SMELL I think I just shit in my own throat
          canvas = StringIO.new
          canvas.puts "<!--", oops.message, oops.backtrace, "-->"
          canvas.string
        end
      end

      example "happy path" do
        renders_code = double("I render the code")
        downloads_gist = double("I download the gist", download: "::downloaded code::")

        renders_code.should_receive(:render).with("::downloaded code::").and_return("::rendered code::")

        GistNoCssTag.with(renders_code: renders_code, downloads_gist: downloads_gist).render().should == "::rendered code::"
      end

      example "failure rendering code" do
        renders_code = double("I render the code")
        downloads_gist = double("I download the gist", download: "::downloaded code::")

        renders_code.stub(:render).and_raise("I failed to render the code")

        GistNoCssTag.with(renders_code: renders_code, downloads_gist: downloads_gist).render().should =~ /<!--.+I failed to render the code.+-->/m
      end

      example "failure downloading gist"
    end
  end

  context "integrating the pieces with other Octopress plugins" do
    require "jekyll" # only because the CodeBlock plugin doesn't do this
    require "plugins/code_block"

    context "rendering code with CodeBlock" do
      class RendersCodeUsingOctopressCodeBlock
        def initialize(octopress_code_block_class, liquid_context)
          @octopress_code_block_class = octopress_code_block_class
          @liquid_context = liquid_context
        end

        # options: username, filename
        def render(gist_id, options)
          parameters_as_text = "#{options[:filename]} https://gist.github.com/#{options[:username]}/#{gist_id}/raw/#{options[:filename]}"
          irrelevant_tokens = []
          code_block_tag = @octopress_code_block_class.new("irrelevant tag name", parameters_as_text, irrelevant_tokens)
          code_block_tag.render(@liquid_context)
        end
      end

      # Assume we've already successfully downloaded code
      example "gist ID, username and filename" do
        # I'd rather mock a class to instantiate a mock instance (for now) than integrate with the real Octopress tag implementation
        # It might be better to use the real thing, but just mock render()
        code_block = double("code block")
        code_block_class = double("code block factory")

        code_block_class.should_receive(:new) { | _, parameters_as_text, _ |
          # CodeBlock needs to have filename, then URL
          parameters_as_text.strip.should =~ %r{#{Regexp.escape("file.rb")}\s+#{Regexp.escape("https://gist.github.com/jbrains/1234/raw/file.rb")}}
        }.and_return(code_block)

        irrelevant_context = double("a Liquid context").as_null_object

        code_block.should_receive(:render).with(irrelevant_context)

        renders_code = RendersCodeUsingOctopressCodeBlock.new(code_block_class, irrelevant_context)
        renders_code.render("1234", username: "jbrains", filename: "file.rb")
      end

      example "gist ID and filename"
      example "gist ID and username"
      example "gist ID"
    end
  end

  context "integrating the pieces into the Liquid extension point", future: true do
    it "should be a Liquid tag"
    it "should register itself in Liquid"

    describe "render()" do
      example "happy path"
      example "failure in rendering abstract tag"
    end

    describe "initialize()" do
      example "happy path"
      example "parsing parameters fails"
    end
  end
end

