# frozen_string_literal: true

require "rails_helper"

feature "View provider courses" do
  let(:user) { create(:user, :admin) }

  scenario "i can view courses belonging to a provider" do
    given_i_am_authenticated(user: user)
    and_there_is_a_provider_with_courses
    when_i_visit_the_provider_show_page
    and_click_on_the_courses_tab
    then_i_should_see_a_table_of_courses
  end

  def and_there_is_a_provider_with_courses
    @provider = create(:provider)
    @provider.courses << create(:course)
  end

  def when_i_visit_the_provider_show_page
    provider_show_page.load(id: @provider.id)
  end

  def and_click_on_the_courses_tab
    provider_show_page.courses_tab.click
  end

  def then_i_should_see_a_table_of_courses
    expect(provider_courses_index_page.courses.size).to eq(1)
  end
end
