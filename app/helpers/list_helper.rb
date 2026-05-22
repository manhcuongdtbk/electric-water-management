module ListHelper
  ALIGN_CLASSES = {
    left:   "text-left",
    right:  "text-right",
    center: "text-center"
  }.freeze

  # Render <th> chứa link sort cho column. Click vào header sẽ toggle ASC/DESC.
  # column:        Symbol — key trong SORT_COLUMNS hash của controller.
  # label:         String — đã dịch bởi caller (t("...")).
  # current_sort:  params[:sort]
  # current_dir:   params[:dir]
  # extra_params:  Hash giữ filter/search hiện tại khi navigate (vd: {q:, type:}).
  # align:         :left (mặc định) / :right (cột số) / :center.
  def sortable_header(column, label, current_sort:, current_dir:, extra_params: {}, align: :left)
    current = current_sort.to_s == column.to_s
    if current && current_dir.to_s.downcase == "desc"
      url_params = extra_params.compact.except(:sort, :dir)
      arrow = "⇓"
    elsif current
      url_params = extra_params.compact.merge(sort: column, dir: "desc")
      arrow = "⇑"
    else
      url_params = extra_params.compact.merge(sort: column, dir: "asc")
      arrow = "⇅"
    end
    arrow_class = current ? "text-blue-600" : "text-gray-300"

    link = link_to url_params,
                   class: "inline-flex items-center gap-1 hover:text-blue-700",
                   data: { turbo_action: "replace" } do
      safe_join([label, content_tag(:span, arrow, class: "text-xs #{arrow_class}")], " ")
    end

    content_tag :th,
                link,
                class: "px-4 py-2 #{ALIGN_CLASSES.fetch(align)} text-xs font-semibold text-gray-600 uppercase select-none"
  end

  # Render <th> non-sortable nhất quán style.
  # align: :left (mặc định) / :right (cột số/action) / :center.
  def list_header(label, align: :left)
    content_tag :th, label,
                class: "px-4 py-2 #{ALIGN_CLASSES.fetch(align)} text-xs font-semibold text-gray-600 uppercase select-none"
  end

  # Tổng số bản ghi (đã được dịch).
  def list_total(count)
    t("common.list.total", count: count)
  end

  # Placeholder hiển thị trong cột "Thao tác" khi không có thao tác nào khả dụng
  # (vd user không có quyền hoặc kỳ đã đóng). Báo cho user biết "không có action"
  # thay vì ô trống dễ gây hiểu lầm là bug.
  def empty_actions_dash
    content_tag :span, "—", class: "text-gray-400"
  end
end
