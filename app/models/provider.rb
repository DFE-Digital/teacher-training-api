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
#  website              :text
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
#  recruitment_cycle_id :integer          not null
#

class Provider < ApplicationRecord
  include RegionCode
  include ChangedAt
  include Discard::Model

  before_create :set_defaults

  has_associated_audits
  audited except: :changed_at

  enum provider_type: {
    scitt: "B",
    lead_school: "Y",
    university: "O",
    unknown: "",
    invalid_value: "0", # there is only one of these in the data
  }

  enum accrediting_provider: {
    accredited_body: "Y",
    not_an_accredited_body: "N",
  }

  enum scheme_member: {
    is_a_UCAS_ITT_member: "Y",
    not_a_UCAS_ITT_member: "N",
  }

  belongs_to :recruitment_cycle

  has_and_belongs_to_many :organisations, join_table: :organisation_provider
  has_many :users, through: :organisations

  has_many :sites

  # NOTE: To be removed as "ProviderEnrichment" is no longer
  #       START
  has_one :latest_enrichment,
          -> { latest_created_at },
          class_name: "ProviderEnrichment"

  has_many :enrichments,
           class_name: "ProviderEnrichment",
           inverse_of: "provider" do
             def find_or_initialize_draft(current_user)
               # This is a ruby search as opposed to an AR search, because calling `draft`
               # will return a new instance of a ProviderEnrichment object which is different
               # to the ones in the cached `enrichments` association. This makes checking
               # for validations later down non-trivial.
               latest_draft_enrichment = select(&:draft?).last

               latest_draft_enrichment.presence || new(new_draft_attributes(current_user))
             end

             def new_draft_attributes(current_user)
               latest_published_enrichment = latest_created_at.published.first

               new_enrichments_attributes = {
                 status: :draft,
                 updated_by_user_id: current_user.id,
                 created_by_user_id: current_user.id,
               }.with_indifferent_access

               if latest_published_enrichment.present?
                 published_enrichment_attributes = latest_published_enrichment.dup.attributes.with_indifferent_access
                   .except(:json_data, :status)

                 new_enrichments_attributes.merge!(published_enrichment_attributes)
               end

               new_enrichments_attributes
             end
           end

  has_one :latest_published_enrichment,
          -> { published.latest_published_at },
          class_name: "ProviderEnrichment",
          inverse_of: "provider"

  #      END
  has_many :courses, -> { kept }
  has_one :ucas_preferences, class_name: "ProviderUCASPreference"
  has_many :contacts
  has_many :accredited_courses,
           class_name: "Course",
           foreign_key: :accrediting_provider_code,
           primary_key: :provider_code,
           inverse_of: :accrediting_provider

  has_many :accrediting_providers, -> { distinct }, through: :courses

  scope :changed_since, ->(timestamp) do
    if timestamp.present?
      where("provider.changed_at > ?", timestamp)
    else
      where("changed_at is not null")
    end.order(:changed_at, :id)
  end

  scope :in_order, -> { order(:provider_name) }
  scope :search_by_code_or_name, ->(search_term) {
    where("provider_name ILIKE ? OR provider_code ILIKE ?", "%#{search_term}%", "%#{search_term}%")
  }

  serialize :accrediting_provider_enrichments, AccreditingProviderEnrichment::ArraySerializer

  validates :train_with_us, words_count: { maximum: 250, message: "^Reduce the word count for training with you" }
  validates :train_with_disability, words_count: { maximum: 250, message: "^Reduce the word count for training with disabilities and other needs" }

  validates :email, email: true

  validates :telephone, phone: { message: "^Enter a valid telephone number" }

  validates :train_with_us, presence: true, on: :update
  validates :train_with_disability, presence: true, on: :update

  validate :add_enrichment_errors

  def syncable_courses
    courses.includes(
      :enrichments,
      :subjects,
      :sites,
      site_statuses: :site,
      provider: %i[sites],
    ).select(&:syncable?)
  end

  # Currently Provider#contact_info isn't used but will likely be needed when
  # we need to expose the candidate-facing contact info.
  #
  # When the time comes:
  # - rename this method to reflect that it's the candidate-facing contact
  # - resurrect the tests which were stripped from models/provider_spec.rb
  #
  # def contact_info
  #   self
  #     .attributes_before_type_cast
  #     .slice('address1', 'address2', 'address3', 'address4', 'postcode', 'region_code', 'telephone', 'email')
  # end

  # This is used by the providers index; it is a replacement for `.includes(:courses)`,
  # but it only fetches the counts for the associated courses. By not fetching all the
  # course objects for 1000+ providers, the db query runs much faster, and the view spends
  # less time rendering because there's less data to comb through.
  def self.include_courses_counts
    joins(
      %{
        LEFT OUTER JOIN (
          SELECT b.provider_id, COUNT(*) courses_count
          FROM course b
          WHERE b.discarded_at IS NULL
          GROUP BY b.provider_id
        ) a ON a.provider_id = provider.id
      },
    ).select("provider.*, COALESCE(a.courses_count, 0) AS included_courses_count")
  end

  def courses_count
    self.respond_to?("included_courses_count") ? included_courses_count : courses.size
  end

  def update_changed_at(timestamp: Time.now.utc)
    # Changed_at represents changes to related records as well as provider
    # itself, so we don't want to alter the semantics of updated_at which
    # represents changes to just the provider record.
    update_columns changed_at: timestamp
  end

  def unassigned_site_codes
    Site::POSSIBLE_CODES - sites.pluck(:code)
  end

  def can_add_more_sites?
    sites.size < Site::POSSIBLE_CODES.size
  end

  def external_contact_info
    attribute_names = %w[
      address1
      address2
      address3
      address4
      postcode
      region_code
      telephone
      email
      website
    ]

    attributes.slice(*attribute_names)
  end

  # NOTE: This can be removed, it should not be in use any more
  def content_status
    :published
  end

  # This reflects the fact that organisations should actually be a has_one.
  def organisation
    organisations.first
  end

  def provider_type=(new_value)
    super
    self.accrediting_provider = if scitt? || university?
                                  :accredited_body
                                else
                                  :not_an_accredited_body
                                end
  end

  def to_s
    "#{provider_name} (#{provider_code}) [#{recruitment_cycle}]"
  end

  def accredited_bodies
    accrediting_providers.map do |ap|
      accrediting_provider_enrichment = accrediting_provider_enrichment(ap.provider_code)
      {
        provider_name: ap.provider_name,
        provider_code: ap.provider_code,
        description: accrediting_provider_enrichment&.Description || "",
      }
    end
  end

  def generated_ucas_contact(type)
    contacts.find_by!(type: type).slice("name", "email", "telephone") if contacts.map(&:type).include?(type)
  end

private

  def accrediting_provider_enrichment(provider_code)
    accrediting_provider_enrichments&.find do |enrichment|
      enrichment.UcasProviderCode == provider_code
    end
  end

  def add_enrichment_errors
    accrediting_provider_enrichments&.each do |item|
      accrediting_provider = accrediting_providers.find { |ap| ap.provider_code == item.UcasProviderCode }

      if accrediting_provider.present? && item.invalid?
        message = "^Reduce the word count for #{accrediting_provider.provider_name}"
        errors.add :accredited_bodies, message
      end
    end
  end

  def set_defaults
    self.scheme_member ||= "is_a_UCAS_ITT_member"
    self.year_code ||= recruitment_cycle.year
  end
end
