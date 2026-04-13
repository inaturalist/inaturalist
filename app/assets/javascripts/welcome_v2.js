// Carousel logic
(function () {
  document.querySelectorAll("[data-carousel]").forEach(function (carousel) {
    var track   = carousel.querySelector(".wv2-carousel__track");
    var dots    = Array.from(carousel.querySelectorAll(".wv2-carousel__dot"));
    var items   = Array.from(track.querySelectorAll(".wv2-carousel__item"));
    var prevBtn = carousel.querySelector(".wv2-carousel__arrow--prev");
    var nextBtn = carousel.querySelector(".wv2-carousel__arrow--next");
    if (!track || !items.length) return;

    function activeDotIndex() {
      var trackRect = track.getBoundingClientRect();
      var center = trackRect.width / 2;
      var centeredIdx = 0, closestDistanceToCenter = Infinity;
      items.forEach(function (item, i) {
        var r = item.getBoundingClientRect();
        var distanceToCenter = Math.abs(r.left + r.width / 2 - center);
        if (distanceToCenter < closestDistanceToCenter) {
          closestDistanceToCenter = distanceToCenter;
          centeredIdx = i;
        }
      });
      return centeredIdx;
    }

    function scrollToIndex(idx) {
      idx = ((idx % items.length) + items.length) % items.length;
      var item = items[idx];
      var itemRect = item.getBoundingClientRect();
      var trackRect = track.getBoundingClientRect();
      var offset = track.scrollLeft + itemRect.left - trackRect.left - (trackRect.width - itemRect.width) / 2;
      track.scrollTo({ left: offset, behavior: "smooth" });
    }

    function syncDots() {
      var atStart = track.scrollLeft <= 1;
      var atEnd   = track.scrollLeft >= track.scrollWidth - track.clientWidth - 1;
      var idx = atStart ? 0 : atEnd ? items.length - 1 : activeDotIndex();
      dots.forEach(function (d, i) { d.classList.toggle("active", i === idx); });
    }

    // Touch handling — require 60px swipe to advance, otherwise snap back
    var touchStartX = 0, touchStartY = 0, touchStartScrollLeft = 0, isTouching = false;
    track.addEventListener("touchstart", function (e) {
      touchStartX = e.touches[0].clientX;
      touchStartY = e.touches[0].clientY;
      touchStartScrollLeft = track.scrollLeft;
      isTouching = true;
      track.style.scrollSnapType = "none";
    }, { passive: true });
    track.addEventListener("touchmove", function (e) {
      if (!isTouching) return;
      var dx = touchStartX - e.touches[0].clientX;
      var dy = touchStartY - e.touches[0].clientY;
      if (Math.abs(dx) > Math.abs(dy)) {
        e.preventDefault();
        track.scrollLeft = touchStartScrollLeft + dx;
      }
    }, { passive: false });
    track.addEventListener("touchend", function (e) {
      if (!isTouching) return;
      isTouching = false;
      track.style.scrollSnapType = "";
      var dx = touchStartX - e.changedTouches[0].clientX;
      var threshold = 60;
      var currentIdx = activeDotIndex();
      if (Math.abs(dx) >= threshold) {
        scrollToIndex(dx > 0 ? currentIdx + 1 : currentIdx - 1);
      } else {
        scrollToIndex(currentIdx);
      }
    }, { passive: true });

    var raf;
    track.addEventListener("scroll", function () {
      cancelAnimationFrame(raf);
      raf = requestAnimationFrame(syncDots);
    }, { passive: true });

    dots.forEach(function (dot, i) {
      dot.addEventListener("click", function () { scrollToIndex(i); });
    });

    if (prevBtn) prevBtn.addEventListener("click", function () { scrollToIndex(activeDotIndex() - 1); });
    if (nextBtn) nextBtn.addEventListener("click", function () { scrollToIndex(activeDotIndex() + 1); });

    function updateStaticMode() {
      // Temporarily remove overflow clip so scrollWidth reflects natural content width
      var wasStatic = carousel.classList.contains("wv2-carousel--static");
      carousel.classList.remove("wv2-carousel--static");
      var fits = track.scrollWidth <= track.clientWidth;
      carousel.classList.toggle("wv2-carousel--static", fits);
      if (!fits && wasStatic) {
        // Re-center after switching back to carousel mode
        requestAnimationFrame(function () {
          var initIdx = carousel.dataset.initialIndex != null ? parseInt(carousel.dataset.initialIndex, 10) : Math.floor(items.length / 2);
          var item = items[initIdx];
          var itemRect = item.getBoundingClientRect();
          var trackRect = track.getBoundingClientRect();
          track.scrollLeft = track.scrollLeft + itemRect.left - trackRect.left - (trackRect.width - itemRect.width) / 2;
          syncDots();
        });
      }
    }

    requestAnimationFrame(function () {
      var initIdx = carousel.dataset.initialIndex != null ? parseInt(carousel.dataset.initialIndex, 10) : Math.floor(items.length / 2);
      var item = items[initIdx];
      var itemRect = item.getBoundingClientRect();
      var trackRect = track.getBoundingClientRect();
      track.scrollLeft = track.scrollLeft + itemRect.left - trackRect.left - (trackRect.width - itemRect.width) / 2;
      syncDots();
      updateStaticMode();
    });

    new ResizeObserver(updateStaticMode).observe(carousel);
  });
})();

// Header donate icon resizing logic
(function () {
  var header = document.getElementById("header");
  if (!header) return;
  var signinLink = header.querySelector(".signin_link");
  var orSpan = signinLink && signinLink.nextElementSibling && signinLink.nextElementSibling.tagName === "SPAN"
    ? signinLink.nextElementSibling
    : null;
  function updateDonateText() {
    // Reset
    header.classList.remove("header-donate-icon-only");
    if (signinLink) signinLink.style.display = "";
    if (orSpan) orSpan.style.display = "";
    // Step 1: hide signin + or if overflowing
    if (header.scrollWidth > header.clientWidth) {
      if (signinLink) signinLink.style.display = "none";
      if (orSpan) orSpan.style.display = "none";
    }
    // Step 2: shrink donate button if still overflowing
    if (header.scrollWidth > header.clientWidth) {
      header.classList.add("header-donate-icon-only");
    }
  }
  new ResizeObserver(updateDonateText).observe(header);
  updateDonateText();
})();

// Override standard details functionality of setting display: none when closing summary
(function () {
  document.querySelectorAll(".wv2-faq details").forEach(function (el) {
    el.addEventListener("click", function (e) {
      if (!el.open) return;
      e.preventDefault();
      el.classList.add("closing");
      el.addEventListener("transitionend", function () {
        el.classList.remove("closing");
        el.removeAttribute("open");
      }, { once: true });
    });
  });
})();

// Calculate content height for FAQ animations
document.querySelectorAll('.wv2-faq details').forEach(detail => {
  const p = detail.querySelector('p');
  if (p) detail.style.setProperty('--content-height', `-${p.offsetHeight}px`);
});
