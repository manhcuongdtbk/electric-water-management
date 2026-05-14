// Replace Turbo's default window.confirm() with the styled <dialog> modal
// rendered by layouts/_confirm_modal. Applies to every data-turbo-confirm.
window.Turbo.config.forms.confirm = (message) => {
  const dialog = document.getElementById("confirm-dialog")
  if (!dialog) return Promise.resolve(window.confirm(message))

  dialog.querySelector("[data-confirm-message]").textContent = message
  dialog.showModal()

  return new Promise((resolve) => {
    dialog.addEventListener(
      "close",
      () => resolve(dialog.returnValue === "confirm"),
      { once: true }
    )
  })
}

// Clicking the backdrop (outside the form) cancels.
document.addEventListener("click", (event) => {
  const dialog = document.getElementById("confirm-dialog")
  if (dialog && event.target === dialog) dialog.close("cancel")
})
