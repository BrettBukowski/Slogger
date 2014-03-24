=begin
Plugin: Bitbucket Logger
Version: 1.0
Description: Logs daily Bitbucket activity for the specified user
Author: [Brett Bukowski](http://brettbukowski.com)
Configuration:
  bitbucket_user: bitbucketuser
  oauth_token: oauthtoken
  oauth_token_secret: oauthtokensecret
  client_key: client key
  client_secret: client secret
  bitbucket_tags: "#coding"
Notes:

=end
# NOTE: Requires oauth gem
config = {
  'description' => ['Logs daily Bitbucket activity for the specified user','bitbucket_user should be your Bitbucket username'],
  'bitbucket_user' => '',
  'oauth_token' => '',
  'oauth_token_secret' => '',
  'client_key' => '',
  'client_secret' => '',
  'bitbucket_tags' => '#coding',
}
$slog.register_plugin({ 'class' => 'BitbucketLogger', 'config' => config })

require 'oauth'

class BitbucketLogger < Slogger
  def required_configs
    # {
    #   'bitbucket_user': '',
    #   'oauth_token': '',
    #   'oauth_token_secret': '',
    #   'client_key': '',
    #   'client_secret': '',
    # }
    %w{bitbucket_user oauth_token oauth_token_secret client_key client_secret}
  end

  def verify_config_values
    if @config.key?(self.class.name)
        config = @config[self.class.name]
        required_configs.each do |required|
          if !config.key?(required) || config[required].empty?
            @log.warn("Bitbucket setting #{required} has not been configured or is invalid, please edit your slogger_config file.")
            return false
          end
        end
    else
      @log.warn("Bitbucket user has not been configured, please edit your slogger_config file.")
      return false
    end
    true
  end

  def do_log
    return if !verify_config_values
    config = @config[self.class.name]
    @log.info("Logging Bitbucket activity for #{config['bitbucket_user']}")

    consumer = OAuth::Consumer.new config['client_key'], config['client_secret'], :site => 'https://bitbucket.org'
    access_token = OAuth::AccessToken.from_hash(consumer, {
      :oauth_token => config['oauth_token'],
      :oauth_token_secret => config['oauth_token_secret'],
    })

    response = access_token.get "/api/2.0/repositories/#{config['bitbucket_user']}"
    result = JSON.parse response.body

    activity = []

    result['values'].each do |repo|
      repo_api_url = repo['links']['commits']['href']

      repo_href = repo['links']['html']['href']
      repo_name = repo['full_name']
      timespan_commits = []

      response = access_token.get repo_api_url
      repo_result = JSON.parse response.body

      repo_result['values'].each do |commit|
        commit_date = Time.parse(commit['date'])
        if commit_date > @timespan && commit['author']['user']['username'] == config['bitbucket_user']
          timespan_commits << "[#{commit['message'].strip}](#{repo_href}/commits/#{commit['hash']})"
        end
        break if commit_date <= @timespan
      end

      if !timespan_commits.empty?
        activity << {
          :name => repo_name,
          :href => repo_href,
          :commits => timespan_commits,
        }
      end
    end

    if !activity.empty?
      entry = "## Bitbucket activity for #{Time.now.strftime(@date_format)}:\n\n" +
      activity.map do |repo|
        "* [#{repo[:name]}](#{repo[:href]})\n" +
        repo[:commits].map { |commit| "    * #{commit}" }.join("\n")
      end.join("\n") + "\n\n(#{config['bitbucket_tags']})"

      DayOne.new.to_dayone({ 'content' => entry })
    end
  end

  def init_oauth_flow

  end
end
