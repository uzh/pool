module Database = Pool_database
open Entity

let src = Logs.Src.create "user_import.event"

type event = Confirmed of t [@@deriving eq, show]

let handle_event pool : event -> unit Lwt.t = function
  | Confirmed m ->
    { m with confirmed_at = ConfirmedAt.(() |> create_now |> CCOption.return) }
    |> Repo.update pool
  [@@deriving eq, show]
;;

let show_event = Format.asprintf "%a" pp_event
