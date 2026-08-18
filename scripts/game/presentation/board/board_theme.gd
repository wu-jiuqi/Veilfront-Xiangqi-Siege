class_name BoardTheme
extends Resource

@export var theme_id: StringName = &""
@export var cell_size: Vector2 = Vector2(128.0, 128.0)
@export var terrain_tileset: TileSet
@export var zone_tileset: TileSet
@export var decal_tileset: TileSet
@export var grid_palette: Dictionary = {}
@export var region_label_style: Dictionary = {}
@export var wall_scene_set: Array[PackedScene] = []
@export var piece_scene_set: Array[PackedScene] = []
@export var flag_scene: PackedScene
@export var ghost_scene: PackedScene
@export var marker_assets: Dictionary = {}
@export var fog_material: Material
@export var effect_scenes: Array[PackedScene] = []
