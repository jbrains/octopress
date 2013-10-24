require "rspec"

describe "gist_no_css tag" do
  context "the pieces" do
    context "rendering code" do
      # Assume we've already successfully downloaded code
      example "gist ID, username and filename"
      example "gist ID and filename"
      example "gist ID and username"
      example "gist ID"
    end

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
        end
      end

      example "happy path" do
        renders_code = mock("I render the code")
        downloads_gist = mock("I download the gist", download: "::downloaded code::")

        renders_code.should_receive(:render).with("::downloaded code::").and_return("::rendered code::")

        GistNoCssTag.with(renders_code: renders_code, downloads_gist: downloads_gist).render().should == "::rendered code::"
      end

      example "failure rendering code"
      example "failure downloading gist"
    end
  end

  context "integrating the pieces into the Liquid extension point" do
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

