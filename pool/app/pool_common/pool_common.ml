include Entity
module Message = Entity_message
module I18n = Entity_i18n
module Repo = Repo

module Utils = struct
  include Pool_common_utils
  include Utils_to_string
  module Time = Utils_time
end
