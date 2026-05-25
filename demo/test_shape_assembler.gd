## Phase 4 test — attach to a Node3D in a blank 3D scene.
## Loads humanoid_base.tres and assembles a full biped silhouette using
## ShapeAssembler.  Press F6 (not F5) to run this scene.
##
## Expected result:
##   A standing humanoid figure at the scene origin, ~2.5 units tall.
##   The figure stands with feet at y = 0 and crown at y ≈ 2.47.
##
## Debug color legend (left side = cool, right side = warm, extremities = darker):
##   Midriff (waist)        Orange
##   Torso   (chest)        Red
##   Neck                   Amber
##   Head                   Yellow
##   Arm L / Arm R          Cyan / Magenta
##   Hand L / Hand R        Deep Cyan / Deep Magenta
##   Leg L / Leg R          Green / Gold
##   Foot L / Foot R        Deep Green / Deep Gold
##
## What to confirm:
##   • Torso tapers — chest wider at shoulders, midriff narrower at waist
##   • Arms hang from shoulder level, hands near hip level (T-pose at rest)
##   • Legs reach y = 0 (feet touch the grid)
##   • All face edges read as hard — no smooth shading anywhere
##   • Left side uses cool colors; right side uses warm colors
extends Node3D

@export var definition: CreatureDefinition = preload("res://creatures/definitions/humanoid_base.tres")

func _ready() -> void:
	ShapeAssembler.assemble(definition, self)
