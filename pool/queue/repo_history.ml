module Dynparam = Utils.Database.Dynparam
module Database = Pool_database

let sql_select_columns =
  [ Pool_common.Id.sql_select_fragment ~field:"pool_message_history.entity_uuid"
  ; "pool_message_history.message_template"
  ]
  @ Repo.sql_select_columns
;;

let joins =
  {sql|
    INNER JOIN queue_jobs
      ON pool_message_history.queue_job_uuid = queue_jobs.uuid
  |sql}
;;

let find_request_sql ?(count = false) where_fragment =
  let columns =
    if count then "COUNT(*)" else CCString.concat ", " sql_select_columns
  in
  Format.asprintf
    {sql|SELECT %s FROM pool_message_history %s %s|sql}
    columns
    joins
    where_fragment
;;

let insert_request =
  let open Caqti_request.Infix in
  {sql|
      INSERT INTO pool_message_history (
        queue_job_uuid,
        entity_uuid,
        message_template
      ) VALUES (
        UNHEX(REPLACE($1, '-', '')),
        UNHEX(REPLACE($2, '-', '')),
        $3
      )
    |sql}
  |> Caqti_type.(Repo_entity.write_caqti_type ->. unit)
;;

let insert pool t =
  Utils.Database.exec (Pool_database.Label.value pool) insert_request t
;;

let find_by_entity_request =
  let open Caqti_request.Infix in
  {sql|
    WHERE
      entity_uuid = UNHEX(REPLACE($1, '-', ''))
  |sql}
  |> find_request_sql
  |> Caqti_type.(t2 string string) ->? Repo_entity.t
;;

let query_by_entity ?query pool entity_uuid =
  let where =
    ( "pool_message_history.entity_uuid = UNHEX(REPLACE(?, '-', ''))"
    , Dynparam.(empty |> add Pool_common.Repo.Id.t entity_uuid) )
  in
  Query.collect_and_count
    pool
    query
    ~select:find_request_sql
    ~where
    Repo_entity.t
;;

let find_related_request entity =
  let joins =
    match entity with
    | `contact ->
      {sql| INNER JOIN pool_contacts ON entity_uuid = pool_contacts.user_uuid |sql}
    | `experiment ->
      {sql| INNER JOIN pool_experiments ON entity_uuid = pool_experiments.uuid |sql}
  in
  let open Caqti_request.Infix in
  Format.asprintf
    {sql|
      SELECT 
        %s 
      FROM pool_message_history
        %s
      WHERE queue_job_uuid = UNHEX(REPLACE(?, '-', ''))
    |sql}
    (Pool_common.Id.sql_select_fragment ~field:"entity_uuid")
    joins
  |> Caqti_type.(string ->? Pool_common.Repo.Id.t)
;;

let find_related pool { Sihl_queue.id; _ } entity =
  Utils.Database.find_opt
    (Pool_database.Label.value pool)
    (find_related_request entity)
    id
;;
