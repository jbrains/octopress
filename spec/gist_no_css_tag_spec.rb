require "rspec"

# :filename is optional
GistFile = Struct.new(:code, :gist_url, :filename)

class GistNoCssTag
  def initialize(renders_code, downloads_gist)
    @renders_code = renders_code
    @downloads_gist = downloads_gist
  end

  def self.with(collaborators_as_hash)
    self.new(collaborators_as_hash[:renders_code], collaborators_as_hash[:downloads_gist])
  end

  def render(gist_file_key)
    # REFACTOR COMPOSE, MOTHERFUCKER!
    @renders_code.render(@downloads_gist.download(gist_file_key))
  rescue => oops
    StringIO.new.tap { |canvas| canvas.puts "<!--", oops.message, oops.backtrace, "-->" }.string
  end
end

class DownloadsGistUsingFaraday
  # options: username, filename
  def download(gist_file_key, gist_id, options = {})
    base = "https://gist.github.com"
    if options[:username]
      filename_portion = "/#{options[:filename]}" if options[:filename]
      raw_url = "https://gist.github.com/#{options[:username]}/#{gist_id}/raw#{filename_portion}"
      pretty_url = "https://gist.github.com/#{options[:username]}/#{gist_id}"
      uri = "/#{options[:username]}/#{gist_id}/raw#{filename_portion}"
    else
      filename_portion = "/#{options[:filename]}" if options[:filename]
      raw_url = "https://gist.github.com/raw/#{gist_id}#{filename_portion}"
      pretty_url = "https://gist.github.com/#{gist_id}"
      uri = "/raw/#{gist_id}#{filename_portion}"
    end
    response = http_get(base, uri)

    return GistFile.new(response.body, pretty_url, nil) unless (400..599).include?(response.status.to_i)
    raise RuntimeError.new(StringIO.new.tap { |s| s.puts "I failed to download the gist at #{raw_url}", response.inspect.to_s }.string)
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

require "jekyll" # only because the CodeBlock plugin doesn't do this
require "plugins/code_block" # registers the CodeBlock tag, which we need

# Everything in here knows about Liquid
class RendersGistFileAsHtml
  def render_gist_file_as_code_block(gist_file)
    raise ArgumentError.new(%q(Liquid can't handle % or { or } inside tags, so don't do it.)) if [gist_file.filename, gist_file.gist_url].any? { |each| each =~ %r[{|%|}] }
    <<-CODEBLOCK
{% codeblock #{gist_file.filename} #{gist_file.gist_url} %}
#{gist_file.code}
{% endcodeblock %}
CODEBLOCK
  end

  def render_code_block_as_html(code_block)
    Liquid::Template.parse(code_block).render(Liquid::Context.new)
  end

  def render(gist_file)
    render_code_block_as_html(render_gist_file_as_code_block(gist_file))
  end
end

describe "gist_no_css tag" do
  context "the pieces" do
    # Intentionally link to the gist page, rather than the raw code.
    context "packaging the GistFile" do
      subject { DownloadsGistUsingFaraday.new.tap { | d | d.stub(:http_get).and_return(double("like a Faraday response", body: "::code::", status: 200)) } }

      example "happy path" do
        subject.download(GistFileKey.new(1, "::username::", "::filename::"), 1, username: "::username::", filename: "::filename::").should == GistFile.new("::code::", "https://gist.github.com/::username::/1")
      end

      example "filename not specified" do
        subject.download(GistFileKey.new(1, "::username::"), 1, username: "::username::").should == GistFile.new("::code::", "https://gist.github.com/::username::/1")
      end

      example "username not specified" do
        subject.download(GistFileKey.new(1, nil, "::filename::"), 1, filename: "::filename::").should == GistFile.new("::code::", "https://gist.github.com/1")
      end

      example "neither username nor filename specified" do
        subject.download(GistFileKey.new(1), 1).should == GistFile.new("::code::", "https://gist.github.com/1")
      end
    end

    context "downloading gist code" do
      require "vcr"
      require "faraday"
      require "faraday_middleware"

      VCR.configure do |c|
        c.cassette_library_dir = 'fixtures/downloading_gists'
        c.hook_into :faraday
        c.allow_http_connections_when_no_cassette = true
      end

      context "gist found" do
        context "gist has only one file" do
          example "filename specified" do
            VCR.use_cassette("gist_exists_with_single_file") do
              DownloadsGistUsingFaraday.new.download(GistFileKey.new(4111662, "jbrains", "TestingIoFailure.java"), 4111662, username: "jbrains", filename: "TestingIoFailure.java").code.should == Faraday.get("https://gist.github.com/jbrains/4111662/raw/TestingIoFailure.java").body
            end
          end

          example "filename not specified" do
            VCR.use_cassette("gist_exists_with_single_file") do
              DownloadsGistUsingFaraday.new.download(GistFileKey.new(4111662, "jbrains", "TestingIoFailure.java"), 4111662, username: "jbrains", filename: "TestingIoFailure.java").code.should == Faraday.get("https://gist.github.com/jbrains/4111662/raw/TestingIoFailure.java").body
            end
          end

          example "filename does not match" do
            VCR.use_cassette("gist_exists_with_single_file_but_the_wrong_file") do
              lambda {
                DownloadsGistUsingFaraday.new.download(GistFileKey.new(4111662, "jbrains", "TheWrongFilename.java"), 4111662, username: "jbrains", filename: "TheWrongFilename.java")
              }.should raise_error()
            end
          end

          example "username not specified, but filename specified" do
            VCR.use_cassette("gist_exists_with_single_file_username_not_specified") do
              # IMPORTANT The expected result should be the target URL, not the
              # one through which the username-less shortcut redirects!
              DownloadsGistUsingFaraday.new.download(GistFileKey.new(4111662, nil, "TestingIoFailure.java"), 4111662, filename: "TestingIoFailure.java").code.should == Faraday.get("https://gist.github.com/jbrains/4111662/raw/TestingIoFailure.java").body
            end
          end

          example "neither username nor filename specified" do
            VCR.use_cassette("gist_exists_with_single_file_username_not_specified_and_filename_not_specified") do
              DownloadsGistUsingFaraday.new.download(GistFileKey.new(4111662), 4111662).code.should == Faraday.get("https://gist.github.com/jbrains/4111662/raw/TestingIoFailure.java").body
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
                DownloadsGistUsingFaraday.new.download(GistFileKey.new(6964587, "jbrains", "Gist1.java"), 6964587, username: "jbrains", filename: "Gist1.java").code.should == Faraday.get("https://gist.github.com/jbrains/6964587/raw/Gist1.java").body
              end
            end

            example "matches other-than-first file" do
              VCR.use_cassette("gist_exists_with_many_files_matching_not_the_first_file") do
                DownloadsGistUsingFaraday.new.download(GistFileKey.new(6964587, "jbrains", "Gist2.rb"), 6964587, username: "jbrains", filename: "Gist2.rb").code.should == Faraday.get("https://gist.github.com/jbrains/6964587/raw/Gist2.rb").body
              end
            end

            example "filename does not match" do
              VCR.use_cassette("gist_exists_with_many_files_but_the_wrong_file") do
                lambda {
                  DownloadsGistUsingFaraday.new.download(GistFileKey.new(6964587, "jbrains", "SoTotallyNotTheRightFile.java"), 6964587, username: "jbrains", filename: "SoTotallyNotTheRightFile.java")
                }.should raise_error()
              end
            end

            context "username not specified" do
              example "matches first file" do
                VCR.use_cassette("gist_exists_with_many_files_matching_the_first_file_username_not_specified") do
                  DownloadsGistUsingFaraday.new.download(GistFileKey.new(6964587, nil, "Gist1.java"), 6964587, filename: "Gist1.java").code.should == Faraday.get("https://gist.github.com/jbrains/6964587/raw/Gist1.java").body
                end
              end

              example "matches other-than-first file" do
                VCR.use_cassette("gist_exists_with_many_files_matching_not_the_first_file_username_not_specified") do
                  DownloadsGistUsingFaraday.new.download(GistFileKey.new(6964587, nil, "Gist2.rb"), 6964587, filename: "Gist2.rb").code.should == Faraday.get("https://gist.github.com/jbrains/6964587/raw/Gist2.rb").body
                end
              end
            end
          end

          example "filename not specified" do
            VCR.use_cassette("gist_exists_with_many_files_but_not_specifying_the_filename") do
              DownloadsGistUsingFaraday.new.download(GistFileKey.new(6964587, "jbrains"), 6964587, username: "jbrains").code.should == Faraday.get("https://gist.github.com/jbrains/6964587/raw/#{name_of_first_file}").body
            end
          end

          example "neither filename nor username specified" do
            VCR.use_cassette("gist_exists_with_many_files_but_specifying_only_gist_id") do
              DownloadsGistUsingFaraday.new.download(GistFileKey.new(6964587), 6964587).code.should == Faraday.get("https://gist.github.com/jbrains/6964587/raw/#{name_of_first_file}").body
            end
          end
        end
      end

      context "gist not found" do
        example "wrong gist ID" do
          VCR.use_cassette("gist_not_found_due_to_wrong_gist_id") do
            # ASSUME No gist will ever have a negative ID.
            lambda {
              DownloadsGistUsingFaraday.new.download(GistFileKey.new(-1), -1)
            }.should raise_error()
          end
        end

        example "right gist ID, wrong username" do
          VCR.use_cassette("gist_not_found_due_to_wrong_username") do
            lambda {
              DownloadsGistUsingFaraday.new.download(GistFileKey.new(6964587, "notjbrains"), 6964587, username: "notjbrains")
            }.should raise_error()
          end
        end
      end

      example "failure downloading gist" do
        intentional_failure = RuntimeError.new("I intentionally failed to download the gist")
        # SMELL I don't like the implicit dependency on an implementation detail here, but at least it's small.
        # REFACTOR Split computing the URL from downloading it, perhaps?!
        expect {
          DownloadsGistUsingFaraday.new.tap { |d| d.stub(:http_get).and_raise(intentional_failure) }.download(GistFileKey.new(6964587, "jbrains", "Gist1.java"), 6964587, username: "jbrains", filename: "Gist1.java") 
        }.to raise_error(intentional_failure)
      end
    end
  end

  context "putting the pieces together" do
    describe "render()" do
      example "happy path" do
        renders_code = double("I render the code")
        downloads_gist = double("I download the gist", download: "::gist file description::")

        downloads_gist.should_receive(:download).with("::gist file key::").and_return("::gist file description::")
        renders_code.should_receive(:render).with("::gist file description::").and_return("::rendered HTML fragment::")

        GistNoCssTag.with(renders_code: renders_code, downloads_gist: downloads_gist).render("::gist file key::").should == "::rendered HTML fragment::"
      end

      example "failure rendering code" do
        renders_code = double("I render the code")
        downloads_gist = double("I download the gist", download: "::downloaded code::")

        renders_code.stub(:render).and_raise("I failed to render the code")

        GistNoCssTag.with(renders_code: renders_code, downloads_gist: downloads_gist).render("::gist file key::").should =~ /<!--.+I failed to render the code.+-->/m
      end

      example "failure downloading gist" do
        renders_code = double("I render the code")
        downloads_gist = double("I download the gist")

        downloads_gist.stub(:download).and_raise("I failed to download the gist")
        renders_code.should_not_receive(:render)

        GistNoCssTag.with(renders_code: renders_code, downloads_gist: downloads_gist).render("::gist file key::").should =~ /<!--.+I failed to download the gist.+-->/m
      end
    end
  end

  context "integrating the pieces with other Octopress plugins" do
    context "rendering the gist file with a CodeBlock" do
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
        render_gist_file = RendersGistFileAsHtml.new
        render_gist_file.stub(:render_gist_file_as_code_block).with("::gist file::").and_return("::code block::")
        render_gist_file.stub(:render_code_block_as_html).with("::code block::").and_return("::html::")

        render_gist_file.render("::gist file::").should == "::html::"
      end

      example "rendering the gist file as a code block fails" do
        # Just let the error bubble up
      end

      example "rendering the code block as HTML fails" do
        # Just let the error bubble up
      end

      context "generating codeblock from GistFile" do
        def render_gist_file_as_code_block(gist_file)
          RendersGistFileAsHtml.new.render_gist_file_as_code_block(gist_file)
        end

        example "happy path" do
          gist_file = GistFile.new("::code::", "::gist URL::", "::filename::")
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
          expect { render_gist_file_as_code_block(GistFile.new("code is safe, so don't worry about it", "{% gist URL not playing nicely %}", "{% filename not playing nicely %}")) }.to raise_error(ArgumentError) { |e| e.message.should =~ %r[Liquid can't handle % or { or } inside tags, so don't do it.] }
        end

        example "no filename" do
          render_gist_file_as_code_block(GistFile.new("::code::", "::gist URL::", nil)).should =~ Regexp.new([%w({% codeblock ::gist\ URL:: %} ::code:: {% endcodeblock %})].join("\\s+"), Regexp::MULTILINE)
        end
      end

      context "rendering codeblock" do
        # ASSUME codeblock_template has been sanitised for my protection
        def render_code_block(codeblock_template)
          RendersGistFileAsHtml.new.render_code_block_as_html(codeblock_template)
        end

        example "happy path" do
          codeblock_template = <<-TEMPLATE
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
          
          rendered = render_code_block(codeblock_template)
          # Spot checks, rather than checking the entire content.
          # Is the title there?
          rendered.should =~ %r{TestingIoFailure.java}m
          # Is the URL there?
          rendered.should =~ %r{https://gist.github.com/jbrains/4111662}m
          # Do we probably have the expected code? (Where else would this come from?)
          rendered.should =~ %r{fail.+How did you survive the I/O failure\?\!}m
        end
      end
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
          Jekyll::GistNoCssTag.parse_parameters("jbrains/1234 Gist1.java").should == GistFileKey.new(1234, "jbrains", "Gist1.java")
        end

        example "omit username" do
          Jekyll::GistNoCssTag.parse_parameters("1234 Gist1.java").should == GistFileKey.new(1234, nil, "Gist1.java")
        end

        example "omit filename" do
          Jekyll::GistNoCssTag.parse_parameters("jbrains/1234").should == GistFileKey.new(1234, "jbrains", nil)
        end

        example "omit username and filename" do
          Jekyll::GistNoCssTag.parse_parameters("1234").should == GistFileKey.new(1234, nil, nil)
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

