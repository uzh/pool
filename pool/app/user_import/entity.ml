open Pool_common.Message

module Token = struct
  include Pool_common.Model.String

  let field = Field.Token
  let schema () = schema field ()
end

module ConfirmedAt = struct
  include Pool_common.Model.Ptime

  let create m = Ok m
  let schema = schema Field.ConfirmedAt create
end

module NotifiedAt = struct
  include Pool_common.Model.Ptime

  let create m = Ok m
  let schema = schema Field.NotifiedAt create
end

module ReminderCount = struct
  include Pool_common.Model.Integer

  let init = 0
  let field = Field.ReminderCount
  let create count = if count >= 0 then Ok count else Error NegativeAmount
  let schema = schema field create
  let increment m = m + 1
end

module LastRemindedAt = struct
  include Pool_common.Model.Ptime

  let create m = Ok m
  let schema = schema Field.LastRemindedAt create
end

type t =
  { user_uuid : Pool_common.Id.t
  ; token : Token.t
  ; confirmed_at : ConfirmedAt.t option
  ; notified_at : NotifiedAt.t option
  ; reminder_count : ReminderCount.t
  ; last_reminded_at : LastRemindedAt.t option
  ; created_at : Pool_common.CreatedAt.t
  ; updated_at : Pool_common.UpdatedAt.t
  }
[@@deriving eq, show]
