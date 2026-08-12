import 'package:flutter_test/flutter_test.dart';
import 'package:pawdo/features/pet/models/pet_state.dart';

void main() {
  test('legacy pet documents receive safe complete defaults', () {
    final pet = PetState.fromMap(const {'name': '', 'energy': 500});

    expect(pet.name, 'Pawdo');
    expect(pet.hunger, 70);
    expect(pet.happiness, 80);
    expect(pet.energy, 100);
    expect(pet.hygiene, 85);
    expect(pet.toiletNeed, 15);
  });

  test('sleeping has priority over other mood conditions', () {
    final pet = PetState.fromMap(const {
      'isSleeping': true,
      'hunger': 0,
      'hygiene': 0,
      'energy': 0,
    });

    expect(pet.mood, PetMood.sleeping);
    expect(pet.moodLabel, 'Dormido');
  });

  test('pet mood reports urgent care needs before happiness', () {
    expect(
      PetState.fromMap(const {'hygiene': 20, 'happiness': 100}).mood,
      PetMood.dirty,
    );
    expect(
      PetState.fromMap(const {'hunger': 20, 'happiness': 100}).mood,
      PetMood.hungry,
    );
    expect(
      PetState.fromMap(const {'energy': 15, 'happiness': 100}).mood,
      PetMood.tired,
    );
  });

  test('healthy high stats make Pawdo excited', () {
    final pet = PetState.fromMap(const {
      'hunger': 90,
      'happiness': 95,
      'energy': 80,
      'hygiene': 90,
      'toiletNeed': 10,
    });

    expect(pet.mood, PetMood.excited);
    expect(pet.reaction, contains('jugar'));
  });
}
