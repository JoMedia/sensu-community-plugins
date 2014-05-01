#!/usr/bin/env ruby
#
# Sensu Handler: mailer
#
# This handler formats alerts as mails and sends them off to a recipient,
# either defined in the check (optional) or default to a prefined value.
#
# Required: mailer.json that should have at least, mail_to and mail_from
#
# Optional: checks can contain, mail_to, mail_from, and mail_subject that
# will override the defaults.
#
# Original done by:
#  Pål-Kristian Hamre (https://github.com/pkhamre | http://twitter.com/pkhamre)
#
# Extended by:
#  Zach Dunn @SillySophist http://github.com/zadunn
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'
require 'mail'
require 'timeout'

class Mailer < Sensu::Handler
  def short_name
    @event['client']['name'] + '/' + @event['check']['name']
  end

  def action_to_string
   @event['action'].eql?('resolve') ? "RESOLVED" : "ALERT"
  end

  def handle
    # Use mail_to from the check or fail to default
    mail_to = (@event['check'].has_key?('mail_to') &&
                 @event['check']['mail_to']) || settings['mailer']['mail_to']
    # Use mail_from from the check or fail to default
    mail_from = (@event['check'].has_key?('mail_from') &&
              @event['check']['mail_from']) || settings['mailer']['mail_from']
    # Use mail_subject from the check or fail to default
    subject = (@event['check'].has_key?('mail_subject') &&
               @event['check']['mail_subject']) ||
               "#{action_to_string} - #{short_name}" +
               ": #{@event['check']['notification']}"
    smtp_address = settings['mailer']['smtp_address'] || 'localhost'
    smtp_port = settings['mailer']['smtp_port'] || '25'
    smtp_domain = settings['mailer']['smtp_domain'] || 'localhost.localdomain'
    opening = "#{@event['check']['output']}\n\n"
    # Shame people into adding a description field
    description = (@event['check'].has_key?('description') &&
                   @event['check']['description']) || "Ooops!  Someone has " +
                   "been a naughty boy or girl and has not provided a " +
                   "description for their check.  They really should go add " +
                   "a description field to the check configuration, with " +
                   "some  meaningful informationi. Maybe, I don't know say " +
                   "what to do when you get this email?  Good luck!"
    closing = "\n\nLove,\n\nSensu"

    if @event['action'].eql?('resolve')
      body = opening + "All Clear!" + closing
    else
      body = opening + "Check Description:\n" + description + closing
    end

    Mail.defaults do
      delivery_method :smtp, {
        :address => smtp_address,
        :port    => smtp_port,
        :domain  => smtp_domain,
        :openssl_verify_mode => 'none'
      }
    end

    begin
      timeout 10 do
        Mail.deliver do
          to      mail_to
          from    mail_from
          subject subject
          body    body
        end
        puts 'mail -- sent alert for ' + short_name + ' to ' + mail_to
      end
    rescue Timeout::Error
      puts 'mail -- timed out while attempting to ' + @event['action'] +
           ' an incident -- ' + short_name
    end
  end
end
