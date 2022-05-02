include Entity
include Event

let find = Repo.find
let find_by_email = Repo.find_by_email

let find_by_user pool (user : Sihl_user.t) =
  user.Sihl_user.id |> Pool_common.Id.of_string |> Repo.find pool
;;

let has_terms_accepted = Event.has_terms_accepted
