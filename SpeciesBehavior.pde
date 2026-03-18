abstract class SpeciesBehavior {
  abstract void updateMovement(AnimalAgent agent, ArrayList<FoodPellet> foods);
  abstract void tryEat(AnimalAgent agent, ArrayList<FoodPellet> foods);
}
