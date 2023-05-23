include Entity
include Event
include Default
module Guard = Entity_guard

let[@warning "-4"] find_languages pool =
  let open Utils.Lwt_result.Infix in
  Repo.find_languages pool
  ||> fun { value; _ } ->
  match value with
  | Value.TenantLanguages value -> value
  | _ ->
    (* Due to Repo function, this state cannot be reached. *)
    Pool_common.(
      Error Message.(Retrieve Field.Language) |> Utils.get_or_failwith)
;;

let[@warning "-4"] find_email_suffixes pool =
  let open Utils.Lwt_result.Infix in
  Repo.find_email_suffixes pool
  ||> fun { value; _ } ->
  match value with
  | Value.TenantEmailSuffixes value -> value
  | _ ->
    (* Due to Repo function, this state cannot be reached. *)
    Pool_common.(
      Error Message.(Retrieve Field.EmailSuffix) |> Utils.get_or_failwith)
;;

let[@warning "-4"] find_contact_email pool =
  let open Utils.Lwt_result.Infix in
  Repo.find_contact_email pool
  ||> fun { value; _ } ->
  match value with
  | Value.TenantContactEmail value -> value
  | _ ->
    (* Due to Repo function, this state cannot be reached. *)
    Pool_common.(
      Error Message.(Retrieve Field.ContactEmail) |> Utils.get_or_failwith)
;;

let[@warning "-4"] find_inactive_user_disable_after pool =
  let open Utils.Lwt_result.Infix in
  Repo.find_inactive_user_disable_after pool
  ||> fun { value; _ } ->
  match value with
  | Value.InactiveUserDisableAfter value -> value
  | _ ->
    (* Due to Repo function, this state cannot be reached. *)
    Pool_common.(
      Error Message.(Retrieve Field.InactiveUserDisableAfter)
      |> Utils.get_or_failwith)
;;

let[@warning "-4"] find_inactive_user_warning pool =
  let open Utils.Lwt_result.Infix in
  Repo.find_inactive_user_warning pool
  ||> fun { value; _ } ->
  match value with
  | Value.InactiveUserWarning value -> value
  | _ ->
    (* Due to Repo function, this state cannot be reached. *)
    Pool_common.(
      Error Message.(Retrieve Field.InactiveUserWarning)
      |> Utils.get_or_failwith)
;;

let[@warning "-4"] find_trigger_profile_update_after pool =
  let open Utils.Lwt_result.Infix in
  Repo.find_trigger_profile_update_after pool
  ||> fun { value; _ } ->
  match value with
  | Value.TriggerProfileUpdateAfter value -> value
  | _ ->
    (* Due to Repo function, this state cannot be reached. *)
    Pool_common.(
      Error Message.(Retrieve Field.TriggerProfileUpdateAfter)
      |> Utils.get_or_failwith)
;;

let[@warning "-4"] find_terms_and_conditions pool =
  let open Utils.Lwt_result.Infix in
  Repo.find_terms_and_conditions pool
  ||> fun { value; _ } ->
  match value with
  | Value.TermsAndConditions value -> value
  | _ ->
    (* Due to Repo function, this state cannot be reached. *)
    Pool_common.(
      Error Message.(Retrieve Field.TermsAndConditions) |> Utils.get_or_failwith)
;;

let[@warning "-4"] find_default_reminder_lead_time pool =
  let open Utils.Lwt_result.Infix in
  Repo.find_default_reminder_lead_time pool
  ||> fun { value; _ } ->
  match value with
  | Value.DefaultReminderLeadTime value -> value
  | _ ->
    (* Due to Repo function, this state cannot be reached. *)
    Pool_common.(
      Error Message.(Retrieve Field.LeadTime) |> Utils.get_or_failwith)
;;

let terms_and_conditions_last_updated pool =
  let open Utils.Lwt_result.Infix in
  Repo.find_terms_and_conditions pool ||> fun { updated_at; _ } -> updated_at
;;

let default_language pool =
  let open Utils.Lwt_result.Infix in
  find_languages pool
  ||> CCList.head_opt
  ||> CCOption.to_result Pool_common.Message.(NotFound Field.DefaultLanguage)
  ||> Pool_common.Utils.get_or_failwith
;;

let terms_and_conditions pool language =
  let%lwt terms = find_terms_and_conditions pool in
  CCList.assoc ~eq:Pool_common.Language.equal language terms |> Lwt.return
;;
