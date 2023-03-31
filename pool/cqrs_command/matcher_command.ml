let get_or_failwith = Pool_common.Utils.get_or_failwith

module Run : sig
  type t =
    { mailing : Mailing.t
    ; experiment : Experiment.t
    ; contacts : Contact.t list
    ; create_message :
        Contact.t -> (Sihl_email.t, Pool_common.Message.error) result
    }

  val handle : t list -> (Pool_event.t list, Pool_common.Message.error) result
  val effects : unit -> Guard.ValidationSet.t
end = struct
  type t =
    { mailing : Mailing.t
    ; experiment : Experiment.t
    ; contacts : Contact.t list
    ; create_message :
        Contact.t -> (Sihl_email.t, Pool_common.Message.error) result
    }

  let handle mailings =
    let open CCFun.Infix in
    let open CCList in
    mailings
    |> map (fun { experiment; contacts; create_message; _ } ->
         let open Invitation_command.Create in
         { experiment; contacts; invited_contacts = []; create_message }
         |> handle)
       %> all_ok
       %> CCResult.map flatten
  ;;

  let effects () = failwith "Background command: unused effect"
end
