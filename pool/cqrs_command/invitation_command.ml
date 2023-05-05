let src = Logs.Src.create "invitation.cqrs"

module Create : sig
  include Common.CommandSig

  type t =
    { experiment : Experiment.t
    ; contacts : Contact.t list
    ; invited_contacts : Pool_common.Id.t list
    ; create_message :
        Contact.t -> (Sihl_email.t, Pool_common.Message.error) result
    }

  val handle
    :  ?tags:Logs.Tag.set
    -> t
    -> (Pool_event.t list, Pool_common.Message.error) result

  val effects : Experiment.Id.t -> Guard.ValidationSet.t
end = struct
  type t =
    { experiment : Experiment.t
    ; contacts : Contact.t list
    ; invited_contacts : Pool_common.Id.t list
    ; create_message :
        Contact.t -> (Sihl_email.t, Pool_common.Message.error) result
    }

  let handle
    ?(tags = Logs.Tag.empty)
    { invited_contacts; contacts; create_message; experiment }
    =
    Logs.info ~src (fun m -> m "Handle command Create" ~tags);
    let open CCResult in
    let errors, contacts =
      CCList.partition
        (fun contact ->
          CCList.mem
            ~eq:Pool_common.Id.equal
            (Contact.id contact)
            invited_contacts)
        contacts
    in
    let errors = CCList.map CCFun.(Contact.id %> Pool_common.Id.value) errors in
    let emails = CCList.map create_message contacts in
    if CCList.is_empty errors |> not
    then Error Pool_common.Message.(AlreadyInvitedToExperiment errors)
    else (
      match CCList.all_ok emails with
      | Ok emails when CCList.is_empty emails -> Ok []
      | Ok emails ->
        Ok
          ([ Invitation.Created (contacts, experiment) |> Pool_event.invitation
           ; Email.BulkSent emails |> Pool_event.email
           ]
           @ (contacts
              |> CCList.map
                   CCFun.(
                     Contact_counter.update_on_invitation_sent
                     %> Contact.updated
                     %> Pool_event.contact)))
      | Error err -> Error err)
  ;;

  let effects = Invitation.Guard.Access.create
end

module Resend : sig
  include Common.CommandSig

  type t =
    { invitation : Invitation.t
    ; experiment : Experiment.t
    }

  val handle
    :  ?tags:Logs.Tag.set
    -> Sihl_email.t
    -> t
    -> (Pool_event.t list, Pool_common.Message.error) result

  val effects : Experiment.Id.t -> Pool_common.Id.t -> Guard.ValidationSet.t
end = struct
  type t =
    { invitation : Invitation.t
    ; experiment : Experiment.t
    }

  let handle ?(tags = Logs.Tag.empty) invitation_email (command : t) =
    Logs.info ~src (fun m -> m "Handle command Resend" ~tags);
    Ok
      [ Invitation.Resent command.invitation |> Pool_event.invitation
      ; Email.Sent invitation_email |> Pool_event.email
      ]
  ;;

  let effects = Invitation.Guard.Access.update
end
