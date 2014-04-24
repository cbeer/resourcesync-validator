module ApplicationHelper
  def on_sitemaps_new_page?
    controller.is_a?(SitemapsController) && action_name == "new"
  end
end
