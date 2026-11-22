extends GutTest
## Qualité des effets du décor : nombre de particules.

var _saved_quality: Settings.Quality


func before_each() -> void:
	_saved_quality = Settings.quality


func after_each() -> void:
	Settings.quality = _saved_quality


func test_high_quality_keeps_every_particle() -> void:
	Settings.quality = Settings.Quality.HIGH
	assert_eq(Settings.particles(40), 40)


func test_low_quality_keeps_about_a_third() -> void:
	Settings.quality = Settings.Quality.LOW
	assert_eq(Settings.particles(40), 14)


func test_there_is_always_at_least_one_particle() -> void:
	Settings.quality = Settings.Quality.LOW
	assert_eq(Settings.particles(1), 1)
