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
          let(:name_of_first_file) { "Gist1.java" }
          let(:name_of_other_file) { "Gist2.rb" }

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

            context "username not specified" do
              example "matches first file" do
                VCR.use_cassette("gist_exists_with_many_files_matching_the_first_file_username_not_specified") do
                  DownloadsGistUsingFaraday.new.download(6964587, filename: "Gist1.java").should == Faraday.get("https://gist.github.com/jbrains/6964587/raw/Gist1.java").body
                end
              end

              example "matches other-than-first file" do
                VCR.use_cassette("gist_exists_with_many_files_matching_not_the_first_file_username_not_specified") do
                  DownloadsGistUsingFaraday.new.download(6964587, filename: "Gist2.rb").should == Faraday.get("https://gist.github.com/jbrains/6964587/raw/Gist2.rb").body
                end
              end
            end
          end

          example "filename not specified" do
            VCR.use_cassette("gist_exists_with_many_files_but_not_specifying_the_filename") do
              DownloadsGistUsingFaraday.new.download(6964587, username: "jbrains").should == Faraday.get("https://gist.github.com/jbrains/6964587/raw/#{name_of_first_file}").body
            end
          end

          example "neither filename nor username specified" do
            VCR.use_cassette("gist_exists_with_many_files_but_specifying_only_gist_id") do
              DownloadsGistUsingFaraday.new.download(6964587).should == Faraday.get("https://gist.github.com/jbrains/6964587/raw/#{name_of_first_file}").body
            end
          end
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
        downloads_gist = double("I download the gist", download: "::gist file description::")

        renders_code.should_receive(:render).with("::gist file description::").and_return("::rendered HTML fragment::")

        GistNoCssTag.with(renders_code: renders_code, downloads_gist: downloads_gist).render().should == "::rendered HTML fragment::"
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

  GistFile = Struct.new(:code, :filename, :gist_url)

  class RendersCodeUsingOctopressCodeBlock
    def initialize(octopress_code_block_class, liquid_context)
      raise "I have this utterly and hopelessly wrong"
    end

    def render(code, title, url)
      raise "I have this utterly and hopelessly wrong"
    rescue => oops
      StringIO.new.tap { | canvas | canvas.puts "<!--", "I failed to render the code", oops.message, oops.backtrace, "title: #{title}", "url: #{url}", "code: #{code}", "-->" }.string
    end

    def self.render(gist_file)
      "Intentionally nothing yet"
    end
  end

  context "contracts" do
    pending "None of this will work until I figure out how to use CodeBlock correctly" do
      context "Renders Code" do
        subject { RendersCodeUsingOctopressCodeBlock.new() }

        example "responds to render(code, title, url)" do
          subject.should respond_to(:render)
        end

        example "renders text" do
          subject.render("::code::", "::title::", "::url::").should be_kind_of(String)
          subject.render("::code::", "::title::", "::url::").should == ""
        end
      end
    end
  end

  context "integrating the pieces with other Octopress plugins" do
    require "jekyll" # only because the CodeBlock plugin doesn't do this
    require "plugins/code_block"

    # WARNING This depends heavily on global data in the Liquid::Template
    # universe, which I hate, but which I couldn't figure out how to
    # avoid. There be magic here. Please, if you have energy, figure out
    # how not to depend on that magic. Copy the magic here, if you can.
    context "learning how to render a Liquid::Template" do
      example "realistic example using the previously downloaded content of a gist" do
        equivalent_liquid_template_text = <<-TEMPLATE
{% codeblock TestingIoFailure.java https://gist.github.com/jbrains/4111662 %}
@Test
public void ioFailure() throws Exception {
    final IOException ioFailure = new IOException("Simulating a failure writing to the file.");
    try {
        new WriteTextToFileActionImpl() {
            @Override
            protected FileWriter fileWriterOn(File path) throws IOException {
                return new FileWriter(path) {
                    @Override
                    public void write(String str, int off, int len) throws IOException {
                        throw ioFailure;
                    }
                };
            }
        }.writeTextToFile("::text::", new File("anyWritableFile.txt"));
        fail("How did you survive the I/O failure?!");
    } catch (IOException success) {
        if (success != ioFailure)
            throw success;
    }
}
{% endcodeblock %}
TEMPLATE

        rendered_gist_as_html = Liquid::Template.parse(equivalent_liquid_template_text).render(Liquid::Context.new)
        # Spot checks, rather than checking the entire content.
        # Is the title there?
        rendered_gist_as_html =~ %r{TestingIoFailure.java}
        # Is the URL there?
        rendered_gist_as_html =~ %r{https://gist.github.com/jbrains/4111662}
        # Do we probably have the expected code? (Where else would this come from?)
        rendered_gist_as_html =~ %r{fail("How did you survive the I/O failure?!");}
      end

      example "do not try to use multiple Liquid 'raw' tags in a line, because they're greedy" do
        pending "I have opened https://github.com/Shopify/liquid/issues/280 with Shopify/liquid" do
          Liquid::Template.parse(["{% codeblock %}", "A line with {% raw %}{% {% endraw %} and {% raw %} %}{% endraw %} in it, which need to be escaped for Liquid.", "{% endcodeblock %}"].join("\n")).render(Liquid::Context.new).should =~ /A\ line\ with\ \{\%\ and\ \%\}\ in\ it/
        end
      end


      example "escaping for Liquid a little more sensibly" do
        Liquid::Template.parse(["{% codeblock %}", "{% raw %}", "A line with {% and %} in it, which need to be escaped for Liquid.", "{% endraw %}", "{% endcodeblock %}"].join("\n")).render(Liquid::Context.new).should =~ /A\ line\ with\ \{\%\ and\ \%\}\ in\ it/
      end

      example "what if we put these characters inside the opening tag?" do
        rendered = Liquid::Template.parse(["{% codeblock filename{%behaving%}badly %}", "{% raw %}", "{% endraw %}", "{% endcodeblock %}"].join("\n")).render(Liquid::Context.new)
        # The parameter I attempted to pass to {% codeblock %} was cleft in twain!
        rendered.should =~ %r{<span>filename\{%behaving</span>.+<span class='line'>badly %\}</span>}m
      end

      example "what if we Liquid-escape the characters inside the opening tag?" do
        rendered = Liquid::Template.parse(["{% codeblock filename{%behaving%}badly %}", "{% raw %}", "{% endraw %}", "{% endcodeblock %}"].join("\n")).render(Liquid::Context.new)
        # The parameter I attempted to pass to {% codeblock %} was cleft in twain!
        rendered.should =~ %r{<span>filename\{%behaving</span>.+<span class='line'>badly %\}</span>}m
      end
    end

    context "rendering code with CodeBlock" do
      # Assume we've already successfully downloaded code
      #
      # WTF We have to do this by rendering an entire Liquid::Template,
      # because I couldn't figure out how to instantiate and render only
      # a Jekyll::CodeBlock.
      #
      # WARNING This depends heavily on global data in the Liquid::Template
      # universe, which I hate, but which I couldn't figure out how to
      # avoid. There be magic here. Please, if you have energy, figure out
      # how not to depend on that magic. Copy the magic here, if you can.
      #
      example "happy path" do
        pending "WIP" do
          rendered_html = RendersCodeUsingOctopressCodeBlock.render(GistFile.new("::code::", "::title::", "::url::"))
          # Spot checks. I don't want to get into comparing HTML just yet.
          # If I need to check the HTML more carefully, then I'll dive into
          # how to do that without wanting to gouge out my eyes.
          rendered_html.should =~ %r{::code::}
          rendered_html.should =~ %r{::title::}
          rendered_html.should =~ %r{::url::}
        end
      end

      context "generating codeblock from GistFile" do
        def render_gist_file_as_code_block(gist_file)
          raise ArgumentError.new(%q(Liquid can't handle % or { or } inside tags, so don't do it.)) if [gist_file.filename, gist_file.gist_url].any? { |each| each =~ %r[{|%|}] }
          <<-CODEBLOCK
{% codeblock #{gist_file.filename} #{gist_file.gist_url} %}
#{gist_file.code}
{% endcodeblock %}
CODEBLOCK
        end

        example "happy path" do
          gist_file = GistFile.new("::code::", "::filename::", "::gist URL::")
          codeblock_source = render_gist_file_as_code_block(gist_file)
          # I'd rather compare abstract syntax trees or something, but I really
          # don't want to reimplement a parser.
          codeblock_source.should =~ %r[{%\s+codeblock\s+::filename::\s+::gist\ URL::\s+%}\s+::code::\s+{%\s+endcodeblock\s+%}]mx
        end

        example "nils" do
          empty_codeblock_regex = Regexp.new([%w({% codeblock %} {% endcodeblock %})].join("\\s+"), Regexp::MULTILINE)
          render_gist_file_as_code_block(GistFile.new(nil, nil, nil)).should =~ empty_codeblock_regex
        end

        example "what if somehow {% and %} get into the tag parameters?!" do
          expect { render_gist_file_as_code_block(GistFile.new("code is safe, so don't worry about it", "{% filename not playing nicely %}", "{% gist URL not playing nicely %}")) }.to raise_error(ArgumentError) { |e| e.message.should =~ %r[Liquid can't handle % or { or } inside tags, so don't do it.] }
        end
      end
      context "rendering codeblock"

      example "rendering codeblock fails"
      example "generating codeblock fails"
    end
  end

  require "plugins/gist_no_css_tag.rb"
  context "integrating the pieces into the Liquid extension point" do
    it "should be a Liquid tag" do
      Jekyll::GistNoCssTag.ancestors.should include(Liquid::Tag)
    end

    it "should register itself in Liquid" do
      Liquid::Template.tags.should include("gist_no_css" => Jekyll::GistNoCssTag)
    end

    describe "render()" do
      example "happy path"
      example "failure in rendering abstract tag"
    end

    describe "initialize()" do
      context "happy paths" do
        example "specify everything" do
          Jekyll::GistNoCssTag.parse_parameters("jbrains/1234 Gist1.java").should == Jekyll::GistNoCssTagParameters.new(1234, "jbrains", "Gist1.java")
        end

        example "omit username" do
          Jekyll::GistNoCssTag.parse_parameters("1234 Gist1.java").should == Jekyll::GistNoCssTagParameters.new(1234, nil, "Gist1.java")
        end

        example "omit filename" do
          Jekyll::GistNoCssTag.parse_parameters("jbrains/1234").should == Jekyll::GistNoCssTagParameters.new(1234, "jbrains", nil)
        end

        example "omit username and filename" do
          Jekyll::GistNoCssTag.parse_parameters("1234").should == Jekyll::GistNoCssTagParameters.new(1234, nil, nil)
        end
      end

      # Somebody Soap Opera the fuck out of this, will you?
      context "parsing parameters fails" do
        [
          "jbrains/ File1.java", 
          "/1234 File1.java",
          "/ File1.java",
          "File1.java",
          "jbrains File1.java",
          "jbrains",
          "",
          "...",
        ].each do | bad_parameters_text |
        example "#{bad_parameters_text} is invalid" do
          expect { Jekyll::GistNoCssTag.parse_parameters(bad_parameters_text) }.to raise_error(ArgumentError)
        end
        end
      end
    end
  end
end

