# == Schema Information
#
# Table name: provider
#
#  id                   :integer          not null, primary key
#  address4             :text
#  provider_name        :text
#  scheme_member        :text
#  contact_name         :text
#  year_code            :text
#  provider_code        :text
#  provider_type        :text
#  postcode             :text
#  scitt                :text
#  url                  :text
#  address1             :text
#  address2             :text
#  address3             :text
#  email                :text
#  telephone            :text
#  region_code          :integer
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  accrediting_provider :text
#  last_published_at    :datetime
#  changed_at           :datetime         not null
#  opted_in             :boolean          default(FALSE)
#

class ProviderSerializer < ActiveModel::Serializer
  has_many :sites, key: :campuses

  attributes :institution_code, :institution_name, :institution_type, :accrediting_provider,
             :address1, :address2, :address3, :address4, :postcode, :region_code, :scheme_member,
             :contact_name, :email, :telephone, :recruitment_cycle, :utt_application_alerts,
             :type_of_gt12, :application_alert_recipient

  attribute :contacts do
    object.contacts.map { |c| c.attributes.slice('type', 'name', 'email', 'telephone') } + [{
      type: 'application_alert_recipient',
      email: object.ucas_preferences.application_alert_email,
      }]
  end

  def institution_code
    object.provider_code
  end

  def institution_name
    object.provider_name
  end

  def institution_type
    object.provider_type_before_type_cast
  end

  def address1
    object.contact_info['address1']
  end

  def address2
    object.contact_info['address2']
  end

  def address3
    object.contact_info['address3']
  end

  def address4
    object.contact_info['address4']
  end

  def postcode
    object.contact_info['postcode']
  end

  def email
    object.contact_info['email']
  end

  def telephone
    object.contact_info['telephone']
  end

  def region_code
    "%02d" % object.contact_info['region_code'] if object.contact_info['region_code'].present?
  end

  def utt_application_alerts
    @object.ucas_preferences.send_application_alerts_before_type_cast
  end

  def type_of_gt12
    @object.ucas_preferences.type_of_gt12_before_type_cast
  end

  def application_alert_recipient
    @object.ucas_preferences.application_alert_email
  end

private

  def select_value_for_provider(provider_code, values)
    # Using `to_i(36)` is an easy, cheap way to convert 'A1' into a consistent
    # hash. ex. 'A1'.to_i(36) == 361
    index = provider_code.to_i(36) % values.count
    values[index]
  end
end
