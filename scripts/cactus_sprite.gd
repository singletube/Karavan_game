extends Sprite3D

func _ready() -> void:
	billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	pixel_size = 0.04
	texture = TextureGen.make_cactus()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	alpha_cut = Sprite3D.ALPHA_CUT_DISCARD
