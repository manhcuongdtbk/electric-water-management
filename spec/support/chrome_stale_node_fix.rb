# Chrome 136+ can report error -32000 "Node with given id does not belong to the
# document" during visibility checks (ChromeDriver isElementDisplayed endpoint).
# This is a newer variant of the stale element problem: the DOM node was found by
# a CSS/XPath query but Chrome invalidated its internal node ID before Capybara
# could call visible? — a race condition between Selenium element references and
# rapid DOM mutations (e.g. Stimulus updating textContent).
#
# Returning false (not visible) causes Capybara's synchronize loop to treat the
# element as absent and retry the entire query from scratch, which is the correct
# recovery path. Without this patch the UnknownError propagates up and the test
# fails non-deterministically.
if defined?(Capybara::Selenium::ChromeNode)
  Capybara::Selenium::ChromeNode.prepend(Module.new do
    def visible?
      super
    rescue Selenium::WebDriver::Error::UnknownError => e
      raise unless e.message.include?("does not belong to the document")

      false
    end
  end)
end
