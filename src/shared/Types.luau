--!strict
-- Shared type definitions.

-- Plain string aliases: literal unions fight table iteration in the current type checker.
export type ElementId = string -- "Fire" | "Ice" | "Lightning" | "Wind" | "Earth" | "Shadow"
export type StatusId = string -- "Burn" | "Chill" | "Shock" | "Knockback" | "Armor" | "Drain"
export type SlotId = string -- "Attack" | "Special" | "Cast" | "Dash"

export type Element = {
	id: ElementId,
	displayName: string,
	color: Color3,
	status: StatusId,
}

export type Skill = {
	slot: SlotId,
	displayName: string,
	damage: number,
	cooldown: number,
	range: number, -- distance in front of the player where the hit lands
	radius: number, -- size of the hit area
}

export type Fusion = {
	id: string,
	displayName: string,
	elements: { ElementId },
	color: Color3,
	damageMultiplier: number,
	radiusMultiplier: number,
	statuses: { StatusId },
	description: string,
}

-- One slot's state during a run.
export type SlotState = {
	elements: { [ElementId]: number }, -- element -> level
	fusion: string?, -- fusion id once two elements are merged
}

export type Loadout = { [SlotId]: SlotState }

return {}
