// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:matrix/matrix.dart';
// import 'package:image_picker/image_picker.dart';

// class MatrixSelfProfileScreen extends StatefulWidget {
//   final Client client;

//   const MatrixSelfProfileScreen({Key? key, required this.client}) : super(key: key);

//   @override
//   _MatrixSelfProfileScreenState createState() => _MatrixSelfProfileScreenState();
// }

// class _MatrixSelfProfileScreenState extends State<MatrixSelfProfileScreen> {
//   late TextEditingController _displayNameController;
//   late TextEditingController _bioController;
//   bool _isEditing = false;
//   bool _isLoading = false;
//   XFile? _selectedProfileImage;

//   @override
//   void initState() {
//     super.initState();
//     _displayNameController = TextEditingController(
//       text: widget.client.userProfile?.displayName ?? ''
//     );
//     _bioController = TextEditingController(
//       text: widget.client.userProfile?.statusMessage ?? ''
//     );
//   }

//   @override
//   void dispose() {
//     _displayNameController.dispose();
//     _bioController.dispose();
//     super.dispose();
//   }

//   // Fetch user's current profile information
//   Future<Profile?> get _currentProfile async=> await widget.client.getProfileFromUserId(widget.client.userID!);

//   // Pick profile image from gallery
//   Future<void> _pickProfileImage() async {
//     final ImagePicker picker = ImagePicker();
//     final XFile? image = await picker.pickImage(
//       source: ImageSource.gallery,
//       maxWidth: 1000,
//       maxHeight: 1000,
//       imageQuality: 75,
//     );

//     if (image != null) {
//       setState(() {
//         _selectedProfileImage = image;
//       });
//     }
//   }

//   // Save profile changes
//   Future<void> _saveProfile() async {
//     setState(() {
//       _isLoading = true;
//     });

//     try {
//       // Update display name
//       if (_displayNameController.text != _currentProfile?.displayName) {
//         await widget.client.setDisplayName(
//           widget.client.userID!, 
//           _displayNameController.text
//         );
//       }

//       // Update profile image if selected
//       if (_selectedProfileImage != null) {
//         final File imageFile = File(_selectedProfileImage!.path);
//         await widget.client.setAvatarUrl(
//           widget.client.userID!, 
//           await widget.client.uploadContent(imageFile)
//         );
//       }

//       // Note: Matrix doesn't have a direct "bio" field, 
//       // so status message might be used as a workaround
//       // You may need to implement this via custom state or third-party method

//       setState(() {
//         _isEditing = false;
//         _isLoading = false;
//         _selectedProfileImage = null;
//       });

//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Profile updated successfully')),
//       );
//     } catch (e) {
//       setState(() {
//         _isLoading = false;
//       });

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Failed to update profile: $e')),
//       );
//     }
//   }

//   // Build profile image widget
//   Widget _buildProfileImage() {
//     return GestureDetector(
//       onTap: _isEditing ? _pickProfileImage : null,
//       child: Stack(
//         children: [
//           CircleAvatar(
//             radius: 60,
//             backgroundImage: _selectedProfileImage != null
//               ? FileImage(File(_selectedProfileImage!.path))
//               : (_currentProfile?.avatarUrl != null
//                   ? NetworkImage(_currentProfile!.avatarUrl.toString())
//                   : null),
//             child: _selectedProfileImage == null && _currentProfile?.avatarUrl == null
//               ? const Icon(Icons.person, size: 60)
//               : null,
//           ),
//           if (_isEditing)
//             Positioned(
//               bottom: 0,
//               right: 0,
//               child: Container(
//                 decoration: BoxDecoration(
//                   color: Colors.blue,
//                   borderRadius: BorderRadius.circular(20),
//                 ),
//                 child: const Padding(
//                   padding: EdgeInsets.all(4.0),
//                   child: Icon(Icons.edit, color: Colors.white, size: 20),
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }

//   // Build profile details
//   Widget _buildProfileDetails() {
//     if (_isEditing) {
//       return Column(
//         children: [
//           TextField(
//             controller: _displayNameController,
//             decoration: const InputDecoration(
//               labelText: 'Display Name',
//               border: OutlineInputBorder(),
//             ),
//           ),
//           const SizedBox(height: 16),
//           TextField(
//             controller: _bioController,
//             decoration: const InputDecoration(
//               labelText: 'Status Message',
//               border: OutlineInputBorder(),
//             ),
//             maxLines: 3,
//           ),
//         ],
//       );
//     }

//     return Column(
//       children: [
//         Text(
//           _currentProfile?.displayName ?? 'No Name',
//           style: Theme.of(context).textTheme.headlineSmall,
//         ),
//         const SizedBox(height: 8),
//         Text(
//           _currentProfile?.statusMessage ?? 'No status',
//           style: Theme.of(context).textTheme.bodyMedium,
//           textAlign: TextAlign.center,
//         ),
//       ],
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('My Profile'),
//         actions: [
//           if (!_isEditing)
//             IconButton(
//               icon: const Icon(Icons.edit),
//               onPressed: () => setState(() => _isEditing = true),
//             ),
//         ],
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.center,
//           children: [
//             _buildProfileImage(),
//             const SizedBox(height: 16),
//             _buildProfileDetails(),
//             if (_isEditing)
//               Padding(
//                 padding: const EdgeInsets.only(top: 16.0),
//                 child: _isLoading
//                   ? const CircularProgressIndicator()
//                   : Row(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         ElevatedButton(
//                           onPressed: _saveProfile,
//                           child: const Text('Save Changes'),
//                         ),
//                         const SizedBox(width: 16),
//                         TextButton(
//                           onPressed: () => setState(() {
//                             _isEditing = false;
//                             _selectedProfileImage = null;
//                             _displayNameController.text = 
//                               _currentProfile?. ?? '';
//                             _bioController.text = 
//                               _currentProfile?.statusMessage ?? '';
//                           }),
//                           child: const Text('Cancel'),
//                         ),
//                       ],
//                     ),
//               ),
//           ],
//         ),
//       ),
//     );
//   }
// }