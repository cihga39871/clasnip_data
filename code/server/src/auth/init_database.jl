### functions
function sqlite_type_and_default(x)
    if x <: Integer
        "INTEGER", 0
    elseif x <: Float64
        "REAL", 0
    elseif x <: AbstractString
        "TEXT", "TEXT"
    elseif x <: Nothing
        "NULL", "NULL"
    end
end

###
schema_user = Tables.Schema(
    (:username, :password, :name  , :email , :salt  , :time_last_try, :n_try_fail),
    ( String  ,  String  ,  String,  String,  String, Int, Int)
) # no null allowed

SQLite.createtable!(sql_db, "user", schema_user, ifnotexists=true)


# if some columns missing, create columns
user_col_info = DataFrame(SQLite.columns(sql_db, "user"))
existing_col_names = Symbol.(user_col_info.name)

for (i, name) in enumerate(schema_user.names)
    if !(name in existing_col_names)
        type, default = sqlite_type_and_default(schema_user.types[i])
        if type == "NULL"
            sql = """
                ALTER TABLE user ADD COLUMN $name $type;
            """
        else
            sql = """
                ALTER TABLE user ADD COLUMN $name $type NOT NULL DEFAULT $default;
            """
        end
        @info "DB: user table: create column $name $type"
        SQLite.execute(sql_db, sql)
    end
end
# index
db_indices = SQLite.indices(sql_db)
if isempty(db_indices) || !("id" in db_indices[1])
    SQLite.createindex!(sql_db, "user", "id", "username")
end
