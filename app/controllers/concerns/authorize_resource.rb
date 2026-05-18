module AuthorizeResource
  extend ActiveSupport::Concern

  private

  def load_collection(model_class)
    scope = model_class.respond_to?(:kept) ? model_class.kept : model_class.all
    scope.accessible_by(current_ability)
  end

  def load_member(model_class, action: :read)
    record = load_collection(model_class).find(params[:id])
    authorize!(action, record)
    record
  end
end
