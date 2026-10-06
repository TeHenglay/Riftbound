--!strict
-- Server entry point: starts each service in order.

local Services = script.Services

require(Services.LoadoutService).start()
require(Services.CombatService).start()
require(Services.DummyService).start()
