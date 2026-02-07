import 'package:equatable/equatable.dart';

abstract class InventoryEvent extends Equatable {
  const InventoryEvent();

  @override
  List<Object?> get props => [];
}

class LoadInventory extends InventoryEvent {}

class AddFoodItem extends InventoryEvent {
  final String name;
  final String barcode;
  final DateTime expiryDate;

  const AddFoodItem({
    required this.name,
    required this.barcode,
    required this.expiryDate,
  });

  @override
  List<Object?> get props => [name, barcode, expiryDate];
}

class RemoveFoodItem extends InventoryEvent {
  final String itemId;

  const RemoveFoodItem(this.itemId);

  @override
  List<Object?> get props => [itemId];
}
