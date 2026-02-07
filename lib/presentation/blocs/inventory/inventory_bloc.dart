import 'package:flutter_bloc/flutter_bloc.dart';
import 'inventory_event.dart';
import 'inventory_state.dart';

class InventoryBloc extends Bloc<InventoryEvent, InventoryState> {
  InventoryBloc() : super(InventoryInitial()) {
    on<LoadInventory>(_onLoadInventory);
    on<AddFoodItem>(_onAddFoodItem);
    on<RemoveFoodItem>(_onRemoveFoodItem);
  }

  Future<void> _onLoadInventory(
    LoadInventory event,
    Emitter<InventoryState> emit,
  ) async {
    emit(InventoryLoading());
    try {
      // TODO: Load from repository
      await Future.delayed(const Duration(seconds: 1));
      emit(const InventoryLoaded([]));
    } catch (e) {
      emit(InventoryError(e.toString()));
    }
  }

  Future<void> _onAddFoodItem(
    AddFoodItem event,
    Emitter<InventoryState> emit,
  ) async {
    // TODO: Implement add logic
  }

  Future<void> _onRemoveFoodItem(
    RemoveFoodItem event,
    Emitter<InventoryState> emit,
  ) async {
    // TODO: Implement remove logic
  }
}
