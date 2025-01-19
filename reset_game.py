import redis

r = redis.Redis()

players = r.hgetall("tokens")

r.delete("necrovoiders")
r.delete("global_vars")

for _, public_key in players.items():
    public_key = public_key.decode()

    r.hset("time_units", public_key, 0)
    r.hset("time_units_per_second", public_key, 1)
    r.delete(f"powerups-{public_key}")
