module FlashHelper
  FLASH_CLASSES = {
    "notice"  => "bg-green-50 border-l-4 border-green-500 text-green-800",
    "alert"   => "bg-red-50 border-l-4 border-red-500 text-red-800",
    "warning" => "bg-yellow-50 border-l-4 border-yellow-500 text-yellow-800"
  }.freeze

  def flash_class(key)
    FLASH_CLASSES[key.to_s] || "bg-gray-50 border-l-4 border-gray-500 text-gray-800"
  end
end
