require 'hako/script'
require 'octokit'

module Hako
  module Scripts
    class GithubStatusTag < Script
      class NoSuccessfulBuildError < StandardError; end

      TARGET_TAG = 'github'

      GITHUB_APP_MEDIA = 'application/vnd.github.machine-man-preview+json'
      GITHUB_CHECKS_MEDIA = 'application/vnd.github.antiope-preview+json'

      def configure(options)
        super
        @repo = options.fetch('repo')
        @ref = options.fetch('ref', 'master')
        @checks = options.fetch('checks', [])
        @statuses = options.fetch('statuses ', [])
        @client_options = options.fetch('client', {})

        if @checks.empty? && @statuses.empty?
          raise ArgumentError, "at least 1 check or 1 status must be set to github_status_tag script"
        end
      end

      def deploy_starting(containers)
        app = containers.fetch('app')
        if app.definition['tag'] == TARGET_TAG
          rewrite_tag(app)
        end
      end

      alias_method :oneshot_starting, :deploy_starting

      private

      def rewrite_tag(app)
        tag = fetch_version
        app.definition['tag'] = tag
        Hako.logger.info("Rewrite tag to #{app.image_tag}")
      end

      def fetch_version
        page = octokit.commits(@repo, sha: @ref)
        num_commits = 0

        loop do

          page.each do |commit|
            num_commits += 1
            ok = true
            ok &&= @checks.empty? || (@checks - succeeded_checks_for_commit(commit[:sha])).empty?
            ok &&= @statuses.empty? || (@statuses - succeeded_statuses_for_commit(commit[:sha])).empty?
            return commit[:sha] if ok
          end

          next_page = octokit.last_response.rels[:next]&.href
          raise NoSuccessfulBuildError unless next_page
          Hako.logger.warn("github_status_tag is still finding a succeeding commit (num_commits=#{num_commits})")
          sleep 1
          page = octokit.get next_page
        end
      end

      def succeeded_checks_for_commit(sha)
        resp = octokit.check_runs_for_ref(@repo, sha, filter: 'completed', accept: GITHUB_CHECKS_MEDIA)
        resp[:check_runs]
          .select { |_| _[:status] == 'completed' && _[:conclusion] == 'success'}
          .map{ |_| _[:name] }
      end

      def succeeded_statuses_for_commit(sha)
        resp = octokit.combined_status(@repo, sha)
        resp[:statuses]
          .select{ |_| _[:state] == 'success' }
          .map{ |_| _[:context] }
      end

      def octokit
        @octokit ||= if @client_options['github_app']
                       repo_octokit
                     else
                       Octokit::Client.new(octokit_options)
                     end
      end

      def repo_octokit
        @octokit ||= Octokit::Client.new(
          octokit_options.merge(
            access_token: github_installation_token,
          )
        )
      end

      def octokit_options
        {}.tap do |o|
          o[:web_endpoint] = @client_options['web_endpoint'] if @client_options['web_endpoint']
          o[:api_endpoint] = @client_options['api_endpoint'] if @client_options['api_endpoint']
          o[:login] = @client_options['login'] if @client_options['login']
          o[:password] = @client_options['password'] if @client_options['password']
          o[:access_token] = @client_options['access_token'] if @client_options['access_token']
        end
      end

      def app_octokit
        @app_octokit ||= Octokit::Client.new(
          octokit_options.merge(
            bearer_token: github_jwt,
          )
        )
      end

      def github_installation_token
        return @github_installation_token if defined? @github_installation_token

        installation = app_octokit.find_repository_installation(@repo, accept: GITHUB_APP_MEDIA)
        raise "no github app installation found for #{repo.name.inspect}" unless installation

        issuance = app_octokit.create_app_installation_access_token(installation[:id], accept: GITHUB_APP_MEDIA)
        @github_installation_token = issuance[:token]
      end

      def github_jwt
        iat = Time.now.to_i
        payload = {
          iss: @client_options['github_app'].fetch('id'),
          iat: iat,
          exp: iat + (3*60),
        }
        JWT.encode(payload, @client_options['github_app'].fetch('id'), 'RS256')
      end
    end
  end
end

