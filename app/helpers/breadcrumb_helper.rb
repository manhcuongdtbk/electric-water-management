module BreadcrumbHelper
  def page_title(title)
    content_for(:page_title) { title }
    content_for(:breadcrumb) { title }
  end
end
