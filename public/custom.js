
"#updatelink".onClick(function(event) {
  event.stop();
  this.hide();
  $('spinner').show();
  $('content').load("/update");
});