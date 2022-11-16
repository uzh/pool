let get_or_failwith = Pool_common.Utils.get_or_failwith

module Run : sig
  type t =
    { mailing : Mailing.t
    ; experiment : Experiment.t
    ; contacts : Contact.t list
    ; i18n_templates : (Pool_common.Language.t * (I18n.t * I18n.t)) list
    }

  val handle : t list -> (Pool_event.t list, Pool_common.Message.error) result

  val effects
    :  Pool_database.Label.t
    -> (Guard.Authorizer.effect list, Pool_common.Message.error) Lwt_result.t
end = struct
  type t =
    { mailing : Mailing.t
    ; experiment : Experiment.t
    ; contacts : Contact.t list
    ; i18n_templates : (Pool_common.Language.t * (I18n.t * I18n.t)) list
    }

  let handle =
    let open CCFun.Infix in
    CCList.map (fun { experiment; contacts; i18n_templates; _ } ->
      let open Invitation_command in
      let languages = Pool_common.Language.all in
      let command = Create.{ experiment; contacts; invited_contacts = [] } in
      Create.handle command languages i18n_templates)
    %> CCList.all_ok
    %> CCResult.map CCList.flatten
  ;;

  let effects db_label =
    let open Lwt_result.Syntax in
    let* tenant = Pool_tenant.find_by_label db_label in
    Lwt.return_ok
      [ ( `Update
        , `Target
            (tenant.Pool_tenant.id |> Guard.Uuid.target_of Pool_common.Id.value)
        )
      ]
  ;;
end
