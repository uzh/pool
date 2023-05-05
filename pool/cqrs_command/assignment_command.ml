module Conformist = Pool_common.Utils.PoolConformist

let src = Logs.Src.create "assignment.cqrs"

let assignment_effect action id =
  let open Guard in
  ValidationSet.One
    ( action
    , TargetSpec.Id (`Assignment, id |> Guard.Uuid.target_of Assignment.Id.value)
    )
;;

(* TODO: Remove or move to entity *)
module IncrementParticipationCount = struct
  type t = bool

  let create b = b
end

module Create : sig
  include Common.CommandSig

  type t =
    { contact : Contact.t
    ; sessions : Session.Public.t list
    ; experiment : Experiment.Public.t
    }

  val handle
    :  ?tags:Logs.Tag.set
    -> t
    -> Sihl_email.t
    -> bool
    -> (Pool_event.t list, Pool_common.Message.error) result

  val effects : Experiment.Id.t -> Guard.ValidationSet.t
end = struct
  type t =
    { contact : Contact.t
    ; sessions : Session.Public.t list
    ; experiment : Experiment.Public.t
    }

  let handle
    ?(tags = Logs.Tag.empty)
    (command : t)
    confirmation_email
    already_enrolled
    =
    Logs.info ~src (fun m -> m "Handle command Create" ~tags);
    let open CCResult in
    if already_enrolled
    then Error Pool_common.Message.(AlreadySignedUpForExperiment)
    else
      let* () =
        command.experiment.Experiment.Public.direct_registration_disabled
        |> Experiment.DirectRegistrationDisabled.value
        |> Utils.bool_to_result_not
             Pool_common.Message.(DirectRegistrationIsDisabled)
      in
      let* (_ : unit list) =
        command.sessions
        |> CCList.map Session.Public.assignment_creatable
        |> CCList.all_ok
      in
      let create_events =
        command.sessions
        |> CCList.map (fun session ->
             let create =
               Assignment.
                 { contact = command.contact
                 ; session_id = session.Session.Public.id
                 }
             in
             Assignment.Created create |> Pool_event.assignment)
      in
      let contact_event =
        Contact_counter.update_on_session_signup
          command.contact
          command.sessions
        |> Contact.updated
        |> Pool_event.contact
      in
      Ok
        (create_events
         @ [ contact_event; Email.Sent confirmation_email |> Pool_event.email ]
        )
  ;;

  let effects = Assignment.Guard.Access.create
end

module Cancel : sig
  include Common.CommandSig with type t = Assignment.t list * Session.t

  val effects : Experiment.Id.t -> Assignment.Id.t -> Guard.ValidationSet.t
end = struct
  type t = Assignment.t list * Session.t

  let handle ?(tags = Logs.Tag.empty) (assignments, session)
    : (Pool_event.t list, Pool_common.Message.error) result
    =
    let open CCResult in
    Logs.info ~src (fun m -> m "Handle command Cancel" ~tags);
    let contact =
      assignments
      |> CCList.hd
      |> fun ({ Assignment.contact; _ } : Assignment.t) -> contact
    in
    let* (_ : unit list) =
      let* () = Session.assignments_cancelable session in
      CCList.map Assignment.is_cancellable assignments |> CCList.all_ok
    in
    let cancel_events =
      CCList.map
        (fun assignment ->
          Assignment.Canceled assignment |> Pool_event.assignment)
        assignments
    in
    let decrease_assignment_count =
      Contact_counter.update_on_assignment_cancellation assignments contact
      |> Contact.updated
      |> Pool_event.contact
    in
    Ok (cancel_events @ [ decrease_assignment_count ])
  ;;

  let effects = Assignment.Guard.Access.delete
end

module SetAttendance : sig
  type t =
    (Assignment.t
    * Assignment.NoShow.t
    * Assignment.Participated.t
    * IncrementParticipationCount.t
    * Assignment.t list option)
    list

  val handle
    :  ?tags:Logs.Tag.set
    -> Session.t
    -> t
    -> (Pool_event.t list, Pool_common.Message.error) result

  val effects : Experiment.Id.t -> Session.Id.t -> Guard.ValidationSet.t
end = struct
  type t =
    (Assignment.t
    * Assignment.NoShow.t
    * Assignment.Participated.t
    * IncrementParticipationCount.t
    * Assignment.t list option)
    list

  let handle ?(tags = Logs.Tag.empty) (session : Session.t) (command : t) =
    Logs.info ~src (fun m -> m "Handle command SetAttendance" ~tags);
    let open CCResult in
    let open Assignment in
    let open Session in
    let* () = Session.is_closable session in
    CCList.fold_left
      (fun events participation ->
        events
        >>= fun events ->
        participation
        |> fun ( ({ contact; _ } as assignment : Assignment.t)
               , no_show
               , participated
               , increment_num_participaton
               , follow_ups ) ->
        let open Contact in
        let cancel_followups =
          NoShow.value no_show || not (Participated.value participated)
        in
        let* () = attendance_settable assignment in
        let* contact =
          Contact_counter.update_on_session_closing
            contact
            no_show
            participated
            increment_num_participaton
        in
        let num_assignments_decrement, mark_as_deleted =
          match cancel_followups, follow_ups with
          | true, Some follow_ups ->
            let num_assignments =
              follow_ups
              |> CCFun.(
                   CCList.filter (fun assignment ->
                     CCOption.is_none assignment.Assignment.canceled_at)
                   %> CCList.length)
            in
            let marked_as_deleted =
              follow_ups
              |> CCList.map CCFun.(markedasdeleted %> Pool_event.assignment)
            in
            num_assignments, marked_as_deleted
          | _, _ -> 0, []
        in
        let contact =
          { contact with
            num_assignments =
              Contact.NumberOfAssignments.decrement
                contact.num_assignments
                num_assignments_decrement
          }
        in
        let contact_events =
          (Contact.Updated contact |> Pool_event.contact) :: mark_as_deleted
        in
        events
        @ ((Assignment.AttendanceSet (assignment, no_show, participated)
            |> Pool_event.assignment)
           :: contact_events)
        |> CCResult.return)
      (Ok [ Closed session |> Pool_event.session ])
      command
  ;;

  let effects = Session.Guard.Access.update
end

module CreateFromWaitingList : sig
  include Common.CommandSig

  type t =
    { sessions : Session.t list
    ; waiting_list : Waiting_list.t
    ; already_enrolled : bool
    }

  val handle
    :  ?tags:Logs.Tag.set
    -> t
    -> Sihl_email.t
    -> (Pool_event.t list, Pool_common.Message.error) result

  val effects : Experiment.Id.t -> Pool_common.Id.t -> Guard.ValidationSet.t
end = struct
  type t =
    { sessions : Session.t list
    ; waiting_list : Waiting_list.t
    ; already_enrolled : bool
    }

  let handle ?(tags = Logs.Tag.empty) (command : t) confirmation_email =
    Logs.info ~src (fun m -> m "Handle command CreateFromWaitingList" ~tags);
    let open CCResult in
    if command.already_enrolled
    then Error Pool_common.Message.(AlreadySignedUpForExperiment)
    else
      let* () =
        command.waiting_list.Waiting_list.experiment
        |> Experiment.registration_disabled_value
        |> Utils.bool_to_result_not Pool_common.Message.(RegistrationDisabled)
      in
      let* (_ : unit list) =
        command.sessions
        |> CCList.map Session.assignment_creatable
        |> CCList.all_ok
      in
      let contact = command.waiting_list.Waiting_list.contact in
      let create_events =
        command.sessions
        |> CCList.map (fun session ->
             let create =
               Assignment.{ contact; session_id = session.Session.id }
             in
             Assignment.Created create |> Pool_event.assignment)
      in
      Ok
        (create_events
         @ [ Contact_counter.update_on_assignment_from_waiting_list
               contact
               command.sessions
             |> Contact.updated
             |> Pool_event.contact
           ; Email.Sent confirmation_email |> Pool_event.email
           ])
  ;;

  let effects experiment_id waiting_list_id =
    let open Guard in
    ValidationSet.(
      And
        [ Waiting_list.Guard.Access.update experiment_id waiting_list_id
        ; Assignment.Guard.Access.create experiment_id
        ])
  ;;
end

module MarkAsDeleted : sig
  include Common.CommandSig with type t = Contact.t * Assignment.t list * bool

  val effects : Experiment.Id.t -> Assignment.Id.t -> Guard.ValidationSet.t
end = struct
  type t = Contact.t * Assignment.t list * bool

  let handle
    ?(tags = Logs.Tag.empty)
    (contact, assignments, decrement_participation_count)
    : (Pool_event.t list, Pool_common.Message.error) result
    =
    let open Assignment in
    let open CCResult in
    Logs.info ~src (fun m -> m ~tags "Handle command MarkAsDeleted");
    let* (_ : unit list) =
      CCList.map is_deletable assignments |> CCList.all_ok
    in
    let mark_as_deleted =
      CCList.map CCFun.(markedasdeleted %> Pool_event.assignment) assignments
    in
    let contact_updated =
      Contact_counter.update_on_assignment_deletion
        assignments
        contact
        decrement_participation_count
      |> Contact.updated
      |> Pool_event.contact
    in
    Ok (contact_updated :: mark_as_deleted)
  ;;

  let effects = Assignment.Guard.Access.delete
end
