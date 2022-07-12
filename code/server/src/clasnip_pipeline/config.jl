
# clean up database when the size of database reach
"""
If `CLASNIP_DB` uses more than `DB_MEM_LIMIT` bytes in memory, unload databases based on the last access time.
"""
const DB_MEM_LIMIT = 128 * 1024 * 1024

"""
`DB_PROTECT_TIME` protects a database to be automatically unload in a limited time from the last access time.
"""
DB_PROTECT_TIME = Hour(1)

"""
Periodically check whether databases need to unload. `DB_UNLOAD_CHECK_INTERVAL` sets the time interval between two checks.
"""
DB_UNLOAD_CHECK_INTERVAL = Second(500)
