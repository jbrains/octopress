require "rspec"

describe "gist_no_css tag" do
  context "the pieces" do
    context "downloading gist code" do
      require "vcr"
      require "faraday"
      require "faraday_middleware"

      VCR.configure do |c|
        c.cassette_library_dir = 'fixtures/downloading_gists'
        c.hook_into :faraday
        c.allow_http_connections_when_no_cassette = true
      end

      class DownloadsGistUsingFaraday
        # options: username, filename
        def download(gist_id, options = {})
          url_base = "https://gist.github.com"
          if options[:username]
            filename_portion = "/#{options[:filename]}" if options[:filename]
            url = "https://gist.github.com/#{options[:username]}/#{gist_id}/raw#{filename_portion}"
            uri = "/#{options[:username]}/#{gist_id}/raw#{filename_portion}"
          else
            filename_portion = "/#{options[:filename]}" if options[:filename]
            url = "https://gist.github.com/raw/#{gist_id}#{filename_portion}"
            uri = "/raw/#{gist_id}#{filename_portion}"
          end
          response = http_get(url_base, uri)

          return response.body unless (400..599).include?(response.status.to_i)
          raise RuntimeError.new(StringIO.new.tap { |s| s.puts "I failed to download the gist at #{url}", response.inspect.to_s }.string)
        end

        # REFACTOR Move this onto a collaborator
        def http_get(base, uri)
          faraday_with_default_adapter(base) { | connection |
            connection.use FaradayMiddleware::FollowRedirects, limit: 1
          }.get(uri)
        end

        # REFACTOR Move this into Faraday
        # REFACTOR Rename this something more intention-revealing
        def faraday_with_default_adapter(base, &block)
          Faraday.new(base) { | connection |
            yield connection

            # IMPORTANT Without this line, nothing will happen.
            connection.adapter Faraday.default_adapter
          }
        end
      end

      context "gist found" do
        context "gist has only one file" do
          example "filename specified" do
            VCR.use_cassette("gist_exists_with_single_file") do
              DownloadsGistUsingFaraday.new.download(4111662, username: "jbrains", filename: "TestingIoFailure.java").should == Faraday.get("https://gist.github.com/jbrains/4111662/raw/TestingIoFailure.java").body
            end
          end

          example "filename not specified" do
            VCR.use_cassette("gist_exists_with_single_file") do
              DownloadsGistUsingFaraday.new.download(4111662, username: "jbrains", filename: "TestingIoFailure.java").should == Faraday.get("https://gist.github.com/jbrains/4111662/raw/TestingIoFailure.java").body
            end
          end

          example "filename does not match" do
            VCR.use_cassette("gist_exists_with_single_file_but_the_wrong_file") do
              lambda {
                DownloadsGistUsingFaraday.new.download(4111662, username: "jbrains", filename: "TheWrongFilename.java")
              }.should raise_error()
            end
          end

          example "username not specified, but filename specified" do
            VCR.use_cassette("gist_exists_with_single_file_username_not_specified") do
              # IMPORTANT The expected result should be the target URL, not the
              # one through which the username-less shortcut redirects!
              DownloadsGistUsingFaraday.new.download(4111662, filename: "TestingIoFailure.java").should == Faraday.get("https://gist.github.com/jbrains/4111662/raw/TestingIoFailure.java").body
            end
          end

          example "neither username nor filename specified" do
            VCR.use_cassette("gist_exists_with_single_file_username_not_specified_and_filename_not_specified") do
              DownloadsGistUsingFaraday.new.download(4111662).should == Faraday.get("https://gist.github.com/jbrains/4111662/raw/TestingIoFailure.java").body
            end
          end

          example "github throws me a redirect" do
            # This happens when we don't specify the username, and
            # /raw/:gist_id redirects to /:detected_username/:gist_id/raw
          end
        end

        context "gist has many files" do
          context "filename specified" do
            example "matches first file" do
              VCR.use_cassette("gist_exists_with_many_files_matching_the_first_file") do
                DownloadsGistUsingFaraday.new.download(6964587, username: "jbrains", filename: "Gist1.java").should == Faraday.get("https://gist.github.com/jbrains/6964587/raw/Gist1.java").body
              end
            end

            example "matches other-than-first file" do
              VCR.use_cassette("gist_exists_with_many_files_matching_not_the_first_file") do
                DownloadsGistUsingFaraday.new.download(6964587, username: "jbrains", filename: "Gist2.rb").should == Faraday.get("https://gist.github.com/jbrains/6964587/raw/Gist2.rb").body
              end
            end

            example "filename does not match" do
              VCR.use_cassette("gist_exists_with_many_files_but_the_wrong_file") do
                lambda {
                  DownloadsGistUsingFaraday.new.download(6964587, username: "jbrains", filename: "SoTotallyNotTheRightFile.java")
                }.should raise_error()
              end
            end

            example "username not specified"
          end

          example "filename not specified" do
            VCR.use_cassette("gist_exists_with_many_files_but_not_specifying_the_filename") do
              # SMELL You'll have to look this up to be sure
              name_of_first_file = "Gist1.java"  
              DownloadsGistUsingFaraday.new.download(6964587, username: "jbrains").should == Faraday.get("https://gist.github.com/jbrains/6964587/raw/#{name_of_first_file}").body
            end
          end

          example "neither filename nor username specified"
        end
      end

      context "gist not found" do
        example "wrong gist ID" do
          VCR.use_cassette("gist_not_found_due_to_wrong_gist_id") do
            # ASSUME No gist will ever have a negative ID.
            lambda {
              DownloadsGistUsingFaraday.new.download(-1)
            }.should raise_error()
          end
        end

        example "right gist ID, wrong username" do
          VCR.use_cassette("gist_not_found_due_to_wrong_username") do
            lambda {
              DownloadsGistUsingFaraday.new.download(6964587, username: "notjbrains")
            }.should raise_error()
          end
        end
      end

      example "failure downloading gist" do
        intentional_failure = RuntimeError.new("I intentionally failed to download the gist")
        # SMELL I don't like the implicit dependency on an implementation detail here, but at least it's small.
        # REFACTOR Split computing the URL from downloading it, perhaps?!
        expect {
          DownloadsGistUsingFaraday.new.tap { |d| d.stub(:http_get).and_raise(intentional_failure) }.download(6964587, username: "jbrains", filename: "Gist1.java") 
        }.to raise_error(intentional_failure)
      end
    end

    context "parsing tag parameters", future: true do
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
          StringIO.new.tap { |canvas| canvas.puts "<!--", oops.message, oops.backtrace, "-->" }.string
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

      example "failure downloading gist" do
        renders_code = double("I render the code")
        downloads_gist = double("I download the gist")

        downloads_gist.stub(:download).and_raise("I failed to download the gist")
        renders_code.should_not_receive(:render)

        GistNoCssTag.with(renders_code: renders_code, downloads_gist: downloads_gist).render().should =~ /<!--.+I failed to download the gist.+-->/m
      end
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

