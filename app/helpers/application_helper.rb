# frozen_string_literal: true

module ApplicationHelper
  def page_title(title = nil)
    if title.present?
      content_for(:title, title)
    elsif content_for?(:title)
      content_for(:title)
    else
      "Bánk's Repository"
    end
  end
end
