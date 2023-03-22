module Key : sig
  type t =
    | CreditsText
    | GreetingsText
    | PasswordPolicyText
    | WelcomeText

  val create : string -> (t, Pool_common.Message.error) result
  val show : t -> string
  val equal : t -> t -> bool
  val compare : t -> t -> int
  val is_rich_text : t -> bool
  val all : t list

  val schema
    :  unit
    -> (Pool_common.Message.error, t) Pool_common.Utils.PoolConformist.Field.t
end

module Content : sig
  include Pool_common.Model.StringSig
end

type t

val show : t -> string
val equal : t -> t -> bool
val pp : Format.formatter -> t -> unit
val create : Key.t -> Pool_common.Language.t -> Content.t -> t

type create =
  { key : Key.t
  ; language : Pool_common.Language.t
  ; content : Content.t
  }

type edit = { content : Content.t }

val id : t -> Pool_common.Id.t
val key : t -> Key.t
val language : t -> Pool_common.Language.t
val content : t -> Content.t
val content_to_string : t -> string
val default_values : t list

type event =
  | Created of create
  | Updated of t * edit
  | DefaultRestored of t list

val equal_event : event -> event -> bool
val pp_event : Format.formatter -> event -> unit
val show_event : event -> string
val handle_event : Pool_database.Label.t -> event -> unit Lwt.t

val find
  :  Pool_database.Label.t
  -> Pool_common.Id.t
  -> (t, Pool_common.Message.error) result Lwt.t

val find_by_key
  :  Pool_database.Label.t
  -> Key.t
  -> Pool_common.Language.t
  -> (t, Pool_common.Message.error) result Lwt.t

val find_all : Pool_database.Label.t -> unit -> t list Lwt.t

module Guard : sig
  module Target : sig
    val to_authorizable
      :  ?ctx:Guardian__.Persistence.context
      -> t
      -> (Role.Target.t Guard.Target.t, Entity.PoolError.error) Lwt_result.t

    type t

    val equal : t -> t -> bool
    val pp : Format.formatter -> t -> unit
    val show : t -> string
  end
end
