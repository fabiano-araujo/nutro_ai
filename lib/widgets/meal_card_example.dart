import 'package:flutter/material.dart';
import '../models/food_model.dart';
import '../models/meal_model.dart';
import 'meal_card.dart';

/// Exemplo de uso do MealCard widget
class MealCardExample extends StatefulWidget {
  const MealCardExample({Key? key}) : super(key: key);

  @override
  State<MealCardExample> createState() => _MealCardExampleState();
}

class _MealCardExampleState extends State<MealCardExample> {
  late Meal meal;

  @override
  void initState() {
    super.initState();

    // Dados de exemplo baseados no código React fornecido
    final foods = [
      Food(
        name: 'Egg',
        amount: '1 large',
        calories: 78,
        protein: 6,
        carbs: 1,
        fat: 5,
        emoji: '🥚',
        imageUrl: 'https://images.unsplash.com/photo-1587486913049-53fc88980cfc?w=200&h=200&fit=crop',
      ),
      Food(
        name: 'Couscous',
        amount: '100g',
        calories: 376,
        protein: 13,
        carbs: 77,
        fat: 1,
        emoji: '🍚',
        imageUrl: 'https://images.unsplash.com/photo-1596040033229-a0b0d1f6e2e3?w=200&h=200&fit=crop',
      ),
      Food(
        name: 'Milk',
        amount: '200ml',
        calories: 91,
        protein: 6,
        carbs: 9,
        fat: 3,
        emoji: '🥛',
        imageUrl: 'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=200&h=200&fit=crop',
      ),
    ];

    meal = Meal(
      id: '1',
      type: MealType.freeMeal,
      foods: foods,
    );
  }

  void _handleMealTypeChange(MealType newType) {
    setState(() {
      meal = meal.copyWith(type: newType);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Meal type changed to: ${newType.toString().split('.').last}'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _handleEditFood() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Edit food functionality - to be implemented'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _handleAddFood() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Add food functionality - to be implemented'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Meal Card Example'),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF7F9FC),
              Color(0xFFE8EEF5),
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children: [
              MealCard(
                meal: meal,
                onEditFood: _handleEditFood,
                onMealTypeChanged: _handleMealTypeChange,
                onAddFood: _handleAddFood,
              ),
              SizedBox(height: 20),

              // Informações sobre os totais
              Padding(
                padding: EdgeInsets.all(16),
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Meal Summary',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        SizedBox(height: 12),
                        _buildInfoRow('Total Calories', '${meal.totalCalories} kcal'),
                        _buildInfoRow('Total Protein', '${meal.totalProtein.toStringAsFixed(1)}g'),
                        _buildInfoRow('Total Carbs', '${meal.totalCarbs.toStringAsFixed(1)}g'),
                        _buildInfoRow('Total Fat', '${meal.totalFat.toStringAsFixed(1)}g'),
                        _buildInfoRow('Foods Count', '${meal.foods.length}'),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
