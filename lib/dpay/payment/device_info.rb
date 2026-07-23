# frozen_string_literal: true

module DPay
  class DeviceInfo
    def self.create(browser_accept_header:, browser_language:, browser_color_depth:, browser_screen_height:,
                    browser_screen_width:, browser_tz:, browser_user_agent:, system_family:, geo_localization:,
                    device_id:, application_name:)
      new(
        { "browserAcceptHeader" => browser_accept_header, "browserLanguage" => browser_language,
          "browserColorDepth" => browser_color_depth, "browserScreenHeight" => browser_screen_height,
          "browserScreenWidth" => browser_screen_width, "browserTZ" => browser_tz,
          "browserUserAgent" => browser_user_agent, "systemFamily" => system_family,
          "geoLocalization" => geo_localization, "deviceID" => bounded(device_id, "Device ID"),
          "applicationName" => bounded(application_name, "Application name") }
      )
    end

    def self.bounded(value, label)
      raise InvalidArgumentError, "#{label} must be 1-64 characters" unless value.is_a?(String) &&
                                                                            !value.empty? && value.length <= 64

      value
    end
    private_class_method :bounded

    def initialize(fields)
      @fields = fields
      @browser_java_enabled = nil
    end

    def with_browser_java_enabled(enabled)
      @browser_java_enabled = enabled
      self
    end

    def to_h
      data = @fields.dup
      data["browserJavaEnabled"] = @browser_java_enabled ? "true" : "false" unless @browser_java_enabled.nil?
      data
    end
  end
end
