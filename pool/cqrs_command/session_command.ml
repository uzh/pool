module Conformist = Pool_common.Utils.PoolConformist
module Reminder = Pool_common.Reminder
module TimeUnit = Pool_common.Model.TimeUnit
open CCFun

type reschedule =
  { start : Session.Start.t
  ; duration : int
  ; duration_unit : TimeUnit.t
  }

let src = Logs.Src.create "session.cqrs"

let command
  start
  duration
  duration_unit
  internal_description
  public_description
  max_participants
  min_participants
  overbook
  email_reminder_lead_time
  email_reminder_lead_time_unit
  text_message_reminder_lead_time
  text_message_reminder_lead_time_unit
  : Session.base
  =
  Session.
    { start
    ; duration
    ; duration_unit
    ; internal_description
    ; public_description
    ; max_participants
    ; min_participants
    ; overbook
    ; email_reminder_lead_time
    ; email_reminder_lead_time_unit
    ; text_message_reminder_lead_time
    ; text_message_reminder_lead_time_unit
    }
;;

let schema =
  let open Pool_common in
  Conformist.(
    make
      Field.
        [ Session.Start.schema ()
        ; Session.Duration.integer_schema ()
        ; TimeUnit.named_schema Session.Duration.name ()
        ; Conformist.optional @@ Session.InternalDescription.schema ()
        ; Conformist.optional @@ Session.PublicDescription.schema ()
        ; Session.ParticipantAmount.schema Message.Field.MaxParticipants
        ; Session.ParticipantAmount.schema Message.Field.MinParticipants
        ; Session.ParticipantAmount.schema Message.Field.Overbook
        ; Conformist.optional @@ Reminder.EmailLeadTime.integer_schema ()
        ; Conformist.optional
          @@ TimeUnit.named_schema Reminder.EmailLeadTime.name ()
        ; Conformist.optional @@ Reminder.TextMessageLeadTime.integer_schema ()
        ; Conformist.optional
          @@ TimeUnit.named_schema Reminder.TextMessageLeadTime.name ()
        ]
      command)
;;

let decode_time_durations
  { Session.duration
  ; duration_unit
  ; email_reminder_lead_time
  ; email_reminder_lead_time_unit
  ; text_message_reminder_lead_time
  ; text_message_reminder_lead_time_unit
  ; _
  }
  =
  let open CCResult in
  let open Pool_common in
  let* duration = Session.Duration.of_int duration duration_unit in
  let* email_lead_time =
    Reminder.EmailLeadTime.of_int_opt
      email_reminder_lead_time
      email_reminder_lead_time_unit
  in
  let* text_message_lead_time =
    Reminder.TextMessageLeadTime.of_int_opt
      text_message_reminder_lead_time
      text_message_reminder_lead_time_unit
  in
  Ok (duration, email_lead_time, text_message_lead_time)
;;

(* If session is follow-up, make sure it's later than parent *)
let starts_after_parent parent_session start =
  let open Session in
  CCOption.map_or
    ~default:false
    (fun (s : Session.t) ->
      Ptime.is_earlier ~than:(Start.value s.start) (Start.value start))
    parent_session
;;

let validate_start follow_up_sessions parent_session start =
  let open Session in
  (* If session has follow-ups, make sure they are all later *)
  let starts_before_followups =
    CCList.exists
      (fun (follow_up : Session.t) ->
        Ptime.is_earlier ~than:(Start.value start) (Start.value follow_up.start))
      follow_up_sessions
  in
  if starts_after_parent parent_session start || starts_before_followups
  then Error Pool_common.Message.FollowUpIsEarlierThanMain
  else Ok ()
;;

let run_validations validations =
  let open CCResult in
  validations
  |> CCList.filter fst
  |> CCList.map (fun (_, err) -> Error err)
  |> flatten_l
  |> map ignore
;;

module Create : sig
  include Common.CommandSig with type t = Session.base

  val handle
    :  ?tags:Logs.Tag.set
    -> ?parent_session:Session.t
    -> ?session_id:Session.Id.t
    -> Experiment.t
    -> Pool_location.t
    -> t
    -> (Pool_event.t list, Conformist.error_msg) result

  val decode : Conformist.input -> (t, Conformist.error_msg) result
  val effects : Experiment.Id.t -> Guard.ValidationSet.t
end = struct
  type t = Session.base

  let schema = schema

  let handle
    ?(tags = Logs.Tag.empty)
    ?parent_session
    ?session_id
    experiment
    location
    (Session.
       { start
       ; internal_description
       ; public_description
       ; max_participants
       ; min_participants
       ; overbook
       ; _
       } as command :
      Session.base)
    =
    Logs.info ~src (fun m -> m "Handle command Create" ~tags);
    let open CCResult in
    let validations =
      [ ( starts_after_parent parent_session start
        , Pool_common.Message.FollowUpIsEarlierThanMain )
      ; ( max_participants < min_participants
        , Pool_common.Message.(
            Smaller (Field.MaxParticipants, Field.MinParticipants)) )
      ]
    in
    let* () = run_validations validations in
    let* duration, email_reminder_lead_time, text_message_reminder_lead_time =
      decode_time_durations command
    in
    let session =
      Session.create
        ?id:session_id
        ?internal_description
        ?public_description
        ?email_reminder_lead_time
        ?follow_up_to:(parent_session |> CCOption.map (fun s -> s.Session.id))
        ?text_message_reminder_lead_time
        start
        duration
        location
        max_participants
        min_participants
        overbook
        experiment
    in
    Ok [ Session.Created session |> Pool_event.session ]
  ;;

  let decode data =
    Conformist.decode_and_validate schema data
    |> CCResult.map_err Pool_common.Message.to_conformist_error
  ;;

  let effects exp_id = Session.Guard.Access.create exp_id
end

module Duplicate : sig
  include Common.CommandSig with type t = (string * string list) list

  val handle
    :  ?tags:Logs.Tag.set
    -> ?parent_session:Session.t
    -> Session.t
    -> Session.t list
    -> t
    -> (Pool_event.t list, Conformist.error_msg) result

  val effects : Experiment.Id.t -> Guard.ValidationSet.t
end = struct
  type t = (string * string list) list

  let parse_urlencoded urlencoded
    : ((int, (Session.Id.t * Session.Start.t) list) CCList.Assoc.t, 'b) Result.t
    =
    let error = Pool_common.Message.InvalidRequest in
    let open CCResult in
    let start_of_string str =
      Pool_common.Utils.Time.parse_time str >|= Session.Start.create
    in
    let parse_row id group value =
      let to_result = CCOption.to_result in
      let* group = CCInt.of_string group |> to_result error in
      let* start =
        CCList.head_opt value |> to_result error >>= start_of_string
      in
      Ok (group, (Session.Id.of_string id, start))
    in
    urlencoded
    |> CCList.fold_left
         (fun acc (key, value) ->
           let open CCString in
           match acc with
           | Error _ -> acc
           | Ok (acc : (int * (Session.Id.t * Session.Start.t) list) list) ->
             key
             |> replace ~which:`Right ~sub:"]" ~by:""
             |> split ~by:"["
             |> (function
              | [ id; group ] ->
                parse_row id group value
                >|= fun (group, data) ->
                let eq = CCInt.equal in
                let current =
                  CCList.assoc_opt ~eq group acc |> CCOption.value ~default:[]
                in
                CCList.Assoc.set ~eq group (data :: current) acc
              | _ -> Ok acc))
         (Ok [])
  ;;

  let handle
    ?(tags = Logs.Tag.empty)
    ?parent_session
    session
    followups
    (urlencoded : t)
    =
    let open CCResult in
    Logs.info ~src (fun m -> m "Handle command Duplicate" ~tags);
    let validate_and_merge_session
      ?parent
      { Session.internal_description
      ; public_description
      ; email_reminder_lead_time
      ; text_message_reminder_lead_time
      ; duration
      ; location
      ; max_participants
      ; min_participants
      ; overbook
      ; experiment
      ; _
      }
      start
      =
      if starts_after_parent parent start
      then Error Pool_common.Message.FollowUpIsEarlierThanMain
      else
        Ok
          (Session.create
             ?follow_up_to:(parent |> CCOption.map (fun { Session.id; _ } -> id))
             ?internal_description
             ?public_description
             ?email_reminder_lead_time
             ?text_message_reminder_lead_time
             start
             duration
             location
             max_participants
             min_participants
             overbook
             experiment)
    in
    let find_start session_id data
      : (Session.Start.t, Pool_common.Message.error) Result.t
      =
      CCList.find_opt (fun (id, _) -> Session.Id.equal id session_id) data
      |> CCOption.to_result Pool_common.Message.(Missing Field.Start)
      >|= snd
    in
    let created session = Session.Created session |> Pool_event.session in
    let build_session ?parent form_data session =
      find_start session.Session.id form_data
      >>= validate_and_merge_session ?parent session
    in
    urlencoded
    |> parse_urlencoded
    >>= CCList.fold_left
          (fun acc (_, form_data) ->
            acc
            >>= fun acc ->
            let sessions =
              let* parent_clone =
                build_session ?parent:parent_session form_data session
              in
              let* followup_clones =
                let open CCList in
                followups
                >|= build_session ~parent:parent_clone form_data
                |> all_ok
              in
              Ok (parent_clone :: followup_clones)
            in
            sessions >|= CCList.map created >|= CCList.append acc)
          (Ok [])
  ;;

  let effects exp_id = Session.Guard.Access.create exp_id
end

module Update : sig
  include Common.CommandSig with type t = Session.base

  val handle
    :  ?tags:Logs.Tag.set
    -> ?parent_session:Session.t
    -> Session.t list
    -> Session.t
    -> Pool_location.t
    -> t
    -> (Pool_event.t list, Conformist.error_msg) result

  val decode
    :  (string * string list) list
    -> (t, Pool_common.Message.error) result

  val effects : Experiment.Id.t -> Session.Id.t -> Guard.ValidationSet.t
end = struct
  type t = Session.base

  let handle
    ?(tags = Logs.Tag.empty)
    ?parent_session
    follow_up_sessions
    session
    location
    (Session.
       { start
       ; internal_description
       ; public_description
       ; max_participants
       ; min_participants
       ; overbook
       ; _
       } as command :
      Session.base)
    =
    Logs.info ~src (fun m -> m "Handle command Update" ~tags);
    let open Session in
    let open CCResult in
    let open Pool_common.Message in
    let* duration, email_reminder_lead_time, text_message_reminder_lead_time =
      decode_time_durations command
    in
    let* () =
      match Session.has_assignments session with
      | false -> Ok ()
      | true ->
        let error field = Error (CannotBeUpdated field) in
        let* () =
          if Start.equal session.start start then Ok () else error Field.Start
        in
        if Duration.equal session.duration duration
        then Ok ()
        else error Field.Start
    in
    let* () = validate_start follow_up_sessions parent_session start in
    let* () =
      if max_participants < min_participants
      then Error (Smaller (Field.MaxParticipants, Field.MinParticipants))
      else Ok ()
    in
    let session =
      Session.
        { session with
          start
        ; duration
        ; internal_description
        ; public_description
        ; location
        ; max_participants
        ; min_participants
        ; overbook
        ; email_reminder_lead_time
        ; text_message_reminder_lead_time
        }
    in
    Ok [ Session.Updated session |> Pool_event.session ]
  ;;

  let decode data =
    Conformist.decode_and_validate schema data
    |> CCResult.map_err Pool_common.Message.to_conformist_error
  ;;

  let effects exp_id = Session.Guard.Access.update exp_id
end

module Reschedule : sig
  include Common.CommandSig with type t = reschedule

  val handle
    :  ?tags:Logs.Tag.set
    -> ?parent_session:Session.t
    -> Session.t list
    -> Session.t
    -> Assignment.t list
    -> (Contact.t
        -> Session.Start.t
        -> Session.Duration.t
        -> (Email.job, Pool_common.Message.error) result)
    -> t
    -> (Pool_event.t list, Conformist.error_msg) result

  val decode
    :  (string * string list) list
    -> (t, Pool_common.Message.error) result

  val effects : Experiment.Id.t -> Session.Id.t -> Guard.ValidationSet.t
end = struct
  type t = reschedule

  let command start duration duration_unit = { start; duration; duration_unit }

  let schema =
    Conformist.(
      make
        Field.
          [ Session.Start.schema ()
          ; Session.Duration.integer_schema ()
          ; TimeUnit.named_schema Session.Duration.name ()
          ]
        command)
  ;;

  let handle
    ?(tags = Logs.Tag.empty)
    ?parent_session
    follow_up_sessions
    session
    assignments
    create_message
    ({ start; duration; duration_unit } : t)
    =
    Logs.info ~src (fun m -> m "Handle command Reschedule" ~tags);
    let open CCResult in
    let* () = validate_start follow_up_sessions parent_session start in
    let* duration = Session.Duration.of_int duration duration_unit in
    let* () =
      if Ptime.is_earlier
           ~than:(Ptime_clock.now ())
           (start |> Session.Start.value)
      then Error Pool_common.Message.TimeInPast
      else Ok ()
    in
    let* emails =
      let open Assignment in
      assignments
      |> CCList.map (fun ({ contact; _ } : t) ->
        create_message contact start duration)
      |> CCResult.flatten_l
    in
    Ok
      ((Session.Rescheduled (session, { Session.start; duration })
        |> Pool_event.session)
       ::
       (if emails |> CCList.is_empty |> not
        then [ Email.BulkSent emails |> Pool_event.email ]
        else []))
  ;;

  let decode data =
    Conformist.decode_and_validate schema data
    |> CCResult.map_err Pool_common.Message.to_conformist_error
  ;;

  let effects exp_id = Session.Guard.Access.update exp_id
end

module Delete : sig
  include Common.CommandSig

  type t =
    { session : Session.t
    ; follow_ups : Session.t list
    ; templates : Message_template.t list
    }

  val handle
    :  ?tags:Logs.Tag.set
    -> t
    -> (Pool_event.t list, Pool_common.Message.error) result

  val effects : Experiment.Id.t -> Session.Id.t -> Guard.ValidationSet.t
end = struct
  type t =
    { session : Session.t
    ; follow_ups : Session.t list
    ; templates : Message_template.t list
    }

  let handle ?(tags = Logs.Tag.empty) { session; follow_ups; templates } =
    let open CCResult in
    Logs.info ~src (fun m -> m "Handle command Delete" ~tags);
    if CCList.is_empty follow_ups |> not
    then Error Pool_common.Message.SessionHasFollowUps
    else
      let* () = Session.is_deletable session in
      let delete_template =
        Message_template.deleted %> Pool_event.message_template
      in
      Ok
        ((Session.Deleted session |> Pool_event.session)
         :: (templates |> CCList.map delete_template))
  ;;

  let effects exp_id = Session.Guard.Access.delete exp_id
end

module Cancel : sig
  type t = Session.CancellationReason.t

  val handle
    :  ?tags:Logs.Tag.set
    -> Session.t list
    -> (Contact.t * Assignment.t list) list
    -> (t -> Contact.t -> (Email.job, Pool_common.Message.error) result)
    -> (t
        -> Contact.t
        -> Pool_user.CellPhone.t
        -> (Text_message.job, Pool_common.Message.error) result)
    -> Pool_common.NotifyVia.t list
    -> t
    -> (Pool_event.t list, Pool_common.Message.error) result

  val decode : Conformist.input -> (t, Conformist.error_msg) result
  val effects : Experiment.Id.t -> Session.Id.t -> Guard.ValidationSet.t
end = struct
  type t = Session.CancellationReason.t

  let handle
    ?(tags = Logs.Tag.empty)
    sessions
    (assignments : (Contact.t * Assignment.t list) list)
    email_fn
    text_message_fn
    notify_via
    (reason : t)
    =
    Logs.info ~src (fun m -> m "Handle command Cancel" ~tags);
    let open CCResult in
    let* (_ : unit list) =
      sessions |> CCList.map Session.is_cancellable |> CCList.all_ok
    in
    let* (_ : unit list) =
      let open CCList in
      sessions >|= Session.is_cancelable |> all_ok
    in
    let contact_events =
      assignments
      |> CCList.map (fun (contact, assignments) ->
        contact
        |> Contact_counter.update_on_session_cancellation assignments
        |> Contact.updated
        |> Pool_event.contact)
    in
    let* notification_events =
      let open Pool_common.NotifyVia in
      let email_event contact =
        email_fn reason contact >|= Email.sent >|= Pool_event.email
      in
      let text_msg_event contact phone_number =
        text_message_fn reason contact phone_number
        >|= Text_message.sent
        >|= Pool_event.text_message
      in
      let fallback_to_email = CCList.mem ~eq:equal Email notify_via |> not in
      match notify_via with
      | [] -> Error Pool_common.Message.(NoOptionSelected Field.NotifyVia)
      | notify_via ->
        notify_via
        |> CCList.flat_map (function
          | Email ->
            assignments |> CCList.map (fun (contact, _) -> email_event contact)
          | TextMessage ->
            assignments
            |> CCList.filter_map (fun (contact, _) ->
              match contact.Contact.cell_phone, fallback_to_email with
              | Some phone_number, (true | false) ->
                text_msg_event contact phone_number |> CCOption.return
              | None, true -> email_event contact |> CCOption.return
              | _, _ -> None))
        |> CCList.all_ok
    in
    let cancel_events =
      sessions
      |> CCList.map (fun session ->
        Session.Canceled session |> Pool_event.session)
    in
    [ notification_events; cancel_events; contact_events ]
    |> CCList.flatten
    |> CCResult.return
  ;;

  let schema =
    Conformist.(make Field.[ Session.CancellationReason.schema () ] CCFun.id)
  ;;

  let decode data =
    Conformist.decode_and_validate schema data
    |> CCResult.map_err Pool_common.Message.to_conformist_error
  ;;

  let effects exp_id = Session.Guard.Access.update exp_id
end

module Close : sig
  type t =
    (Assignment.t
    * Assignment.IncrementParticipationCount.t
    * Assignment.t list option)
      list

  val handle
    :  ?tags:Logs.Tag.set
    -> Experiment.t
    -> Session.t
    -> Tags.t list
    -> t
    -> (Pool_event.t list, Pool_common.Message.error) result

  val effects : Experiment.Id.t -> Session.Id.t -> Guard.ValidationSet.t
end = struct
  type t =
    (Assignment.t
    * Assignment.IncrementParticipationCount.t
    * Assignment.t list option)
      list

  let handle
    ?(tags = Logs.Tag.empty)
    experiment
    (session : Session.t)
    (participation_tags : Tags.t list)
    (command : t)
    =
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
               , increment_num_participaton
               , follow_ups ) ->
        let assignment, no_show, participated =
          set_close_default_values assignment
        in
        let* () =
          validate experiment assignment
          |> CCResult.map_err
               (CCFun.const Pool_common.Message.AssignmentsHaveErrors)
        in
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
          let open CCList in
          match cancel_followups, follow_ups with
          | true, Some follow_ups ->
            let num_assignments =
              follow_ups
              |> filter (fun assignment ->
                   CCOption.is_none assignment.Assignment.canceled_at)
                 %> length
            in
            let marked_as_deleted =
              follow_ups >|= markedasdeleted %> Pool_event.assignment
            in
            num_assignments, marked_as_deleted
          | _, _ -> 0, []
        in
        let contact =
          Contact.update_num_assignments
            ~step:(CCInt.neg num_assignments_decrement)
            contact
        in
        let tag_events =
          let open Tags in
          match participated |> Participated.value with
          | false -> []
          | true ->
            participation_tags
            |> CCList.map (fun (tag : t) ->
              Tagged
                Tagged.{ model_uuid = Contact.id contact; tag_uuid = tag.id }
              |> Pool_event.tags)
        in
        let contact_events =
          (Contact.Updated contact |> Pool_event.contact) :: mark_as_deleted
        in
        events
        @ ((Assignment.Updated assignment |> Pool_event.assignment)
           :: contact_events)
        @ tag_events
        |> CCResult.return)
      (Ok [ Closed session |> Pool_event.session ])
      command
  ;;

  let effects = Session.Guard.Access.close
end

module ResendReminders : sig
  include Common.CommandSig with type t = Pool_common.MessageChannel.t

  val handle
    :  ?tags:Logs.Tag.set
    -> (Assignment.t -> (Email.job, Pool_common.Message.error) result)
       * (Assignment.t
          -> Pool_user.CellPhone.t
          -> (Text_message.job, Pool_common.Message.error) result)
    -> Session.t
    -> Assignment.t list
    -> t
    -> (Pool_event.t list, Conformist.error_msg) result

  val decode : Conformist.input -> (t, Conformist.error_msg) result
  val effects : Experiment.Id.t -> Session.Id.t -> Guard.ValidationSet.t
end = struct
  type t = Pool_common.MessageChannel.t

  let schema =
    Conformist.(make Field.[ Pool_common.MessageChannel.schema () ] CCFun.id)
  ;;

  let handle
    ?(tags = Logs.Tag.empty)
    (create_email, create_text_message)
    session
    assignments
    channel
    =
    Logs.info ~src (fun m -> m "Handle command ResendReminders" ~tags);
    let open Pool_common.MessageChannel in
    let open CCResult.Infix in
    let* () = Session.reminder_resendable session in
    let* events =
      match channel with
      | Email ->
        assignments
        |> CCList.map create_email
        |> CCList.all_ok
        >|= Email.bulksent
        >|= Pool_event.email
        >|= CCList.return
        >|= CCList.cons (Session.EmailReminderSent session |> Pool_event.session)
      | TextMessage ->
        let* emails, text_messages =
          assignments
          |> CCList.fold_left
               (fun messages ({ Assignment.contact; _ } as assignment) ->
                 messages
                 >>= fun (emails, text_messages) ->
                 match contact.Contact.cell_phone with
                 | None ->
                   create_email assignment
                   >|= fun email -> email :: emails, text_messages
                 | Some cell_phone ->
                   create_text_message assignment cell_phone
                   >|= fun msg -> emails, msg :: text_messages)
               (Ok ([], []))
        in
        Ok
          [ Email.BulkSent emails |> Pool_event.email
          ; Text_message.BulkSent text_messages |> Pool_event.text_message
          ; Session.TextMsgReminderSent session |> Pool_event.session
          ]
    in
    Ok events
  ;;

  let decode data =
    Conformist.decode_and_validate schema data
    |> CCResult.map_err Pool_common.Message.to_conformist_error
  ;;

  let effects id = Session.Guard.Access.update id
end

type direct_message_email =
  { language : Pool_common.Language.t
  ; email_subject : Message_template.EmailSubject.t
  ; email_text : Message_template.EmailText.t
  ; plain_text : Message_template.PlainText.t
  }
[@@deriving eq, show]

type direct_text_message =
  { language : Pool_common.Language.t
  ; sms_text : Message_template.SmsText.t
  ; email_subject : Message_template.EmailSubject.t
  ; fallback_to_email : Message_template.FallbackToEmail.t
  }
[@@deriving eq, show]

type direct_message =
  | Mail of direct_message_email
  | Sms of direct_text_message
[@@deriving eq, show, variants]

module SendDirectMessage : sig
  include Common.CommandSig with type t = direct_message

  val handle
    :  ?tags:Logs.Tag.set
    -> (Assignment.t -> Message_template.ManualMessage.t -> Email.job)
    -> (Pool_common.Language.t
        -> Assignment.t
        -> Message_template.SmsText.t
        -> Pool_user.CellPhone.t
        -> Text_message.job)
    -> Assignment.t list
    -> t
    -> (Pool_event.t list, Conformist.error_msg) result

  val decode
    :  Pool_common.MessageChannel.t
    -> Conformist.input
    -> (t, Conformist.error_msg) result

  val effects : Experiment.Id.t -> Session.Id.t -> Guard.ValidationSet.t
end = struct
  type t = direct_message

  let handle
    ?(tags = Logs.Tag.empty)
    make_email_job
    make_sms_job
    assignments
    command
    =
    Logs.info ~src (fun m -> m "Handle command SendDirectMessage" ~tags);
    let open Message_template in
    let make_email_job language email_text email_subject plain_text assignment =
      ManualMessage.
        { recipient = Contact.email_address assignment.Assignment.contact
        ; language
        ; email_subject
        ; email_text
        ; plain_text
        }
      |> make_email_job assignment
    in
    CCResult.return
    @@
    match command with
    | Mail { language; email_subject; email_text; plain_text } ->
      assignments
      |> CCList.map
           (make_email_job language email_text email_subject plain_text)
      |> Email.bulksent
      |> Pool_event.email
      |> CCList.return
    | Sms { language; sms_text; email_subject; fallback_to_email } ->
      let sms_jobs, email_jobs =
        let open Assignment in
        assignments
        |> CCList.partition_filter_map (fun ({ contact; _ } as assignment) ->
          match
            contact.Contact.cell_phone, FallbackToEmail.value fallback_to_email
          with
          | Some cell_phone, _ ->
            `Left (make_sms_job language assignment sms_text cell_phone)
          | None, true ->
            let email_text, plain_text = sms_text_to_email sms_text in
            `Right
              (make_email_job
                 language
                 email_text
                 email_subject
                 plain_text
                 assignment)
          | None, false -> `Drop)
      in
      [ Text_message.BulkSent sms_jobs |> Pool_event.text_message
      ; Email.BulkSent email_jobs |> Pool_event.email
      ]
  ;;

  let email_command language email_subject email_text plain_text =
    { language; email_subject; email_text; plain_text }
  ;;

  let email_schema =
    let open Message_template in
    Pool_common.Utils.PoolConformist.(
      make
        Field.
          [ Pool_common.Language.schema ()
          ; EmailSubject.schema ()
          ; EmailText.schema ()
          ; PlainText.schema ()
          ]
        email_command)
  ;;

  let sms_command language email_subject sms_text fallback_to_email =
    { language; email_subject; sms_text; fallback_to_email }
  ;;

  let sms_schema =
    let open Message_template in
    Pool_common.Utils.PoolConformist.(
      make
        Field.
          [ Pool_common.Language.schema ()
          ; EmailSubject.schema ()
          ; SmsText.schema ()
          ; FallbackToEmail.schema ()
          ]
        sms_command)
  ;;

  let decode channel data =
    let open Pool_common.MessageChannel in
    let open CCResult.Infix in
    CCResult.map_err Pool_common.Message.to_conformist_error
    @@
    match channel with
    | Email -> Conformist.decode_and_validate email_schema data >|= mail
    | TextMessage -> Conformist.decode_and_validate sms_schema data >|= sms
  ;;

  let effects id = Session.Guard.Access.update id
end
