// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// Vanilla JS for Mobile Tabs and Header Dropdown (using global event delegation)
document.addEventListener("click", function(event) {
  // 1. Mobile Tabs switching
  const navItem = event.target.closest("[data-tab-name]");
  if (navItem) {
    const tabName = navItem.getAttribute("data-tab-name");
    
    // Toggle active class on nav items
    document.querySelectorAll(".nav-item").forEach(item => {
      item.classList.toggle("active", item.getAttribute("data-tab-name") === tabName);
    });

    // Toggle active class on tabs
    const heroTab = document.getElementById("character_sheet");
    const storyTab = document.querySelector(".game-main");
    const journalTab = document.querySelector(".game-sidebar.right");

    if (heroTab) heroTab.classList.toggle("mobile-tab-active", tabName === "hero");
    if (storyTab) storyTab.classList.toggle("mobile-tab-active", tabName === "story");
    if (journalTab) journalTab.classList.toggle("mobile-tab-active", tabName === "journal");
  }

  // 2. Header Dropdown Menu Toggle
  const dropdownBtn = event.target.closest(".header-dropdown-btn");
  if (dropdownBtn) {
    event.stopPropagation();
    const dropdownWrapper = dropdownBtn.closest(".header-dropdown-wrapper");
    if (dropdownWrapper) {
      const menu = dropdownWrapper.querySelector(".header-dropdown-menu");
      if (menu) {
        menu.classList.toggle("open");
      }
    }
  } else {
    // Clicked outside - close all dropdown menus
    document.querySelectorAll(".header-dropdown-menu.open").forEach(menu => {
      menu.classList.remove("open");
    });
  }
});
