# frozen_string_literal: true

module RustRadio
  # Posts to Facebook every time a new show starts.
  #
  # TODO: Re-implement Facebook posting. The fb_graph2 gem was removed, so this
  # class is currently a no-op placeholder that keeps the existing interface.
  class FacebookPoster
    def initialize(_config); end

    def show_update(_show_info); end
  end
end
