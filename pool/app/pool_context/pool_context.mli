type user =
  | Admin of Sihl_user.t
  | Contact of Contact.t
  | Root of Sihl_user.t

val admin : Sihl_user.t -> user
val contact : Contact.t -> user
val root : Sihl_user.t -> user

type t =
  { query_language : Pool_common.Language.t option
  ; language : Pool_common.Language.t
  ; tenant_db : Pool_tenant.Database.Label.t
  ; message : Pool_common.Message.Collection.t option
  ; csrf : string
  ; user : user option
  }

val create
  :  Pool_common.Language.t option
     * Pool_common.Language.t
     * Pool_tenant.Database.Label.t
     * Pool_common.Message.Collection.t option
     * string
     * user option
  -> t

val find : Rock.Request.t -> (t, Pool_common.Message.error) result
val find_exn : Rock.Request.t -> t
val set : Rock.Request.t -> t -> Rock.Request.t

module Tenant : sig
  type t =
    { tenant : Pool_tenant.t
    ; tenant_languages : Pool_common.Language.t list
    }

  val create : Pool_tenant.t -> Pool_common.Language.t list -> t
  val key : t Rock.Context.key
  val find : Rock.Request.t -> (t, Pool_common.Message.error) result
  val set : Rock.Request.t -> t -> Rock.Request.t

  val get_tenant_languages
    :  Rock.Request.t
    -> (Pool_common.Language.t list, Pool_common.Message.error) result
end
