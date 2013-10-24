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

  context "integrating the pieces into the Liquid extension point" do
    it "should be a Liquid tag"
    it "should register itself in Liquid"

    describe "render()" do
      example "happy path"
      example "failure rendering code"
      example "failure downloading gist"
    end

    describe "initialize()" do
      example "happy path"
      example "parsing parameters fails"
    end
  end
end

