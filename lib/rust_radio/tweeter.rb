# frozen_string_literal: true

module RustRadio
  # Updates Twitter/X every time a new show starts.
  #
  # TODO: Re-implement posting to Twitter/X. The twitter gem was removed, so
  # this class is currently a no-op placeholder that keeps the existing interface.
  class Tweeter
    def initialize(_config); end

    def show_update(_show_info); end
  end
end
