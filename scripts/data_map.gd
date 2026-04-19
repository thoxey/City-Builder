extends Resource
class_name DataMap

## Cash surplus — running balance of tax income minus service overhead.
## Spent on decorative (nature) placement; growth buildings stay demand-bank gated.
## Starting grant of 1000 lets the player put down a few decoratives before tax kicks in.
@export var cash: int = 1000

@export var structures: Array[DataStructure]
