require "rspec"

require "faraday"
require "faraday_middleware"

describe Faraday do
  context ".get" do
    example "moved permanently, not following redirects" do
      VCR.use_cassette("duckduckgo_welcome") do
        response = Faraday.get("https://www.duckduckgo.com")
        response.status.should == 301
        response.body.should =~ /Moved Permanently/
      end
    end

    example "moved permanently, following redirects" do
      VCR.use_cassette("duckduckgo_welcome_following_redirects") do
        connection = Faraday.new() do | connection |
          connection.use FaradayMiddleware::FollowRedirects, limit: 1
        end

        response = connection.get("https://www.duckduckgo.com")
        pending "I can't figure out how to get Faraday to really follow a redirect" do
          response.status.should == 200
        end
      end
    end
  end
end
