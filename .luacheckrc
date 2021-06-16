unused_args = false

ignore = {
	"631",
}

globals = {
	"elevator",
}

read_globals = {
	-- Stdlib
	string = {fields = {"split"}},
	table = {fields = {"copy", "getn"}},

	-- Minetest
	"minetest",
	"core",
	"vector",
	"VoxelManip",

	-- deps
	"default", "screwdriver",
	"farming", "armor",
	"mcl_core", "mcl_sounds",
	"aurum",
}
