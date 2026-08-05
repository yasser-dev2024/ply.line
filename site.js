(() => {
  const dialog = document.querySelector("#install-dialog");
  if (!(dialog instanceof HTMLDialogElement)) return;

  document.querySelectorAll("[data-install]").forEach((link) => {
    link.addEventListener("click", (event) => {
      event.preventDefault();
      if (!dialog.open) dialog.showModal();
    });
  });

  dialog.querySelector(".dialog-close")?.addEventListener("click", () => dialog.close());
  dialog.addEventListener("click", (event) => {
    if (event.target === dialog) dialog.close();
  });

  if (new URLSearchParams(window.location.search).get("install") === "1") {
    requestAnimationFrame(() => dialog.showModal());
  }
})();
