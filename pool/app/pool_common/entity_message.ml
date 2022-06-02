open Sexplib.Conv

module Field = struct
  let go m fmt _ = Format.pp_print_string fmt m

  type t =
    | Admin [@name "admin"] [@printer go "admin"]
    | AssetId [@name "asset_id"] [@printer go "asset_id"]
    | AssignmentCount [@name "assignment_count"]
        [@printer go "assignment_count"]
    | Building [@name "building"] [@printer go "building"]
    | CanceledAt [@name "canceled_at"] [@printer go "canceled_at"]
    | City [@name "city"] [@printer go "city"]
    | Comment [@name "comment"] [@printer go "comment"]
    | Contact [@name "contact"] [@printer go "contact"]
    | ContactEmail [@name "contact_email"] [@printer go "contact_email"]
    | Contacts [@name "contacts"] [@printer go "contacts"]
    | CreatedAt [@name "created_at"] [@printer go "created_at"]
    | CurrentPassword [@name "current_password"]
        [@printer go "current_password"]
    | Database [@name "database"] [@printer go "database"]
    | DatabaseLabel [@name "database_label"] [@printer go "database_label"]
    | DatabaseUrl [@name "database_url"] [@printer go "database_url"]
    | Date [@name "date"] [@printer go "date"]
    | DateTime [@name "date_time"] [@printer go "date_time"]
    | DefaultLanguage [@name "default_language"]
        [@printer go "default_language"]
    | Description [@name "description"] [@printer go "description"]
    | DirectRegistrationDisabled [@name "direct_registration_disabled"]
        [@printer go "direct_registration_disabled"]
    | Disabled [@name "disabled"] [@printer go "disabled"]
    | Duration [@name "duration"] [@printer go "duration"]
    | Email [@name "email"] [@printer go "email"]
    | EmailAddress [@name "email_address"] [@printer go "email_address"]
        [@printer go "default_language"]
    | EmailAddressUnverified [@name "email_address_unverified"]
        [@printer go "email_address_unverified"]
    | EmailAddressVerified [@name "email_address_verified"]
        [@printer go "email_address_verified"]
    | EmailSuffix [@name "email_suffix"] [@printer go "email_suffix"]
    | Experiment [@name "experiment"] [@printer go "experiment"]
    | File [@name "file"] [@printer go "file"]
    | FileMapping [@name "file_mapping"] [@printer go "file_mapping"]
    | FileMimeType [@name "file_mime_type"] [@printer go "file_mime_type"]
    | Filename [@name "filename"] [@printer go "filename"]
    | Filesize [@name "filesize"] [@printer go "filesize"]
    | Firstname [@name "firstname"] [@printer go "firstname"]
    | Host [@name "host"] [@printer go "host"]
    | I18n [@name "i18n"] [@printer go "i18n"]
    | Icon [@name "icon"] [@printer go "icon"]
    | Id [@name "id"] [@printer go "id"]
    | InactiveUserDisableAfter [@name "inactive_user_disable_after"]
        [@printer go "inactive_user_disable_after"]
    | InactiveUserWarning [@name "inactive_user_warning"]
        [@printer go "inactive_user_warning"]
    | Invitation [@name "invitation"] [@printer go "invitation"]
    | Invitations [@name "invitations"] [@printer go "invitations"]
    | Key [@name "key"] [@printer go "key"]
    | Label [@name "label"] [@printer go "label"]
    | Language [@name "language"] [@printer go "language"]
    | LanguageDe [@name "language_de"] [@printer go "language_de"]
    | LanguageEn [@name "language_en"] [@printer go "language_en"]
    | Lastname [@name "lastname"] [@printer go "lastname"]
    | Link [@name "link"] [@printer go "link"]
    | Location [@name "location"] [@printer go "location"]
    | LogoType [@name "logo_type"] [@printer go "logo_type"]
    | MaxParticipants [@name "max_participants"]
        [@printer go "max_participants"]
    | MinParticipants [@name "min_participants"]
        [@printer go "min_participants"]
    | Name [@name "name"] [@printer go "name"]
    | NewPassword [@name "new_password"] [@printer go "new_password"]
    | Operator [@name "operator"] [@printer go "operator"]
    | Overbook [@name "overbook"] [@printer go "overbook"]
    | Page [@name "page"] [@printer go "page"]
    | Participant [@name "participant"] [@printer go "participant"]
    | ParticipantCount [@name "participant_count"]
        [@printer go "participant_count"]
    | Participants [@name "participants"] [@printer go "participants"]
    | Participated [@name "participated"] [@printer go "participated"]
    | PartnerLogos [@name "partner_logos"] [@printer go "partner_logos"]
    | Password [@name "password"] [@printer go "password"]
    | PasswordConfirmation [@name "password_confirmation"]
        [@printer go "password_confirmation"]
    | Paused [@name "paused"] [@printer go "paused"]
    | RecruitmentChannel [@name "recruitment_channel"]
        [@printer go "recruitment_channel"]
    | ResentAt [@name "resent_at"] [@printer go "resent_at"]
    | Role [@name "role"] [@printer go "role"]
    | Room [@name "room"] [@printer go "room"]
    | Root [@name "root"] [@printer go "root"]
    | Session [@name "session"] [@printer go "session"]
    | Setting [@name "setting"] [@printer go "setting"]
    | ShowUp [@name "show_up"] [@printer go "show_up"]
    | SmtpAuthMethod [@name "smtp_auth_method"] [@printer go "smtp_auth_method"]
    | SmtpAuthServer [@name "smtp_auth_server"] [@printer go "smtp_auth_server"]
    | SmtpPassword [@name "smtp_password"] [@printer go "smtp_password"]
    | SmtpPort [@name "smtp_port"] [@printer go "smtp_port"]
    | SmtpProtocol [@name "smtp_protocol"] [@printer go "smtp_protocol"]
    | SmtpReadModel [@name "smtp_read_model"] [@printer go "smtp_read_model"]
    | SmtpUsername [@name "smtp_username"] [@printer go "smtp_username"]
    | SmtpWriteModel [@name "smtp_write_model"] [@printer go "smtp_write_model"]
    | Start [@name "start"] [@printer go "start"]
    | Status [@name "status"] [@printer go "status"]
    | Street [@name "street"] [@printer go "street"]
    | Styles [@name "styles"] [@printer go "styles"]
    | Tenant [@name "tenant"] [@printer go "tenant"]
    | TenantDisabledFlag [@name "tenant_disabled_flag"]
        [@printer go "tenant_disabled_flag"]
    | TenantId [@name "tenant_id"] [@printer go "tenant_id"]
    | TenantLogos [@name "tenant_logos"] [@printer go "tenant_logos"]
    | TenantMaintenanceFlag [@name "tenant_maintenance_flag"]
        [@printer go "tenant_maintenance_flag"]
    | TenantPool [@name "tenant_pool"] [@printer go "tenant_pool"]
    | TermsAccepted [@name "terms_accepted"] [@printer go "terms_accepted"]
    | TermsAndConditions [@name "terms_and_conditions"]
        [@printer go "terms_and_conditions"]
    | Time [@name "time"] [@printer go "time"]
    | TimeSpan [@name "timespan"] [@printer go "timespan"]
    | Title [@name "title"] [@printer go "title"]
    | Token [@name "token"] [@printer go "token"]
    | Translation [@name "translation"] [@printer go "translation"]
    | Url [@name "url"] [@printer go "url"]
    | User [@name "user"] [@printer go "user"]
    | Version [@name "version"] [@printer go "version"]
    | Virtual [@name "virtual"] [@printer go "virtual"]
    | WaitingList [@name "waiting_list"] [@printer go "waiting_list"]
    | WaitingListDisabled [@name "waiting_list_disabled"]
        [@printer go "waiting_list_disabled"]
    | Zip [@name "zip"] [@printer go "zip"]
        [@printer field_name "terms_and_conditions"]
  [@@deriving eq, show { with_path = false }, yojson, variants, sexp_of]

  let read m =
    m |> Format.asprintf "[\"%s\"]" |> Yojson.Safe.from_string |> t_of_yojson
  ;;

  let url_key m = m |> show |> Format.asprintf ":%s"
  let array_key m = m |> show |> Format.asprintf "%s[]"
end

(* TODO [aerben] make these general, compare what fields exist already, whenever
   pattern is "FIELD_ADJECTIVE", turn FIELD to Field.t and make it ADJECTIVE of
   Field.t *)
type error =
  | AlreadySignedUpForExperiment
  | Conformist of (Field.t * error) list
  | ConformistModuleErrorType
  | ContactSignupInvalidEmail
  | ContactUnconfirmed
  | Decode of Field.t
  | DecodeAction
  | Disabled of Field.t
  | EmailAddressMissingOperator
  | EmailAddressMissingRoot
  | EmailAlreadyInUse
  | EmailDeleteAlreadyVerified
  | EmailMalformed
  | ExperimentSessionCountNotZero
  | HtmxVersionNotFound of string
  | Invalid of Field.t
  | LoginProvideDetails
  | MeantimeUpdate of Field.t
  | NegativeAmount
  | NoOptionSelected of Field.t
  | NotADatetime of (string * string)
  | NotANumber of string
  | NoTenantsRegistered
  | NotFound of Field.t
  | NotFoundList of Field.t * string list
  | NotEligible
  | NotHandled of string
  | NoValue
  | PasswordConfirmationDoesNotMatch
  | PasswordPolicy of string
  | PasswordResetFailMessage
  | PasswordResetInvalidData
  | PoolContextNotFound
  | RequestRequiredFields
  | Retrieve of Field.t
  | SessionFullyBooked
  | SessionInvalid
  | SessionTenantNotFound
  | Smaller of (Field.t * Field.t)
  | TerminatoryRootError
  | TerminatoryRootErrorTitle
  | TerminatoryTenantError
  | TerminatoryTenantErrorTitle
  | TermsAndConditionsMissing
  | TermsAndConditionsNotAccepted
  | TimeInPast
  | TimeSpanPositive
  | TokenAlreadyUsed
  | TokenInvalidFormat
  | Undefined of Field.t
  | WaitingListFlagsMutuallyExclusive
  | WriteOnlyModel
[@@deriving eq, show, yojson, variants, sexp_of]

type warning = Warning of string
[@@deriving eq, show, yojson, variants, sexp_of]

type success =
  | AddedToWaitingList
  | AssignmentCreated
  | Canceled of Field.t
  | Created of Field.t
  | Deleted of Field.t
  | EmailConfirmationMessage
  | EmailVerified
  | FileDeleted
  | PasswordChanged
  | PasswordReset
  | PasswordResetSuccessMessage
  | RemovedFromWaitingList
  | SentList of Field.t
  | SettingsUpdated
  | TenantUpdateDatabase
  | TenantUpdateDetails
  | Updated of Field.t
[@@deriving eq, show, yojson, variants, sexp_of]

type info = Info of string [@@deriving eq, show, yojson, variants, sexp_of]

type t =
  | Message of string
  | PageNotFoundMessage
[@@deriving eq, show, yojson, variants, sexp_of]

let field_message prefix field suffix =
  Format.asprintf "%s %s %s" prefix field suffix
  |> CCString.trim
  |> CCString.capitalize_ascii
;;

let handle_sihl_login_error = function
  | `Incorrect_password | `Does_not_exist -> Invalid Field.Password
;;

type control =
  | Accept of Field.t option
  | Add of Field.t option
  | AddToWaitingList
  | Assign of Field.t option
  | Back
  | Cancel of Field.t option
  | Choose of Field.t option
  | Create of Field.t option
  | Decline
  | Delete of Field.t option
  | Disable
  | Edit of Field.t option
  | Enable
  | Enroll
  | Login
  | More
  | RemoveFromWaitingList
  | Resend of Field.t option
  | Save of Field.t option
  | Send of Field.t option
  | SendResetLink
  | SelectFilePlaceholder
  | SignUp
  | Update of Field.t option
[@@deriving eq, show, yojson, variants, sexp_of]

let to_conformist_error error_list =
  CCList.map (fun (name, _, msg) -> name |> Field.read, msg) error_list
  |> conformist
;;

let add_field_query_params path params =
  CCList.map (CCPair.map_fst Field.show) params
  |> Uri.add_query_params' (Uri.of_string path)
  |> Uri.to_string
;;

module Collection = struct
  type t =
    { error : error list
    ; warning : warning list
    ; success : success list
    ; info : info list
    }
  [@@deriving eq, show, yojson, sexp_of]

  let empty = { error = []; warning = []; success = []; info = [] }
  let set_success txts message = { message with success = txts }
  let set_warning txts message = { message with warning = txts }
  let set_error txts message = { message with error = txts }
  let set_info txts message = { message with info = txts }

  let of_string str =
    let json =
      try Some (Yojson.Safe.from_string str) with
      | _ -> None
    in
    match json with
    | Some json -> Some (t_of_yojson json)
    | None -> None
  ;;

  let to_string t = yojson_of_t t |> Yojson.Safe.to_string
end
