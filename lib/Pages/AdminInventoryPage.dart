import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart'; // For generating unique IDs

class AdminInventoryPage extends StatefulWidget {
  const AdminInventoryPage({super.key});

  @override
  _AdminInventoryPageState createState() => _AdminInventoryPageState();
}

class _AdminInventoryPageState extends State<AdminInventoryPage> {
  final inv = Hive.box('inventory'); // Reference to the inventory Hive box

  // Controllers for the input fields
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();

  // For category filtering (similar to Cashier page)
  final List<String> _categories = ['ALL', 'FOOD', 'DRINKS', 'THINGS'];
  String _selectedCategory = 'ALL';
  String _searchQuery = ''; // For the search bar

  Map? _itemToEdit; // Holds the item data when editing
  String _selectedImagePath = 'food_placeholder.png'; // Default image

  // --- Utility Methods ---

  // Method to add or update an item
  void _saveItem() {
    final name = _nameController.text;
    final price = int.tryParse(_priceController.text) ?? 0;
    final stock = int.tryParse(_stockController.text) ?? 0;

    if (name.isEmpty || price <= 0 || stock < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields correctly.')),
      );
      return;
    }

    if (_itemToEdit == null) {
      // Add New Item
      final newItem = {
        'id': const Uuid().v4(), // Generate a unique ID
        'name': name,
        'price': price,
        'stock': stock,
        'category':
            _selectedCategory != 'ALL'
                ? _selectedCategory
                : 'FOOD', // Assign a category
        'imagePath': _selectedImagePath, // Store image path
      };
      inv.put(newItem['id'], newItem);
    } else {
      // Edit Existing Item
      final updatedItem = {
        'id': _itemToEdit!['id'],
        'name': name,
        'price': price,
        'stock': stock,
        'category': _selectedCategory,
        'imagePath': _selectedImagePath,
      };
      inv.put(updatedItem['id'], updatedItem);
    }

    _clearForm();
    // No need to setState explicitly here, ValueListenableBuilder will handle updates
  }

  // Method to delete an item
  void _deleteItem(dynamic itemKey) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Product'),
            content: const Text(
              'Are you sure you want to delete this product?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  inv.delete(itemKey);
                  _clearForm(); // Clear form if the deleted item was being edited
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  // Method to load item data into the form for editing
  void _editItem(Map item) {
    setState(() {
      _itemToEdit = item;
      _nameController.text = item['name'];
      _priceController.text = item['price'].toString();
      _stockController.text = item['stock'].toString();
      _selectedCategory = item['category'] ?? 'FOOD'; // Ensure category is set
      _selectedImagePath =
          item['imagePath'] ?? 'food_placeholder.png'; // Set image path
    });
  }

  // Method to clear the form fields and reset state
  void _clearForm() {
    setState(() {
      _itemToEdit = null;
      _nameController.clear();
      _priceController.clear();
      _stockController.clear();
      _selectedCategory = 'ALL'; // Reset category filter
      _selectedImagePath = 'food_placeholder.png'; // Reset to default image
    });
  }

  // Placeholder for image selection - we'll make this functional later
  void _selectImage() {
    // In a real app, this would open an image picker.
    // For now, let's just cycle through some dummy image paths or mock a selection.
    List<String> dummyImages = [
      'food_bread.png',
      'drink_water.png',
      'food_chips.png',
      'drink_coffee.png',
      'things_detergent.png',
      'food_placeholder.png', // Keep a generic placeholder
    ];
    setState(() {
      // Cycle to the next image in the dummy list
      int currentIndex = dummyImages.indexOf(_selectedImagePath);
      if (currentIndex == -1 || currentIndex == dummyImages.length - 1) {
        _selectedImagePath = dummyImages[0];
      } else {
        _selectedImagePath = dummyImages[currentIndex + 1];
      }
    });
    // You'd integrate an actual image picker here, e.g., using `image_picker` package:
    // final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    // if (pickedFile != null) {
    //   setState(() {
    //     _selectedImagePath = pickedFile.path;
    //   });
    // }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin'),
        centerTitle: true,
        automaticallyImplyLeading: false, // Hide back button as per design
      ),
      body: SafeArea(
        child: Row(
          children: [
            // LEFT SIDE: Product List & Search
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  // Search Bar
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Search Product',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                    ),
                  ),
                  // Category Tabs
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8.0,
                      horizontal: 8.0,
                    ),
                    child: SizedBox(
                      height: 40,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _categories.length,
                        itemBuilder: (_, i) {
                          final category = _categories[i];
                          final isSelected = category == _selectedCategory;
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4.0,
                            ),
                            child: FilterChip(
                              label: Text(category),
                              selected: isSelected,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() => _selectedCategory = category);
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  // Product List
                  Expanded(
                    child: ValueListenableBuilder(
                      valueListenable: inv.listenable(),
                      builder: (_, box, __) {
                        final allItems = inv.values.cast<Map>().toList();

                        // Filter by category
                        final categoryFilteredItems =
                            _selectedCategory == 'ALL'
                                ? allItems
                                : allItems
                                    .where(
                                      (item) =>
                                          item['category'] == _selectedCategory,
                                    )
                                    .toList();

                        // Filter by search query
                        final filteredItems =
                            categoryFilteredItems.where((item) {
                              final name = item['name']?.toLowerCase() ?? '';
                              final query = _searchQuery.toLowerCase();
                              return name.contains(query);
                            }).toList();

                        if (filteredItems.isEmpty) {
                          return Center(
                            child: Text(
                              _searchQuery.isEmpty
                                  ? 'No items in "$_selectedCategory" category.'
                                  : 'No items found for "$_searchQuery".',
                            ),
                          );
                        }

                        return ListView.builder(
                          itemCount: filteredItems.length,
                          itemBuilder: (_, i) {
                            final item = filteredItems[i];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              child: ListTile(
                                leading:
                                    item['imagePath'] != null &&
                                            item['imagePath'].isNotEmpty
                                        ? SizedBox(
                                          width: 50,
                                          height: 50,
                                          child: Image.asset(
                                            'assets/images/${item['imagePath']}',
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                        : const Icon(
                                          Icons.broken_image,
                                          size: 50,
                                        ),
                                title: Text(item['name']),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Harga Rp ${item['price']}'),
                                    Text('Stok ${item['stock']}'),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit,
                                        color: Colors.blue,
                                      ),
                                      onPressed: () => _editItem(item),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      onPressed: () => _deleteItem(item['id']),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            // Vertical Divider
            const VerticalDivider(width: 1, thickness: 1),

            // RIGHT SIDE: Add/Edit Product Form
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _itemToEdit == null ? 'Add Product' : 'Edit Product',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Image Input
                      GestureDetector(
                        onTap: _selectImage,
                        child: Container(
                          height: 150,
                          decoration: BoxDecoration(
                            // *** FIX APPLIED HERE: Using BorderStyle.solid ***
                            border: Border.all(
                              color: Colors.grey.shade400,
                              // Changed 'dashed' to the standard 'solid' style
                              style: BorderStyle.solid,
                              width:
                                  1.0, // Optionally make it thinner if needed
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child:
                              _selectedImagePath.isNotEmpty
                                  ? Image.asset(
                                    'assets/images/$_selectedImagePath',
                                    fit: BoxFit.contain,
                                  )
                                  : const Center(
                                    child: Icon(
                                      Icons.add_photo_alternate,
                                      size: 50,
                                      color: Colors.grey,
                                    ),
                                  ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Category selection (DropDown or FilterChips)
                      DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                        ),
                        items:
                            _categories.map((String category) {
                              return DropdownMenuItem<String>(
                                value: category,
                                child: Text(category),
                              );
                            }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedCategory = newValue;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),

                      // Name Input
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Price Input
                      TextField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Price',
                          prefixText: 'Rp ',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Stock Input
                      TextField(
                        controller: _stockController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Stock',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Add/Update Button
                      ElevatedButton(
                        onPressed: _saveItem,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          _itemToEdit == null
                              ? 'Add Product'
                              : 'Update Product',
                        ),
                      ),
                      if (_itemToEdit != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: TextButton(
                            onPressed: _clearForm,
                            child: const Text('Cancel Edit'),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
