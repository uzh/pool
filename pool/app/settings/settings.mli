module ContactEmail : sig
  type t

  val equal : t -> t -> bool
  val pp : Format.formatter -> t -> unit
  val show : t -> string
  val value : t -> string
  val create : string -> (t, Pool_common.Message.error) result

  val schema
    :  unit
    -> (Pool_common.Message.error, t) Pool_common.Utils.PoolConformist.Field.t
end

module EmailSuffix : sig
  type t

  val equal : t -> t -> bool
  val pp : Format.formatter -> t -> unit
  val show : t -> t
  val value : t -> string
  val create : string -> (t, Pool_common.Message.error) result

  val schema
    :  unit
    -> (Pool_common.Message.error, t) Pool_common.Utils.PoolConformist.Field.t
end

module InactiveUser : sig
  module DisableAfter : sig
    type t

    val create : string -> (t, Pool_common.Message.error) result
    val equal : t -> t -> bool
    val pp : Format.formatter -> t -> unit
    val show : t -> string
    val value : t -> int
    val to_timespan : t -> Ptime.span

    val schema
      :  unit
      -> (Pool_common.Message.error, t) Pool_common.Utils.PoolConformist.Field.t
  end

  module Warning : sig
    type t

    val create : string -> (t, Pool_common.Message.error) result
    val equal : t -> t -> bool
    val pp : Format.formatter -> t -> unit
    val show : t -> string
    val value : t -> int
    val to_timespan : t -> Ptime.span

    val schema
      :  unit
      -> (Pool_common.Message.error, t) Pool_common.Utils.PoolConformist.Field.t
  end
end

module TermsAndConditions : sig
  module Terms : sig
    type t

    val value : t -> string
  end

  type t

  val equal : t -> t -> bool
  val pp : Format.formatter -> t -> unit
  val create : string -> string -> (t, Pool_common.Message.error) result
  val value : t -> Pool_common.Language.t * Terms.t
end

type default =
  { default_reminder_lead_time : Pool_common.Reminder.LeadTime.t
  ; tenant_languages : Pool_common.Language.t list
  ; tenant_email_suffixes : EmailSuffix.t list
  ; tenant_contact_email : ContactEmail.t
  ; inactive_user_disable_after : InactiveUser.DisableAfter.t
  ; inactive_user_warning : InactiveUser.Warning.t
  ; terms_and_conditions : TermsAndConditions.t list
  }

val default_values : default

module Value : sig
  type t
end

type t

val action_of_param
  :  string
  -> ( [> `CreateTenantEmailSuffix
       | `DeleteTenantEmailSuffix
       | `UpdateDefaultLeadTime
       | `UpdateInactiveUserDisableAfter
       | `UpdateInactiveUserWarning
       | `UpdateTenantContactEmail
       | `UpdateTenantEmailSuffixes
       | `UpdateTenantLanguages
       | `UpdateTermsAndConditions
       ]
     , Pool_common.Message.error )
     result

val stringify_action
  :  [< `CreateTenantEmailSuffix
     | `DeleteTenantEmailSuffix
     | `UpdateDefaultLeadTime
     | `UpdateInactiveUserDisableAfter
     | `UpdateInactiveUserWarning
     | `UpdateTenantContactEmail
     | `UpdateTenantEmailSuffixes
     | `UpdateTenantLanguages
     | `UpdateTermsAndConditions
     ]
  -> string

type event =
  | LanguagesUpdated of Pool_common.Language.t list
  | EmailSuffixesUpdated of EmailSuffix.t list
  | DefaultReminderLeadTimeUpdated of Pool_common.Reminder.LeadTime.t
  | ContactEmailUpdated of ContactEmail.t
  | InactiveUserDisableAfterUpdated of InactiveUser.DisableAfter.t
  | InactiveUserWarningUpdated of InactiveUser.Warning.t
  | TermsAndConditionsUpdated of TermsAndConditions.t list
  | DefaultRestored of default

val handle_event : Pool_database.Label.t -> event -> unit Lwt.t
val equal_event : event -> event -> bool
val pp_event : Format.formatter -> event -> unit
val find_languages : Pool_database.Label.t -> Pool_common.Language.t list Lwt.t
val find_email_suffixes : Pool_database.Label.t -> EmailSuffix.t list Lwt.t
val find_contact_email : Pool_database.Label.t -> ContactEmail.t Lwt.t

val find_inactive_user_disable_after
  :  Pool_database.Label.t
  -> InactiveUser.DisableAfter.t Lwt.t

val find_inactive_user_warning
  :  Pool_database.Label.t
  -> InactiveUser.Warning.t Lwt.t

val find_terms_and_conditions
  :  Pool_database.Label.t
  -> TermsAndConditions.t list Lwt.t

val terms_and_conditions_last_updated : Pool_database.Label.t -> Ptime.t Lwt.t

val default_language
  :  Pool_database.Label.t
  -> (Pool_common.Language.t, Pool_common.Message.error) result Lwt.t

val terms_and_conditions
  :  Pool_database.Label.t
  -> Pool_common.Language.t
  -> (TermsAndConditions.Terms.t, Pool_common.Message.error) result Lwt.t

val find_default_reminder_lead_time
  :  Pool_database.Label.t
  -> Pool_common.Reminder.LeadTime.t Lwt.t
