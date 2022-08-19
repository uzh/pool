module Conformist = Pool_common.Utils.PoolConformist

module ResetPassword = struct
  type t = Pool_user.EmailAddress.t

  let command m = m

  let schema =
    Conformist.(make Field.[ Pool_user.EmailAddress.schema () ] command)
  ;;

  let handle user language =
    Ok [ Email.ResetPassword (user, language) |> Pool_event.email ]
  ;;

  let decode data =
    Conformist.decode_and_validate schema data
    |> CCResult.map_err Pool_common.Message.to_conformist_error
  ;;

  let effects = Utils.todo [%here]
end
