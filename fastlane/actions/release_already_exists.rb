require 'json'
module Fastlane
  module Actions
    module SharedValues

    end

    class ReleaseAlreadyExistsAction < Action
      def self.run(params)
        tag_name = params[:tag_name]

        GithubApiAction.run(
          server_url: "https://api.github.com",
          api_token: ENV["GITHUB_TOKEN"],
          http_method: "GET",
          path: "/repos/#{ENV["GITHUB_OWNER"]}/#{ENV["GITHUB_REPOSITORY"]}/releases",
          body: { ref: ENV["REPOSITORY_PROD_BRANCH"] },
          ) do |result|
            json = result[:json]
            
            
            match = json.any? {|release|   
              release["tag_name"].include? tag_name
            }
            
            return match
        end
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        'Given a tag and a configuration, checks if the release already exists'
      end

      def self.details
      end

      def self.available_options
        # Define all options your action supports.

        # Below a few examples
        [
          FastlaneCore::ConfigItem.new(key: :tag_name,
                                       # The name of the environment variable
                                       env_name: 'FL_RELEASE_ALREADY_EXISTS_TAG_NAME',
                                       # a short description of this parameter
                                       description: 'Tag name to check against in Github',
                                       verify_block: proc do |value|
                                         unless value && !value.empty?
                                           UI.user_error!("No tag_name value provided")
                                         end
                                       end),
        ]
      end

      def self.output
        # Define the shared values you are going to provide
        # Example
        []
      end

      def self.return_value
        "Returns true if exists, false if not"
      end

      def self.authors
        []
      end

      def self.is_supported?(platform)
        # you can do things like
        #
        #  true
        #
        #  platform == :ios
        #
        #  [:ios, :mac].include?(platform)
        #

        true
      end
    end
  end
end
