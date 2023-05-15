let target_of = Guard.Uuid.target_of Entity.Id.value

let relation ?ctx () =
  let open Guard in
  let to_target = Relation.Query.create Repo.Sql.find_binary_session_id_sql in
  Persistence.Relation.add ?ctx ~to_target ~target:`Session `Assignment
;;

module Target = struct
  type t = Entity.t [@@deriving eq, show]

  let to_authorizable ?ctx t =
    let open Utils.Lwt_result.Infix in
    let open Guard in
    Persistence.Target.decorate
      ?ctx
      (fun { Entity.id; _ } -> Target.make `Assignment (id |> target_of))
      t
    >|- Pool_common.Message.authorization
  ;;
end

module Access = struct
  open Guard
  open ValidationSet

  let assignment action id =
    One (action, TargetSpec.Id (`Assignment, target_of id))
  ;;

  let index id =
    And
      [ One (Action.Read, TargetSpec.Entity `Assignment)
      ; Experiment.Guard.Access.read id
      ; Experiment.Guard.Access.recruiter_of id
      ]
  ;;

  let create id =
    And
      [ One (Action.Create, TargetSpec.Entity `Assignment)
      ; Experiment.Guard.Access.read id
      ; Experiment.Guard.Access.recruiter_of id
      ]
  ;;

  let read experiment_id assignment_id =
    And
      [ assignment Action.Read assignment_id
      ; Experiment.Guard.Access.read experiment_id
      ; Experiment.Guard.Access.recruiter_of experiment_id
      ]
  ;;

  let update experiment_id assignment_id =
    And
      [ assignment Action.Update assignment_id
      ; Experiment.Guard.Access.update experiment_id
      ; Experiment.Guard.Access.recruiter_of experiment_id
      ]
  ;;

  let delete experiment_id assignment_id =
    And
      [ assignment Action.Delete assignment_id
      ; Experiment.Guard.Access.update experiment_id
      ; Experiment.Guard.Access.recruiter_of experiment_id
      ]
  ;;

  let deleted = index
end
