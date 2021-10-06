module Id = Pool_common.Id
module Location = Entity_location

module Title = struct
  type t = string [@@deriving eq, show]

  let value m = m

  let create title =
    if String.length title <= 0 then Error "Invalid title!" else Ok title
  ;;
end

module Description = struct
  type t = string [@@deriving eq, show]

  let value m = m

  let create description =
    if String.length description <= 0
    then Error "Invalid description!"
    else Ok description
  ;;
end

module ExperimentDate = struct
  type t = Ptime.t [@@deriving eq, show]

  let create date =
    let open CCResult.Infix in
    let experiment_date =
      date |> Ptime.of_date |> CCOpt.to_result "Invalid experiment date"
    in
    let now = () |> Ptime_clock.now in
    let compare experiment_date =
      match Ptime.is_earlier experiment_date ~than:now with
      | true -> Error "Experiment Date cannot be in the past"
      | false -> Ok experiment_date
    in
    experiment_date >>= compare
  ;;

  let value m = m
end

type t =
  { id : Id.t
  ; title : Title.t
  ; description : Description.t
  ; created_at : Ptime.t
  ; updated_at : Ptime.t
  }
[@@deriving eq, show]

let create ?id title description () =
  { id = id |> Option.value ~default:(Id.create ())
  ; title
  ; description
  ; created_at = Ptime_clock.now ()
  ; updated_at = Ptime_clock.now ()
  }
;;
