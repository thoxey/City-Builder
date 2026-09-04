extends GutTest

const COHORT := {
	"cohort_id": "test",
	"quality_importance_centre": {"opportunity": 0.4, "liveability": 0.3, "beauty": 0.2, "belonging": 0.1},
	"manifestation_centre": {
		"opportunity": {"identity": 0.8, "freedom": 0.1, "care": 0.1},
		"liveability": {"identity": 0.1, "freedom": 0.8, "care": 0.1},
		"beauty": {"identity": 0.1, "freedom": 0.1, "care": 0.8},
		"belonging": {"identity": 0.5, "freedom": 0.4, "care": 0.1},
	},
	"variation": 0.1,
	"candidate_weight": 1.0,
}

func test_same_seed_reproduces_and_different_seed_varies() -> void:
	var generator := CommunityPersonalityGenerator.new([COHORT], 1, 0.8, 1.2)
	var first := generator.generate(12345, 1)
	var again := generator.generate(12345, 1)
	var other := generator.generate(12346, 2)
	assert_eq(first.to_dict(), again.to_dict())
	assert_ne(first.quality_importance, other.quality_importance)

func test_every_vector_normalizes_and_qualities_vary_independently() -> void:
	var resident := CommunityPersonalityGenerator.new([COHORT]).generate(41, 3)
	var quality_total := 0.0
	for value in resident.quality_importance.values(): quality_total += value
	assert_almost_eq(quality_total, 1.0, 0.0001)
	for quality in CommunityConstants.QUALITIES:
		var row_total := 0.0
		for value in resident.manifestation_weights[quality].values(): row_total += value
		assert_almost_eq(row_total, 1.0, 0.0001)
	assert_ne(resident.manifestation_weights["opportunity"], resident.manifestation_weights["beauty"])

func test_sensitivities_stay_in_authored_bounds() -> void:
	var resident := CommunityPersonalityGenerator.new([COHORT], 1, 0.8, 1.2).generate(5, 1)
	for value in resident.sensitivities.values():
		assert_between(value, 0.8, 1.2)

func test_declared_candidate_stream_is_identical_ten_times() -> void:
	var generator := CommunityPersonalityGenerator.new([COHORT], 1, 0.8, 1.2)
	var expected: Array = []
	for id in 20: expected.append(generator.generate(9000 + id, id + 1).to_dict())
	for _run in 10:
		var actual: Array = []
		for id in 20: actual.append(generator.generate(9000 + id, id + 1).to_dict())
		assert_eq(actual, expected)
