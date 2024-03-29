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
      AND YEAR(S.start) = ?
      AND S.canceled_at IS NULL
      AND A.canceled_at IS NULL
      AND A.marked_as_deleted = 0
  |sql}
  |> Caqti_type.(t2 Repo_entity.Id.t int) ->! statistics
;;

let statistics year pool id =
  Utils.Database.find
    (Pool_database.Label.value pool)
    statistics_requeset
    (id, year)
;;

let find_statistics_starting_year_request =
  let open Caqti_request.Infix in
  {sql|
    SELECT
      YEAR(COALESCE(created_at, NOW()))
    FROM
      pool_assignments
    ORDER BY
      created_at ASC
    LIMIT 1
  |sql}
  |> Caqti_type.(unit ->! int)
;;

let find_statistics_starting_year pool =
  Utils.Database.find
    (Pool_database.Label.value pool)
    find_statistics_starting_year_request
    ()
;;
