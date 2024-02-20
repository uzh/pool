open Entity_statistics

let statistics =
  let encode _ =
    failwith
      Pool_common.(Message.ReadOnlyModel |> Utils.error_to_string Language.En)
  in
  let decode
    ( experiment_count
    , (assignment_count, (showup_count, (noshow_count, participation_count))) )
    =
    Ok
      { experiment_count
      ; assignment_count
      ; showup_count
      ; noshow_count
      ; participation_count
      }
  in
  Caqti_type.(custom ~encode ~decode (t2 int (t2 int (t2 int (t2 int int)))))
;;

let statistics_requeset =
  let open Caqti_request.Infix in
  {sql|
    SELECT
      COUNT(DISTINCT S.experiment_uuid),
      COUNT(A.id),
      COALESCE(SUM(A.no_show = 0), 0),
      COALESCE(SUM(A.no_show), 0),
      COALESCE(SUM(A.participated), 0)
    FROM
      pool_assignments A
      INNER JOIN pool_sessions S ON A.session_uuid = S.uuid
      INNER JOIN pool_locations L ON S.location_uuid = L.uuid
    WHERE
      S.location_uuid = UNHEX(REPLACE(?, '-', ''))
      AND S.canceled_at IS NULL
      AND A.canceled_at IS NULL
      AND A.marked_as_deleted = 0
  |sql}
  |> Repo_entity.Id.t ->! statistics
;;

let statistics pool =
  Utils.Database.find (Pool_database.Label.value pool) statistics_requeset
;;
