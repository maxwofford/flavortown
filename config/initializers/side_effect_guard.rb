# Lets a copy of production (real data, real credentials) run without reaching
# real people or real systems. Enable with BLOCK_SIDE_EFFECTS=true.
return unless ENV["BLOCK_SIDE_EFFECTS"] == "true"

module SideEffectGuard
  SLACK_READ_METHOD = /\.(info|list|history|replies|members|lookupByEmail|get)\z/

  def self.blocked(what)
    Rails.logger.warn("[SideEffectGuard] blocked #{what}")
  end

  module SlackRequest
    private

    def request(method, path, options)
      return super if path.to_s.match?(SLACK_READ_METHOD)

      SideEffectGuard.blocked("Slack #{path}")
      Slack::Messages::Message.new("ok" => true)
    end
  end

  module Theseus
    def _conn
      raise "[SideEffectGuard] Theseus is disabled in this environment"
    end
  end

  module StorageDeletes
    def delete(key)
      SideEffectGuard.blocked("storage delete #{key}")
    end

    def delete_prefixed(prefix)
      SideEffectGuard.blocked("storage delete_prefixed #{prefix}")
    end
  end
end

Rails.application.config.after_initialize do
  ActionMailer::Base.perform_deliveries = false
  Slack::Web::Client.prepend(SideEffectGuard::SlackRequest)
  TheseusService.singleton_class.prepend(SideEffectGuard::Theseus)
  require "active_storage/service/s3_service"
  ActiveStorage::Service::S3Service.prepend(SideEffectGuard::StorageDeletes)
end
