module Conformist = Pool_common.Utils.PoolConformist

let src = Logs.Src.create "message_template.cqrs"

module Create : sig
  include Common.CommandSig

  type t =
    { language : Pool_common.Language.t
    ; email_subject : Message_template.EmailSubject.t
    ; email_text : Message_template.EmailText.t
    ; plain_text : Message_template.PlainText.t
    ; sms_text : Message_template.SmsText.t
    }

  val handle
    :  ?tags:Logs.Tag.set
    -> ?id:Message_template.Id.t
    -> Message_template.Label.t
    -> Pool_common.Id.t
    -> Pool_common.Language.t list
    -> t
    -> (Pool_event.t list, Pool_common.Message.error) result

  val decode : Conformist.input -> (t, Pool_common.Message.error) result
end = struct
  type t =
    { language : Pool_common.Language.t
    ; email_subject : Message_template.EmailSubject.t
    ; email_text : Message_template.EmailText.t
    ; plain_text : Message_template.PlainText.t
    ; sms_text : Message_template.SmsText.t
    }

  let command language email_subject email_text plain_text sms_text =
    { language; email_subject; email_text; plain_text; sms_text }
  ;;

  let schema =
    let open Message_template in
    Pool_common.Utils.PoolConformist.(
      make
        Field.
          [ Pool_common.Language.schema ()
          ; EmailSubject.schema ()
          ; EmailText.schema ()
          ; PlainText.schema ()
          ; SmsText.schema ()
          ]
        command)
  ;;

  let handle
    ?(tags = Logs.Tag.empty)
    ?(id = Message_template.Id.create ())
    label
    entity_uuid
    available_languages
    { language; email_subject; email_text; plain_text; sms_text }
    =
    let open CCResult in
    Logs.info ~src (fun m -> m "Handle command Create" ~tags);
    let* (_ : Pool_common.Language.t) =
      available_languages
      |> CCList.find_opt (Pool_common.Language.equal language)
      |> CCOption.to_result Pool_common.Message.(Invalid Field.Language)
    in
    let template =
      Message_template.
        { id
        ; label
        ; entity_uuid = Some entity_uuid
        ; language
        ; email_subject
        ; email_text
        ; plain_text
        ; sms_text
        }
    in
    Ok Message_template.[ Created template |> Pool_event.message_template ]
  ;;

  let decode data =
    Conformist.decode_and_validate schema data
    |> CCResult.map_err Pool_common.Message.to_conformist_error
  ;;

  let effects = Message_template.Guard.Access.create
end

module Update : sig
  include Common.CommandSig with type t = Message_template.update

  val handle
    :  ?tags:Logs.Tag.set
    -> Message_template.t
    -> t
    -> (Pool_event.t list, Pool_common.Message.error) result

  val decode
    :  Conformist.input
    -> (Message_template.update, Pool_common.Message.error) result

  val effects : Message_template.Id.t -> Guard.ValidationSet.t
end = struct
  type t = Message_template.update

  let command email_subject email_text plain_text sms_text =
    Message_template.{ email_subject; email_text; plain_text; sms_text }
  ;;

  let schema =
    let open Message_template in
    Pool_common.Utils.PoolConformist.(
      make
        Field.
          [ EmailSubject.schema ()
          ; EmailText.schema ()
          ; PlainText.schema ()
          ; SmsText.schema ()
          ]
        command)
  ;;

  let handle ?(tags = Logs.Tag.empty) template command =
    Logs.info ~src (fun m -> m "Handle command Update" ~tags);
    Ok
      Message_template.
        [ Updated (template, command) |> Pool_event.message_template ]
  ;;

  let decode data =
    Conformist.decode_and_validate schema data
    |> CCResult.map_err Pool_common.Message.to_conformist_error
  ;;

  let effects = Message_template.Guard.Access.update
end

module Delete : sig
  type t = Message_template.t

  val handle
    :  ?tags:Logs.Tag.set
    -> t
    -> (Pool_event.t list, Pool_common.Message.error) result
end = struct
  type t = Message_template.t

  let handle ?(tags = Logs.Tag.empty) template =
    Logs.info ~src (fun m -> m "Handle command Delete" ~tags);
    let open Message_template in
    match template.entity_uuid with
    | None -> Error Pool_common.Message.(CannotBeDeleted Field.MessageTemplate)
    | Some _ -> Ok [ template |> deleted |> Pool_event.message_template ]
  ;;
end
