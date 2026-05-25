class_name BoneAnchor
extends Node3D

## A lightweight anchor node that marks a joint in the creature's skeleton.
##
## One BoneAnchor per logical bone — ShapeAssembler creates these to form the
## spatial hierarchy; SkeletonInferer (Phase 6) walks the tree and converts them
## into a Skeleton3D.
##
## bone_name  — matches the bone name in the eventual Skeleton3D (set by ShapeAssembler)
## axis       — the joint's primary rotation axis (read by AnimationController in Phase 9+)

@export var bone_name: String = ""
@export var axis: Vector3 = Vector3.UP
