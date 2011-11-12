$(function() {
  $("div.entries").sortable({
    containment: $("div.entries"),
    opacity: 0.75,
    stop: function(event, ui) {
      var item = ui.item;

      var entryId = item.attr("data-entry-id");
      var previous = item.prev(".entry");

      if (previous.length == 0) {
        $.post("/move/" + entryId + "/to_top", function() {
          location.reload();
        });
      } else {
        var prevEntryId = previous.attr("data-entry-id");
        $.post("/move/" + entryId + "/below/" + prevEntryId, function() {
          location.reload();
        });
      }
    }
  });
});
