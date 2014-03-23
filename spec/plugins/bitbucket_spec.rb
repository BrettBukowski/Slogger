require_relative 'spec_helper'
require 'bitbucketlogger'

describe BitbucketLogger do
  let(:bitbucket) {
    BitBucketLogger.new.tap do |strava|
      bitbucket.config = {
        'BitbucketLogger' => {
          'oauth_token' => 'the_access_token',
          'oauth_token_secret' => 'the_access_token',
          'strava_unit' => 'imperial',
          'bitbucket_tags' => '#the_tags',
        }
      }
    end
  }

  it 'warns if config not found' do
    bitbucket.config.delete('BitbucketLogger')
    bitbucket.log.should_receive(:warn).with('Bitbucket has not been configured or is invalid, please edit your slogger_config file.')
    bitbucket.do_log
  end

  it 'warns if access_token is not set' do
    bitbucket.config['StravaLogger']['strava_access_token'] = '   '
    bitbucket.log.should_receive(:warn).with('Strava access token has not been configured, please edit your slogger_config file.')
    bitbucket.do_log
  end

  it 'does not log anything if there are no activities newer than the timespan' do
    VCR.use_cassette('bitbucket') do
      bitbucket.timespan = Time.now
      bitbucket.do_log
    end
  end

  it 'logs the activity to DayOne' do
    VCR.use_cassette('bitbucket') do
      bitbucket.timespan = Time.parse('2014-04-17 00:00:00')
      bitbucket.do_log

      DayOne.to_dayone_options.size.should == 1
      options = DayOne.to_dayone_options.first
      options['uuid'].should_not be_nil
      options['starred'].should be_false
      options['datestamp'].should == '2014-02-17T23:59:58Z'

      expected_content = <<-eos.unindent
        # Strava Activity - 2.00 mi - 0h 31m 34s - 3.8 mph - Afternoon Walk

        * **Type**: Walk
        * **Distance**: 2.00 mi
        * **Elevation Gain**: 0 ft
        * **Average Speed**: 3.8 mph
        * **Max Speed**: 0.0 mph
        * **Elapsed Time**: 00:31:34
        * **Moving Time**: 00:31:34
        * **Link**: http://www.strava.com/activities/114100845


        #the_tags
      eos

      options['content'].should == expected_content
    end
  end
end
