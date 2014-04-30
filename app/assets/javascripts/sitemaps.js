(function($) { 
  function attach_validation_handlers() {
    $('.validate-resource').on('click', function(e) {
      e.preventDefault();
      var $btn = $(this);
      $btn.tooltip('destroy');
      
      if ($btn.is('.disabled')) {
        return;
      }
      
      $(this).removeClass('btn-success');
      $(this).removeClass('btn-danger');
      $(this).addClass('disabled');
      $btn.find('.text').html('processing');
      
      $btn.find('.glyphicon').removeClass('glyphicon-transfer');
      $btn.find('.glyphicon').removeClass('glyphicon-remove');
      $btn.find('.glyphicon').removeClass('glyphicon-ok');
      $btn.find('.glyphicon').addClass('glyphicon-asterisk');
      
      var jqxhr = $.get( $btn.attr('href'), function() {
        $btn.find('.glyphicon').removeClass('glyphicon-asterisk');
        $btn.find('.glyphicon').removeClass('glyphicon-remove');
        $btn.find('.glyphicon').addClass('glyphicon-ok');
        $btn.addClass('btn-success');
        $btn.find('.text').html('valid');
      })
        .fail(function(data) {
          $btn.find('.glyphicon').removeClass('glyphicon-asterisk');
          $btn.find('.glyphicon').removeClass('glyphicon-ok');
          $btn.find('.glyphicon').addClass('glyphicon-remove');
          $btn.addClass('btn-danger');
          $btn.find('.text').html('invalid');
          $btn.tooltip({ title: data.responseText, placement: 'auto right', trigger: 'hover', delay: { show: 50, hide: 5000}});
          $btn.tooltip('show');
        })
        .always(function() {
          $btn.removeClass('disabled');
        });
      
    });
  }
  
    $(document).ready(attach_validation_handlers);
    $(document).on("page:load", attach_validation_handlers);
})(jQuery);
