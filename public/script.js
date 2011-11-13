$(function() {
  $(".entries").sortable({
    connectWith: ".entries",
    opacity: 0.75,
    stop: function(event, ui) {
      var item = ui.item;

      var entryId = item.attr("data-entry-id");
      var previousItem = item.prev(".entry");

      if (previousItem.length == 0) {
        var box = $(item).parents(".entries");
        var previousBox = box.prev(".entries");

        if (previousBox.length == 0) {
          moveToTop(entryId);
        } else {
          var otherEntryId = previousBox.find(".entry:last").attr("data-entry-id");
          moveBelow(entryId, otherEntryId);
        }
      } else {
        var otherEntryId = previousItem.attr("data-entry-id");
        moveBelow(entryId, otherEntryId);
      }
    }
  });
});

function moveToTop(entryId) {
  $.post("/move/" + entryId + "/to_top", function() {
    location.reload();
  });
}

function moveBelow(entryId, otherEntryId) {
  $.post("/move/" + entryId + "/below/" + otherEntryId, function() {
    location.reload();
  });
}
