module Conformist = Pool_common.Utils.PoolConformist

type name_command = (Pool_common.Language.t * string) list

module Create : sig
  val handle
    :  ?id:Custom_field.Group.Id.t
    -> Pool_common.Language.t list
    -> name_command
    -> Custom_field.Model.t
    -> (Pool_event.t list, Pool_common.Message.error) result

  val effects : Guard.Authorizer.effect list
end = struct
  let handle ?id sys_languages name model =
    let open CCResult in
    let* name = Custom_field.Name.create sys_languages name in
    let group = Custom_field.Group.create ?id model name in
    Ok Custom_field.[ GroupCreated group |> Pool_event.custom_field ]
  ;;

  let effects = [ `Create, `TargetEntity `Admin ]
end

module Update : sig
  val handle
    :  Pool_common.Language.t list
    -> Custom_field.Group.t
    -> name_command
    -> Custom_field.Model.t
    -> (Pool_event.t list, Pool_common.Message.error) result

  val effects : Guard.Authorizer.effect list
end = struct
  let handle sys_languages group names model =
    let open CCResult in
    let* names = Custom_field.Name.create sys_languages names in
    let group = Custom_field.Group.{ group with model; name = names } in
    Ok Custom_field.[ GroupUpdated group |> Pool_event.custom_field ]
  ;;

  let effects = [ `Create, `TargetEntity `Admin ]
end

module Destroy : sig
  val handle
    :  Custom_field.Group.t
    -> (Pool_event.t list, Pool_common.Message.error) result

  val effects : Guard.Authorizer.effect list
end = struct
  let handle option =
    Ok [ Custom_field.GroupDestroyed option |> Pool_event.custom_field ]
  ;;

  let effects = [ `Create, `TargetEntity `Admin ]
end

module Sort : sig
  type t = Custom_field.Group.t list

  val handle : t -> (Pool_event.t list, Pool_common.Message.error) result
  val effects : Guard.Authorizer.effect list
end = struct
  type t = Custom_field.Group.t list

  let handle t = Ok [ Custom_field.GroupsSorted t |> Pool_event.custom_field ]
  let effects = [ `Create, `TargetEntity `Admin ]
end
