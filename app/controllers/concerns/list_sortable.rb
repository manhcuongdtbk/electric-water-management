module ListSortable
  extend ActiveSupport::Concern

  PER_PAGE_OPTIONS = [10, 25, 50, 100].freeze

  private

  # Áp dụng sort an toàn lên scope.
  #
  # SECURITY: `allowed` PHẢI là Hash hardcode trong controller, ví dụ:
  #   SORT_COLUMNS = { name: "users.name", role: "users.role" }.freeze
  # KHÔNG BAO GIỜ nhận `allowed` từ params hoặc input user — nếu không sẽ bị
  # SQL injection qua Arel.sql. Chỉ key user-controlled là `sort_key` (lookup
  # vào allowed) và `dir` (whitelist ASC/DESC).
  def apply_sort(scope, allowed:, default: nil)
    sort_key = params[:sort].to_s.to_sym
    dir = params[:dir].to_s.downcase == "desc" ? "DESC" : "ASC"

    if allowed.key?(sort_key)
      scope.order(Arel.sql("#{allowed[sort_key]} #{dir}"))
    elsif default
      col, d = default
      column_sql = allowed.fetch(col)
      scope.order(Arel.sql("#{column_sql} #{d.to_s.upcase}"))
    else
      scope
    end
  end

  def pagy_with_per_page(scope, default: 25)
    pp = params[:per_page].to_i
    limit = PER_PAGE_OPTIONS.include?(pp) ? pp : default
    pagy(scope, limit: limit)
  end
end
