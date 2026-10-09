-- What the Crossroads market sells and buys. Shared so the client can show
-- prices; the server (MarketService) is the one that charges and pays.
local Market = {}

-- The Rift Shop: spend gold.
Market.ShopOrder = { "FlaskRefill", "Tome", "RiftShard", "HuskIchor", "EmberCore" }
Market.Shop = {
	FlaskRefill = {
		Name = "Flask Refill",
		Description = "Refills every charge of your Rift Flask.",
		Price = 25,
		Icon = "Flask",
	},
	Tome = {
		Name = "Tome of Insight",
		Description = "Study it to gain 1 Stat Point (press C to spend).",
		Price = 150,
		Icon = "Tome",
	},
	RiftShard = { Item = "RiftShard", Count = 1, Price = 15 },
	HuskIchor = { Item = "HuskIchor", Count = 1, Price = 40 },
	EmberCore = { Item = "EmberCore", Count = 1, Price = 110 },
}

-- The Goods Merchant: gold paid per item you sell.
Market.SellPrice = {
	RiftShard = 6,
	HuskIchor = 16,
	EmberCore = 45,
}

-- How close (studs) you must stand to a stall to trade.
Market.Reach = 24

return Market
