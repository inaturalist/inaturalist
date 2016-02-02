module Shared::LicenseModule
  COPYRIGHT = 0
  NO_COPYRIGHT = 7

  CC_VERSION = "4.0"
  CC0_VERSION = "1.0"
  
  LICENSE_INFO = {
    0 => {code: "C",                       short: "(c)",          name: "Copyright", url: "http://en.wikipedia.org/wiki/Copyright"},
    1 => {code: Observation::CC_BY_NC_SA,  short: "CC BY-NC-SA",  name: "Creative Commons Attribution-NonCommercial-ShareAlike License", url: "http://creativecommons.org/licenses/by-nc-sa/#{CC_VERSION}/"},
    2 => {code: Observation::CC_BY_NC,     short: "CC BY-NC",     name: "Creative Commons Attribution-NonCommercial License", url: "http://creativecommons.org/licenses/by-nc/#{CC_VERSION}/"},
    3 => {code: Observation::CC_BY_NC_ND,  short: "CC BY-NC-ND",  name: "Creative Commons Attribution-NonCommercial-NoDerivs License", url: "http://creativecommons.org/licenses/by-nc-nd/#{CC_VERSION}/"},
    4 => {code: Observation::CC_BY,        short: "CC BY",        name: "Creative Commons Attribution License", url: "http://creativecommons.org/licenses/by/#{CC_VERSION}/"},
    5 => {code: Observation::CC_BY_SA,     short: "CC BY-SA",     name: "Creative Commons Attribution-ShareAlike License", url: "http://creativecommons.org/licenses/by-sa/#{CC_VERSION}/"},
    6 => {code: Observation::CC_BY_ND,     short: "CC BY-ND",     name: "Creative Commons Attribution-NoDerivs License", url: "http://creativecommons.org/licenses/by-nd/#{CC_VERSION}/"},
    7 => {code: "PD",                      short: "PD",           name: "Public domain", url: "http://en.wikipedia.org/wiki/Public_domain"},
    8 => {code: "GFDL",                    short: "GFDL",         name: "GNU Free Documentation License", url: "http://www.gnu.org/copyleft/fdl.html"},
    9 => {code: Observation::CC0,          short: "CC0",          name: "Creative Commons CC0 Universal Public Domain Dedication", url: "http://creativecommons.org/publicdomain/zero/#{CC0_VERSION}/"}
  }
  LICENSE_NUMBERS = LICENSE_INFO.keys
  LICENSE_INFO.each do |number, info|
    const_set info[:code].upcase.gsub(/\-/, '_'), number
    const_set info[:code].upcase.gsub(/\-/, '_') + "_CODE", info[:code]
  end
  CC_LICNSES = [
    CC_BY,
    CC_BY_NC,
    CC_BY_ND,
    CC_BY_SA,
    CC_BY_NC_ND,
    CC_BY_NC_SA,
    CC0
  ]
  MASS_ASSIGNABLE_ATTRIBUTES = [:make_license_default, :make_licenses_same]

  attr_accessor :make_license_default
  attr_accessor :make_licenses_same

  # Return a string with attribution info about this photo
  def attribution
    if license == PD
      I18n.t('copyright.no_known_copyright_restrictions', :name => attribution_name, :license_name => I18n.t("copyright.#{license_name.gsub(' ','_').gsub('-','_').downcase}", :default => license_name))
    elsif license == CC0
      I18n.t('copyright.no_rights_reserved', :name => attribution_name, :license_name => I18n.t("copyright.#{license_name.gsub(' ','_').gsub('-','_').downcase}", :default => license_name))
    elsif open_licensed?
      I18n.t('copyright.some_rights_reserved_by', :name => attribution_name, :license_short => license_short)
    else
      I18n.t('copyright.all_rights_reserved', :name => attribution_name)
    end
  end

  def attribution_name
    if !native_realname.blank?
      native_realname
    elsif !native_username.blank?
      native_username
    elsif user
      user.name.blank? ? user.login : user.name
    else
      I18n.t('copyright.anonymous')
    end
  end

  def license_short
    LICENSE_INFO[license.to_i].try(:[], :short)
  end
  
  def license_name
    LICENSE_INFO[license.to_i].try(:[], :name)
  end
  
  def license_code
    LICENSE_INFO[license.to_i].try(:[], :code)
  end
  
  def license_url
    LICENSE_INFO[license.to_i].try(:[], :url)
  end
  
  def copyrighted?
    license.to_i < PD
  end

  def all_rights_reserved?
    license.to_i == COPYRIGHT
  end

  def some_rights_reserved?
    license.to_i > COPYRIGHT && license < PD
  end
  
  def creative_commons?
    CC_LICNSES.include?( license.to_i )
  end

  def open_licensed?
    license.to_i > COPYRIGHT && license != PD
  end

  # Make some class methods on the class including this module, e.g. Photo.license_number_for_code
  module ClassMethods
    def license_number_for_code(code)
      return COPYRIGHT if code.blank?
      LICENSE_INFO.detect{|k,v| v[:code] == code}.try(:first)
    end
    
    def license_code_for_number(number)
      LICENSE_INFO[number].try(:[], :code)
    end

    def license_name_for_code( code )
      LICENSE_INFO[ license_number_for_code( code ) ].try(:[], :name)
    end
  end

  def self.included(base)
    base.extend(ClassMethods)
  end

  # Make class methods available as module methods, e.g. Shared::LicenseModule.license_number_for_code
  extend ClassMethods
end
