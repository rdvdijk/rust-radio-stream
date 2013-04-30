// make list sortable
$(function() {
  $(".entries").sortable({
    connectWith: ".entries",
    opacity: 0.75,
    stop: function(event, ui) {
      var item = ui.item;

      var entryId = item.attr("data-entry-id");
      var previousItem = item.prev(".entry")

      if (previousItem.length == 0) { // no previous item (= top of the list)
        moveToTop(entryId);
      } else {
        var otherEntryId = previousItem.attr("data-entry-id");
        moveBelow(entryId, otherEntryId);
      }
    }
  });
});

// move to the top
$(function() {
  $(".entry .to-top").click(function() {
    item = $(this).parents(".entry")
    var entryId = item.attr("data-entry-id");
    moveToTop(entryId);
  });
});

// remove entry
$(function() {
  $(".entry .remove").click(function() {
    item = $(this).parents(".entry")
    var entryId = item.attr("data-entry-id");
    remove(entryId);
  });
});

// add show
$(function() {
  $(".show .add").click(function() {
    item = $(this).parents(".show")
    var showId = item.attr("data-show-id");
    add(showId);
  });
});

// Server interactions:
function moveToTop(entryId) {
  $.post("/move/" + entryId + "/to_top", function() {
    reloadPage();
  });
}

function moveBelow(entryId, otherEntryId) {
  $.post("/move/" + entryId + "/below/" + otherEntryId, function() {
    reloadPage();
  });
}

function remove(entryId) {
  $.post("/remove/" + entryId, function() {
    reloadPage();
  });
}

function add(showId) {
  $.post("/add/" + showId, function() {
    reloadPage();
  });
}

function reloadPage() {
  location.reload();
}
